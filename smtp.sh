#!/bin/bash
# ================================================
# Ultimate SMTP/IMAP Server Deployment Script
# Version: 6.2
# ================================================
# Требуемые DNS записи ДО установки:
# 1. A запись: mail.yourdomain.com → IP сервера
# 2. MX запись: yourdomain.com → mail.yourdomain.com (приоритет 10)
# ================================================

# Strict mode
set -euo pipefail
IFS=$'\n\t'

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Переменные
LOG_FILE="/var/log/mailserver_setup.log"
CONFIG_BACKUP_DIR="/root/mailserver_backup_$(date +%Y%m%d_%H%M%S)"
DOMAIN=""
EMAIL_USER=""
EMAIL_PASS=""
SERVER_IP=""
ADMIN_EMAIL="admin@example.com"
INSTALL_MODE="install"

# Функции для вывода
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
}

print_header() {
    echo -e "${BLUE}$1${NC}" | tee -a "$LOG_FILE"
}

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Скрипт должен запускаться от root!"
        exit 1
    fi
}

# Проверка зависимостей
check_dependencies() {
    local deps=("dig" "curl" "systemctl")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            print_error "Необходима утилита: $dep"
            exit 1
        fi
    done
}

# Валидация домена
validate_domain() {
    if [[ ! "$DOMAIN" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        print_error "Некорректный домен: $DOMAIN"
        exit 1
    fi
}

# Получение ввода пользователя
get_user_input() {
    clear
    print_header "=== Ultimate SMTP/IMAP Server Setup v6.2 ==="
    
    # Предупреждение о необходимых DNS записях
    print_header "‼️ ВАЖНО: Перед установкой добавьте эти DNS записи:"
    echo -e "${YELLOW}1. A запись: mail.yourdomain.com → IP вашего сервера"
    echo "2. MX запись: yourdomain.com → mail.yourdomain.com (приоритет 10)${NC}"
    SERVER_IP=$(curl -s ifconfig.me)
    echo -e "\nТекущий IP сервера: ${YELLOW}$SERVER_IP${NC}"
    echo -e "Проверить DNS записи можно командой: ${YELLOW}dig mail.yourdomain.com +short${NC}\n"

    read -p "Продолжить установку? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Установка отменена. Сначала добавьте DNS записи!"
        exit 1
    fi

    print_header "Выберите действие:"
    echo "1) Установить почтовый сервер"
    echo "2) Удалить почтовый сервер"
    read -rp "Ваш выбор (1/2): " choice

    case $choice in
        1) INSTALL_MODE="install" ;;
        2) INSTALL_MODE="uninstall" ;;
        *) print_error "Неверный выбор"; exit 1 ;;
    esac

    if [ "$INSTALL_MODE" = "install" ]; then
        read -rp "Введите домен (например: example.com): " DOMAIN
        read -rp "Введите имя пользователя для почты (например: user): " EMAIL_USER
        read -srp "Введите пароль для пользователя: " EMAIL_PASS
        echo
        read -rp "Введите email администратора (для Let's Encrypt): " ADMIN_EMAIL

        validate_domain

        print_status "\nНастройки:"
        print_status "Домен: $DOMAIN"
        print_status "Почтовый сервер: mail.$DOMAIN"
        print_status "IP сервера: $SERVER_IP"
        print_status "Почтовый пользователь: $EMAIL_USER@$DOMAIN"
        print_status "Админ email: $ADMIN_EMAIL"

        read -rp "Все верно? Продолжить установку? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_error "Установка отменена"
            exit 1
        fi
    fi
}

# Проверка DNS записей
check_dns() {
    print_status "Проверяем обязательные DNS записи..."
    local errors=0

    # Проверка A записи
    if ! dig +short "mail.$DOMAIN" A | grep -q "$SERVER_IP"; then
        print_error "❌ A запись для mail.$DOMAIN не найдена или указывает на другой IP!"
        print_error "Текущий IP сервера: $SERVER_IP"
        print_error "Добавьте запись: mail.$DOMAIN A $SERVER_IP"
        errors=$((errors+1))
    else
        print_status "✅ A запись для mail.$DOMAIN настроена верно"
    fi

    # Проверка MX записи
    if ! dig +short "$DOMAIN" MX | grep -q "mail.$DOMAIN"; then
        print_error "❌ MX запись для $DOMAIN не найдена!"
        print_error "Добавьте запись: $DOMAIN MX 10 mail.$DOMAIN"
        errors=$((errors+1))
    else
        print_status "✅ MX запись для $DOMAIN настроена верно"
    fi

    if [ $errors -gt 0 ]; then
        print_error "Сначала исправьте DNS записи! Установка прервана."
        exit 1
    fi

    # Дополнительные рекомендации
    print_status "\nРекомендуемые дополнительные DNS записи (можно добавить после установки):"
    echo -e "${YELLOW}- SPF запись:"
    echo "  Имя: @"
    echo "  Тип: TXT"
    echo "  Значение: \"v=spf1 mx a:mail.$DOMAIN ~all\""
    echo ""
    echo "- DMARC запись:"
    echo "  Имя: _dmarc"
    echo "  Тип: TXT"
    echo "  Значение: \"v=DMARC1; p=none; rua=mailto:$ADMIN_EMAIL\""
    echo ""
    echo "- DKIM запись (будет сгенерирована автоматически)${NC}"
}

# Установка пакетов
install_packages() {
    print_status "Обновляем систему и устанавливаем пакеты..."

    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get upgrade -y -qq

    apt-get install -y -qq postfix dovecot-core dovecot-imapd dovecot-pop3d \
                          dovecot-lmtpd opendkim opendkim-tools ssl-cert \
                          certbot bind9-dnsutils mailutils net-tools ufw \
                          fail2ban

    print_status "Пакеты установлены успешно"
}

# Настройка hostname
setup_hostname() {
    print_status "Настраиваем hostname..."
    hostnamectl set-hostname "mail.$DOMAIN"
    echo "127.0.0.1 mail.$DOMAIN" >> /etc/hosts
    echo "mail.$DOMAIN" > /etc/mailname
}

# Получение сертификата Let's Encrypt
setup_letsencrypt() {
    print_status "Получаем сертификат Let's Encrypt..."

    systemctl stop postfix dovecot nginx apache2 2>/dev/null || true

    if ! certbot certonly --standalone --agree-tos --non-interactive \
        --email "$ADMIN_EMAIL" --no-eff-email \
        -d "mail.$DOMAIN" --force-renewal; then
        print_error "Не удалось получить сертификат Let's Encrypt!"
        print_error "Проверьте, что:"
        print_error "1. Домен mail.$DOMAIN указывает на IP $SERVER_IP"
        print_error "2. Порт 80 открыт и не занят другими сервисами"
        exit 1
    fi

    # Автообновление сертификатов
    cat > /etc/cron.d/letsencrypt-renew << CRON_EOF
0 2 * * * root /usr/bin/certbot renew --quiet --post-hook "systemctl reload postfix dovecot"
CRON_EOF

    print_status "Сертификат Let's Encrypt получен и настроено автообновление"
}

# Настройка DKIM
setup_dkim() {
    print_status "Настраиваем DKIM..."

    mkdir -p "/etc/opendkim/keys/$DOMAIN"
    opendkim-genkey -s default -d "$DOMAIN" -D "/etc/opendkim/keys/$DOMAIN/"
    chown opendkim:opendkim "/etc/opendkim/keys/$DOMAIN/default.private"
    chmod 600 "/etc/opendkim/keys/$DOMAIN/default.private"

    cat > /etc/opendkim.conf << DKIM_EOF
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
Domain                  $DOMAIN
Selector                default
KeyFile                 /etc/opendkim/keys/$DOMAIN/default.private
Socket                  inet:8891@localhost
ExternalIgnoreList      /etc/opendkim/trusted.hosts
InternalHosts           /etc/opendkim/trusted.hosts
SigningTable            refile:/etc/opendkim/signing.table
KeyTable                refile:/etc/opendkim/key.table
DKIM_EOF

    cat > /etc/opendkim/trusted.hosts << TRUSTED_EOF
127.0.0.1
::1
localhost
mail.$DOMAIN
$DOMAIN
*.$DOMAIN
TRUSTED_EOF

    echo "*@$DOMAIN default._domainkey.$DOMAIN" > /etc/opendkim/signing.table
    echo "default._domainkey.$DOMAIN $DOMAIN:default:/etc/opendkim/keys/$DOMAIN/default.private" > /etc/opendkim/key.table

    chown -R opendkim:opendkim /etc/opendkim/
    chmod 755 "/etc/opendkim/keys/$DOMAIN/"

    print_status "DKIM настроен успешно"
}

# Настройка Postfix
setup_postfix() {
    print_status "Настраиваем Postfix..."

    # Backup original config
    mkdir -p "$CONFIG_BACKUP_DIR"
    cp -a /etc/postfix /etc/postfix.orig

    cat > /etc/postfix/main.cf << POSTFIX_EOF
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
smtpd_sasl_type = dovecot
smtpd_sasl_path = private/auth
smtpd_sasl_auth_enable = yes
smtpd_sasl_security_options = noanonymous
smtpd_sasl_local_domain = \$myhostname
smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination
smtpd_recipient_restrictions = permit_mynetworks permit_sasl_authenticated reject_unauth_destination
smtpd_client_restrictions = permit_mynetworks permit_sasl_authenticated reject_unauth_destination
smtpd_tls_cert_file = /etc/letsencrypt/live/mail.$DOMAIN/fullchain.pem
smtpd_tls_key_file = /etc/letsencrypt/live/mail.$DOMAIN/privkey.pem
smtpd_use_tls = yes
smtpd_tls_security_level = may
smtpd_tls_auth_only = yes
smtpd_tls_session_cache_database = btree:\${data_directory}/smtpd_scache
smtp_tls_session_cache_database = btree:\${data_directory}/smtp_scache
milter_protocol = 2
milter_default_action = accept
smtpd_milters = inet:localhost:8891
non_smtpd_milters = inet:localhost:8891
smtpd_banner = \$myhostname ESMTP \$mail_name
biff = no
append_dot_mydomain = no
readme_directory = no
compatibility_level = 2
message_size_limit = 10485760
mailbox_size_limit = 1073741824
POSTFIX_EOF

    cat > /etc/postfix/master.cf << MASTER_EOF
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

smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
  -o smtpd_tls_security_level=encrypt

submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_recipient_restrictions=permit_sasl_authenticated,reject
  -o smtpd_client_restrictions=permit_sasl_authenticated,reject
MASTER_EOF

    print_status "Postfix настроен успешно"
}

# Настройка Dovecot
setup_dovecot() {
    print_status "Настраиваем Dovecot..."

    # Backup original config
    cp -a /etc/dovecot /etc/dovecot.orig

    cat > /etc/dovecot/dovecot.conf << DOVECOT_EOF
protocols = imap pop3 lmtp
listen = *
base_dir = /var/run/dovecot/
instance_name = dovecot
ssl = required
ssl_cert = </etc/letsencrypt/live/mail.$DOMAIN/fullchain.pem
ssl_key = </etc/letsencrypt/live/mail.$DOMAIN/privkey.pem
ssl_min_protocol = TLSv1.2
userdb {
  driver = passwd
}
passdb {
  driver = pam
}
mail_location = maildir:~/Maildir
mail_privileged_group = mail
first_valid_uid = 1000
auth_mechanisms = plain login
auth_username_format = %n
service auth {
  unix_listener /var/spool/postfix/private/auth {
    mode = 0666
    user = postfix
    group = postfix
  }
}
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
service lmtp {
  unix_listener /var/spool/postfix/private/dovecot-lmtp {
    mode = 0600
    user = postfix
    group = postfix
  }
}
log_path = /var/log/dovecot.log
info_log_path = /var/log/dovecot-info.log
DOVECOT_EOF

    print_status "Dovecot настроен успешно"
}

# Создание пользователя
create_user() {
    print_status "Создаём пользователя $EMAIL_USER..."

    if ! id "$EMAIL_USER" &>/dev/null; then
        useradd -m -s /bin/bash "$EMAIL_USER"
    fi

    echo "$EMAIL_USER:$EMAIL_PASS" | chpasswd
    sudo -u "$EMAIL_USER" mkdir -p "/home/$EMAIL_USER/Maildir/{cur,new,tmp}"
    chown -R "$EMAIL_USER:$EMAIL_USER" "/home/$EMAIL_USER/Maildir"

    print_status "Пользователь создан успешно"
}

# Настройка firewall
setup_firewall() {
    print_status "Настраиваем firewall..."

    if ! command -v ufw >/dev/null 2>&1; then
        print_status "Устанавливаем ufw..."
        apt-get install -y -qq ufw
    fi

    ufw --force enable
    ufw allow ssh
    ufw allow 25/tcp    # SMTP
    ufw allow 143/tcp   # IMAP
    ufw allow 110/tcp   # POP3
    ufw allow 587/tcp   # SMTP submission
    ufw allow 465/tcp   # SMTPS
    ufw allow 993/tcp   # IMAPS
    ufw allow 995/tcp   # POP3S
    ufw allow 80/tcp    # HTTP
    ufw allow 443/tcp   # HTTPS

    print_status "Firewall настроен"
}

# Настройка Fail2Ban
setup_fail2ban() {
    setup_opendkim
    print_status "Настраиваем Fail2Ban..."

    cat > /etc/fail2ban/jail.local << FAIL2BAN_EOF
[postfix]
enabled = true
port = smtp,465,587
filter = postfix
logpath = /var/log/mail.log
maxretry = 3
bantime = 3600

[dovecot]
enabled = true
port = imap2,imap3,imaps,pop3,pop3s
filter = dovecot
logpath = /var/log/mail.log
maxretry = 3
bantime = 3600

[postfix-sasl]
enabled = true
port = smtp,465,587
filter = postfix-sasl
logpath = /var/log/mail.log
maxretry = 3
bantime = 3600
FAIL2BAN_EOF

    systemctl restart fail2ban
    print_status "Fail2Ban настроен"
}

# Генерация DNS записей
generate_correct_dns_records() {
    check_dns_records
    print_status "Генерируем DNS записи..."

    local DKIM_RECORD
    if [ -f "/etc/opendkim/keys/$DOMAIN/default.txt" ]; then
        DKIM_RECORD=$(grep -v "^;" "/etc/opendkim/keys/$DOMAIN/default.txt" | tr -d "\n" | sed -e 's/"//g' -e 's/[[:space:]]\+/ /g' -e 's/IN TXT //' -e 's/[()]//g')
    else
        DKIM_RECORD="DKIM ключ не найден!"
    fi

    cat > "/root/DNS_RECORDS_$DOMAIN.txt" << DNS_EOF
=== Правильные DNS записи для домена $DOMAIN ===
(Добавьте эти записи в панель управления вашего DNS-хостинга)

1. A запись для почтового сервера:
   Имя: mail
   Тип: A
   Значение: $SERVER_IP
   TTL: 3600

2. MX запись (основная почтовая запись):
   Имя: @ (или оставьте пустым для корневого домена)
   Тип: MX
   Значение: mail.$DOMAIN
   Приоритет: 10
   TTL: 3600

3. SPF запись (защита от подделки отправителя):
   Имя: @ (или оставьте пустым для корневого домена)
   Тип: TXT
   Значение: "v=spf1 mx a:mail.$DOMAIN ~all"
   TTL: 3600

4. DKIM запись (цифровая подпись писем):
   Имя: default._domainkey
   Тип: TXT
   Значение: "v=DKIM1; k=rsa; p=$DKIM_RECORD"
   TTL: 3600

5. DMARC запись (политика обработки писем):
   Имя: _dmarc
   Тип: TXT
   Значение: "v=DMARC1; p=quarantine; rua=mailto:$ADMIN_EMAIL; ruf=mailto:$ADMIN_EMAIL; fo=1"
   TTL: 3600

6. PTR запись (обратный DNS, настраивается у хостинг-провайдера):
   IP: $SERVER_IP
   Значение: mail.$DOMAIN

=== Проверка записей после добавления ===
Проверить A запись: dig +short mail.$DOMAIN A
Проверить MX: dig +short $DOMAIN MX
Проверить SPF: dig +short $DOMAIN TXT | grep spf
Проверить DKIM: dig +short default._domainkey.$DOMAIN TXT
Проверить DMARC: dig +short _dmarc.$DOMAIN TXT
Проверить PTR: dig +short -x $SERVER_IP

=== Важные заметки ===
1. PTR запись нужно настраивать у хостинг-провайдера сервера
2. Изменения DNS могут занимать до 24 часов
3. Для проверки правильности записей используйте:
   - https://mxtoolbox.com/
   - https://www.dmarcanalyzer.com/
   - https://dkimvalidator.com/
DNS_EOF

    print_status "DNS записи сохранены в /root/DNS_RECORDS_$DOMAIN.txt"
}

# Тестирование сервисов
    start_and_verify_services
test_services() {
    print_status "Тестируем сервисы..."

    # Проверка SMTP
    if ! echo "quit" | telnet localhost 25 | grep -q "220"; then
        print_warning "SMTP сервис не отвечает"
    else
        print_status "SMTP сервис работает"
    fi

    # Проверка IMAP
    if ! echo "a logout" | openssl s_client -connect localhost:993 -quiet 2>/dev/null | grep -q "OK"; then
        print_warning "IMAP сервис не отвечает"
    else
        print_status "IMAP сервис работает"
    fi

    # Проверка DKIM
    if ! opendkim-testkey -d "$DOMAIN" -s default -vvv; then
        print_warning "DKIM проверка не удалась"
    else
        print_status "DKIM настроен правильно"
    fi
}

# Удаление почтового сервера
uninstall_mailserver() {
    print_header "=== Удаление почтового сервера ==="

    read -rp "Введите домен для удаления (например: example.com): " DOMAIN
    validate_domain

    # Подтверждение
    read -rp "Вы точно хотите удалить почтовый сервер для $DOMAIN? Это действие нельзя отменить! (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Удаление отменено"
        exit 0
    fi

    # Остановка сервисов
    systemctl stop postfix dovecot opendkim fail2ban

    # Удаление пакетов
    apt-get remove -y --purge postfix dovecot-core dovecot-imapd dovecot-pop3d \
        dovecot-lmtpd opendkim opendkim-tools fail2ban

    # Удаление конфигураций
    rm -rf /etc/postfix /etc/dovecot /etc/opendkim /etc/fail2ban

    # Удаление cron jobs
    rm -f /etc/cron.d/letsencrypt-renew

    # Удаление пользователей (кроме системных)
    local mail_users=$(grep "/home" /etc/passwd | cut -d: -f1 | grep -vE "root|syslog")
    for user in $mail_users; do
        userdel -r "$user" 2>/dev/null || print_warning "Не удалось удалить пользователя $user"
    done

    # Удаление Let's Encrypt сертификатов
    if [ -d "/etc/letsencrypt/live/mail.$DOMAIN" ]; then
        certbot delete --cert-name "mail.$DOMAIN" 2>/dev/null || \
            print_warning "Не удалось удалить сертификат для mail.$DOMAIN"
    fi

    # Сброс firewall
    ufw --force reset
    ufw --force disable

    print_status "Почтовый сервер для $DOMAIN полностью удален"
    print_status "Ручное удаление:"
    print_status "1. Удалите DNS записи (MX, SPF, DKIM, DMARC)"
    print_status "2. Попросите хостинг-провайдера удалить PTR запись"
}

# Вывод итоговой информации
show_summary() {
    print_header "=== Установка завершена успешно ==="
    echo
    print_status "📧 НАСТРОЙКИ ДЛЯ ПОЧТОВЫХ КЛИЕНТОВ:"
    echo "Сервер: mail.$DOMAIN"
    echo "Пользователь: $EMAIL_USER@$DOMAIN"
    echo "Пароль: [ваш пароль]"
    echo
    echo "IMAP (входящие):"
    echo "  Сервер: mail.$DOMAIN"
    echo "  Порт: 993 (SSL/TLS)"
    echo
    echo "SMTP (исходящие):"
    echo "  Сервер: mail.$DOMAIN"
    echo "  Порт: 587 (STARTTLS) или 465 (SSL/TLS)"
    echo
    print_status "🔧 ЛОГИ:"
    echo "Postfix: /var/log/mail.log"
    echo "Dovecot: /var/log/dovecot.log"
    echo
    print_status "🌐 DNS ЗАПИСИ:"
    echo "Файл с DNS записями: /root/DNS_RECORDS_$DOMAIN.txt"
    echo
    print_status "✅ ТЕСТИРОВАНИЕ:"
    echo "Проверить SMTP: telnet mail.$DOMAIN 25"
    echo "Проверить IMAP: openssl s_client -connect mail.$DOMAIN:993"
    echo
    print_status "🔒 БЕЗОПАСНОСТЬ:"
    echo "1. Не забудьте добавить все DNS записи"
    echo "2. Настроить PTR запись у хостинг-провайдера"
    echo "3. Проверить настройки с помощью mxtoolbox.com"
    echo
    print_status "🎉 Почтовый сервер готов к работе!"
}

# Основная функция
main() {
    # Настройка логов
    exec > >(tee -a "$LOG_FILE") 2>&1
    echo -e "\n\n=== Начало установки $(date) ===" >> "$LOG_FILE"

    # Проверки
    check_root
    check_dependencies
    get_user_input

    if [ "$INSTALL_MODE" = "uninstall" ]; then
        uninstall_mailserver
        exit 0
    fi

    # Установка
    check_dns
    install_packages
    setup_hostname
    setup_letsencrypt
    setup_dkim
    setup_postfix
    setup_dovecot
    create_user
    setup_firewall
    setup_fail2ban
    setup_opendkim
    start_and_verify_services
    test_services
    generate_correct_dns_records
    check_dns_records
    show_summary
}

# Запуск
main "$@"

# ================================================
# PATCH: Запуск и проверка служб
# ================================================

# Функция для запуска и проверки служб
start_and_verify_services() {
    print_status "🚀 Запуск и проверка служб"
    
    # Запуск служб
    echo "Запуск Postfix..."
    systemctl start postfix
    systemctl enable postfix
    
    echo "Запуск Dovecot..."
    systemctl start dovecot
    systemctl enable dovecot
    
    # Проверка статуса
    sleep 3
    
    echo "Проверка статуса служб..."
    if systemctl is-active --quiet postfix; then
        echo -e "${GREEN}✅ Postfix запущен${NC}"
    else
        echo -e "${RED}❌ Postfix не запущен${NC}"
        systemctl status postfix --no-pager
    fi
    
    if systemctl is-active --quiet dovecot; then
        echo -e "${GREEN}✅ Dovecot запущен${NC}"
    else
        echo -e "${RED}❌ Dovecot не запущен${NC}"
        systemctl status dovecot --no-pager
    fi
    
    # Проверка портов
    echo "Проверка открытых портов..."
    ss -tlnp | grep -E "(25|465|587|993|143)" || true
    
    echo
    print_status "✅ Службы запущены и проверены"
}


# ================================================
# PATCH: Правильная настройка OpenDKIM
# ================================================

# Функция для настройки OpenDKIM
setup_opendkim() {
    print_status "🔐 Настройка OpenDKIM для подписи писем"
    
    # Установка OpenDKIM
    echo "Установка OpenDKIM..."
    apt update -qq
    apt install -y opendkim opendkim-tools
    
    # Создание директории для ключей
    mkdir -p /etc/opendkim/keys/$DOMAIN
    
    # Конфигурация OpenDKIM
    cat > /etc/opendkim.conf << 'DKIM_CONF'
# OpenDKIM Configuration
Syslog yes
UMask 002
Mode sv
Canonicalization relaxed/simple
ExternalIgnoreList refile:/etc/opendkim/TrustedHosts
InternalHosts refile:/etc/opendkim/TrustedHosts
KeyTable refile:/etc/opendkim/KeyTable
SigningTable refile:/etc/opendkim/SigningTable
SignatureAlgorithm rsa-sha256
Socket inet:8891@localhost
RequireSafeKeys false
DKIM_CONF

    # TrustedHosts
    cat > /etc/opendkim/TrustedHosts << TRUSTED_EOF
127.0.0.1
::1
localhost
$DOMAIN
*.$DOMAIN
TRUSTED_EOF

    # SigningTable
    cat > /etc/opendkim/SigningTable << SIGN_EOF
*@$DOMAIN default._domainkey.$DOMAIN
SIGN_EOF

    # KeyTable
    cat > /etc/opendkim/KeyTable << KEY_EOF
default._domainkey.$DOMAIN $DOMAIN:default:/etc/opendkim/keys/$DOMAIN/default.private
KEY_EOF

    # Генерация DKIM ключей
    echo "Генерация DKIM ключей..."
    cd /etc/opendkim/keys/$DOMAIN
    opendkim-genkey -s default -d $DOMAIN
    
    # Настройка прав доступа
    chown opendkim:opendkim /etc/opendkim/keys/$DOMAIN/default.private
    chmod 600 /etc/opendkim/keys/$DOMAIN/default.private
    
    # Настройка Postfix для работы с OpenDKIM
    echo "Настройка Postfix для OpenDKIM..."
    postconf -e 'smtpd_milters = inet:localhost:8891'
    postconf -e 'non_smtpd_milters = inet:localhost:8891'
    postconf -e 'milter_default_action = accept'
    
    # Запуск OpenDKIM
    systemctl start opendkim
    systemctl enable opendkim
    
    # Проверка статуса
    if systemctl is-active --quiet opendkim; then
        echo -e "${GREEN}✅ OpenDKIM запущен и работает${NC}"
    else
        echo -e "${RED}❌ Проблема с OpenDKIM${NC}"
        systemctl status opendkim --no-pager
    fi
    
    echo
    print_status "✅ OpenDKIM настроен успешно"
}


# ================================================
# PATCH: Исправленная генерация DNS записей
# ================================================

# Функция для генерации правильных DNS записей
generate_correct_dns_records() {
    print_status "🌐 Генерация DNS записей для $DOMAIN"
    
    # Получим публичный ключ DKIM из файла
    local dkim_public_key=""
    if [ -f "/etc/opendkim/keys/$DOMAIN/default.txt" ]; then
        dkim_public_key=$(cat /etc/opendkim/keys/$DOMAIN/default.txt | grep -E '^[^;]*' | sed 's/.*TXT[[:space:]]*(//' | sed 's/[[:space:]]*);.*//' | tr -d '\n\t"' | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
    fi
    
    # Создадим файл с DNS записями
    cat > /root/DNS_RECORDS_$DOMAIN.txt << DNS_EOF
=== DNS записи для $DOMAIN ===

1. A запись:
   Имя: mail.$DOMAIN
   Тип: A
   Значение: $SERVER_IP
   TTL: 3600

2. MX запись:
   Имя: $DOMAIN (или @)
   Тип: MX
   Значение: mail.$DOMAIN
   Приоритет: 10
   TTL: 3600

3. SPF запись:
   Имя: $DOMAIN (или @)
   Тип: TXT
   Значение: "v=spf1 mx a:mail.$DOMAIN ~all"
   TTL: 3600

4. DKIM запись:
   Имя: default._domainkey.$DOMAIN
   Тип: TXT
   Значение: "$dkim_public_key"
   TTL: 3600

5. DMARC запись:
   Имя: _dmarc.$DOMAIN
   Тип: TXT
   Значение: "v=DMARC1; p=quarantine; rua=mailto:$EMAIL"
   TTL: 3600

=== КОМАНДЫ ДЛЯ ПРОВЕРКИ ===
dig +short mail.$DOMAIN A
dig +short $DOMAIN MX
dig +short $DOMAIN TXT
dig +short default._domainkey.$DOMAIN TXT
dig +short _dmarc.$DOMAIN TXT

DNS_EOF

    echo -e "${GREEN}✅ DNS записи созданы в файле: /root/DNS_RECORDS_$DOMAIN.txt${NC}"
    echo
    echo -e "${YELLOW}=== КРИТИЧЕСКИ ВАЖНО! ===${NC}"
    echo -e "${YELLOW}Добавьте ВСЕ эти записи в DNS вашего провайдера:${NC}"
    echo
    echo -e "${BLUE}1. A запись: mail.$DOMAIN → $SERVER_IP${NC}"
    echo -e "${BLUE}2. MX запись: $DOMAIN → mail.$DOMAIN (приоритет 10)${NC}"
    echo -e "${BLUE}3. SPF запись: $DOMAIN → v=spf1 mx a:mail.$DOMAIN ~all${NC}"
    echo -e "${BLUE}4. DKIM запись: default._domainkey.$DOMAIN → $dkim_public_key${NC}"
    echo -e "${BLUE}5. DMARC запись: _dmarc.$DOMAIN → v=DMARC1; p=quarantine; rua=mailto:$EMAIL${NC}"
    echo
    echo -e "${RED}⚠️  БЕЗ ЭТИХ ЗАПИСЕЙ ПОЧТА НЕ БУДЕТ РАБОТАТЬ!${NC}"
    echo
}

