#!/bin/bash

# Останавливаем скрипт при ошибках
set -e

echo "--- УСТАНОВКА AMNEZIAWG (WARP GATEWAY) ---"

# 1. Установка Go
echo "Загрузка и установка Go 1.25.6..."
wget https://go.dev/dl/go1.25.6.linux-amd64.tar.gz
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.25.6.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# 2. Сборка AmneziaWG-go
echo "Клонирование и сборка amneziawg-go..."
apt-get update && apt-get install -y git make build-essential
git clone https://github.com/amnezia-vpn/amneziawg-go
cd amneziawg-go
make && make install
cd ..

# 3. Установка модуля ядра и инструментов
echo "Добавление репозитория и установка amneziawg-dkms..."
apt-get install -y software-properties-common
add-apt-repository -y ppa:amnezia/ppa
apt-get update
apt-get install -y amneziawg-dkms amneziawg-tools

# Проверка модуля
echo "Загрузка модуля ядра..."
modprobe amneziawg || echo "Предупреждение: Модуль не загрузился."
lsmod | grep amneziawg

# 4. Создание конфигурации
mkdir -p /etc/amnezia/amneziawg/
CONFIG_PATH="/etc/amnezia/amneziawg/awg0.conf"

echo "--------------------------------------------------------"
echo "СЕЙЧАС ОТКРОЕТСЯ РЕДАКТОР ДЛЯ ВАШЕГО WARP КОНФИГА"
echo "Вставьте данные (PrivateKey, Address, Endpoint, Маскировка)"
echo "После вставки: Ctrl+O, Enter, Ctrl+X"
echo "--------------------------------------------------------"
read -p "Нажмите [Enter], чтобы открыть редактор..."

nano "$CONFIG_PATH"

# 5. Запуск и проверка
echo "Поднимаем интерфейс awg0..."
# Используем awg-quick напрямую, как в твоем ТЗ
awg-quick up awg0 || { echo "Ошибка: Не удалось поднять интерфейс."; exit 1; }

echo "Проверка соединения через awg0 (Госуслуги)..."
curl --interface awg0 -I https://www.gosuslugi.ru || echo "Сайт недоступен, проверьте конфиг."

# 6. Автозагрузка
echo "Добавление в автозагрузку..."
# Для AmneziaWG-tools обычно используется префикс awg-quick
systemctl enable awg-quick@awg0

# 7. Вывод настроек для Xray
echo "--------------------------------------------------------"
echo "ГОТОВО! Интерфейс awg0 активен."
echo "Ниже приведены блоки для вашего Xray (outbounds и routing):"
cat <<EOF

--- OUTBOUND BLOCK ---
{
  "tag": "WARP_OUT",
  "protocol": "freedom",
  "streamSettings": {
    "sockopt": {
      "interface": "awg0"
    }
  }
}

--- ROUTING RULES ---
{
  "network": "tcp,udp",
  "outboundTag": "WARP_OUT"
}
EOF
echo "--------------------------------------------------------"
