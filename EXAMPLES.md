# 📚 Примеры конфигураций AKUMA SMTP Server

## 🔧 Ручная настройка Postfix

Если нужно дополнительно настроить Postfix после установки:

```bash
# Редактируем main.cf
nano /etc/postfix/main.cf

# Основные параметры
mydomain = yourdomain.com
myhostname = mail.yourdomain.com
myorigin = $mydomain
mydestination = $myhostname, localhost.$mydomain, localhost, $mydomain

# Перезапускаем
systemctl restart postfix
```

## 📧 Настройка виртуальных почтовых ящиков

```bash
# Создаем файл виртуальных алиасов
echo "admin@yourdomain.com    admin" >> /etc/postfix/virtual
echo "support@yourdomain.com support" >> /etc/postfix/virtual
echo "info@yourdomain.com    info" >> /etc/postfix/virtual

# Обновляем базу данных
postmap /etc/postfix/virtual

# Перезапускаем Postfix
systemctl restart postfix
```

## 🛡️ Усиленные настройки безопасности

### Postfix security hardening

```bash
# Добавляем в /etc/postfix/main.cf
disable_vrfy_command = yes
smtpd_helo_required = yes
smtpd_helo_restrictions = 
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_invalid_helo_hostname,
    reject_non_fqdn_helo_hostname,
    reject_unknown_helo_hostname,
    permit

smtpd_sender_restrictions = 
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_non_fqdn_sender,
    reject_unknown_sender_domain,
    permit

smtpd_recipient_restrictions = 
    permit_mynetworks,
    permit_sasl_authenticated,
    reject_unauth_destination,
    reject_non_fqdn_recipient,
    reject_unknown_recipient_domain,
    permit
```

## 📊 Мониторинг и логирование

### Настройка детального логирования

```bash
# В /etc/postfix/main.cf
debug_peer_level = 2
debug_peer_list = gmail.com, yahoo.com, outlook.com

# В /etc/dovecot/dovecot.conf  
mail_debug = yes
auth_verbose = yes
auth_debug = yes
```

### Анализ логов

```bash
# Топ отправителей
grep "from=" /var/log/mail.log | awk '{print $7}' | sort | uniq -c | sort -nr | head -10

# Топ получателей  
grep "to=" /var/log/mail.log | awk '{print $7}' | sort | uniq -c | sort -nr | head -10

# Ошибки доставки
grep "status=bounced" /var/log/mail.log

# DKIM проверки
grep "dkim" /var/log/mail.log | tail -20
```

## 🚀 Настройки для высокой нагрузки

### Оптимизация Postfix

```bash
# В /etc/postfix/main.cf
default_process_limit = 200
smtpd_client_connection_count_limit = 50
smtpd_client_connection_rate_limit = 100
anvil_rate_time_unit = 60s
anvil_status_update_time = 600s

# Очереди
maximal_queue_lifetime = 5d
bounce_queue_lifetime = 5d
maximal_backoff_time = 4000s
minimal_backoff_time = 300s
queue_run_delay = 300s
```

### Оптимизация Dovecot

```bash
# В /etc/dovecot/dovecot.conf
default_process_limit = 1000
default_client_limit = 1000

# В /etc/dovecot/conf.d/10-master.conf
service imap-login {
  inet_listener imap {
    port = 143
  }
  inet_listener imaps {
    port = 993
    ssl = yes
  }
  process_min_avail = 4
  process_limit = 200
}
```

## 📱 Настройки для мобильных клиентов

### iOS Mail

```
Входящий сервер: mail.yourdomain.com
Имя пользователя: username
Пароль: password
Сервер исходящей почты: mail.yourdomain.com
Использовать SSL: Да
Аутентификация: Пароль
IMAP порт: 993
SMTP порт: 465
```

### Android Gmail

```
Тип учетной записи: IMAP
Сервер входящей почты: mail.yourdomain.com:993
Требуется SSL: Да
Сервер исходящей почты: mail.yourdomain.com:465
Требуется SSL: Да
Требуется вход: Да
```

## 🔧 Решение частых проблем

### Проблема: Письма не отправляются

```bash
# Проверяем очередь
postqueue -p

# Принудительная отправка
postqueue -f

# Проверяем логи
tail -f /var/log/mail.log
```

### Проблема: Письма попадают в спам

```bash
# Проверяем DKIM
dig TXT default._domainkey.yourdomain.com

# Проверяем SPF
dig TXT yourdomain.com | grep spf1

# Проверяем DMARC
dig TXT _dmarc.yourdomain.com

# Тестируем на mail-tester.com
echo "Test message" | mail -s "Test" check-auth@verifier.port25.com
```

### Проблема: SSL сертификат не обновляется

```bash
# Ручное обновление
certbot renew --force-renewal

# Проверяем автообновление
systemctl status certbot.timer

# Тестируем обновление
certbot renew --dry-run
```

## 🌐 Интеграция с веб-интерфейсами

### Roundcube Webmail

```bash
# Установка
apt install roundcube roundcube-mysql

# Настройка в /etc/roundcube/config.inc.php
$config['default_host'] = 'ssl://mail.yourdomain.com';
$config['default_port'] = 993;
$config['smtp_server'] = 'ssl://mail.yourdomain.com';
$config['smtp_port'] = 465;
```

### Rainloop

```bash
# Скачиваем
wget -O rainloop.zip http://www.rainloop.net/repository/webmail/rainloop-community-latest.zip

# Распаковываем
unzip rainloop.zip -d /var/www/webmail/

# Настраиваем права
chown -R www-data:www-data /var/www/webmail/
```

## 📈 Backup и восстановление

### Backup конфигураций

```bash
#!/bin/bash
# backup-mail-config.sh

BACKUP_DIR="/backup/mail/$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Backup Postfix
cp -r /etc/postfix $BACKUP_DIR/
cp -r /etc/opendkim $BACKUP_DIR/

# Backup Dovecot
cp -r /etc/dovecot $BACKUP_DIR/

# Backup SSL certificates
cp -r /etc/letsencrypt $BACKUP_DIR/

# Backup mailboxes
tar -czf $BACKUP_DIR/mailboxes.tar.gz /home/*/Maildir/

echo "Backup completed: $BACKUP_DIR"
```

### Восстановление

```bash
#!/bin/bash
# restore-mail-config.sh

BACKUP_DIR="/backup/mail/20241201"

# Stop services
systemctl stop postfix dovecot opendkim

# Restore configs
cp -r $BACKUP_DIR/postfix /etc/
cp -r $BACKUP_DIR/dovecot /etc/
cp -r $BACKUP_DIR/opendkim /etc/

# Restore SSL certificates
cp -r $BACKUP_DIR/letsencrypt /etc/

# Restore mailboxes
tar -xzf $BACKUP_DIR/mailboxes.tar.gz -C /

# Fix permissions
chown -R opendkim:opendkim /etc/opendkim
chown -R dovecot:dovecot /etc/dovecot

# Start services
systemctl start opendkim postfix dovecot
```

## 🎯 Advanced DKIM настройки

### Множественные селекторы

```bash
# Создаем дополнительный селектор
mkdir -p /etc/opendkim/keys/yourdomain.com
opendkim-genkey -s backup -d yourdomain.com -D /etc/opendkim/keys/yourdomain.com/

# Добавляем в KeyTable
echo "backup._domainkey.yourdomain.com yourdomain.com:backup:/etc/opendkim/keys/yourdomain.com/backup.private" >> /etc/opendkim/KeyTable

# Добавляем в SigningTable  
echo "*@yourdomain.com backup._domainkey.yourdomain.com" >> /etc/opendkim/SigningTable
```

---

*Все примеры протестированы на боевых серверах. Используйте с умом!*
