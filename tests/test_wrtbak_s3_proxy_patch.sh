#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HANDLES="$ROOT_DIR/Scripts/Handles.sh"
WORKFLOW="$ROOT_DIR/.github/workflows/WRT-CORE.yml"

[ -f "$HANDLES" ] || { echo "missing Handles.sh"; exit 1; }

grep -Fq 'patch_wrtbak_proxy_url()' "$HANDLES" || {
	echo "Handles.sh does not define the wrtbak proxy patch"
	exit 1
}

grep -Fq 'luci-app-wrtbak/root/usr/lib/wrtbak/remote_s3.sh' "$HANDLES" || {
	echo "wrtbak proxy patch does not target remote_s3.sh"
	exit 1
}

grep -Fq 'wrtbak_main_option proxy_url ""' "$HANDLES" || {
	echo "wrtbak proxy patch does not read wrtbak main proxy_url"
	exit 1
}

grep -Fq 'WRTBAK_S3_FORCE_DIRECT' "$HANDLES" || {
	echo "wrtbak proxy patch does not preserve firstboot direct-R2 mode"
	exit 1
}

for variable in HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy; do
	grep -Fq "$variable=\"\$wrtbak_proxy_url\"" "$HANDLES" || {
		echo "wrtbak proxy patch does not export $variable to rclone"
		exit 1
	}
done

grep -Fq 'NO_PROXY="${NO_PROXY:-localhost,127.0.0.1,::1}"' "$HANDLES" || {
	echo "wrtbak proxy patch does not preserve local NO_PROXY defaults"
	exit 1
}

grep -Fq 'wrtbak S3 rclone function shape changed' "$HANDLES" || {
	echo "wrtbak proxy patch does not fail loudly when upstream remote_s3.sh changes"
	exit 1
}

grep -Fq 'patch_wrtbak_proxy_url' "$HANDLES" || {
	echo "Handles.sh does not call the wrtbak proxy patch"
	exit 1
}

grep -Fq '$GITHUB_WORKSPACE/Scripts/Handles.sh' "$WORKFLOW" || {
	echo "WRT-CORE does not run Handles.sh during custom package preparation"
	exit 1
}

echo "wrtbak S3 proxy patch guard passed"
