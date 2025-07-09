# 🚀 AKUMA SMTP Server - Ultimate Mail Server Deployment

![Version](https://img.shields.io/badge/version-5.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![OS](https://img.shields.io/badge/OS-Ubuntu-orange.svg)
![Status](https://img.shields.io/badge/status-Production%20Ready-brightgreen.svg)

**Автор:** Феня (легендарный хакер и гуру микросервисов)  
**Email:** dmitriyvisotskiydr15061991@gmail.com  
**Версия:** 5.0 FINAL BOSS EDITION  

## 📖 Описание

AKUMA SMTP Server - это полностью автоматизированный скрипт для развертывания production-ready почтового сервера с полным набором современных функций безопасности и шифрования.

### 🎯 Что делает скрипт:

- ✅ **Автоматическая настройка Postfix** (SMTP сервер)
- ✅ **Автоматическая настройка Dovecot** (IMAP/POP3 сервер)
- ✅ **Let's Encrypt SSL сертификаты** (автообновление)
- ✅ **DKIM подписи** (DomainKeys Identified Mail)
- ✅ **SPF записи** (Sender Policy Framework)
- ✅ **DMARC записи** (Domain Message Authentication Reporting)
- ✅ **Автоматическая настройка firewall**
- ✅ **Генерация DNS записей**
- ✅ **Поддержка SSL/TLS шифрования**
- ✅ **Интерактивная настройка**

### 🔧 Поддерживаемые протоколы и порты:

| Протокол | Порт | Шифрование | Описание |
|----------|------|------------|----------|
| SMTP | 25 | STARTTLS | Стандартный SMTP |
| SMTP | 587 | STARTTLS | Submission port |
| SMTPS | 465 | SSL/TLS | Secure SMTP |
| IMAP | 143 | STARTTLS | Стандартный IMAP |
| IMAPS | 993 | SSL/TLS | Secure IMAP |
| POP3 | 110 | STARTTLS | Стандартный POP3 |
| POP3S | 995 | SSL/TLS | Secure POP3 |

## 🛠️ Системные требования

- **ОС:** Ubuntu 20.04+ / Debian 10+
- **RAM:** Минимум 1GB
- **Диск:** Минимум 5GB свободного места
- **Сеть:** Публичный IP адрес
- **Права:** Root доступ
- **DNS:** Настроенный домен

## 🚀 Быстрый старт

### 1. Подготовка DNS записей

Перед запуском скрипта добавьте следующие DNS записи:

```dns
A     mail.yourdomain.com        IN A     YOUR_SERVER_IP
MX    yourdomain.com            IN MX    10 mail.yourdomain.com
```

### 2. Скачивание и запуск

```bash
# Скачиваем скрипт
wget https://raw.githubusercontent.com/sweetpotatohack/AKUMA_smtp_server/main/smtp_ultimate_deploy.sh

# Делаем исполняемым
chmod +x smtp_ultimate_deploy.sh

# Запускаем от root
sudo ./smtp_ultimate_deploy.sh
```

### 3. Интерактивная настройка

Скрипт запросит у вас:
- **Домен:** Ваш домен (например: example.com)
- **Пользователь:** Имя пользователя для почты (например: admin)
- **Пароль:** Пароль для пользователя почты

## 📧 Настройки для почтовых клиентов

### Thunderbird / Outlook

**Входящие сообщения (IMAP):**
- Сервер: `mail.yourdomain.com`
- Порт: `993`
- Шифрование: `SSL/TLS`
- Авторизация: `Обычный пароль`

**Исходящие сообщения (SMTP):**
- Сервер: `mail.yourdomain.com`
- Порт: `465` (SSL/TLS) или `587` (STARTTLS)
- Шифрование: `SSL/TLS`
- Авторизация: `Обычный пароль`

### GoPhish

```json
{
  "host": "mail.yourdomain.com",
  "port": "465",
  "username": "user@yourdomain.com",
  "password": "your_password",
  "encryption": "SSL/TLS"
}
```

## 🌐 DNS записи

После завершения установки скрипт автоматически сгенерирует все необходимые DNS записи в файле `/root/dns_records_yourdomain.com.txt`

### Основные записи:

```dns
# Базовые записи
A     mail.yourdomain.com           IN A     YOUR_SERVER_IP
MX    yourdomain.com               IN MX    10 mail.yourdomain.com

# SPF запись
TXT   yourdomain.com               IN TXT   "v=spf1 mx ~all"

# DMARC запись
TXT   _dmarc.yourdomain.com        IN TXT   "v=DMARC1; p=none; rua=mailto:dmarc@yourdomain.com"

# DKIM запись (генерируется автоматически)
TXT   default._domainkey.yourdomain.com   IN TXT   "v=DKIM1; k=rsa; p=YOUR_DKIM_KEY"
```

### Дополнительные записи (опционально):

```dns
CNAME webmail.yourdomain.com       IN CNAME mail.yourdomain.com
CNAME smtp.yourdomain.com          IN CNAME mail.yourdomain.com
CNAME imap.yourdomain.com          IN CNAME mail.yourdomain.com
```

## 🔐 Безопасность

### Реализованные меры безопасности:

- **Let's Encrypt SSL** - Автоматические SSL сертификаты
- **DKIM подписи** - Подписание исходящих писем
- **SPF записи** - Защита от спуфинга
- **DMARC политики** - Мониторинг и отчеты
- **TLS шифрование** - Защита трафика
- **SASL авторизация** - Безопасная авторизация
- **Firewall** - Автоматическая настройка UFW

### Автоматическое обновление:

- SSL сертификаты обновляются каждые 60 дней
- Настроен cron для автоматического обновления

## 🧪 Тестирование

### Проверка SMTP:

```bash
# Тест подключения
telnet mail.yourdomain.com 25

# Тест SSL
openssl s_client -connect mail.yourdomain.com:465 -servername mail.yourdomain.com
```

### Проверка IMAP:

```bash
# Тест подключения
telnet mail.yourdomain.com 143

# Тест SSL
openssl s_client -connect mail.yourdomain.com:993 -servername mail.yourdomain.com
```

### Проверка DKIM:

```bash
# Проверка DKIM записи
dig TXT default._domainkey.yourdomain.com

# Отправка тестового письма
echo "Test message" | mail -s "Test" test@gmail.com
```

## 📊 Мониторинг и логи

### Основные логи:

```bash
# Postfix логи
tail -f /var/log/mail.log

# Dovecot логи
tail -f /var/log/dovecot.log

# OpenDKIM логи
tail -f /var/log/mail.log | grep opendkim
```

### Проверка статуса служб:

```bash
systemctl status postfix
systemctl status dovecot
systemctl status opendkim
```

## 🛠️ Примеры использования

### Пример 1: Базовая настройка

```bash
sudo ./smtp_ultimate_deploy.sh
# Следуйте инструкциям на экране
```

### Пример 2: Настройка для GoPhish

1. Запустите скрипт и настройте сервер
2. Используйте сгенерированные настройки в GoPhish
3. Проверьте работу через тестовое письмо

### Пример 3: Корпоративная почта

1. Настройте DNS записи для вашего корпоративного домена
2. Запустите скрипт с соответствующими параметрами
3. Настройте почтовые клиенты сотрудников

## 🔧 Продвинутые настройки

### Изменение настроек Postfix:

```bash
# Редактируем main.cf
nano /etc/postfix/main.cf

# Перезагружаем
systemctl reload postfix
```

### Добавление виртуальных доменов:

```bash
# Добавляем в /etc/postfix/virtual_domains
echo "newdomain.com" >> /etc/postfix/virtual_domains

# Обновляем базу
postmap /etc/postfix/virtual_domains
```

## 🐛 Устранение проблем

### Проблема: Порт 25 заблокирован

**Решение:** Многие провайдеры блокируют порт 25. Используйте порт 587 для отправки.

### Проблема: SSL сертификат не получен

**Решение:** Убедитесь, что DNS записи настроены правильно и порт 80 открыт.

### Проблема: Письма попадают в спам

**Решение:** Проверьте настройки DKIM, SPF и DMARC записей.

## 📚 Дополнительные ресурсы

- [Postfix Documentation](http://www.postfix.org/documentation.html)
- [Dovecot Documentation](https://doc.dovecot.org/)
- [Let's Encrypt](https://letsencrypt.org/)
- [OpenDKIM](http://opendkim.org/)

## 🤝 Поддержка

Если у вас возникли проблемы или вопросы:

1. Проверьте раздел "Устранение проблем"
2. Изучите логи системы
3. Создайте Issue в GitHub репозитории
4. Свяжитесь с автором: dmitriyvisotskiydr15061991@gmail.com

## 📝 Лицензия

MIT License

## 🎉 Благодарности

**Как говорил мой дед:** *"Хорошо настроенный почтовый сервер - это как швейцарские часы: работает точно и никого не подводит!"*

---

**Сделано с ❤️ и кофе ☕ командой AKUMA**
