# 💣 AKUMA SMTP Server - Ultimate Mail Server Deployment Script 💣

**Автор:** Феня (легендарный хакер и гуру микросервисов)  
**Версия:** 5.0 FINAL BOSS EDITION  
**Email:** dmitriyvisotskiydr15061991@gmail.com  

## 🚀 Описание

Полный автоматический деплой SMTP/IMAP сервера с поддержкой:
- **Postfix** (SMTP сервер)
- **Dovecot** (IMAP/POP3 сервер) 
- **OpenDKIM** (цифровые подписи)
- **Let's Encrypt** (бесплатные SSL сертификаты)
- **UFW Firewall** (автоматическая настройка портов)
- **SPF/DKIM/DMARC** записи для максимальной доставляемости

## ⚡ Быстрый старт

```bash
# Скачиваем скрипт
git clone https://github.com/sweetpotatohack/AKUMA_smtp_server.git
cd AKUMA_smtp_server

# Делаем исполняемым
chmod +x smtp_ultimate_deploy.sh

# Запускаем от root
sudo ./smtp_ultimate_deploy.sh
```

## 🔧 Что устанавливается

- **SMTP порты:** 25, 587 (STARTTLS), 465 (SSL/TLS)
- **IMAP порты:** 143 (STARTTLS), 993 (SSL/TLS)  
- **POP3 порты:** 110 (STARTTLS), 995 (SSL/TLS)
- **SSL сертификаты** от Let's Encrypt с автообновлением
- **DKIM подписи** для защиты от спама
- **Firewall правила** для всех нужных портов

## 📧 Настройки для почтовых клиентов

### Thunderbird / Outlook / Mail.app

**Входящий сервер (IMAP):**
- Сервер: `mail.yourdomain.com`
- Порт: `993` (SSL/TLS) или `143` (STARTTLS)
- Шифрование: SSL/TLS
- Логин: `username` (без @домен)

**Исходящий сервер (SMTP):**
- Сервер: `mail.yourdomain.com`
- Порт: `465` (SSL/TLS) или `587` (STARTTLS)
- Шифрование: SSL/TLS
- Аутентификация: Да
- Логин: `username` (без @домен)

## 🎯 Настройки для Gophish

```
SMTP Host: mail.yourdomain.com
SMTP Port: 465 (SSL/TLS) или 587 (STARTTLS)
Username: username@yourdomain.com
Password: [ваш пароль]
Encryption: SSL/TLS
From Address: username@yourdomain.com
```

## 🌐 Обязательные DNS записи

После установки скрипт создаст файл `/root/DNS_RECORDS_yourdomain.txt` с полными инструкциями. Основные записи:

```dns
# A-запись
mail.yourdomain.com.    IN A     YOUR_SERVER_IP

# MX-запись  
yourdomain.com.         IN MX    10 mail.yourdomain.com

# SPF-запись
yourdomain.com.         IN TXT   "v=spf1 mx a:mail.yourdomain.com ~all"

# DKIM-запись (генерируется скриптом)
default._domainkey.yourdomain.com. IN TXT "v=DKIM1; k=rsa; p=..."

# DMARC-запись
_dmarc.yourdomain.com.  IN TXT   "v=DMARC1; p=quarantine; rua=mailto:dmarc@yourdomain.com"
```

## 🛡️ Требования

- **OS:** Ubuntu 20.04+ / Debian 11+
- **RAM:** Минимум 1GB (рекомендуется 2GB+)
- **Права:** root доступ
- **Домен:** Зарегистрированный домен с доступом к DNS
- **Порты:** 25, 80, 143, 443, 465, 587, 993 должны быть открыты

## 🔍 Проверка работы

```bash
# Проверка статуса сервисов
systemctl status postfix dovecot opendkim

# Проверка портов
netstat -tlnp | grep -E "(25|587|465|143|993)"

# Проверка SSL сертификатов
openssl s_client -connect mail.yourdomain.com:465
openssl s_client -connect mail.yourdomain.com:993

# Проверка DNS записей
dig +short mail.yourdomain.com A
dig +short yourdomain.com MX
dig +short yourdomain.com TXT | grep spf1
dig +short default._domainkey.yourdomain.com TXT
```

## 📊 Онлайн инструменты проверки

1. **MX Toolbox:** https://mxtoolbox.com/
2. **DKIM Validator:** https://dkimvalidator.com/
3. **SPF Record Check:** https://www.kitterman.com/spf/validate.html
4. **Mail Tester:** https://www.mail-tester.com/

## 🔧 Логи и отладка

```bash
# Логи Postfix
tail -f /var/log/mail.log

# Логи Dovecot  
tail -f /var/log/dovecot.log

# Проверка конфигурации Postfix
postfix check

# Проверка конфигурации Dovecot
dovecot -n

# Тест отправки письма
echo "Test email" | mail -s "Test" test@gmail.com
```

## 📁 Структура файлов

```
AKUMA_smtp_server/
├── smtp_ultimate_deploy.sh     # Основной скрипт установки
├── mail_setup_improved.py      # Python версия (устаревшая)
├── setup_mail.sh              # Простая версия (устаревшая)
├── README.md                   # Эта инструкция
├── EXAMPLES.md                 # Примеры конфигураций
├── dns_records_example.txt     # Пример DNS записей
└── requirements.txt            # Python зависимости
```

## ⚠️ Важные предупреждения

1. **DNS записи** обновляются 24-48 часов
2. **PTR запись** должна быть настроена у хостинг-провайдера
3. **Сначала** добавьте A и MX записи, потом защитные (SPF/DKIM/DMARC)
4. **Без SPF/DKIM/DMARC** письма попадут в спам
5. **Backup** конфигураций перед изменениями

## 🆘 Поддержка

Если что-то пошло не так:

1. Проверьте логи: `/var/log/mail.log` и `/var/log/dovecot.log`
2. Убедитесь, что DNS записи добавлены и распространились
3. Проверьте, что все порты открыты и доступны
4. Используйте онлайн инструменты для диагностики

## 📝 Лицензия

MIT License - используйте свободно, но с умом!

## 🎉 Благодарности

Как говорил мой дед: *"Хорошо настроенный почтовый сервер - это как швейцарские часы: работает точно и никого не подводит!"*

---

**Создано с ❤️ и большим количеством кофеина**
