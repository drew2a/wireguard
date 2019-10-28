#!/usr/bin/env bash

# usage:
#     wg-ubuntu-server-up.sh [<number_of_clients>]

clients_count=${1:-10}

mkdir -p "$HOME/wireguard"
mkdir -p "/etc/wireguard"

echo --------------------------install linux headers and enable IPv4 forwarding
sudo apt install -y linux-headers-"$(uname -r)"
sysctl net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-sysctl.conf

echo ---------------------------------------------------------install wireguard
sudo add-apt-repository -y ppa:wireguard/wireguard
sudo apt update
sudo apt install -y wireguard

echo ----------------------------------------------------------install qrencode
sudo apt install -y qrencode

echo -------------------------------------------------- download wg-genconfig.sh
cd "$HOME/wireguard" &&
wget https://raw.githubusercontent.com/drew2a/wireguard/master/wg-genconf.sh
chmod +x ./wg-genconf.sh

echo ----------------------generate configurations for "${clients_count}" clients
./wg-genconf.sh "${clients_count}"

echo -----------------------------------move server\'s config to /etc/wireguard/
mv -v ./wg0.conf \
      /etc/wireguard/

echo ------------------------------------------------------------- run wireguard
wg-quick up wg0
systemctl enable wg-quick@wg0

wg show