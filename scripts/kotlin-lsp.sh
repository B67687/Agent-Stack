#!/bin/bash
# Wrapper: OpenCode builtin expects binary "kotlin-lsp" but JetBrains ships "kotlin-ls"
# Also adds --stdio flag (defaults to socket mode)
exec /home/nami/.local/bin/kotlin-ls --stdio "$@"
