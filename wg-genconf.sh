#!/usr/bin/env bash
# usage:
#     wg-genconf.sh [<number_of_clients> [<dns_ip> [<server_public_ip>]]]

set -e # exit when any command fails
set -x # enable print all commands

#  clients' count
clients_count=${1:-10}

# dns ip
dns_ip=${2:-10.0.0.1}

# server ip
server_ip=${3}
if [ -z "$server_ip" ]; then
  server_ip=$(hostname -I | awk '{print $1;}') # get only first hostname
fi




server_private_key=$(wg genkey)
server_public_key=$(echo "${server_private_key}" | wg pubkey)
server_config=wg0.conf

# The older code was directly referencing eth0 as the public interface in PostUp&PostDown events.
# Let's find that interface's name dynamic.
# If you have a different configuration just uncomment and edit the following line and comment the next.
#
#server_public_interface=eth0
#
#   thanks https://github.com/buraksarica for this improvement.
server_public_interface=$(route -n | awk '$1 == "0.0.0.0" {print $8}')

echo Generate server \("${server_ip}"\) config:
echo
echo -e "\t$(pwd)/${server_config}"
#
# server configs
#
cat > "${server_config}" <<EOL
[Interface]
Address = 10.0.0.1/24
SaveConfig = true
ListenPort = 51820
PrivateKey = ${server_private_key}
PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${server_public_interface} -j MASQUERADE
PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${server_public_interface} -j MASQUERADE
EOL

echo
echo Generate configs for "${clients_count}" clients:
echo
#
# clients configs
#
for i in $(seq 1 "${clients_count}");
do
    client_private_key=$(wg genkey)
    client_public_key=$(echo "${client_private_key}" | wg pubkey)
    client_ip=10.0.0.$((i+1))/32
    client_config=client$i.conf
    echo -e "\t$(pwd)/${client_config}"
  	cat > "${client_config}" <<EOL
[Interface]
PrivateKey = ${client_private_key}
ListenPort = 51820
Address = ${client_ip}
DNS = ${dns_ip}

[Peer]
PublicKey = ${server_public_key}
AllowedIPs = 0.0.0.0/0
Endpoint = ${server_ip}:51820
PersistentKeepalive = 21
EOL
    cat >> "${server_config}" <<EOL
[Peer]
PublicKey = ${client_public_key}
AllowedIPs = ${client_ip}
EOL
done
