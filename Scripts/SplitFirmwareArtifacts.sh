#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
	echo "usage: $0 <flat-upload-dir> <artifact-groups-dir>" >&2
	exit 1
fi

INPUT_DIR="$1"
OUTPUT_DIR="$2"

[ -d "$INPUT_DIR" ] || {
	echo "firmware artifact splitter: input directory does not exist: $INPUT_DIR" >&2
	exit 1
}

case "$OUTPUT_DIR" in
	''|/|.)
		echo "firmware artifact splitter: unsafe output directory: $OUTPUT_DIR" >&2
		exit 1
		;;
esac

rm -rf -- "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

metadata=()
firmware=()
while IFS= read -r -d '' file; do
	name="$(basename "$file")"
	case "$name" in
		Config-*|*.manifest|*.buildinfo|metadata.json) metadata+=("$file") ;;
		SHA256SUMS|sha256sums|*.sha256) ;;
		*) firmware+=("$file") ;;
	esac
done < <(find "$INPUT_DIR" -mindepth 1 -maxdepth 1 -type f -print0)

for file in "${firmware[@]}"; do
	name="$(basename "$file")"
	case "$name" in
		*jdcloud_re-ss-01*) group='jdcloud_re-ss-01' ;;
		*jdcloud_re-cs-02*) group='jdcloud_re-cs-02' ;;
		*jdcloud_re-cs-07*) group='jdcloud_re-cs-07' ;;
		*) group='other-devices' ;;
	esac
	mkdir -p "$OUTPUT_DIR/$group"
	cp -p -- "$file" "$OUTPUT_DIR/$group/"
done

for group_dir in "$OUTPUT_DIR"/*; do
	[ -d "$group_dir" ] || continue
	for file in "${metadata[@]}"; do
		cp -p -- "$file" "$group_dir/"
	done
	(
		cd "$group_dir"
		find . -maxdepth 1 -type f ! -name SHA256SUMS -printf '%f\n' |
			LC_ALL=C sort | xargs -r sha256sum >SHA256SUMS
	)
done

echo "firmware artifacts split into $OUTPUT_DIR"
