#!/bin/bash

# Update system packages
apt update && apt install -y opendkim opendkim-tools

# Create DKIM keys directory
mkdir -p /etc/opendkim/keys/regxa.sbs

# Generate DKIM key
opendkim-genkey -s mail -d regxa.sbs -D /etc/opendkim/keys/regxa.sbs

# Move private key and set permissions
mv /etc/opendkim/keys/regxa.sbs/mail.private /etc/opendkim/keys/regxa.sbs/mail.key
chown opendkim:opendkim /etc/opendkim/keys/regxa.sbs/mail.key
chmod 600 /etc/opendkim/keys/regxa.sbs/mail.key

# Echo instructions for DNS
cat /etc/opendkim/keys/regxa.sbs/mail.txt

echo "Add the above public key to the DNS as TXT record for: mail._domainkey.regxa.sbs"

