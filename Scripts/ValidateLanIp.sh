#!/bin/bash
set -euo pipefail

ip="${1:-}"

if [[ ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
	echo "ERROR: LAN IP must be a plain IPv4 address, got: ${ip:-<empty>}" >&2
	exit 1
fi

IFS=. read -r o1 o2 o3 o4 <<<"$ip"

for octet in "$o1" "$o2" "$o3" "$o4"; do
	if ((octet < 0 || octet > 255)); then
		echo "ERROR: LAN IP octet out of range: $ip" >&2
		exit 1
	fi
done

if ((o4 == 0 || o4 == 255)); then
	echo "ERROR: LAN IP must be a usable host address, got: $ip" >&2
	exit 1
fi

if ! (
	((o1 == 10)) ||
	((o1 == 172 && o2 >= 16 && o2 <= 31)) ||
	((o1 == 192 && o2 == 168))
); then
	echo "ERROR: LAN IP must be an RFC1918 private IPv4 address, got: $ip" >&2
	exit 1
fi

echo "LAN IP validated: $ip"
