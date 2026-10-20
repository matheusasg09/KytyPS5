"""Run the upstream formatter in Docker, protecting partially staged files.

staged: official pre-commit hook on staged C++ files; formatting can change the
working copy, but never stages anything. check: read-only check of explicit paths.
apply: official hook on explicit paths. Git metadata remains read-only.
"""
import argparse
from pathlib import Path
import re
import subprocess
import sys

import yaml


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args])


def validate_config(root):
    config = yaml.safe_load((root / ".pre-commit-config.yaml").read_text())
    expected = {"repos": [{
        "repo": "https://github.com/pre-commit/mirrors-clang-format",
        "rev": "v22.1.3",
        "hooks": [{"id": "clang-format", "name": "clang-format (C++)",
                   "files": r"^src/.*\.(?:cpp|h|inc)$", "types": ["file"]}],
    }]}
    if config != expected:
        raise ValueError("A configuração oficial mudou. Revise origem, versão e hooks antes de executar.")
    version = subprocess.check_output(["clang-format", "--version"], text=True)
    if not re.search(r"\bversion 22\.1\.3\b", version):
        raise ValueError("Use o serviço quality com clang-format 22.1.3.")


def select_paths(root, mode, paths):
    if mode == "staged":
        if git(root, "ls-files", "--unmerged"):
            raise ValueError("Há conflitos não resolvidos.")
        paths = git(root, "diff", "--cached", "--name-only", "-z", "--diff-filter=ACMR").decode().split("\0")
    selected = []
    for name in paths:
        path = Path(name)
        if not re.fullmatch(r"src/.*\.(cpp|h|inc)", name):
            continue
        if path.is_absolute() or ".." in path.parts or (root / path).is_symlink():
            raise ValueError("Caminho de fonte inválido: " + name)
        if not (root / path).resolve().is_relative_to(root.resolve()):
            raise ValueError("Caminho fora do projeto: " + name)
        if not (root / path).is_file():
            raise ValueError("Fonte ausente: " + name)
        selected.append(name)
    if mode == "staged" and selected:
        # --files disables pre-commit's stash. Refuse partial staging instead.
        watched = [*selected, ".pre-commit-config.yaml", "src/.clang-format"]
        if git(root, "diff", "--name-only", "--", *watched):
            raise ValueError("Há mudanças não staged nos fontes/configuração. Separe-as antes de formatar.")
        if git(root, "diff", "--cached", "--name-only", "--", ".pre-commit-config.yaml", "src/.clang-format"):
            raise ValueError("Revise alterações na configuração de formatação em um commit separado.")
    return selected


def run(root, mode, paths):
    selected = select_paths(root, mode, paths)
    if not selected:
        print("Nenhum C++ de src selecionado para formatação.")
        return 0
    validate_config(root)
    if mode == "check":
        command = ["clang-format", "--dry-run", "--Werror", "-style=file", *selected]
    else:
        command = ["pre-commit", "run", "clang-format", "--show-diff-on-failure", "--files", *selected]
    return subprocess.run(command, cwd=root).returncode


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("staged", "check", "apply"))
    parser.add_argument("paths", nargs="*")
    args = parser.parse_args()
    if args.mode != "staged" and not args.paths:
        parser.error("Informe arquivos específicos; não formate o repositório inteiro.")
    root = Path(__file__).resolve().parent.parent
    try:
        if not Path("/.dockerenv").exists():
            raise ValueError("Execute pelo serviço Docker quality.")
        return run(root, args.mode, args.paths)
    except (ValueError, subprocess.CalledProcessError) as error:
        print(str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
