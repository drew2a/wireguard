#!/usr/bin/env bash
# usage:
#     wg-ubuntu-server-up.sh [<number_of_clients>]

clients_count=${1:-10}
working_dir="$HOME/wireguard"

mkdir -p "${working_dir}"
mkdir -p "/etc/wireguard"

echo ------------------------------------------------------install linux headers
sudo apt install -y linux-headers-"$(uname -r)"

echo ------------------------------------------install software-properties-common
sudo apt install -y software-properties-common

echo ---------------------------------------------------------install wireguard
sudo add-apt-repository -y ppa:wireguard/wireguard
sudo apt update && sudo apt upgrade -y
sudo apt install -y wireguard
sudo modprobe wireguard

echo ----------------------------------------------------------install qrencode
sudo apt install -y qrencode

echo -------------------------------------------------- download wg-genconfig.sh
cd "${working_dir}" &&
wget https://raw.githubusercontent.com/drew2a/wireguard/master/wg-genconf.sh
chmod +x ./wg-genconf.sh

echo ----------------------generate configurations for "${clients_count}" clients
./wg-genconf.sh "${clients_count}"

echo -----------------------------------move server\'s config to /etc/wireguard/
mv -v ./wg0.conf \
      /etc/wireguard/
chown -v root:root /etc/wireguard/wg0.conf
chmod -v 600 /etc/wireguard/wg0.conf

echo ------------------------------------------------------------- run wireguard
wg-quick up wg0
systemctl enable wg-quick@wg0

echo ------------------------------------------------------enable IPv4 forwarding
sysctl net.ipv4.ip_forward=1
echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/99-sysctl.conf

echo ---------------------------------------------------configure firewall rules

sudo iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
sudo iptables -A INPUT -p udp -m udp --dport 55000 -m conntrack --ctstate NEW -j ACCEPT
sudo iptables -A INPUT -s 10.0.0.0/24 -p tcp -m tcp --dport 53 -m conntrack --ctstate NEW -j ACCEPT
sudo iptables -A INPUT -s 10.0.0.0/24 -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT

# make firewall changes persistent
echo iptables-persistent iptables-persistent/autosave_v4 boolean true | sudo debconf-set-selections
echo iptables-persistent iptables-persistent/autosave_v6 boolean true | sudo debconf-set-selections

sudo apt install -y iptables-persistent

sudo systemctl enable netfilter-persistent
sudo netfilter-persistent save

echo ---------------------------------------------install and configure unbound
sudo apt install -y unbound unbound-host

curl -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache
echo 'curl -o /var/lib/unbound/root.hints https://www.internic.net/domain/named.cache' > /etc/cron.monthly/curl_root_hints.sh
chmod +x /etc/cron.monthly/curl_root_hints.sh


cat > /etc/unbound/unbound.conf << ENDOFFILE
server:
    num-threads: 4
    # disable logs
    verbosity: 0
    # list of root DNS servers
    root-hints: "/var/lib/unbound/root.hints"
    # use the root server's key for DNSSEC
    auto-trust-anchor-file: "/var/lib/unbound/root.key"
    # respond to DNS requests on all interfaces
    interface: 0.0.0.0
    max-udp-size: 3072
    # IPs authorised to access the DNS Server
    access-control: 0.0.0.0/0                 refuse
    access-control: 127.0.0.1                 allow
    access-control: 10.0.0.0/24             allow
    # not allowed to be returned for public Internet  names
    private-address: 10.0.0.0/24
    #hide DNS Server info
    hide-identity: yes
    hide-version: yes
    # limit DNS fraud and use DNSSEC
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-referral-path: yes
    # add an unwanted reply threshold to clean the cache and avoid, when possible, DNS poisoning
    unwanted-reply-threshold: 10000000
    # have the validator print validation failures to the log
    val-log-level: 1
    # minimum lifetime of cache entries in seconds
    cache-min-ttl: 1800
    # maximum lifetime of cached entries in seconds
    cache-max-ttl: 14400
    prefetch: yes
    prefetch-key: yes
    # don't use Capitalization randomization as it known to cause DNSSEC issues sometimes
    # see https://discourse.pi-hole.net/t/unbound-stubby-or-dnscrypt-proxy/9378 for further details
    use-caps-for-id: no
    # reduce EDNS reassembly buffer size.
    # suggested by the unbound man page to reduce fragmentation reassembly problems
    edns-buffer-size: 1472
    # ensure kernel buffer is large enough to not lose messages in traffic spikes
    so-rcvbuf: 1m
    # ensure privacy of local IP ranges
    private-address: 10.0.0.0/24
ENDOFFILE

# give root ownership of the Unbound config
sudo chown -R unbound:unbound /var/lib/unbound

# disable systemd-resolved
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# enable Unbound in place of systemd-resovled
sudo systemctl enable unbound
sudo systemctl start unbound

# show wg
wg show

echo && echo You can use this config: client1.conf
echo "--------------------------------------------------------↓"
cat "${working_dir}/client1.conf"
echo "--------------------------------------------------------↑"

echo && echo "Or you could find all the generated configs here: ${working_dir}"
echo

# reboot to make changes effective
echo All done, reboot...
reboot
