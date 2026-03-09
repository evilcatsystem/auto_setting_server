#!/bin/bash

# Останавливаем скрипт при ошибках
set -e

echo "--- Настройка сервера (Ubuntu 22/24) ---"

# 1. Добавление пользователя
read -p "Введите имя нового пользователя: " NEW_USER
useradd $NEW_USER -d /home/$NEW_USER -m -G sudo -s /bin/bash
echo "Установите пароль для $NEW_USER:"
passwd $NEW_USER

# 2. Оптимизация сети (BBR)
echo "Включение BBR..."
if ! grep -q "net.core.default_qdisc=fq" /etc/sysctl.conf; then
    echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
    echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
    sysctl -p
fi

# 3. Отключение IPv6
read -p "Отключить IPv6? (y/n): " DISABLE_IPV6
if [[ "$DISABLE_IPV6" == "y" ]]; then
    sed -i '/net.ipv6.conf/d' /etc/sysctl.conf
    echo "net.ipv6.conf.all.disable_ipv6 = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" >> /etc/sysctl.conf
    echo "net.ipv6.conf.lo.disable_ipv6 = 1" >> /etc/sysctl.conf
    sysctl -p
fi

# 4. Настройка SSH порта (Универсальный метод для Ubuntu 22/24)
read -p "Введите новый порт для SSH (вместо 22): " SSH_PORT
SOCKET_FILE="/usr/lib/systemd/system/ssh.socket"

if [ -f "$SOCKET_FILE" ]; then
    echo "Меняем порт в ssh.socket..."
    # Регулярка, которая удаляет всё после ListenStream= и ставит твой порт
    sed -i "s/^ListenStream=.*/ListenStream=$SSH_PORT/" "$SOCKET_FILE"
    
    # На случай, если в файле несколько ListenStream (как часто бывает в 24.04)
    # Этот метод гарантирует, что мы слушаем только твой порт
    systemctl daemon-reload
    systemctl restart ssh.socket
else
    echo "ssh.socket не найден, правим классический sshd_config..."
fi

# В любом случае правим основной конфиг для синхронизации
sed -i "s/^#*Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
echo "Настройка политик аутентификации ssh..."
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart ssh

# 5. Настройка UFW
read -p "Настроить файрвол UFW? (y/n): " INSTALL_UFW
if [[ "$INSTALL_UFW" == "y" ]]; then
    apt-get update && apt-get install -y ufw

    read -p "Порт для VLESS (например, 443): " VLESS_PORT
    read -p "IP адрес панели: " PANEL_IP
    read -p "Порт взаимодействия (например, 2222): " PANEL_PORT

    echo "y" | ufw reset
    ufw default deny incoming
    ufw default allow outgoing

    # Открываем порты
    ufw allow "$SSH_PORT"/tcp
    ufw allow from "$PANEL_IP" to any port "$PANEL_PORT" proto tcp
    ufw allow "$VLESS_PORT"/tcp
    ufw allow "$VLESS_PORT"/udp

    echo "y" | ufw enable
    ufw status
fi

echo "-----------------------------------------------"
echo "ГОТОВО! Новый порт SSH: $SSH_PORT"
echo "Пользователь: $NEW_USER"
echo "Проверь соединение: ssh -p $SSH_PORT $NEW_USER@$(hostname -I | awk '{print $1}')"
