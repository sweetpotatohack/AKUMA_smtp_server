# 📖 Примеры использования AKUMA SMTP Server

## 🎯 Сценарий 1: Настройка сервера для тестирования

### Шаг 1: Подготовка
```bash
# Обновляем систему
sudo apt update && sudo apt upgrade -y

# Скачиваем скрипт
wget https://raw.githubusercontent.com/sweetpotatohack/AKUMA_smtp_server/main/smtp_ultimate_deploy.sh
chmod +x smtp_ultimate_deploy.sh
```

### Шаг 2: Настройка DNS (пример для test.com)
```dns
A     mail.test.com              IN A     123.456.789.10
MX    test.com                  IN MX    10 mail.test.com
```

### Шаг 3: Запуск скрипта
```bash
sudo ./smtp_ultimate_deploy.sh
```

**Ввод данных:**
- Домен: `test.com`
- Пользователь: `admin`
- Пароль: `SecurePass123!`

### Шаг 4: Результат
```
📧 НАСТРОЙКИ ДЛЯ ПОЧТОВЫХ КЛИЕНТОВ:
Домен: test.com
Сервер: mail.test.com (IP: 123.456.789.10)
Пользователь: admin@test.com
Пароль: SecurePass123!
```

## 🎯 Сценарий 2: Настройка для GoPhish

### Шаг 1: Развертывание сервера
```bash
sudo ./smtp_ultimate_deploy.sh
```

### Шаг 2: Настройка GoPhish
```json
{
  "name": "AKUMA SMTP",
  "host": "mail.yourcompany.com:465",
  "username": "phishing@yourcompany.com",
  "password": "YourSecurePassword",
  "ignore_cert_errors": false,
  "headers": [
    {
      "key": "X-Mailer",
      "value": "GoPhish"
    }
  ]
}
```

### Шаг 3: Тестирование
```bash
# Проверяем подключение
telnet mail.yourcompany.com 465

# Проверяем SSL
openssl s_client -connect mail.yourcompany.com:465
```

## 🎯 Сценарий 3: Корпоративная почта

### Настройка для компании Example Corp

**DNS записи:**
```dns
A     mail.example-corp.com      IN A     192.168.1.100
MX    example-corp.com          IN MX    10 mail.example-corp.com
TXT   example-corp.com          IN TXT   "v=spf1 mx ~all"
TXT   _dmarc.example-corp.com   IN TXT   "v=DMARC1; p=quarantine; rua=mailto:dmarc@example-corp.com"
```

**Пользователи:**
- CEO: `ceo@example-corp.com`
- IT: `it@example-corp.com`
- HR: `hr@example-corp.com`

**Настройки Outlook:**
```
Имя: John Doe
Email: john.doe@example-corp.com
Входящий сервер: mail.example-corp.com:993 (SSL)
Исходящий сервер: mail.example-corp.com:465 (SSL)
```

## 🎯 Сценарий 4: Настройка для пентестинга

### Подготовка домена для социальной инженерии

**1. Регистрируем похожий домен:**
```
Оригинал: google.com
Поддельный: g0ogle.com (с нулем вместо o)
```

**2. Настраиваем DNS:**
```dns
A     mail.g0ogle.com           IN A     YOUR_SERVER_IP
MX    g0ogle.com               IN MX    10 mail.g0ogle.com
TXT   g0ogle.com               IN TXT   "v=spf1 mx ~all"
```

**3. Запускаем скрипт:**
```bash
sudo ./smtp_ultimate_deploy.sh
# Домен: g0ogle.com
# Пользователь: noreply
# Пароль: ComplexPassword123!
```

**4. Настраиваем GoPhish для фишинга:**
```json
{
  "name": "Fake Google",
  "host": "mail.g0ogle.com:465",
  "username": "noreply@g0ogle.com",
  "password": "ComplexPassword123!",
  "ignore_cert_errors": false
}
```

## 🎯 Сценарий 5: Высоконагруженный сервер

### Настройка для большого объема писем

**1. Модифицируем Postfix настройки:**
```bash
# Редактируем /etc/postfix/main.cf
nano /etc/postfix/main.cf

# Добавляем:
# Увеличиваем лимиты
default_process_limit = 200
smtpd_client_connection_count_limit = 50
smtpd_client_connection_rate_limit = 100

# Оптимизируем очереди
maximal_queue_lifetime = 1h
bounce_queue_lifetime = 1h
```

**2. Настраиваем мониторинг:**
```bash
# Установка мониторинга
apt install -y mailgraph pflogsumm

# Просмотр статистики
pflogsumm /var/log/mail.log
```

## 🎯 Сценарий 6: Тестирование безопасности

### Проверка DKIM подписей

**1. Отправляем тестовое письмо:**
```bash
echo "Test DKIM message" | mail -s "DKIM Test" test@gmail.com
```

**2. Проверяем DKIM запись:**
```bash
dig TXT default._domainkey.yourdomain.com
```

**3. Используем внешние инструменты:**
```bash
# Проверка на mail-tester.com
curl -X POST https://www.mail-tester.com/test-your-email
```

### Проверка SPF записей

**1. Тестируем SPF:**
```bash
dig TXT yourdomain.com | grep spf
```

**2. Проверяем через внешние сервисы:**
```bash
# Используем mxtoolbox.com
curl "https://mxtoolbox.com/spf.aspx?domain=yourdomain.com"
```

## 🎯 Сценарий 7: Backup и восстановление

### Создание резервной копии

**1. Backup конфигураций:**
```bash
#!/bin/bash
BACKUP_DIR="/root/mail_backup_$(date +%Y%m%d)"
mkdir -p $BACKUP_DIR

# Копируем конфигурации
cp -r /etc/postfix/ $BACKUP_DIR/
cp -r /etc/dovecot/ $BACKUP_DIR/
cp -r /etc/opendkim/ $BACKUP_DIR/
cp -r /etc/letsencrypt/ $BACKUP_DIR/

# Архивируем
tar -czf mail_backup_$(date +%Y%m%d).tar.gz $BACKUP_DIR/
```

**2. Backup пользователей:**
```bash
# Копируем почтовые ящики
cp -r /home/*/Maildir/ $BACKUP_DIR/mailboxes/

# Копируем пользователей
cp /etc/passwd $BACKUP_DIR/
cp /etc/shadow $BACKUP_DIR/
```

### Восстановление

**1. Восстановление конфигураций:**
```bash
# Распаковываем backup
tar -xzf mail_backup_20231201.tar.gz

# Восстанавливаем конфигурации
cp -r backup/postfix/ /etc/
cp -r backup/dovecot/ /etc/
cp -r backup/opendkim/ /etc/

# Перезапускаем службы
systemctl restart postfix dovecot opendkim
```

## 🎯 Сценарий 8: Интеграция с внешними сервисами

### Настройка с MailHog для тестирования

**1. Установка MailHog:**
```bash
# Скачиваем MailHog
wget https://github.com/mailhog/MailHog/releases/download/v1.0.0/MailHog_linux_amd64
chmod +x MailHog_linux_amd64
sudo mv MailHog_linux_amd64 /usr/local/bin/mailhog

# Запускаем
mailhog &
```

**2. Настройка Postfix для тестирования:**
```bash
# Редактируем /etc/postfix/main.cf
relayhost = [127.0.0.1]:1025

# Перезагружаем
systemctl reload postfix
```

## 🎯 Сценарий 9: Масштабирование

### Настройка нескольких доменов

**1. Добавляем виртуальные домены:**
```bash
# Создаем файл виртуальных доменов
echo "domain1.com" >> /etc/postfix/virtual_domains
echo "domain2.com" >> /etc/postfix/virtual_domains

# Обновляем базу
postmap /etc/postfix/virtual_domains
```

**2. Настраиваем виртуальные алиасы:**
```bash
# Создаем /etc/postfix/virtual_aliases
echo "admin@domain1.com user1@domain1.com" >> /etc/postfix/virtual_aliases
echo "admin@domain2.com user2@domain2.com" >> /etc/postfix/virtual_aliases

# Обновляем
postmap /etc/postfix/virtual_aliases
```

## 🎯 Сценарий 10: Устранение проблем

### Проблема: Письма не отправляются

**Диагностика:**
```bash
# Проверяем статус служб
systemctl status postfix

# Смотрим логи
tail -f /var/log/mail.log

# Проверяем очередь
mailq

# Тестируем подключение
telnet mail.yourdomain.com 25
```

**Решение:**
```bash
# Очищаем очередь
postfix flush

# Перезапускаем службы
systemctl restart postfix
```

---

**💡 Совет:** Всегда тестируйте настройки на тестовом сервере перед применением в продакшене!
