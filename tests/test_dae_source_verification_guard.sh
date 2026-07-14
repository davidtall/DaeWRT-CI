#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DAE_MAKEFILE="$ROOT_DIR/package/dae/Makefile"

[ -f "$DAE_MAKEFILE" ] || { echo "missing dae Makefile"; exit 1; }

grep -Fq 'DAE_HOST_GO=$(firstword $(wildcard $(STAGING_DIR_HOSTPKG)/lib/go-*/bin/go $(STAGING_DIR_HOSTPKG)/bin/go))' "$DAE_MAKEFILE" || {
	echo "dae Makefile does not define an explicit host go binary"
	exit 1
}

grep -Fq 'PKG_MIRROR_HASH:=skip' "$DAE_MAKEFILE" || {
	echo "dae Makefile is missing PKG_MIRROR_HASH:=skip"
	exit 1
}

grep -Fq 'OUTBOUND_VERSION:=d7f10a0d190322dfa98bef469c19caa5e72fdbd8' "$DAE_MAKEFILE" || {
	echo "dae Makefile is not pinned to the fixed outbound revision with go-rc2 restored"
	exit 1
}

grep -Fq 'git clone -b $(GIT_BRANCH) $(PKG_SOURCE_URL) $(PKG_BUILD_DIR)' "$DAE_MAKEFILE" || {
	echo "dae Build/Prepare does not clone the configured kdae branch"
	exit 1
}

grep -Fq 'cut -f1' "$DAE_MAKEFILE" || {
	echo "dae Makefile does not resolve the full source revision"
	exit 1
}

grep -Fq 'rm -rf outbound && git clone -b $(OUTBOUND_BRANCH) https://github.com/olicesx/outbound.git outbound && git -C outbound checkout $(OUTBOUND_VERSION)' "$DAE_MAKEFILE" || {
	echo "dae Build/Prepare does not clone and pin the kdae outbound fork inside the source tree"
	exit 1
}

if grep -Fq 'https://github.com/olicesx/quic-go.git' "$DAE_MAKEFILE"; then
	echo "dae Build/Prepare still clones the removed kdae quic-go fork"
	exit 1
fi

PREPARE_BLOCK="$(awk '/^define Build\/Prepare/{flag=1; next} /^endef$/{flag=0} flag' "$DAE_MAKEFILE")"
COMPILE_BLOCK="$(awk '/^define Build\/Compile/{flag=1; next} /^endef$/{flag=0} flag' "$DAE_MAKEFILE")"

if printf '%s\n' "$PREPARE_BLOCK" | grep -Eq 'go (get -u=patch|mod tidy|mod edit|generate )'; then
	echo "dae Build/Prepare still uses Go commands"
	exit 1
fi

printf '%s\n' "$COMPILE_BLOCK" | grep -Fq '$(DAE_HOST_GO) mod edit -replace github.com/daeuniverse/outbound=./outbound' || {
	echo "dae Build/Compile does not replace outbound with the kdae fork"
	exit 1
}

if printf '%s\n' "$COMPILE_BLOCK" | grep -Fq 'github.com/daeuniverse/quic-go=./quic-go'; then
	echo "dae Build/Compile still replaces quic-go with the removed kdae fork"
	exit 1
fi

printf '%s\n' "$COMPILE_BLOCK" | grep -Fq '$(DAE_HOST_GO) get -u=patch' || {
	echo "dae Build/Compile does not use host go for go get"
	exit 1
}

printf '%s\n' "$COMPILE_BLOCK" | grep -Fq '$(DAE_HOST_GO) mod tidy' || {
	echo "dae Build/Compile does not use host go for go mod tidy"
	exit 1
}

printf '%s\n' "$COMPILE_BLOCK" | grep -Fq '$(DAE_HOST_GO) generate ./control/control.go' || {
	echo "dae Build/Compile does not use relative control code generation path"
	exit 1
}

printf '%s\n' "$COMPILE_BLOCK" | grep -Fq '$(DAE_HOST_GO) generate ./trace/trace.go' || {
	echo "dae Build/Compile does not use host go for trace code generation"
	exit 1
}

echo "dae source verification guard test passed"
