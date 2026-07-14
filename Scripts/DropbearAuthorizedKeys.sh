#!/bin/bash
set -euo pipefail

TARGET_FILES="${1:-${GITHUB_WORKSPACE:-$(pwd)}/wrt/files}"
AUTHORIZED_KEYS_FILE="$TARGET_FILES/etc/dropbear/authorized_keys"

keys="${OPENWRT_DROPBEAR_AUTHORIZED_KEYS:-}"

if [ -z "$keys" ]; then
	echo "dropbear authorized_keys: OPENWRT_DROPBEAR_AUTHORIZED_KEYS is empty; leaving overlay unchanged"
	exit 0
fi

if printf '%s\n' "$keys" | grep -qE 'BEGIN (OPENSSH|RSA|EC|DSA) PRIVATE KEY'; then
	echo "dropbear authorized_keys: refusing to write private key material" >&2
	exit 1
fi

mkdir -p "$(dirname "$AUTHORIZED_KEYS_FILE")"
chmod 700 "$(dirname "$AUTHORIZED_KEYS_FILE")" 2>/dev/null || true
umask 077

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT

printf '%s\n' "$keys" \
	| tr -d '\r' \
	| sed '/^[[:space:]]*$/d' \
	| awk '!seen[$0]++' >"$tmp_file"

if [ ! -s "$tmp_file" ]; then
	echo "dropbear authorized_keys: no public keys after normalization; leaving overlay unchanged"
	exit 0
fi

if grep -vqE '^(ssh-rsa|ssh-ed25519|ecdsa-sha2-|sk-ssh-ed25519@openssh.com|sk-ecdsa-sha2-nistp256@openssh.com)[[:space:]]+' "$tmp_file"; then
	echo "dropbear authorized_keys: invalid public key line detected" >&2
	exit 1
fi

cp "$tmp_file" "$AUTHORIZED_KEYS_FILE"
chmod 600 "$AUTHORIZED_KEYS_FILE" 2>/dev/null || true

count="$(wc -l <"$AUTHORIZED_KEYS_FILE" | tr -d ' ')"
echo "dropbear authorized_keys: wrote $count public key(s)"
