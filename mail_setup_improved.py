#!/usr/bin/env python3
"""
Improved Mail Server Setup Script with DKIM Configuration
Исправлены все проблемы с настройкой DKIM и SPF записей
"""

import os
import subprocess
import sys
import logging
from pathlib import Path

# Настройка логирования
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class MailServerSetup:
    def __init__(self, domain, selector="mail"):
        self.domain = domain
        self.selector = selector
        self.dkim_dir = Path(f"/etc/opendkim/keys/{domain}")
        self.private_key_path = self.dkim_dir / f"{selector}.private"
        self.public_key_path = self.dkim_dir / f"{selector}.txt"
        
    def run_command(self, command, check=True):
        """Выполнить команду с логированием"""
        logger.info(f"Executing: {command}")
        try:
            result = subprocess.run(command, shell=True, capture_output=True, text=True, check=check)
            if result.stdout:
                logger.info(f"Output: {result.stdout}")
            return result
        except subprocess.CalledProcessError as e:
            logger.error(f"Command failed: {e}")
            logger.error(f"Error output: {e.stderr}")
            if check:
                raise
            return e
    
    def install_packages(self):
        """Установить необходимые пакеты"""
        logger.info("Installing required packages...")
        self.run_command("apt update")
        self.run_command("apt install -y opendkim opendkim-tools postfix")
        
    def generate_dkim_keys(self):
        """Сгенерировать DKIM ключи"""
        logger.info(f"Generating DKIM keys for domain: {self.domain}")
        
        # Создать директорию для ключей
        self.dkim_dir.mkdir(parents=True, exist_ok=True)
        
        # Сгенерировать ключи
        self.run_command(f"opendkim-genkey -s {self.selector} -d {self.domain} -D {self.dkim_dir}")
        
        # Установить правильные права доступа
        self.run_command(f"chown -R opendkim:opendkim {self.dkim_dir}")
        self.run_command(f"chmod 600 {self.private_key_path}")
        
    def get_public_key(self):
        """Получить публичный ключ в формате для DNS"""
        if not self.public_key_path.exists():
            logger.error(f"Public key file not found: {self.public_key_path}")
            return None
            
        with open(self.public_key_path, 'r') as f:
            content = f.read()
            
        # Извлечь значение p= из публичного ключа
        lines = content.split('\n')
        key_parts = []
        for line in lines:
            if 'p=' in line:
                key_parts.append(line.strip())
        
        return ''.join(key_parts)
    
    def configure_opendkim(self):
        """Настроить OpenDKIM"""
        logger.info("Configuring OpenDKIM...")
        
        # Создать KeyTable
        keytable_content = f"{self.selector}._domainkey.{self.domain} {self.domain}:{self.selector}:{self.private_key_path}\n"
        with open('/etc/opendkim/KeyTable', 'w') as f:
            f.write(keytable_content)
            
        # Создать SigningTable
        signingtable_content = f"*@{self.domain} {self.selector}._domainkey.{self.domain}\n"
        with open('/etc/opendkim/SigningTable', 'w') as f:
            f.write(signingtable_content)
            
        # Создать TrustedHosts
        trustedhosts_content = f"""127.0.0.1
localhost
{self.domain}
*.{self.domain}
"""
        with open('/etc/opendkim/TrustedHosts', 'w') as f:
            f.write(trustedhosts_content)
            
        # Настроить основной конфиг OpenDKIM
        config_content = f"""Syslog yes
UMask 002
Socket inet:8892@localhost
PidFile /var/run/opendkim/opendkim.pid
Mode sv
Canonicalization relaxed/simple
ExternalIgnoreList refile:/etc/opendkim/TrustedHosts
InternalHosts refile:/etc/opendkim/TrustedHosts
KeyTable refile:/etc/opendkim/KeyTable
SigningTable refile:/etc/opendkim/SigningTable
LogWhy yes
"""
        with open('/etc/opendkim.conf', 'w') as f:
            f.write(config_content)
            
    def configure_postfix(self):
        """Настроить Postfix для работы с OpenDKIM"""
        logger.info("Configuring Postfix...")
        
        # Добавить настройки DKIM в main.cf
        postfix_dkim_config = """
# OpenDKIM
milter_default_action = accept
milter_protocol = 2
smtpd_milters = inet:localhost:8892
non_smtpd_milters = inet:localhost:8892
"""
        
        with open('/etc/postfix/main.cf', 'a') as f:
            f.write(postfix_dkim_config)
            
    def print_dns_records(self):
        """Вывести DNS записи для настройки"""
        logger.info("Generating DNS records...")
        
        public_key = self.get_public_key()
        if not public_key:
            logger.error("Failed to get public key")
            return
            
        print("\n" + "="*80)
        print("DNS RECORDS TO ADD:")
        print("="*80)
        
        # DKIM запись
        print(f"\n1. DKIM Record:")
        print(f"   Name: {self.selector}._domainkey.{self.domain}")
        print(f"   Type: TXT")
        print(f"   Value: {public_key}")
        
        # SPF запись
        print(f"\n2. SPF Record:")
        print(f"   Name: {self.domain}")
        print(f"   Type: TXT")
        print(f"   Value: v=spf1 a mx include:mail.{self.domain} ~all")
        
        # DMARC запись
        print(f"\n3. DMARC Record:")
        print(f"   Name: _dmarc.{self.domain}")
        print(f"   Type: TXT")
        print(f"   Value: v=DMARC1; p=quarantine; rua=mailto:admin@{self.domain}")
        
        print("="*80)
        print("After adding DNS records, restart services:")
        print("systemctl restart opendkim postfix")
        print("="*80)
        
    def setup(self):
        """Выполнить полную настройку"""
        try:
            self.install_packages()
            self.generate_dkim_keys()
            self.configure_opendkim()
            self.configure_postfix()
            self.print_dns_records()
            
            logger.info("Mail server setup completed successfully!")
            
        except Exception as e:
            logger.error(f"Setup failed: {e}")
            sys.exit(1)

def main():
    if len(sys.argv) != 2:
        print("Usage: python3 mail_setup_improved.py <domain>")
        print("Example: python3 mail_setup_improved.py regxa.sbs")
        sys.exit(1)
        
    domain = sys.argv[1]
    
    # Проверить права root
    if os.geteuid() != 0:
        print("This script must be run as root")
        sys.exit(1)
        
    setup = MailServerSetup(domain)
    setup.setup()

if __name__ == "__main__":
    main()
