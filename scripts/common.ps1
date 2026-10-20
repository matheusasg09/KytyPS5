Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$OutputEncoding = [Console]::OutputEncoding
$script:ProjectRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
function Invoke-Checked {
    param([string]$Command, [Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command falhou (exit $LASTEXITCODE)." }
}
function Get-GitText {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments)
    $output = & git -C $script:ProjectRoot @Arguments
    if ($LASTEXITCODE -ne 0) { throw "git $($Arguments -join ' ') falhou." }
    return ($output -join "`n").Trim()
}
function Assert-Project {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'Git para Windows não encontrado.' }
    $actual = Get-GitText -Arguments @('rev-parse', '--show-toplevel')
    if ([IO.Path]::GetFullPath($actual) -ne $script:ProjectRoot) { throw 'Raiz Git inesperada.' }
    foreach ($file in @('CMakeLists.txt', 'LICENSE', 'scripts/project.json')) {
        if (-not (Test-Path (Join-Path $script:ProjectRoot $file))) { throw "Projeto inválido: $file ausente." }
    }
    $script:Settings = Get-Content (Join-Path $PSScriptRoot 'project.json') -Raw | ConvertFrom-Json
}
function Assert-Docker {
    if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { throw 'Docker não encontrado.' }
    $os = & docker info --format '{{.OSType}}'
    if ($LASTEXITCODE -ne 0) { throw 'Docker Engine indisponível. Inicie o Docker Desktop existente.' }
    if ($os -ne 'linux') { throw 'Este ambiente exige o backend Linux existente. Não será alternado automaticamente.' }
    $arch = & docker info --format '{{.Architecture}}'
    if ($LASTEXITCODE -ne 0 -or $arch -ne 'x86_64') { throw 'Docker Linux x86-64 necessário.' }
    Invoke-Checked -Command docker -Arguments @('compose', 'version')
}
function Invoke-Compose {
    param([Parameter(ValueFromRemainingArguments=$true)][string[]]$Arguments)
    Invoke-Checked -Command docker -Arguments (@('compose', '--project-directory', $script:ProjectRoot, '-f', (Join-Path $script:ProjectRoot 'compose.yaml')) + $Arguments)
}
function Assert-Clean {
    if (Get-GitText -Arguments @('status', '--porcelain=v1', '--untracked-files=all', '--ignore-submodules=none')) {
        throw 'Há alterações locais ou submódulos modificados. Faça um commit antes de sincronizar.'
    }
    foreach ($state in @('MERGE_HEAD', 'CHERRY_PICK_HEAD', 'rebase-merge', 'rebase-apply')) {
        $path = Get-GitText -Arguments @('rev-parse', '--git-path', $state)
        if (-not [IO.Path]::IsPathRooted($path)) { $path = Join-Path $script:ProjectRoot $path }
        if (Test-Path $path) { throw "Operação Git incompleta: $state." }
    }
}
