#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCHER="$ROOT_DIR/Scripts/patch_mosdns_jsmin_compat.sh"
TMP_DIR="$(mktemp -d)"
MOSDNS_DIR="$TMP_DIR/luci-app-mosdns/htdocs/luci-static/resources/view/mosdns"

cleanup() {
	rm -rf "$TMP_DIR"
}
trap cleanup EXIT

[ -x "$PATCHER" ] || { echo "missing mosdns jsmin compatibility patcher"; exit 1; }

mkdir -p "$MOSDNS_DIR"

cat > "$MOSDNS_DIR/basic.js" <<'EOF'
'use strict';

async function loadCodeMirrorResources() {
	const styles = [
		'/luci-static/resources/codemirror5/theme/dracula.min.css',
		'/luci-static/resources/codemirror5/addon/lint/lint.min.css',
		'/luci-static/resources/codemirror5/codemirror.min.css',
	];
	const scripts = [
		'/luci-static/resources/codemirror5/libs/js-yaml.min.js',
		'/luci-static/resources/codemirror5/codemirror.min.js',
	];
	const loadStyles = async () => {
		for (const href of styles) {
			const link = document.createElement('link');
			link.rel = 'stylesheet';
			link.href = href;
			document.head.appendChild(link);
		}
	};
	const loadScripts = async () => {
		for (const src of scripts) {
			const script = document.createElement('script');
			script.src = src;
			document.head.appendChild(script);
			await new Promise(resolve => script.onload = resolve);
		}
	};
	await loadStyles();
	await loadScripts();
}

var callMosdns = rpc.declare({
	object: 'luci.mosdns'
});
EOF

cat > "$MOSDNS_DIR/update.js" <<'EOF'
'use strict';

return view.extend({
	render: function () {
		var m, s, o;
		for (let t = 0; t < 24; t++) {
			o.value(t, t + ':00');
		};
		return m.render();
	}
});
EOF

"$PATCHER" "$TMP_DIR/luci-app-mosdns"

grep -q '^function loadCodeMirrorResources() {$' "$MOSDNS_DIR/basic.js" || {
	echo "mosdns basic.js was not downgraded to an ES5-compatible loader function"
	exit 1
}

if grep -Eq '\basync\b|\bawait\b|=>|\bconst\b' "$MOSDNS_DIR/basic.js"; then
	echo "mosdns basic.js still contains ES6+ syntax that breaks LuCI jsmin"
	exit 1
fi

grep -q 'for (var hrefIndex = 0; hrefIndex < styles.length; hrefIndex++) {' "$MOSDNS_DIR/basic.js" || {
	echo "mosdns basic.js does not iterate styles with ES5-compatible syntax"
	exit 1
}

grep -q 'for (var srcIndex = 0; srcIndex < scripts.length; srcIndex++) {' "$MOSDNS_DIR/basic.js" || {
	echo "mosdns basic.js does not iterate scripts with ES5-compatible syntax"
	exit 1
}

grep -q 'return loadStyles().then(function () {' "$MOSDNS_DIR/basic.js" || {
	echo "mosdns basic.js does not use a Promise chain compatible with LuCI jsmin"
	exit 1
}

grep -q 'for (var t = 0; t < 24; t++) {' "$MOSDNS_DIR/update.js" || {
	echo "mosdns update.js did not replace let with var"
	exit 1
}

if grep -Eq '\blet\b' "$MOSDNS_DIR/update.js"; then
	echo "mosdns update.js still contains let"
	exit 1
fi

echo "mosdns jsmin compatibility test passed"
