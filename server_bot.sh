#!/bin/bash

# --- CONFIGURATION ---
CONF_FILE="/etc/tg_bot.conf"
APT_CONF="/etc/apt/apt.conf.d/50unattended-upgrades"
LOG_PATH="/var/log/unattended-upgrades/tg_bot.log"
SERVICE_FILE="/etc/systemd/system/tg-server-bot.service"
CRON_FILE="/etc/cron.d/tg-bot-sched"

# Colors
G='\033[0;32m'; R='\033[0;31m'; Y='\033[1;33m'; B='\033[0;34m'; NC='\033[0m'

# --- 1. SYSTEM FUNCTIONS ---

install_deps() {
    echo -e "${B}Checking dependencies...${NC}"
    apt update > /dev/null 2>&1
    for pkg in unattended-upgrades curl cron jq coreutils grep; do
        command -v $pkg &> /dev/null || apt install -y $pkg > /dev/null 2>&1
    done
    if ! command -v docker &> /dev/null; then
        apt install -y docker.io || apt install -y docker-ce > /dev/null 2>&1
    fi
    if ! grep -q "// BEGIN USER APPS" "$APT_CONF"; then
        sed -i '/Unattended-Upgrade::Allowed-Origins {/a \        // BEGIN USER APPS\n        // END USER APPS' "$APT_CONF"
    fi
    [ ! -f "$CONF_FILE" ] && setup_config
    cat << EOF > "$SERVICE_FILE"
[Unit]
Description=Telegram Server Management Bot
After=network.target
[Service]
ExecStart=/bin/bash $(realpath "$0") --run
Restart=always
User=root
[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload && systemctl enable --now tg-server-bot.service
    update_cron
    echo -e "${G}Installation complete! Send /start to your bot in Telegram.${NC}"
}

setup_config() {
    echo "--- Telegram Bot Setup ---"
    read -p "API Token: " TG_TOKEN
    read -p "Chat ID: " TG_CHAT_ID
    read -p "Server Group Name: " GRP
    cat << EOF > "$CONF_FILE"
TG_TOKEN="$TG_TOKEN"
TG_CHAT_ID="$TG_CHAT_ID"
GROUP_NAME="$GRP"
TIME_SYS="04:00"
TIME_APPS="03:00"
TIME_DOCKER="05:00"
STATE="IDLE"
LAST_UPDATE_ID=0
EOF
    chmod 600 "$CONF_FILE"
}

update_cron() {
    source "$CONF_FILE"
    {
        echo "$(echo $TIME_SYS | cut -d: -f2) $(echo $TIME_SYS | cut -d: -f1) * * * root $(realpath $0) --cron-sys"
        echo "$(echo $TIME_APPS | cut -d: -f2) $(echo $TIME_APPS | cut -d: -f1) * * * root $(realpath $0) --cron-apps"
        echo "$(echo $TIME_DOCKER | cut -d: -f2) $(echo $TIME_DOCKER | cut -d: -f1) * * * root $(realpath $0) --cron-docker"
    } > "$CRON_FILE"
    systemctl restart cron
}

# --- 2. TELEGRAM API ---

send_msg() {
    source "$CONF_FILE"
    local text="$1"; local kb="$2"; local mid="$3"
    local url="https://api.telegram.org/bot$TG_TOKEN/sendMessage"
    [ -n "$mid" ] && url="https://api.telegram.org/bot$TG_TOKEN/editMessageText"
    curl -s -X POST "$url" -d "chat_id=$TG_CHAT_ID" ${mid:+-d "message_id=$mid"} -d "text=$text" -d "parse_mode=HTML" -d "reply_markup=$kb" > /dev/null
}

send_doc() {
    source "$CONF_FILE"
    curl -s -X POST "https://api.telegram.org/bot$TG_TOKEN/sendDocument" -F "chat_id=$TG_CHAT_ID" -F "document=@$1" -F "caption=$2" > /dev/null
}

# --- 3. MENUS ---

menu_main() {
    local kb='{"inline_keyboard":[[{"text":"🔄 Updates","callback_data":"m_upd"},{"text":"🐳 Docker","callback_data":"m_dock"}],[{"text":"🎮 Control","callback_data":"m_ctrl"},{"text":"⚙️ Settings","callback_data":"m_sett"}],[{"text":"📊 Status","callback_data":"sys_status"}]]}'
    send_msg "<b>🖥 Group: $GROUP_NAME</b>%0ASelect management section:" "$kb" "$1"
}

menu_updates() {
    local kb='{"inline_keyboard":[[{"text":"➕ Add App","callback_data":"upd_add_l"},{"text":"🔍 Search App (BETA)","callback_data":"upd_search"}],[{"text":"➖ Remove App","callback_data":"upd_rem_l"}],[{"text":"🚀 Update Tracked","callback_data":"run_upd_track"}],[{"text":"🌟 Update All","callback_data":"run_upd_all"}],[{"text":"⬅️ Back to Menu","callback_data":"m_main"}]]}'
    send_msg "<b>📦 Updates Management</b>" "$kb" "$1"
}

menu_docker() {
    local kb='{"inline_keyboard":[[{"text":"📋 List Containers","callback_data":"dk_list"},{"text":"🆙 Image Updates","callback_data":"dk_img_l"}],[{"text":"▶️ Start","callback_data":"dk_sel_start"},{"text":"⏹ Stop","callback_data":"dk_sel_stop"}],[{"text":"🗑 Delete","callback_data":"dk_sel_del"}],[{"text":"⬅️ Back to Menu","callback_data":"m_main"}]]}'
    send_msg "<b>🐳 Docker Management</b>" "$kb" "$1"
}

# --- 4. DAEMON LOGIC ---

run_daemon() {
    while true; do
        source "$CONF_FILE"
        UPD=$(curl -s "https://api.telegram.org/bot$TG_TOKEN/getUpdates?offset=$((LAST_UPDATE_ID + 1))&timeout=20")
        echo "$UPD" | jq -c '.result[]' | while read -r u; do
            ID=$(echo "$u" | jq -r '.update_id'); sed -i "s/LAST_UPDATE_ID=.*/LAST_UPDATE_ID=$ID/" "$CONF_FILE"
            CHAT=$(echo "$u" | jq -r '.message.chat.id // .callback_query.message.chat.id')
            [ "$CHAT" != "$TG_CHAT_ID" ] && continue
            
            TEXT=$(echo "$u" | jq -r '.message.text // empty')
            DATA=$(echo "$u" | jq -r '.callback_query.data // empty')
            MID=$(echo "$u" | jq -r '.callback_query.message.message_id // empty')

            # --- INPUT HANDLING ---
            if [ "$STATE" != "IDLE" ] && [ -n "$TEXT" ]; then
                if [[ $TEXT =~ ^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$ ]]; then
                    sed -i "s/$STATE=.*/$STATE=\"$TEXT\"/;s/STATE=.*/STATE=\"IDLE\"/" "$CONF_FILE"
                    update_cron && send_msg "✅ Schedule updated to $TEXT"
                else send_msg "❌ Use HH:MM format."; fi
                sed -i "s/STATE=.*/STATE=\"IDLE\"/" "$CONF_FILE"
                continue
            fi

            # --- CALLBACKS ---
            case "$DATA" in
                "m_main") menu_main "$MID" ;;
                "m_upd") menu_updates "$MID" ;;
                "m_dock") menu_docker "$MID" ;;
                "m_sett") 
                    source "$CONF_FILE"
                    kb='{"inline_keyboard":[[{"text":"🕒 System: '$TIME_SYS'","callback_data":"st_sys"}],[{"text":"🕒 Apps: '$TIME_APPS'","callback_data":"st_apps"}],[{"text":"🕒 Docker: '$TIME_DOCKER'","callback_data":"st_dock"}],[{"text":"⬅️ Back","callback_data":"m_main"}]]}'
                    send_msg "<b>⚙️ Settings</b>" "$kb" "$MID" ;;
                "m_ctrl")
                    kb='{"inline_keyboard":['
                    [ -f /var/run/reboot-required ] && kb+='[{"text":"♻️ Reboot Now (REQ)","callback_data":"srv_reboot"}],'
                    kb+='[{"text":"🔄 Reboot","callback_data":"srv_reboot"},{"text":"🛑 Shutdown","callback_data":"srv_poweroff"}],[{"text":"⬅️ Back","callback_data":"m_main"}]]}'
                    send_msg "<b>🎮 Control</b>" "$kb" "$MID" ;;
                
                "run_upd_all") send_msg "⏳ Working..." "" "$MID"; apt update && /usr/bin/unattended-upgrade > "$LOG_PATH" 2>&1; send_doc "$LOG_PATH" "Log" ;;
                "dk_list") out=$(docker ps -a --format "table {{.Names}}\t{{.Status}}"); send_msg "<pre>$out</pre>" '{"inline_keyboard":[[{"text":"⬅️ Back","callback_data":"m_dock"}]]}' "$MID" ;;
                "srv_reboot") send_msg "♻️ Rebooting..."; reboot ;;
                "st_sys") sed -i "s/STATE=.*/STATE=\"TIME_SYS\"/" "$CONF_FILE"; send_msg "Send time (HH:MM):" ;;
            esac
            [ "$TEXT" == "/start" ] && menu_main
        done
        sleep 1
    done
}

# --- 5. EXECUTION ---
case "$1" in
    "--run") run_daemon ;;
    "--cron-sys") apt update > /dev/null; /usr/bin/unattended-upgrade > "$LOG_PATH" 2>&1; grep -q "upgraded" "$LOG_PATH" && send_doc "$LOG_PATH" "🔔 Update" ;;
    *) install_deps ;;
esac