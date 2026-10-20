#!/usr/bin/env bash
set -Eeuo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
[[ -f /.dockerenv && $(uname -s) == Linux && $(uname -m) == x86_64 && -d /build && -w /build ]] || { echo 'Execute pelo serviço Docker dev (Linux x86-64).' >&2; exit 2; }
config=${1:-${default_config:-Debug}}
[[ $config == Debug || $config == Release ]] || { echo 'Configuração: Debug ou Release.' >&2; exit 2; }
jobs=${CMAKE_BUILD_PARALLEL_LEVEL:-4}
[[ $jobs =~ ^[1-4]$ ]] || { echo 'CMAKE_BUILD_PARALLEL_LEVEL deve ser de 1 a 4.' >&2; exit 2; }
build_dir="/build/$config"
mkdir -p "$build_dir" /logs /cache/deps /cache/ccache
log_file="/logs/$(date -u +%Y%m%dT%H%M%S)-${operation:-build}-$config-$$.log"
exec > >(tee "$log_file") 2>&1
echo "Log: $log_file"
configure() {
  local tidy=${1:-OFF}
  local deps_dir=/cache/deps
  # FetchContent stores dependency build trees alongside sources. Keep configurations apart.
  if [[ $build_dir != /build/Debug ]]; then deps_dir="/cache/deps-$(basename "$build_dir")"; fi
  command -v clang >/dev/null
  [[ -f 3rdparty/SDL3/CMakeLists.txt && -f 3rdparty/ffmpeg-core/CMakeLists.txt ]] || {
    echo 'Submódulos ausentes. Execute scripts/setup.ps1 no Windows.' >&2; return 2;
  }
  cmake -S . -B "$build_dir" -G Ninja \
    -DCMAKE_BUILD_TYPE="$config" -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_COMPILER_LAUNCHER=ccache -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DBUILD_TESTING=ON \
    -DKYTY_BUILD_ORIGIN=Source -DKYTY_BUILD_LAUNCHER=ON \
    -DFETCHCONTENT_BASE_DIR="$deps_dir" -DKYTY_ENABLE_CLANG_TIDY="$tidy"
}
