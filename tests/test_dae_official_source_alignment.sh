#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DAE_MAKEFILE="$ROOT_DIR/package/dae/Makefile"

[ -f "$DAE_MAKEFILE" ] || { echo "missing dae Makefile"; exit 1; }

grep -Fq 'PKG_SOURCE_URL:=https://github.com/olicesx/dae.git' "$DAE_MAKEFILE" || {
	echo "dae Makefile is not aligned to the kdae upstream"
	exit 1
}

grep -Fq 'GIT_BRANCH:=kdae' "$DAE_MAKEFILE" || {
	echo "dae Makefile is not pinned to the kdae branch"
	exit 1
}

grep -Fq 'https://github.com/olicesx/outbound.git' "$DAE_MAKEFILE" || {
	echo "dae Makefile does not use the kdae outbound replacement"
	exit 1
}

if grep -Fq 'https://github.com/olicesx/quic-go.git' "$DAE_MAKEFILE"; then
	echo "dae Makefile still clones the removed kdae quic-go replacement"
	exit 1
fi

echo "dae kdae source alignment test passed"
