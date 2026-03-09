Настройка сервера: SSH, Firewall и AmneziaWG (WARP)

Этот репозиторий содержит скрипты для быстрой подготовки защищенного сервера на базе Ubuntu 22.04 / 24.04. Решение включает оптимизацию сети, перенос SSH порта, настройку UFW и поднятие туннеля AmneziaWG для маршрутизации трафика через Cloudflare WARP.
Состав репозитория
1. setup.sh — Базовая подготовка сервера

Скрипт предназначен для "фундаментальной" настройки системы:

    Безопасность: Создает нового пользователя с sudo-правами и отключает вход для root.

    SSH: Переносит SSH на кастомный порт (поддерживает новый метод ssh.socket в Ubuntu 22/24) и принудительно включает вход по паролю (PasswordAuthentication yes).

    Сеть: Включает алгоритм BBR для ускорения TCP-соединений и позволяет отключить IPv6.

    Firewall (UFW): Интерактивно настраивает правила для SSH, портов VLESS и взаимодействия с панелью управления.

2. setup_warp.sh — Настройка AmneziaWG

Скрипт для создания выходного узла через Cloudflare WARP с маскировкой:

    Компиляция: Автоматически устанавливает Go 1.25.6 и собирает amneziawg-go из исходников.

    Модуль ядра: Устанавливает и загружает модуль amneziawg через DKMS.

    Интерактив: Запрашивает ваш конфиг (ключи, эндпоинты и параметры маскировки Jc, Jmin, S1...) через встроенный редактор.

    Xray Integration: Генерирует готовые JSON-блоки для вставки в секции outbounds и routing вашей панели (3X-UI и др.).

Использование

    Шаг 1: Базовая настройка
    Bash

    chmod +x setup.sh
    sudo ./setup.sh

    Шаг 2: Поднятие AmneziaWG
    Bash

    chmod +x setup_warp.sh
    sudo ./setup_warp.sh

⚠️ Важные заметки и решение проблем (Troubleshooting)
Ошибка: modprobe: FATAL: Module amneziawg not found

Самая частая проблема при установке AmneziaWG на свежих ядрах Ubuntu (например, 6.8.0-45-generic).

Суть проблемы: Система не может скомпилировать модуль ядра AmneziaWG, так как в системе отсутствуют "заголовки" (headers) текущего ядра. Без них DKMS (система сборки модулей) не знает, как "подружить" код AmneziaWG с вашей системой.

Симптомы:

    При запуске скрипта вы видите сообщение Module amneziawg not found.

    Команда lsmod | grep amneziawg ничего не выводит.

Решение:
Перед запуском setup_warp.sh или при возникновении ошибки выполните:
Bash

sudo apt-get update
sudo apt-get install -y linux-headers-$(uname -r)
sudo dpkg-reconfigure amneziawg-dkms

Это принудительно установит нужные исходники и пересоберет модуль под вашу версию ядра.
Ошибка: Connection closed после смены SSH порта

Если после работы setup.sh вас не пускает на новый порт:

    Проверьте, что в /etc/ssh/sshd_config раскомментирована строка PasswordAuthentication yes.

    В новых Ubuntu обязательно нужно перезагружать не только ssh.service, но и ssh.socket:
    Bash

    systemctl daemon-reload
    systemctl restart ssh.socket

Настройка Xray (Пример)

После выполнения всех скриптов, добавьте в вашу панель следующий выходной узел:
JSON

{
  "tag": "WARP_OUT",
  "protocol": "freedom",
  "streamSettings": {
    "sockopt": {
      "interface": "awg0"
    }
  }
}

И правило маршрутизации для нужных доменов или всего трафика на тег WARP_OUT.
