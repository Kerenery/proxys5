#!/bin/bash

set -e

echo "Detecting interface..."

INTERFACE=$(ip route get 1.1.1.1 | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}')

echo "External IP: $INTERFACE"

export INTERFACE

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

exec danted -f /etc/danted.conf -D
