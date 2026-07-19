#!/bin/bash
LUA_DIR="$HOME/.local/share/lua-language-server"
exec "$LUA_DIR/bin/lua-language-server" -E "$LUA_DIR/main.lua" "$@"
