#!/usr/bin/env bash
set -euo pipefail

required_packages=(gre luci-proto-gre ip-full luci-app-wrtbak vm103-failover)

die() {
	echo "RE-CS-07 artifact guard: $*" >&2
	exit 1
}

validate_device() {
	[ "$1" = 'jdcloud_re-cs-07' ] || die "unsupported expected device: $1"
}

check_manifest() {
	local manifest="$1" package
	for package in "${required_packages[@]}"; do
		grep -Eq "^${package}[[:space:]]+-[[:space:]]+" "$manifest" ||
			die "manifest is missing required package: $package"
	done
}

check_defconfig() {
	local config="$1" device="$2" count package
	[ -f "$config" ] || die "missing defconfig: $config"
	validate_device "$device"
	count="$(grep -Ec '^CONFIG_TARGET_DEVICE_.*=y$' "$config" || true)"
	[ "$count" -eq 1 ] || die "defconfig must enable exactly one device"
	grep -qx "CONFIG_TARGET_DEVICE_qualcommax_ipq60xx_DEVICE_${device}=y" "$config" ||
		die "defconfig does not select $device"
	for package in "${required_packages[@]}"; do
		grep -qx "CONFIG_PACKAGE_${package}=y" "$config" ||
			die "defconfig is missing required package: $package"
	done
}

check_flat_upload() {
	local upload="$1"
	[ -d "$upload" ] || die "missing upload directory: $upload"
	[ -z "$(find "$upload" -mindepth 1 -maxdepth 1 ! -type f -print -quit)" ] ||
		die "upload must contain only top-level regular files"
	[ -z "$(find "$upload" -mindepth 2 -print -quit)" ] ||
		die "upload must not contain nested paths"
}

check_sha256sums() {
	local upload="$1" sysupgrade="$2" manifest="$3" config="$4"
	local line filename actual expected
	local -a checksum_files=()
	while IFS= read -r line || [ -n "$line" ]; do
		[[ "$line" =~ ^[[:xdigit:]]{64}[[:space:]][\ \*](.+)$ ]] ||
			die "SHA256SUMS contains an invalid line"
		filename="${BASH_REMATCH[1]}"
		case "$filename" in
			/*|..|../*|*/../*|*/..) die "SHA256SUMS contains an unsafe path" ;;
		esac
		case "$filename" in
			*/*) die "SHA256SUMS must reference top-level files only" ;;
		esac
		checksum_files+=("$filename")
	done <"$upload/SHA256SUMS"
	[ "${#checksum_files[@]}" -eq 3 ] ||
		die "SHA256SUMS must contain exactly three entries"
	actual="$(printf '%s\n' "${checksum_files[@]}" | sort)"
	expected="$(printf '%s\n' "$sysupgrade" "$manifest" "$config" | sort)"
	[ "$actual" = "$expected" ] ||
		die "SHA256SUMS file set does not match the artifact"
	(cd "$upload" && sha256sum -c SHA256SUMS >/dev/null) ||
		die "SHA256SUMS verification failed"
}

verify_upload() {
	local upload="$1" device="$2" file
	local -a files sysupgrades manifests configs
	validate_device "$device"
	check_flat_upload "$upload"
	mapfile -t files < <(find "$upload" -maxdepth 1 -type f -printf '%f\n' | sort)
	[ "${#files[@]}" -eq 4 ] || die "artifact must contain exactly four files"
	mapfile -t sysupgrades < <(find "$upload" -maxdepth 1 -type f -name "*${device}*sysupgrade.bin" -printf '%f\n')
	mapfile -t manifests < <(find "$upload" -maxdepth 1 -type f -name '*.manifest' -printf '%f\n')
	mapfile -t configs < <(find "$upload" -maxdepth 1 -type f -name 'Config-*.txt' -printf '%f\n')
	[ "${#sysupgrades[@]}" -eq 1 ] || die "artifact must contain one matching sysupgrade"
	[ "${#manifests[@]}" -eq 1 ] || die "artifact must contain one matching manifest"
	[ "${#configs[@]}" -eq 1 ] || die "artifact must contain one final config"
	[ -f "$upload/SHA256SUMS" ] || die "artifact is missing SHA256SUMS"
	for file in "${files[@]}"; do
		case "$file" in
			"${sysupgrades[0]}"|"${manifests[0]}"|"${configs[0]}"|SHA256SUMS) ;;
			*) die "forbidden artifact file: $file" ;;
		esac
	done
	case "${files[*]}" in
		*factory*|*initramfs*|*rootfs*) die "artifact contains a forbidden image type" ;;
	esac
	check_manifest "$upload/${manifests[0]}"
	check_sha256sums "$upload" "${sysupgrades[0]}" "${manifests[0]}" "${configs[0]}"
}

stage_upload() {
	local source="$1" upload="$2" device="$3"
	local -a sysupgrades manifests configs
	validate_device "$device"
	check_flat_upload "$upload"
	mapfile -t sysupgrades < <(find "$source" -type f -name '*sysupgrade.bin' | sort)
	mapfile -t manifests < <(find "$source" -type f -name '*.manifest' | sort)
	[ "${#sysupgrades[@]}" -eq 1 ] || die "build output must contain exactly one sysupgrade"
	case "$(basename "${sysupgrades[0]}")" in
		*"${device}"*sysupgrade.bin) ;;
		*) die "sysupgrade does not match expected device: $device" ;;
	esac
	[ "${#manifests[@]}" -eq 1 ] || die "build output must contain exactly one manifest"
	[ "$(dirname "${sysupgrades[0]}")" = "$(dirname "${manifests[0]}")" ] ||
		die "sysupgrade and manifest must be in the same target directory"
	check_manifest "${manifests[0]}"
	mapfile -t configs < <(find "$upload" -maxdepth 1 -type f -name 'Config-*.txt')
	[ "${#configs[@]}" -eq 1 ] || die "upload staging must contain one final config"
	[ "$(find "$upload" -maxdepth 1 -type f | wc -l)" -eq 1 ] ||
		die "upload staging contains unexpected files"
	cp "${sysupgrades[0]}" "$upload/"
	cp "${manifests[0]}" "$upload/"
	(
		cd "$upload"
		sha256sum "$(basename "${sysupgrades[0]}")" "$(basename "${manifests[0]}")" "$(basename "${configs[0]}")" >SHA256SUMS
	)
	verify_upload "$upload" "$device"
}

case "${1:-}" in
	defconfig)
		[ "$#" -eq 3 ] || die "usage: $0 defconfig CONFIG DEVICE"
		check_defconfig "$2" "$3"
		;;
	stage)
		[ "$#" -eq 4 ] || die "usage: $0 stage SOURCE UPLOAD DEVICE"
		stage_upload "$2" "$3" "$4"
		;;
	verify)
		[ "$#" -eq 3 ] || die "usage: $0 verify UPLOAD DEVICE"
		verify_upload "$2" "$3"
		;;
	*)
		die "expected defconfig, stage, or verify"
		;;
esac
