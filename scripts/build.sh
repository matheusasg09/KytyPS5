#!/usr/bin/env bash
# Uso: bash scripts/build.sh [Debug|Release] [target ...]
operation=build
source "$(dirname "$0")/container-common.sh"
(( $# == 0 )) || shift
configure
if (( $# == 0 )); then set -- launcher; fi
cmake --build "$build_dir" --parallel "$jobs" --target "$@"
echo "Build Linux concluído: $build_dir"
