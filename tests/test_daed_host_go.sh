#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DAED_MAKEFILE="$ROOT_DIR/patches/daed/Makefile"

[ -f "$DAED_MAKEFILE" ] || { echo "missing daed Makefile patch"; exit 1; }

grep -Fq 'DAED_HOST_GO=$(firstword $(wildcard $(STAGING_DIR_HOSTPKG)/lib/go-*/bin/go $(STAGING_DIR_HOSTPKG)/bin/go))' "$DAED_MAKEFILE" || {
  echo "daed Makefile does not define an explicit daemon host go binary"
  exit 1
}

PREPARE_BLOCK="$(awk '/^define Build\/Prepare/{flag=1; next} /^endef$/{flag=0} flag' "$DAED_MAKEFILE")"
COMPILE_BLOCK="$(awk '/^define Build\/Compile/{flag=1; next} /^endef$/{flag=0} flag' "$DAED_MAKEFILE")"

if printf '%s\n' "$PREPARE_BLOCK" | grep -Eq 'go (get -u=patch|mod tidy|mod edit|generate )|\\$\(DAED_HOST_GO\)'; then
  echo "daed Build/Prepare still uses Go commands"
  exit 1
fi

printf '%s\n' "$COMPILE_BLOCK" | grep -Fq '$(DAED_HOST_GO) mod edit -replace github.com/daeuniverse/outbound=../outbound' || {
  echo "daed Build/Compile does not use host go for outbound replacement"
  exit 1
}

printf '%s\n' "$COMPILE_BLOCK" | grep -Fq '$(DAED_HOST_GO) mod edit -replace github.com/olicesx/quic-go=../quic-go' || {
  echo "daed Build/Compile does not use host go for quic-go replacement"
  exit 1
}

printf '%s\n' "$COMPILE_BLOCK" | grep -Fq '$(DAED_HOST_GO) get -u=patch' || {
  echo "daed Build/Compile does not use host go for go get"
  exit 1
}

printf '%s\n' "$COMPILE_BLOCK" | grep -Fq '$(DAED_HOST_GO) mod tidy' || {
  echo "daed Build/Compile does not use host go for go mod tidy"
  exit 1
}

printf '%s\n' "$COMPILE_BLOCK" | grep -Fq '$(DAED_HOST_GO) generate ./...' || {
  echo "daed Build/Compile does not use host go for go generate"
  exit 1
}

printf '%s\n' "$COMPILE_BLOCK" | grep -Fq '$(call GoPackage/Build/Compile)' || {
  echo "daed Build/Compile does not invoke the OpenWrt Go package compiler"
  exit 1
}

if printf '%s\n' "$COMPILE_BLOCK" | grep -Eq '(^|[;[:space:]])go (get -u=patch|mod tidy|mod edit|generate )'; then
  echo "daed Build/Compile still uses bare go commands"
  exit 1
fi

echo "daed host go test passed"
