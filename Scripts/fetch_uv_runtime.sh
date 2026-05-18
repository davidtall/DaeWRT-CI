#!/bin/bash
set -euo pipefail

. "$(dirname "$(realpath "$0")")/retry.sh"

ROOT_DIR="${GITHUB_WORKSPACE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
FILES_DIR="$ROOT_DIR/files"
UV_BIN_DIR="$FILES_DIR/usr/bin"
UV_ROOT_DIR="$FILES_DIR/opt/uv"
UV_PYTHON_DIR="$UV_ROOT_DIR/python"
UV_PYTHON_CACHE_DIR="$UV_ROOT_DIR/python-cache"
UV_PYTHON_MIRROR_DIR="$UV_ROOT_DIR/python-mirror"
UV_CACHE_DIR="$UV_ROOT_DIR/cache"
UV_PYTHON_INSTALL_MIRROR="file:///opt/uv/python-mirror"
UV_AARCH64_ASSET="uv-aarch64-unknown-linux-musl"
UV_X86_64_ASSET="uv-x86_64-unknown-linux-musl"
UV_RELEASES_API="${UV_RELEASES_API:-https://api.github.com/repos/astral-sh/uv/releases/latest}"
PYTHON_RELEASES_API="${PYTHON_RELEASES_API:-https://api.github.com/repos/astral-sh/python-build-standalone/releases?per_page=100}"
UV_FALLBACK_VERSION="${UV_FALLBACK_VERSION:-0.9.20}"
PYTHON_SERIES=(3.10 3.11 3.12 3.13)

warn() {
	echo "WARN: $*" >&2
}

config_file() {
	if [ -n "${WRT_CONFIG:-}" ] && [ -f "$ROOT_DIR/Config/${WRT_CONFIG}.txt" ]; then
		echo "$ROOT_DIR/Config/${WRT_CONFIG}.txt"
	fi
}

map_uv_target() {
	local cfg

	case "${UV_TARGET_TRIPLE:-}" in
		aarch64-unknown-linux-musl|x86_64-unknown-linux-musl)
			echo "$UV_TARGET_TRIPLE"
			return 0
			;;
	esac

	case "${WRT_ARCH:-}" in
		*x86_64*|x86_64)
			echo "${UV_X86_64_ASSET#uv-}"
			return 0
			;;
		*aarch64*|aarch64|*armv8*|armv8|*ipq60*|*ipq807*|*filogic*)
			echo "${UV_AARCH64_ASSET#uv-}"
			return 0
			;;
	esac

	cfg="$(config_file || true)"
	if [ -n "$cfg" ]; then
		if grep -q '^CONFIG_TARGET_x86_64=y$' "$cfg"; then
			echo "${UV_X86_64_ASSET#uv-}"
			return 0
		fi

		if grep -Eq '^CONFIG_TARGET_(qualcommax|mediatek)=y$' "$cfg" || \
			grep -Eq '^CONFIG_TARGET_(mediatek_filogic|rockchip_armv8)=y$' "$cfg"; then
			echo "${UV_AARCH64_ASSET#uv-}"
			return 0
		fi
	fi

	case "${WRT_TARGET:-}" in
		x86)
			echo "${UV_X86_64_ASSET#uv-}"
			return 0
			;;
		qualcommax|mediatek|rockchip)
			echo "${UV_AARCH64_ASSET#uv-}"
			return 0
			;;
	esac

	return 1
}

prepare_overlay_dirs() {
	mkdir -p \
		"$UV_BIN_DIR" \
		"$UV_PYTHON_DIR" \
		"$UV_PYTHON_CACHE_DIR" \
		"$UV_PYTHON_MIRROR_DIR" \
		"$UV_CACHE_DIR"
}

resolve_uv_version() {
	local metadata_file version

	metadata_file="$(mktemp)"
	if retry_cmd 5 15 curl -fsSL "$UV_RELEASES_API" -o "$metadata_file"; then
		version="$(jq -r '.tag_name // empty' "$metadata_file" 2>/dev/null || true)"
		rm -f "$metadata_file"
		printf '%s\n' "$version"
		return 0
	fi

	rm -f "$metadata_file"
	printf '\n'
}

download_uv_binary() {
	local uv_target="$1"
	local uv_version="$2"
	local archive="uv-${uv_target}.tar.gz"
	local url="https://github.com/astral-sh/uv/releases/download/${uv_version}/${archive}"
	local tmpdir uv_binary

	tmpdir="$(mktemp -d)"
	retry_cmd 5 15 curl -fsSL "$url" -o "$tmpdir/$archive"
	tar -xzf "$tmpdir/$archive" -C "$tmpdir"
	uv_binary="$(find "$tmpdir" -type f -name uv -print -quit)"
	[ -n "$uv_binary" ] || {
		rm -rf "$tmpdir"
		echo "ERROR: failed to locate extracted uv binary for $uv_target" >&2
		return 1
	}
	install -m 0755 "$uv_binary" "$UV_BIN_DIR/uv"
	rm -rf "$tmpdir"
}

prepare_mirror_manifest() {
	cat >"$UV_PYTHON_MIRROR_DIR/manifest.txt" <<EOF
mirror=$UV_PYTHON_INSTALL_MIRROR
EOF
}

select_python_asset() {
	local releases_json="$1"
	local series="$2"
	local pbs_target="$3"

	jq -r --arg series "$series" --arg target "$pbs_target" '
		[
			map(select((.draft // false) == false and (.prerelease // false) == false))
			| .[] as $release
			| ($release.assets // [])[]
			| select(.name | test("^cpython-" + ($series | gsub("\\."; "\\\\.")) + "\\.[0-9]+\\+[0-9]+-" + $target + "-install_only\\.tar\\.gz$"))
			| [.name, .browser_download_url]
			| @tsv
		][0] // empty
	' "$releases_json"
}

mirror_python_series() {
	local pbs_target="$1"
	local releases_json="$2"
	local manifest="$UV_PYTHON_MIRROR_DIR/manifest.txt"
	local row asset_name asset_url build_id

	for series in "${PYTHON_SERIES[@]}"; do
		row="$(select_python_asset "$releases_json" "$series" "$pbs_target")"
		if [ -z "$row" ]; then
			warn "no mirrored CPython asset found for $series on $pbs_target"
			continue
		fi

		IFS=$'\t' read -r asset_name asset_url <<EOF
$row
EOF

		build_id=""
		if [[ "$asset_name" =~ \+([0-9]+)- ]]; then
			build_id="${BASH_REMATCH[1]}"
		fi
		if [ -z "$build_id" ]; then
			warn "unable to parse build id from $asset_name"
			continue
		fi

		mkdir -p "$UV_PYTHON_MIRROR_DIR/$build_id"
		if retry_cmd 5 15 curl -fsSL "$asset_url" -o "$UV_PYTHON_MIRROR_DIR/$build_id/$asset_name"; then
			printf '%s\t%s\t%s\n' "$series" "$build_id" "$asset_name" >>"$manifest"
		else
			warn "failed to mirror $asset_name"
		fi
	done
}

fetch_python_releases_json() {
	local output_file="$1"

	if retry_cmd 5 15 curl -fsSL "$PYTHON_RELEASES_API" -o "$output_file"; then
		return 0
	fi

	warn "unable to fetch python-build-standalone release metadata; skipping mirrored Python assets"
	return 1
}

main() {
	local uv_target uv_version releases_json

	prepare_overlay_dirs

	if ! uv_target="$(map_uv_target)"; then
		warn "skipping uv preload for unsupported target (WRT_TARGET=${WRT_TARGET:-unset}, WRT_ARCH=${WRT_ARCH:-unset})"
		exit 0
	fi

	uv_version="$(resolve_uv_version)"
	if [ -z "$uv_version" ]; then
		warn "failed to resolve latest uv release; falling back to $UV_FALLBACK_VERSION"
		uv_version="$UV_FALLBACK_VERSION"
	fi

	download_uv_binary "$uv_target" "$uv_version"
	prepare_mirror_manifest

	releases_json="$(mktemp)"
	if fetch_python_releases_json "$releases_json"; then
		mirror_python_series "$uv_target" "$releases_json"
	fi
	rm -f "$releases_json"
}

main "$@"
