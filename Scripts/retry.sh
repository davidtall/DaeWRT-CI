#!/bin/bash

retry_cmd() {
	local max_attempts=$1
	local sleep_seconds=$2
	local attempt=1
	local exit_code=0
	shift 2

	while true; do
		"$@" && return 0
		exit_code=$?
		if [ "$attempt" -ge "$max_attempts" ]; then
			echo "ERROR: command failed after $attempt attempts: $*" >&2
			return "$exit_code"
		fi
		echo "WARN: command failed (attempt $attempt/$max_attempts): $*" >&2
		echo "WARN: retrying in ${sleep_seconds}s..." >&2
		sleep "$sleep_seconds"
		attempt=$((attempt + 1))
	done
}
