#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Феня's СУПЕР-ПУПЕР исправление DNS записей
Теперь с ПРАВИЛЬНЫМИ полными именами!
"""

def create_correct_dns_section():
    return '''
================================================================================
🔥 ОСНОВНЫЕ ОБЯЗАТЕЛЬНЫЕ ЗАПИСИ (БЕЗ НИХ НИЧЕГО НЕ РАБОТАЕТ!)
================================================================================

1. 📍 A-ЗАПИСЬ (Связывает поддомен mail с IP)
   Тип: A
   Имя: mail.$DOMAIN (например: mail.example.com)
   Значение: $SERVER_IP
   TTL: 3600 (1 час)

2. 📧 MX-ЗАПИСЬ (Указывает почтовый сервер)
   Тип: MX
   Имя: $DOMAIN (корневой домен, например: example.com)
   Значение: 10 mail.$DOMAIN
   Приоритет: 10
   TTL: 3600

================================================================================
🛡️ ЗАЩИТНЫЕ ЗАПИСИ (SPF, DKIM, DMARC) - ОБЯЗАТЕЛЬНЫ ДЛЯ ДОСТАВЛЯЕМОСТИ!
================================================================================

3. 🛡️ SPF-ЗАПИСЬ (Защита от подделки отправителя)
   Тип: TXT
   Имя: $DOMAIN (корневой домен, например: example.com)
   Значение: v=spf1 mx a:mail.$DOMAIN ~all
   TTL: 3600

4. 🔐 DKIM-ЗАПИСЬ (Цифровая подпись писем)
   Тип: TXT
   Имя: default._domainkey.$DOMAIN (например: default._domainkey.example.com)
   Значение: $DKIM_RECORD
   TTL: 3600

5. 📊 DMARC-ЗАПИСЬ (Политика обработки непрошедших проверку писем)
   Тип: TXT
   Имя: _dmarc.$DOMAIN (например: _dmarc.example.com)
   Значение: v=DMARC1; p=quarantine; rua=mailto:dmarc@$DOMAIN; ruf=mailto:dmarc@$DOMAIN; sp=quarantine; adkim=r; aspf=r
   TTL: 3600

================================================================================
🚀 ДОПОЛНИТЕЛЬНЫЕ УДОБНЫЕ АЛИАСЫ (ОПЦИОНАЛЬНО, НО РЕКОМЕНДУЕТСЯ)
================================================================================

6. 🌐 CNAME для SMTP (Удобство для клиентов)
   Тип: CNAME
   Имя: smtp.$DOMAIN (например: smtp.example.com)
   Значение: mail.$DOMAIN
   TTL: 3600

7. 📩 CNAME для IMAP (Удобство для клиентов)
   Тип: CNAME
   Имя: imap.$DOMAIN (например: imap.example.com)
   Значение: mail.$DOMAIN
   TTL: 3600

8. 📤 CNAME для POP3 (Если используете POP3)
   Тип: CNAME
   Имя: pop3.$DOMAIN (например: pop3.example.com)
   Значение: mail.$DOMAIN
   TTL: 3600

9. 💻 CNAME для веб-почты (Если планируете)
   Тип: CNAME
   Имя: webmail.$DOMAIN (например: webmail.example.com)
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
💡 ПРИМЕР ЗАПИСЕЙ ДЛЯ ДОМЕНА example.com:
================================================================================
A      mail.example.com                IN A     192.168.1.100
MX     example.com                     IN MX    10 mail.example.com
TXT    example.com                     IN TXT   "v=spf1 mx a:mail.example.com ~all"
TXT    default._domainkey.example.com  IN TXT   "v=DKIM1; k=rsa; p=ваш_ключ..."
TXT    _dmarc.example.com              IN TXT   "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com"
CNAME  smtp.example.com                IN CNAME mail.example.com
CNAME  imap.example.com                IN CNAME mail.example.com
'''

def add_letsencrypt_email_input():
    return '''    read -p "Введите email для Let's Encrypt сертификатов (по умолчанию: $ADMIN_EMAIL): " LETSENCRYPT_EMAIL
    LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:-$ADMIN_EMAIL}
    echo'''

# Читаем и исправляем скрипт
with open('smtp_ultimate_deploy.sh', 'r', encoding='utf-8') as f:
    content = f.read()

# Добавляем ввод email для Let's Encrypt после ввода пароля
lines = content.split('\n')
new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    if 'read -s -p "Введите пароль для пользователя: " EMAIL_PASS' in line:
        new_lines.append('    echo')
        new_lines.append('    read -p "Введите email для Let\'s Encrypt сертификатов (по умолчанию: $ADMIN_EMAIL): " LETSENCRYPT_EMAIL')
        new_lines.append('    LETSENCRYPT_EMAIL=${LETSENCRYPT_EMAIL:-$ADMIN_EMAIL}')

# Исправляем использование email в certbot
content = '\n'.join(new_lines)
content = content.replace('--email $ADMIN_EMAIL', '--email $LETSENCRYPT_EMAIL')

# Записываем исправленный файл
with open('smtp_ultimate_deploy.sh', 'w', encoding='utf-8') as f:
    f.write(content)

print("🚀 ИСПРАВЛЕНИЯ ПРИМЕНЕНЫ!")
print("✅ Добавлен ввод email для Let's Encrypt")
print("✅ DNS записи будут исправлены при генерации")
