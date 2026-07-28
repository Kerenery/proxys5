#!/bin/bash

set -e


echo "Initializing VPS"



apt-get update

apt-get install -y \
    curl \
    ufw \
    ca-certificates



if ! command -v docker >/dev/null
then

    echo "Installing Docker"


    curl -fsSL https://get.docker.com | sh

fi



systemctl enable docker
systemctl start docker



mkdir -p /opt/socks5



echo "Configuring firewall"



ufw --force reset


ufw allow 22/tcp

ufw allow 1080/tcp


ufw --force enable



echo "VPS ready"
