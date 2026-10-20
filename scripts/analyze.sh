#!/usr/bin/env bash
# Uso: bash scripts/analyze.sh [Debug|Release], análise clang-tidy em diretório separado.
operation=analyze
source "$(dirname "$0")/container-common.sh"
build_dir="/build/Analysis-$config"
mkdir -p "$build_dir"
command -v clang-tidy >/dev/null
configure ON
cmake --build "$build_dir" --parallel "$jobs" --target kyty_emulator
