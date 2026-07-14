#!/bin/bash
set -euo pipefail

PKG_ROOT="${1:-}"

if [ -z "$PKG_ROOT" ]; then
	echo "usage: $0 <luci-app-mosdns-root>" >&2
	exit 1
fi

VIEW_DIR="$PKG_ROOT/htdocs/luci-static/resources/view/mosdns"
BASIC_JS="$VIEW_DIR/basic.js"
UPDATE_JS="$VIEW_DIR/update.js"

[ -d "$VIEW_DIR" ] || exit 0

if [ -f "$BASIC_JS" ]; then
	TMP_BASIC="$(mktemp)"
	awk '
BEGIN {
	replaced = 0
	skip = 0
}
/^async function loadCodeMirrorResources\(\) \{/ {
	replaced = 1
	skip = 1
	print "function loadCodeMirrorResources() {"
	print "\tvar styles = ["
	print "\t\t'\''/luci-static/resources/codemirror5/theme/dracula.min.css'\'',"
	print "\t\t'\''/luci-static/resources/codemirror5/addon/lint/lint.min.css'\'',"
	print "\t\t'\''/luci-static/resources/codemirror5/codemirror.min.css'\'',"
	print "\t];"
	print "\tvar scripts = ["
	print "\t\t'\''/luci-static/resources/codemirror5/libs/js-yaml.min.js'\'',"
	print "\t\t'\''/luci-static/resources/codemirror5/codemirror.min.js'\'',"
	print "\t\t'\''/luci-static/resources/codemirror5/addon/display/autorefresh.min.js'\'',"
	print "\t\t'\''/luci-static/resources/codemirror5/mode/yaml/yaml.min.js'\'',"
	print "\t\t'\''/luci-static/resources/codemirror5/addon/lint/lint.min.js'\'',"
	print "\t\t'\''/luci-static/resources/codemirror5/addon/lint/yaml-lint.min.js'\'',"
	print "\t];"
	print "\tfunction loadStyles() {"
	print "\t\tfor (var hrefIndex = 0; hrefIndex < styles.length; hrefIndex++) {"
	print "\t\t\tvar link = document.createElement('\''link'\'');"
	print "\t\t\tlink.rel = '\''stylesheet'\'';"
	print "\t\t\tlink.href = styles[hrefIndex];"
	print "\t\t\tdocument.head.appendChild(link);"
	print "\t\t}"
	print "\t\treturn Promise.resolve();"
	print "\t}"
	print "\tfunction loadScripts() {"
	print "\t\tvar chain = Promise.resolve();"
	print "\t\tfor (var srcIndex = 0; srcIndex < scripts.length; srcIndex++) {"
	print "\t\t\t(function (currentSrc) {"
	print "\t\t\t\tchain = chain.then(function () {"
	print "\t\t\t\t\treturn new Promise(function (resolve) {"
	print "\t\t\t\t\t\tvar script = document.createElement('\''script'\'');"
	print "\t\t\t\t\t\tscript.src = currentSrc;"
	print "\t\t\t\t\t\tscript.onload = resolve;"
	print "\t\t\t\t\t\tdocument.head.appendChild(script);"
	print "\t\t\t\t\t});"
	print "\t\t\t\t});"
	print "\t\t\t})(scripts[srcIndex]);"
	print "\t\t}"
	print "\t\treturn chain;"
	print "\t}"
	print "\treturn loadStyles().then(function () {"
	print "\t\treturn loadScripts();"
	print "\t});"
	print "}"
	next
}
skip && /^var callMosdns = rpc\.declare\(\{/ {
	skip = 0
}
skip {
	next
}
{
	print
}
END {
	if (!replaced) {
		exit 3
	}
}
' "$BASIC_JS" > "$TMP_BASIC"

	mv "$TMP_BASIC" "$BASIC_JS"
fi

if [ -f "$UPDATE_JS" ]; then
	sed -i 's/for (let t = 0; t < 24; t++) {/for (var t = 0; t < 24; t++) {/' "$UPDATE_JS"
fi

if [ -f "$BASIC_JS" ] && grep -Eq '\basync\b|\bawait\b|=>|\bconst\b' "$BASIC_JS"; then
	echo "mosdns basic.js still contains ES6+ syntax after jsmin compatibility patch" >&2
	exit 1
fi

if [ -f "$UPDATE_JS" ] && grep -Eq '\blet\b' "$UPDATE_JS"; then
	echo "mosdns update.js still contains let after jsmin compatibility patch" >&2
	exit 1
fi
