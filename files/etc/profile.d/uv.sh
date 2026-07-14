#!/bin/sh

[ -f /tmp/uv-env.sh ] && . /tmp/uv-env.sh

export UV_PYTHON_INSTALL_MIRROR=file:///opt/uv/python-mirror
