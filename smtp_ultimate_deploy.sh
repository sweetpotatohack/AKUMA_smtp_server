#!/bin/bash
# ================================================
# Феня's Ultimate SMTP/IMAP Server Deployment Script
# Version: 5.0 FINAL BOSS EDITION
# ================================================
# Автор: Феня (легендарный хакер и гуру микросервисов)
# Email: dmitriyvisotskiydr15061991@gmail.com
# Описание: Полный деплой SMTP/IMAP сервера с Let's Encrypt, DKIM, SPF, DMARC
# Поддерживает: Postfix, Dovecot, OpenDKIM, Let's Encrypt
# Порты: 25, 587, 465 (SMTP), 143, 993 (IMAP), 110, 995 (POP3)
# ================================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функция для цветного вывода
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}$1${NC}"
}

# Параметры по умолчанию
DEFAULT_DOMAIN=""
DEFAULT_EMAIL_USER=""
DEFAULT_EMAIL_PASS=""
ADMIN_EMAIL="dmitriyvisotskiydr15061991@gmail.com"

# Функция для интерактивного ввода параметров
get_user_input() {
    print_header "=== ФЕНЯ'S ULTIMATE SMTP SETUP SCRIPT V5.0 ==="
    print_header "Конфигурация сервера для полного деплоя"
    print_header "=============================================="
    
    read -p "Введите домен (например: regxa.sbs): " DOMAIN
    read -p "Введите имя пользователя для почты (например: testuser): " EMAIL_USER
    read -s -p "Введите пароль для пользователя: " EMAIL_PASS
    echo
    read -p "Введите email для Let's Encrypt сертификатов (по умолчанию: $ADMIN_EMAIL): " LETSENCRYPT_EMAIL
    LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:-$ADMIN_EMAIL}
    echo
        read -p "Введите email для Let's Encrypt сертификатов: " LETSENCRYPT_EMAIL
    echo
    
    if [[ -z "$DOMAIN" || -z "$EMAIL_USER" || -z "$EMAIL_PASS" ]]; then
        print_error "Все поля обязательны для заполнения!"
        exit 1
    fi
    
    SERVER_IP=$(curl -s ifconfig.me)
    
    print_status "Настройки:"
    print_status "Домен: $DOMAIN"
    print_status "Поддомен почты: mail.$DOMAIN"
    print_status "IP сервера: $SERVER_IP"
    print_status "Пользователь: $EMAIL_USER@$DOMAIN"
    print_status "Админ почта: $ADMIN_EMAIL"
    
    read -p "Продолжить? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Установка отменена"
        exit 1
    fi
}

# Функция проверки DNS
check_dns() {
    print_status "Проверяем DNS записи..."
    
    if ! dig +short mail.$DOMAIN A | grep -q $SERVER_IP; then
        print_warning "DNS запись mail.$DOMAIN не указывает на $SERVER_IP"
        print_warning "Убедитесь, что добавили A-запись перед продолжением"
    fi
    
    if ! dig +short $DOMAIN MX | grep -q "mail.$DOMAIN"; then
        print_warning "MX запись для $DOMAIN не найдена"
    fi
}

# Функция установки пакетов
install_packages() {
    print_status "Обновляем систему и устанавливаем пакеты..."
    
    export DEBIAN_FRONTEND=noninteractive
    apt update
    apt upgrade -y
    
    # Устанавливаем основные пакеты
    apt install -y postfix dovecot-core dovecot-imapd dovecot-pop3d dovecot-lmtpd \
                   opendkim opendkim-tools ssl-cert certbot bind9-dnsutils \
                   mailutils net-tools
    
    print_status "Пакеты установлены успешно"
}

# Функция настройки hostname
setup_hostname() {
    print_status "Настраиваем hostname..."
    
    hostnamectl set-hostname mail.$DOMAIN
    echo "127.0.0.1 mail.$DOMAIN" >> /etc/hosts
    
    # Обновляем /etc/mailname
    echo "mail.$DOMAIN" > /etc/mailname
}

# Функция получения Let's Encrypt сертификата
setup_letsencrypt() {
    print_status "Получаем сертификат Let's Encrypt..."
    
    # Останавливаем службы для получения сертификата
    systemctl stop postfix dovecot nginx apache2 2>/dev/null || true
    
    # Получаем сертификат
    certbot certonly --standalone \
        --agree-tos \
        --email ${LETSENCRYPT_EMAIL:-$ADMIN_EMAIL} \
        --no-eff-email \
        -d mail.$DOMAIN \
        --non-interactive \
        --force-renewal
    
    if [ ! -f "/etc/letsencrypt/live/mail.$DOMAIN/fullchain.pem" ]; then
        print_error "Не удалось получить сертификат Let's Encrypt!"
        print_error "Проверьте DNS записи и доступность порта 80"
        exit 1
    fi
    
    print_status "Сертификат Let's Encrypt получен успешно"
}

# Функция настройки DKIM
setup_dkim() {
    print_status "Настраиваем DKIM..."
    
    # Создаём директорию для DKIM
    mkdir -p /etc/opendkim/keys/$DOMAIN
    
    # Генерируем DKIM ключи
    opendkim-genkey -s default -d $DOMAIN -D /etc/opendkim/keys/$DOMAIN/
    
    # Устанавливаем права
    chown opendkim:opendkim /etc/opendkim/keys/$DOMAIN/default.private
    chmod 600 /etc/opendkim/keys/$DOMAIN/default.private
    
    # Настраиваем opendkim.conf
    cat > /etc/opendkim.conf << DKIM_EOF
# OpenDKIM Configuration
Syslog                  yes
SyslogSuccess           yes
LogWhy                  yes
Canonicalization        relaxed/simple
Mode                    sv
SubDomains              no
AutoRestart             yes
AutoRestartRate         10/1M
Background              yes
DNSTimeout              5
SignatureAlgorithm      rsa-sha256

# Домен и селектор
Domain                  $DOMAIN
Selector                default
KeyFile                 /etc/opendkim/keys/$DOMAIN/default.private

# Сокет для Postfix
Socket                  inet:8891@localhost

# Доверенные хосты
ExternalIgnoreList      /etc/opendkim/trusted.hosts
InternalHosts           /etc/opendkim/trusted.hosts

# Настройки подписи
SigningTable            refile:/etc/opendkim/signing.table
KeyTable                refile:/etc/opendkim/key.table

# PID файл для systemd
PidFile                 /run/opendkim/opendkim.pid
DKIM_EOF
    
    # Создаём файл доверенных хостов
    cat > /etc/opendkim/trusted.hosts << TRUSTED_EOF
127.0.0.1
::1
localhost
mail.$DOMAIN
$DOMAIN
*.$DOMAIN
TRUSTED_EOF
    
    # Создаём signing table
    echo "*@$DOMAIN default._domainkey.$DOMAIN" > /etc/opendkim/signing.table
    
    # Создаём key table
    echo "default._domainkey.$DOMAIN $DOMAIN:default:/etc/opendkim/keys/$DOMAIN/default.private" > /etc/opendkim/key.table
    
    # Устанавливаем права
    chown -R opendkim:opendkim /etc/opendkim/
    chmod 755 /etc/opendkim/keys/$DOMAIN/
    
    print_status "DKIM настроен успешно"
}

# Функция настройки Postfix
setup_postfix() {
    print_status "Настраиваем Postfix..."
    
    # Основная конфигурация
    cat > /etc/postfix/main.cf << POSTFIX_EOF
# Основные настройки
myhostname = mail.$DOMAIN
mydomain = $DOMAIN
myorigin = \$mydomain
inet_interfaces = all
mydestination = \$myhostname, localhost.\$mydomain, localhost, \$mydomain
mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
home_mailbox = Maildir/
mailbox_size_limit = 0
recipient_delimiter = +
inet_protocols = all

# SMTP Auth
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = \$myhostname

# Релей и ограничения
smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination
smtpd_recipient_restrictions = permit_mynetworks permit_sasl_authenticated reject_unauth_destination
smtpd_client_restrictions = permit_mynetworks permit_sasl_authenticated reject_unauth_destination

# SSL/TLS настройки
smtpd_tls_cert_file = /etc/letsencrypt/live/mail.$DOMAIN/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/mail.$DOMAIN/privkey.pem
smtpd_use_tls = yes
smtpd_tls_security_level = may
smtpd_tls_auth_only = yes
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache

# DKIM настройки
milter_protocol = 2
milter_default_action = accept
smtpd_milters = inet:localhost:8891
non_smtpd_milters = inet:localhost:8891

# Дополнительные настройки
smtpd_banner = \$myhostname ESMTP \$mail_name (Ubuntu)
biff = no
append_dot_mydomain = no
readme_directory = no
compatibility_level = 2
message_size_limit = 10485760
mailbox_size_limit = 1073741824
POSTFIX_EOF
    
    # Настраиваем master.cf
    cat > /etc/postfix/master.cf << MASTER_EOF
# Postfix master process configuration
smtp      inet  n       -       y       -       -       smtpd
pickup    unix  n       -       y       60      1       pickup
cleanup   unix  n       -       y       -       0       cleanup
qmgr      unix  n       -       n       300     1       qmgr
tlsmgr    unix  -       -       y       1000?   1       tlsmgr
rewrite   unix  -       -       y       -       -       trivial-rewrite
bounce    unix  -       -       y       -       0       bounce
defer     unix  -       -       y       -       0       bounce
trace     unix  -       -       y       -       0       bounce
verify    unix  -       -       y       -       1       verify
flush     unix  n       -       y       1000?   0       flush
proxymap  unix  -       -       n       -       -       proxymap
proxywrite unix -       -       n       -       1       proxymap
smtp      unix  -       -       y       -       -       smtp
relay     unix  -       -       y       -       -       smtp
showq     unix  n       -       y       -       -       showq
error     unix  -       -       y       -       -       error
retry     unix  -       -       y       -       -       error
discard   unix  -       -       y       -       -       discard
local     unix  -       n       n       -       -       local
virtual   unix  -       n       n       -       -       virtual
lmtp      unix  -       -       y       -       -       lmtp
anvil     unix  -       -       y       -       1       anvil
scache    unix  -       -       y       -       1       scache
postlog   unix-dgram n  -       n       -       1       postlogd

# SMTPS порт 465 (SSL wrapper)
smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_tls_security_level=encrypt

# Submission порт 587 (STARTTLS)
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
MASTER_EOF
    
    print_status "Postfix настроен успешно"
}

# Функция настройки Dovecot
setup_dovecot() {
    print_status "Настраиваем Dovecot..."
    
    cat > /etc/dovecot/dovecot.conf << DOVECOT_EOF
# Основные настройки
protocols = imap pop3 lmtp
listen = *
base_dir = /var/run/dovecot/
instance_name = dovecot

# SSL настройки
ssl = required
ssl_cert = </etc/letsencrypt/live/mail.$DOMAIN/fullchain.pem
ssl_key = </etc/letsencrypt/live/mail.$DOMAIN/privkey.pem
ssl_min_protocol = TLSv1.2

# Пользователи
userdb {
  driver = passwd
}

passdb {
  driver = pam
}

# Почтовые настройки
mail_location = maildir:~/Maildir
mail_privileged_group = mail
first_valid_uid = 1000

# Авторизация
auth_mechanisms = plain login
auth_username_format = %n

# Служба авторизации для Postfix
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
}

# IMAP настройки
service imap-login {
  inet_listener imap {
    port = 143
    ssl = no
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
}

# POP3 настройки
service pop3-login {
  inet_listener pop3 {
    port = 110
    ssl = no
  }
  inet_listener pop3s {
    port = 995
    ssl = yes
  }
}

# LMTP настройки
service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    user = postfix
    group = postfix
  }
}

# Логирование
log_path = /var/log/dovecot.log
info_log_path = /var/log/dovecot-info.log
debug_log_path = /var/log/dovecot-debug.log
mail_debug = no
auth_verbose = no
auth_debug = no
verbose_ssl = no
DOVECOT_EOF
    
    print_status "Dovecot настроен успешно"
}

# Функция создания пользователя
create_user() {
    print_status "Создаём пользователя $EMAIL_USER..."
    
    # Создаём пользователя если его нет
    if ! id $EMAIL_USER &>/dev/null; then
        useradd -m -s /bin/bash $EMAIL_USER
    fi
    
    # Устанавливаем пароль
    echo "$EMAIL_USER:$EMAIL_PASS" | chpasswd
    
    # Создаём Maildir
    sudo -u $EMAIL_USER mkdir -p /home/$EMAIL_USER/Maildir/{cur,new,tmp}
    chown -R $EMAIL_USER:$EMAIL_USER /home/$EMAIL_USER/Maildir
    
    print_status "Пользователь создан успешно"
}

# Функция настройки firewall
# Функция настройки firewall
setup_firewall() {
    print_status "Настраиваем firewall..."
    
    # Включаем UFW
    # Install ufw if not present
    if ! command -v ufw >/dev/null 2>&1; then
        echo "[INFO] Устанавливаем ufw..."
        apt-get update -qq && apt-get install -y ufw
    fi

    # Install ufw if not present
    if ! command -v ufw &> /dev/null; then
        echo "Installing ufw..."
        apt-get update -qq && apt-get install -y ufw
    fi
    # Check if ufw is installed
    if ! command -v ufw &> /dev/null; then
        echo "Installing ufw..."
        apt-get update && apt-get install -y ufw
    fi
    ufw --force enable
    
    # Открываем SSH сначала (чтобы не заблокироваться)
    ufw allow ssh
    
    # Открываем порты почтового сервера
    ufw allow 25/tcp    # SMTP
    ufw allow 143/tcp   # IMAP
    ufw allow 110/tcp   # POP3
    ufw allow 587/tcp   # SMTP submission
    ufw allow 465/tcp   # SMTPS
    ufw allow 993/tcp   # IMAPS
    ufw allow 995/tcp   # POP3S
    ufw allow 80/tcp    # HTTP (для Let's Encrypt)
    ufw allow 443/tcp   # HTTPS
    
    print_status "Firewall настроен"
}

# Функция настройки автообновления сертификатов
setup_cert_renewal() {
    print_status "Настраиваем автообновление сертификатов..."
    
    cat > /etc/cron.d/letsencrypt-renew << CRON_EOF
# Автообновление сертификатов Let's Encrypt
0 2 * * * root /usr/bin/certbot renew --quiet --post-hook "systemctl reload postfix dovecot"
CRON_EOF
    
    print_status "Автообновление сертификатов настроено"
}

# Функция запуска служб
start_services() {
    print_status "Запускаем службы..."
    
    systemctl enable opendkim
    systemctl enable postfix
    systemctl enable dovecot
    
    systemctl restart opendkim
    systemctl restart postfix
    systemctl restart dovecot
    
    print_status "Службы запущены"
}

# Функция проверки статуса
check_status() {
    print_status "Проверяем статус служб..."
    
    echo "=== Статус служб ==="
    systemctl is-active opendkim && echo "OpenDKIM: OK" || echo "OpenDKIM: FAIL"
    systemctl is-active postfix && echo "Postfix: OK" || echo "Postfix: FAIL"
    systemctl is-active dovecot && echo "Dovecot: OK" || echo "Dovecot: FAIL"
    
    echo "=== Открытые порты ==="
    netstat -tlnp | grep -E ":25|:143|:110|:587|:465|:993|:995" || echo "Порты не найдены"
}

# Функция генерации DNS записей
generate_dns_records() {
    print_status "Генерируем DNS записи..."
    
    # Получаем DKIM запись
    if [ -f "/etc/opendkim/keys/$DOMAIN/default.txt" ]; then
        DKIM_RECORD=$(cat /etc/opendkim/keys/$DOMAIN/default.txt | grep -v "^;" | tr -d "\n" | sed "s/[[:space:]]\+/ /g")
    else
        DKIM_RECORD="DKIM ключ не найден! Проверьте /etc/opendkim/keys/$DOMAIN/default.txt"
    fi
    
    cat > /root/DNS_RECORDS_$DOMAIN.txt << DNS_EOF
================================================================================
💣 ФЕНЯ'S ПОЛНАЯ ИНСТРУКЦИЯ ПО DNS ЗАПИСЯМ ДЛЯ $DOMAIN 💣
================================================================================
================================================================================
💡 ВАЖНО! ВСЕ ЗАПИСИ НУЖНО ДОБАВЛЯТЬ В DNS ВАШЕГО ДОМЕНА!
================================================================================
Если ваш домен: example.com, то:
- default._domainkey.example.com → default._domainkey.$DOMAIN
- _dmarc.example.com → _dmarc.$DOMAIN
- mail.example.com → mail (как поддомен)
================================================================================

Автор: Феня (легендарный хакер и гуру микросервисов)
Домен: $DOMAIN
IP сервера: $SERVER_IP
Дата: $(date)
Почтовый сервер: mail.$DOMAIN
================================================================================

🔥 ОСНОВНЫЕ ОБЯЗАТЕЛЬНЫЕ ЗАПИСИ (БЕЗ НИХ НИЧЕГО НЕ РАБОТАЕТ!)
================================================================================

1. 📍 A-ЗАПИСЬ (Связывает поддомен mail с IP)
   Тип: A
   Имя: mail (поддомен для $DOMAIN)
   Значение: $SERVER_IP
   TTL: 3600 (1 час)

2. 📧 MX-ЗАПИСЬ (Указывает почтовый сервер)
   Тип: MX
   Имя: @ (или пустое для корневого домена)
   Значение: 10 mail.$DOMAIN
   Приоритет: 10
   TTL: 3600

================================================================================
🛡️ ЗАЩИТНЫЕ ЗАПИСИ (SPF, DKIM, DMARC) - ОБЯЗАТЕЛЬНЫ ДЛЯ ДОСТАВЛЯЕМОСТИ!
================================================================================

3. 🛡️ SPF-ЗАПИСЬ (Защита от подделки отправителя)
   Тип: TXT
   Имя: @ (или пустое для корневого домена)
   Значение: v=spf1 mx a:mail.$DOMAIN ~all
   TTL: 3600

4. 🔐 DKIM-ЗАПИСЬ (Цифровая подпись писем)
   Тип: TXT
   Имя: default._domainkey.$DOMAIN
   Значение: $DKIM_RECORD
   TTL: 3600

5. 📊 DMARC-ЗАПИСЬ (Политика обработки непрошедших проверку писем)
   Тип: TXT
   Имя: _dmarc.$DOMAIN
   Значение: v=DMARC1; p=quarantine; rua=mailto:dmarc@$DOMAIN; ruf=mailto:dmarc@$DOMAIN; sp=quarantine; adkim=s; aspf=s
   TTL: 3600

================================================================================
🚀 ДОПОЛНИТЕЛЬНЫЕ УДОБНЫЕ АЛИАСЫ (ОПЦИОНАЛЬНО, НО РЕКОМЕНДУЕТСЯ)
================================================================================

6. 🌐 CNAME для SMTP (Удобство для клиентов)
   Тип: CNAME
   Имя: smtp
   Значение: mail.$DOMAIN
   TTL: 3600

7. 📩 CNAME для IMAP (Удобство для клиентов)
   Тип: CNAME
   Имя: imap
   Значение: mail.$DOMAIN
   TTL: 3600

8. 📤 CNAME для POP3 (Если используете POP3)
   Тип: CNAME
   Имя: pop3
   Значение: mail.$DOMAIN
   TTL: 3600

9. 💻 CNAME для веб-почты (Если планируете)
   Тип: CNAME
   Имя: webmail
   Значение: mail.$DOMAIN
   TTL: 3600

================================================================================
⚡ PTR-ЗАПИСЬ (ОБРАТНЫЙ DNS) - КРИТИЧНО ДЛЯ РЕПУТАЦИИ!
================================================================================

10. 🔄 PTR-ЗАПИСЬ (Настраивается у хостинг-провайдера!)
    IP: $SERVER_IP
    PTR: mail.$DOMAIN
    
    ⚠️  ВАЖНО: Эта запись настраивается не в вашей DNS зоне, а у провайдера!
    Обратитесь к своему хостинг-провайдеру с просьбой настроить PTR запись!

================================================================================
🧪 КОМАНДЫ ДЛЯ ПРОВЕРКИ DNS ЗАПИСЕЙ
================================================================================

# Проверка A-записи
dig +short mail.$DOMAIN A

# Проверка MX-записи
dig +short $DOMAIN MX

# Проверка SPF
dig +short $DOMAIN TXT | grep spf1

# Проверка DKIM
dig +short default._domainkey.$DOMAIN TXT

# Проверка DMARC
dig +short _dmarc.$DOMAIN TXT

# Проверка PTR (обратный DNS)
dig +short -x $SERVER_IP

================================================================================
🎯 НАСТРОЙКИ ДЛЯ ПОЧТОВЫХ КЛИЕНТОВ (THUNDERBIRD/OUTLOOK)
================================================================================

📧 Входящий сервер (IMAP):
- Сервер: mail.$DOMAIN
- Порт: 993 (SSL/TLS) или 143 (STARTTLS)
- Шифрование: SSL/TLS
- Логин: $EMAIL_USER (без @домен)
- Пароль: [тот что вводили в скрипте]

📤 Исходящий сервер (SMTP):
- Сервер: mail.$DOMAIN
- Порт: 465 (SSL/TLS) или 587 (STARTTLS)
- Шифрование: SSL/TLS
- Аутентификация: Да
- Логин: $EMAIL_USER (без @домен)
- Пароль: [тот что вводили в скрипте]

================================================================================
🚀 НАСТРОЙКИ ДЛЯ GOPHISH
================================================================================

SMTP Host: mail.$DOMAIN
SMTP Port: 465 (SSL/TLS) или 587 (STARTTLS)
Username: $EMAIL_USER@$DOMAIN
Password: [тот что вводили в скрипте]
Encryption: SSL/TLS
From Address: $EMAIL_USER@$DOMAIN

================================================================================
🔍 ОНЛАЙН ИНСТРУМЕНТЫ ДЛЯ ПРОВЕРКИ
================================================================================

1. MXToolbox: https://mxtoolbox.com/domain/$DOMAIN
2. DKIM Validator: https://dkimvalidator.com/
3. SPF Record Check: https://www.kitterman.com/spf/validate.html
4. DMARC Analyzer: https://dmarc.org/dmarc-setup/
5. Mail Tester: https://www.mail-tester.com/

================================================================================
🎉 КАК ГОВОРИЛ МОЙ ДЕД: "ХОРОШО НАСТРОЕННЫЙ ПОЧТОВЫЙ СЕРВЕР - ЭТО КАК 
ШВЕЙЦАРСКИЕ ЧАСЫ: РАБОТАЕТ ТОЧНО И НИКОГО НЕ ПОДВОДИТ!"
================================================================================
DNS_EOF
    
    print_status "DNS записи сохранены в /root/DNS_RECORDS_$DOMAIN.txt"
}

# Функция вывода финальной информации
show_final_info() {
    print_header "=== УСТАНОВКА ЗАВЕРШЕНА УСПЕШНО ==="
    print_header "Феня разрулил всё как надо!"
    print_header "===================================="
    
    echo
    print_status "📧 НАСТРОЙКИ ДЛЯ ПОЧТОВЫХ КЛИЕНТОВ:"
    echo "Домен: $DOMAIN"
    echo "Сервер: mail.$DOMAIN (IP: $SERVER_IP)"
    echo "Пользователь: $EMAIL_USER@$DOMAIN"
    echo "Пароль: $EMAIL_PASS"
    echo
    echo "IMAP (входящие):"
    echo "  Сервер: mail.$DOMAIN"
    echo "  Порт: 993 (SSL/TLS) или 143 (STARTTLS)"
    echo "  Шифрование: SSL/TLS"
    echo
    echo "SMTP (исходящие):"
    echo "  Сервер: mail.$DOMAIN"
    echo "  Порт: 465 (SSL/TLS) или 587 (STARTTLS)"
    echo "  Шифрование: SSL/TLS"
    echo "  Авторизация: Да"
    echo
    print_status "🚀 НАСТРОЙКИ ДЛЯ GOPHISH:"
    echo "SMTP Host: mail.$DOMAIN"
    echo "SMTP Port: 465 (SSL/TLS) или 587 (STARTTLS)"
    echo "Username: $EMAIL_USER@$DOMAIN"
    echo "Password: $EMAIL_PASS"
    echo "Encryption: SSL/TLS"
    echo
    print_status "🌐 DNS ЗАПИСИ:"
    echo "Подробные DNS записи сохранены в: /root/dns_records_$DOMAIN.txt"
    echo "Основные записи:"
    echo "  A     mail.$DOMAIN           IN A     $SERVER_IP"
    echo "  MX    $DOMAIN               IN MX    10 mail.$DOMAIN"
    echo "  TXT   $DOMAIN               IN TXT   \"v=spf1 mx ~all\""
    echo "  TXT   _dmarc.$DOMAIN        IN TXT   \"v=DMARC1; p=none; rua=mailto:dmarc@$DOMAIN\""
    echo
    print_status "✅ ТЕСТИРОВАНИЕ:"
    echo "SMTP: telnet mail.$DOMAIN 25"
    echo "IMAP: telnet mail.$DOMAIN 143"
    echo "SSL SMTP: openssl s_client -connect mail.$DOMAIN:465"
    echo "SSL IMAP: openssl s_client -connect mail.$DOMAIN:993"
    echo
    print_status "🔧 ЛОГИ:"
    echo "Postfix: /var/log/mail.log"
    echo "Dovecot: /var/log/dovecot.log"
    echo "OpenDKIM: /var/log/mail.log"
    echo
    print_status "🔐 БЕЗОПАСНОСТЬ:"
    echo "✅ Let's Encrypt SSL сертификаты"
    echo "✅ DKIM подписи"
    echo "✅ SPF записи"
    echo "✅ DMARC записи"
    echo "✅ Автообновление сертификатов"
    echo
    print_header "🎉 Как говорил мой дед: 'Хорошо настроенный почтовый сервер - это как швейцарские часы: работает точно и никого не подводит!'"
}

# Основная функция
main() {
    # Проверяем права root
    if [[ $EUID -ne 0 ]]; then
        print_error "Скрипт должен запускаться от root!"
        exit 1
    fi
    
    # Получаем параметры от пользователя
    get_user_input
    
    # Выполняем установку
    check_dns
    install_packages
    setup_hostname
    setup_letsencrypt
    setup_dkim
    setup_postfix
    setup_dovecot
    create_user
    setup_firewall
    setup_cert_renewal
    start_services
    
    # Ждём запуска служб
    sleep 5
    
    # Проверяем статус
    check_status
    
    # Генерируем DNS записи
    generate_dns_records
    
    # Показываем финальную информацию
    show_final_info
    
    print_header "🚀 ДЕПЛОЙ ЗАВЕРШЁН! ПОЧТОВЫЙ СЕРВЕР ГОТОВ К РАБОТЕ!"
}

# Запускае
