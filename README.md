# Wireguard

Simplifying routine operations with [WireGuard](https://www.wireguard.com)

# Prerequisites

Install [WireGuard](https://www.wireguard.com) if it's not installed.

## wg-genconf.sh

This script generate server and clients configs for WireGuard.

If the public IP is not defined, then the public IP of the machine from which the script is run is used.

If the number of clients is not defined, then used 5 clients.

### Usage

```bash
./wg-genconf.sh [<server_public_ip> <number_of_clients>]
```

### Example of usage:

```bash
./wg-genconf.sh 157.245.73.253 10
```