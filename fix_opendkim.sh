#!/bin/bash

# Ебанутый патч от Фени для исправления OpenDKIM

echo "Феня чинит OpenDKIM... Как говорил мой дед: 'Если демон не стартует — добавь PID файл!'"

# Проверяем, есть ли уже PidFile в конфиге
if ! grep -q "PidFile" /etc/opendkim.conf 2>/dev/null; then
    echo "# PID файл для systemd" >> /etc/opendkim.conf
    echo "PidFile                 /run/opendkim/opendkim.pid" >> /etc/opendkim.conf
    echo "PidFile добавлен в конфиг!"
fi

# Создаем директорию для PID файла
mkdir -p /run/opendkim
chown opendkim:opendkim /run/opendkim

echo "OpenDKIM исправлен! Теперь systemd не будет срать кирпичами!"
