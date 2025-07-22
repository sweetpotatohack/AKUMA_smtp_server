#!/bin/bash

# 🔥 Феня's Advanced SMTP Server Setup with SSL/TLS 🔥
# Автоматическая установка и настройка Postfix с SSL/TLS шифрованием

set -e

echo "🔥 Феня's Advanced SMTP Server Setup with SSL/TLS 🔥"
echo ""

# Запрос домена
read -p "Введи домен для почтового сервера (например: mail.example.com): " DOMAIN

if [ -z "$DOMAIN" ]; then
    echo "❌ Домен не может быть пустым!"
    exit 1
fi

echo "[+] Обновление системы..."
sudo apt update

echo "[+] Установка зависимостей..."
sudo apt install -y postfix certbot

echo "[+] Остановка служб на портах 80/443 для получения сертификата..."
sudo systemctl stop nginx 2>/dev/null || true
sudo systemctl stop apache2 2>/dev/null || true

echo "[+] Получение SSL сертификата для $DOMAIN..."
sudo certbot certonly --standalone -d $DOMAIN

echo "[+] Создание резервной копии конфигурации Postfix..."
sudo cp /etc/postfix/main.cf /etc/postfix/main.cf.backup
sudo cp /etc/postfix/master.cf /etc/postfix/master.cf.backup

echo "[+] Настройка TLS/SSL в Postfix..."
sudo postconf -e "smtpd_use_tls=yes"
sudo postconf -e "smtpd_tls_security_level=encrypt"
sudo postconf -e "smtpd_tls_cert_file=/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
sudo postconf -e "smtpd_tls_key_file=/etc/letsencrypt/live/$DOMAIN/privkey.pem"
sudo postconf -e "smtpd_tls_CApath=/etc/ssl/certs"
sudo postconf -e "smtpd_tls_protocols=!SSLv2, !SSLv3, !TLSv1, !TLSv1.1"
sudo postconf -e "smtpd_tls_ciphers=high"
sudo postconf -e "smtpd_tls_exclude_ciphers=MD5, SRP, PSK, aDSS, aDH, aECDH"
sudo postconf -e "smtpd_tls_loglevel=1"
sudo postconf -e "smtpd_tls_auth_only=yes"

echo "[+] Настройка исходящих TLS соединений..."
sudo postconf -e "smtp_use_tls=yes"
sudo postconf -e "smtp_tls_security_level=may"
sudo postconf -e "smtp_tls_CApath=/etc/ssl/certs"
sudo postconf -e "smtp_tls_protocols=!SSLv2, !SSLv3, !TLSv1, !TLSv1.1"
sudo postconf -e "smtp_tls_ciphers=high"
sudo postconf -e "smtp_tls_exclude_ciphers=MD5, SRP, PSK, aDSS, aDH, aECDH"
sudo postconf -e "smtp_tls_loglevel=1"

echo "[+] Настройка задержки отправки писем (3 секунды)..."
sudo postconf -e "default_destination_rate_delay=3s"
sudo postconf -e "smtp_destination_rate_delay=3s"
sudo postconf -e "default_destination_concurrency_limit=2"
sudo postconf -e "smtp_destination_concurrency_limit=2"

echo "[+] Настройка портов для TLS (587, 465)..."
cat >> /etc/postfix/master.cf << MASTER_EOF

# Submission port 587 с обязательным TLS
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_tls_auth_only=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=
  -o smtpd_helo_restrictions=
  -o smtpd_sender_restrictions=
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING

# SMTPS port 465  
smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_reject_unlisted_recipient=no
  -o smtpd_client_restrictions=
  -o smtpd_helo_restrictions=
  -o smtpd_sender_restrictions=
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
  -o milter_macro_daemon_name=ORIGINATING
MASTER_EOF

echo "[+] Проверка конфигурации Postfix..."
sudo postfix check

echo "[+] Перезапуск Postfix..."
sudo systemctl restart postfix
sudo systemctl enable postfix

echo "[+] Проверка статуса..."
sudo systemctl status postfix --no-pager

echo "[+] Тестирование SSL соединения..."
echo "QUIT" | openssl s_client -connect $DOMAIN:465 -servername $DOMAIN | grep "Verify return code"

echo ""
echo "✅ Настройка завершена!"
echo "📧 SMTP Server: $DOMAIN"
echo "🔒 TLS Port 587 (Submission): Включен"
echo "🔒 SSL Port 465 (SMTPS): Включен"
echo "⏱️  Rate Limit: 3 секунды между письмами"
echo ""
echo "Для тестирования отправь письмо через порт 587 или 465 с TLS!"
echo "Как говорил мой дед: 'SSL без настройки — как замок без ключа!' 😂"
