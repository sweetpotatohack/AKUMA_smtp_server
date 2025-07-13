#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Феня's ебанутый скрипт для исправления DNS записей в smtp_ultimate_deploy.sh
Как говорил мой дед: "Если DNS кривой — письма идут лесом!"
"""

import re

def fix_smtp_script():
    # Читаем скрипт
    with open('smtp_ultimate_deploy.sh', 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 1. Добавляем ввод email для Let's Encrypt
    # Найдем где запрашивается пароль и добавим email после
    email_input = '''    read -p "Введите email для Let's Encrypt сертификатов: " LETSENCRYPT_EMAIL
    echo'''
    
    # Ищем строку с паролем и добавляем после неё
    pattern = r'(read -s -p "Введите пароль для пользователя: " EMAIL_PASS\s*\n\s*echo)'
    replacement = r'\1\n    ' + email_input
    content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
    
    # 2. Исправляем использование email в Let's Encrypt
    # Заменяем жёстко заданный email на переменную
    content = content.replace('--email $ADMIN_EMAIL', '--email ${LETSENCRYPT_EMAIL:-$ADMIN_EMAIL}')
    
    # 3. Исправляем DNS записи - делаем их полными
    
    # Исправляем SPF запись
    old_spf = r'Значение: v=spf1 mx a:mail\.\$DOMAIN include:mail\.\$DOMAIN ~all'
    new_spf = r'Значение: v=spf1 mx a:mail.$DOMAIN ~all'
    content = re.sub(old_spf, new_spf, content)
    
    # Исправляем DKIM запись - добавляем полное доменное имя
    old_dkim_name = r'Имя: default\._domainkey'
    new_dkim_name = r'Имя: default._domainkey.$DOMAIN'
    content = re.sub(old_dkim_name, new_dkim_name, content)
    
    # Исправляем DMARC запись - добавляем полное доменное имя  
    old_dmarc_name = r'Имя: _dmarc'
    new_dmarc_name = r'Имя: _dmarc.$DOMAIN'
    content = re.sub(old_dmarc_name, new_dmarc_name, content)
    
    # Исправляем MX запись
    old_mx = r'Значение: 10 mail\.\$DOMAIN'
    new_mx = r'Значение: 10 mail.$DOMAIN'
    content = re.sub(old_mx, new_mx, content)
    
    # Исправляем A запись - делаем более понятной
    old_a_name = r'Имя: mail'
    new_a_name = r'Имя: mail (поддомен для $DOMAIN)'
    content = re.sub(old_a_name, new_a_name, content)
    
    # Добавляем примечания о полных записях
    dns_note = '''
================================================================================
💡 ВАЖНО! ВСЕ ЗАПИСИ НУЖНО ДОБАВЛЯТЬ В DNS ВАШЕГО ДОМЕНА!
================================================================================
Если ваш домен: example.com, то:
- default._domainkey.example.com → default._domainkey.$DOMAIN
- _dmarc.example.com → _dmarc.$DOMAIN
- mail.example.com → mail (как поддомен)
================================================================================
'''
    
    # Вставляем примечание после заголовка DNS записей
    dns_header_pattern = r'(💣 ФЕНЯ\'S ПОЛНАЯ ИНСТРУКЦИЯ ПО DNS ЗАПИСЯМ ДЛЯ \$DOMAIN 💣\n================================================================================)'
    content = re.sub(dns_header_pattern, r'\1' + dns_note, content)
    
    # Записываем исправленный файл
    with open('smtp_ultimate_deploy.sh', 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("✅ Скрипт исправлен!")
    print("🔧 Добавлен ввод email для Let's Encrypt")
    print("📧 Исправлены DNS записи - теперь они полные!")
    print("💡 Добавлены пояснения по настройке DNS")

if __name__ == "__main__":
    fix_smtp_script()
