<p align="center">
  <pre>
     _    _  ___    _ __  __    _      ____  __  __ _____ ____
    / \  | |/ / |  | |  \/  |  / \    / ___||  \/  |_   _|  _ \
   / _ \ | ' /| |  | | |\/| | / _ \   \___ \| |\/| | | | | |_) |
  / ___ \|  < | |__| | |  | |/ ___ \   ___) | |  | | | | |  __/
 /_/   \_\_|\_\\____/|_|  |_/_/   \_\ |____/|_|  |_| |_| |_|
  </pre>
</p>

<h3 align="center">Полноценный почтовый сервер за одну команду</h3>

<p align="center">
  <img src="https://img.shields.io/badge/version-6.2-blue" alt="Version">
  <img src="https://img.shields.io/badge/platform-Ubuntu%20%7C%20Debian-orange" alt="Platform">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

---

## О проекте

**AKUMA SMTP** — bash-скрипт для автоматического развёртывания production-ready почтового сервера на Ubuntu/Debian. Скрипт устанавливает и настраивает полный стек: **Postfix** (SMTP) + **Dovecot** (IMAP/POP3) + **OpenDKIM** + **Let's Encrypt** + **Fail2Ban**, а также конфигурирует firewall и генерирует все необходимые DNS-записи.

## Возможности

- **Интерактивный мастер установки** — пошаговый ввод параметров с валидацией
- **SSL/TLS** — автоматическое получение и автообновление сертификатов Let's Encrypt
- **Аутентификация писем** — DKIM-подпись, SPF, DMARC настраиваются автоматически
- **Безопасность** — Fail2Ban для защиты от брутфорса, UFW firewall с преднастроенными правилами
- **Полная проверка** — валидация DNS-записей до установки, тестирование сервисов после
- **Генерация DNS** — скрипт создаёт готовый файл со всеми DNS-записями для вашего провайдера
- **Удаление** — полная деинсталляция одной командой

## Стек

| Компонент | Назначение |
|-----------|-----------|
| **Postfix** | SMTP-сервер (отправка/приём почты) |
| **Dovecot** | IMAP/POP3-сервер (доступ к почте) |
| **OpenDKIM** | Подпись писем (DKIM) |
| **Certbot** | SSL-сертификаты Let's Encrypt |
| **Fail2Ban** | Защита от брутфорса |
| **UFW** | Firewall |

## Требования

- **ОС**: Ubuntu 20.04+ / Debian 11+ (рекомендуется Ubuntu 22.04/24.04)
- **Права**: root
- **Домен** с доступом к управлению DNS
- **Открытые порты**: 25, 80, 110, 143, 443, 465, 587, 993, 995

## Подготовка DNS

**До запуска скрипта** добавьте две обязательные записи у вашего DNS-провайдера:

| Тип | Имя | Значение | Приоритет |
|-----|-----|----------|-----------|
| **A** | `mail.example.com` | IP вашего сервера | — |
| **MX** | `example.com` | `mail.example.com` | 10 |

> Остальные записи (SPF, DKIM, DMARC) скрипт сгенерирует автоматически — их нужно будет добавить после установки.

## Установка

### Быстрый старт

```bash
curl -sSL https://raw.githubusercontent.com/sweetpotatohack/AKUMA_smtp_server/main/smtp.sh -o smtp.sh
chmod +x smtp.sh
sudo ./smtp.sh
```

### Через git

```bash
git clone https://github.com/sweetpotatohack/AKUMA_smtp_server.git
cd AKUMA_smtp_server
chmod +x smtp.sh
sudo ./smtp.sh
```

Скрипт запросит:
1. Домен (например: `example.com`)
2. Имя почтового пользователя (например: `user`)
3. Пароль для пользователя
4. Email администратора (для Let's Encrypt)

После установки все DNS-записи будут сохранены в `/root/DNS_RECORDS_<домен>.txt`.

## Удаление

```bash
sudo ./smtp.sh
# Выберите пункт 2 — "Удалить почтовый сервер"
```

Скрипт полностью удалит все пакеты, конфигурации, сертификаты и почтовых пользователей.

## Настройка почтового клиента

После установки используйте следующие параметры:

**Входящая почта (IMAP):**
```
Сервер: mail.example.com
Порт:   993 (SSL/TLS)
```

**Исходящая почта (SMTP):**
```
Сервер: mail.example.com
Порт:   587 (STARTTLS) или 465 (SSL/TLS)
```

**Логин:** `user@example.com`

## Диагностика

**Проверка сервисов:**
```bash
systemctl status postfix
systemctl status dovecot
systemctl status opendkim
```

**Логи:**
```bash
tail -f /var/log/mail.log       # Postfix
tail -f /var/log/dovecot.log    # Dovecot
```

**Проверка DNS:**
```bash
dig mail.example.com A +short
dig example.com MX +short
dig example.com TXT +short
dig default._domainkey.example.com TXT +short
dig _dmarc.example.com TXT +short
```

**Проверка подключений:**
```bash
openssl s_client -connect mail.example.com:465    # SMTPS
openssl s_client -starttls smtp -connect mail.example.com:587  # SMTP STARTTLS
openssl s_client -connect mail.example.com:993    # IMAPS
```

**Внешние инструменты:**
- [MXToolbox](https://mxtoolbox.com/) — комплексная проверка MX, SPF, DKIM, DMARC
- [Mail Tester](https://www.mail-tester.com/) — оценка доставляемости писем

## Структура конфигураций

```
/etc/postfix/main.cf          — основная конфигурация Postfix
/etc/postfix/master.cf        — сервисы Postfix (SMTP, submission, SMTPS)
/etc/dovecot/dovecot.conf     — конфигурация Dovecot
/etc/opendkim.conf            — конфигурация OpenDKIM
/etc/opendkim/keys/<домен>/   — DKIM-ключи
/etc/fail2ban/jail.local      — правила Fail2Ban
/var/log/mailserver_setup.log — лог установки
/root/DNS_RECORDS_<домен>.txt — сгенерированные DNS-записи
```

## Порты

| Порт | Протокол | Описание |
|------|----------|----------|
| 25 | SMTP | Приём почты от других серверов |
| 465 | SMTPS | SMTP с SSL/TLS |
| 587 | Submission | SMTP с STARTTLS (для клиентов) |
| 993 | IMAPS | IMAP с SSL/TLS |
| 995 | POP3S | POP3 с SSL/TLS |
| 143 | IMAP | IMAP (без шифрования) |
| 110 | POP3 | POP3 (без шифрования) |

## Лицензия

MIT License — свободное использование и модификация.

## Автор

[SweetPotatoHack](https://github.com/sweetpotatohack)
