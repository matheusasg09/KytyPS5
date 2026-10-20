#!/usr/bin/env bash
# Smoke test e persistência entre containers, sem limpeza ou exclusão.
set -Eeuo pipefail
cd "$(dirname "$0")/.."
[[ $(id -u) == 1000 && $(uname -m) == x86_64 ]]
for tool in clang clang++ ld.lld cmake ninja python3 git glslangValidator clang-tidy clang-format gdb ccache; do
  command -v "$tool" >/dev/null
done
python3 - <<'PY'
import hashlib
import json
import pathlib
import sys

code = pathlib.Path('/workspace/CMakeLists.txt').read_bytes()
digest = hashlib.sha256(code).hexdigest()
marker = pathlib.Path('/cache/environment-persistence.json')
if marker.exists():
    stored = json.loads(marker.read_text())
    if stored['source_sha256'] != digest:
        sys.exit('A fonte mudou desde o marcador de persistência. Revise antes de repetir.')
    print('PASS marcador de cache e SHA-256 do código preservados entre containers')
else:
    marker.write_text(json.dumps({'source_sha256': digest}))
    print('Marcador de persistência criado no volume de cache')
for root in ('/build', '/cache', '/logs'):
    path = pathlib.Path(root)
    probe = path / 'environment-persistence.txt'
    if probe.exists():
        assert probe.read_text() == 'kytyps5-dev\n'
    else:
        probe.write_text('kytyps5-dev\n')
    print(f'PASS volume acessível para UID 1000: {root}')
try:
    with pathlib.Path('/workspace/.git/HEAD').open('ab'):
        pass
except OSError:
    print('PASS metadados Git protegidos contra escrita pelo container')
else:
    sys.exit('Metadados Git inesperadamente graváveis')
PY
for script in scripts/*.sh; do bash -n "$script"; done
echo 'PASS ferramentas, arquitetura, shell e scripts Bash'
