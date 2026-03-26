# 🤖 Telegram Server Management Bot

[RU] Универсальный Bash-бот для управления сервером Debian/Ubuntu через Telegram. Позволяет обновлять систему, управлять контейнерами Docker и контролировать питание сервера.

[EN] A versatile Bash bot for managing Debian/Ubuntu servers via Telegram. It allows you to update the system, manage Docker containers, and control server power.

---

## 🇷🇺 Инструкция на русском

### Основные функции:
*   **Обновления**: Ручной и автоматический запуск `unattended-upgrades`.
*   **Docker**: Список контейнеров, запуск, остановка, удаление и обновление образов (`pull`).
*   **Питание**: Перезагрузка и выключение. Умная кнопка перезагрузки при необходимости.
*   **Расписание**: Настройка времени проверок через интерфейс бота.

> ⚠️ **ВНИМАНИЕ**: Функции поиска (`Search App`) и добавления приложений в список автообновления временно **не работают** из-за различий в форматах репозиториев. Исправление ожидается в следующих версиях.

### Установка:
1. Создайте бота в [@BotFather](https://t.me/botfather) и получите токен.
2. Узнайте свой ID через [@userinfobot](https://t.me/userinfobot).
3. Запустите скрипт на сервере:
```bash
wget https://raw.githubusercontent.com/dinlo/Telegram-Server-Management-Bot/main/server_bot.sh
chmod +x server_bot.sh
sudo ./server_bot.sh
```

---

## 🇺🇸 English Instruction

### Key Features:
*   **Updates**: Manual and automated `unattended-upgrades` execution.
*   **Docker**: Container list, start, stop, delete, and image pull updates.
*   **Control**: Reboot and shutdown. Smart reboot button when required by the system.
*   **Scheduling**: Configure check times directly via the bot interface.

> ⚠️ **NOTICE**: The `Search App` and "Add to auto-update" features are **temporarily unavailable** due to repository format inconsistencies. A fix is expected in future updates.

### Installation:
1. Create a bot via [@BotFather](https://t.me/botfather) and get the Token.
2. Get your Chat ID via [@userinfobot](https://t.me/userinfobot).
3. Run the script on your server:
```bash
wget https://raw.githubusercontent.com/dinlo/Telegram-Server-Management-Bot/main/server_bot.sh
chmod +x server_bot.sh
sudo ./server_bot.sh
```
```

