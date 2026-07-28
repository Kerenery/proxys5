#!/bin/bash

set -e

echo "Creating PAM config..."

cat > /etc/pam.d/sockd <<EOF
auth required pam_unix.so
account required pam_unix.so
EOF


echo "Detecting external IP..."

EXTERNAL_IP=$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')

echo "External IP: $EXTERNAL_IP"

export INTERFACE=$EXTERNAL_IP


envsubst '${INTERFACE}' \
 < /etc/danted.conf.template \
 > /etc/danted.conf


echo "Generated Dante config:"
cat /etc/danted.conf


echo "Creating proxy user..."

if ! id "$SOCKS_USER" >/dev/null 2>&1
then
    useradd "$SOCKS_USER"
fi

echo "$SOCKS_USER:$SOCKS_PASSWORD" | chpasswd


echo "Starting Dante"

exec sockd -f /etc/danted.conf -D
