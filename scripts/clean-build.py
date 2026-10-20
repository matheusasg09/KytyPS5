"""Limpeza restrita, chamada somente após a confirmação em clean.ps1."""
import pathlib
import shutil
import sys

name = sys.argv[1]
if name not in {"Debug", "Release", "Analysis-Debug", "Analysis-Release"}:
    raise SystemExit("Configuração inválida")
target = pathlib.Path("/build") / name
if target.is_symlink() or target.resolve().parent != pathlib.Path("/build"):
    raise SystemExit("Alvo fora do volume de build")
if target.exists():
    shutil.rmtree(target)
print(f"Artefatos removidos somente de {target}")
