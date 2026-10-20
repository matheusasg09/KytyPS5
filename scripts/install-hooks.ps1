<# Instala apenas o hook local deste projeto, sem substituir hooks existentes.
   O shim chama pre-commit oficial pelo Docker; nenhuma dependência vai ao Windows. #>
[CmdletBinding()]
param()
. "$PSScriptRoot/common.ps1"
Assert-Project
$custom = & git -C $script:ProjectRoot config --get core.hooksPath
if ($LASTEXITCODE -notin @(0,1)) { throw 'Falha ao consultar core.hooksPath.' }
if ($custom) { throw 'core.hooksPath personalizado. Hook existente preservado; integre manualmente após revisão.' }
$target = Get-GitText -Arguments @('rev-parse','--git-path','hooks/pre-commit')
if (-not [IO.Path]::IsPathRooted($target)) { $target = Join-Path $script:ProjectRoot $target }
$source = Join-Path $PSScriptRoot 'pre-commit'
$desired = [IO.File]::ReadAllBytes($source)
if (Test-Path -LiteralPath $target) {
    $actual = [IO.File]::ReadAllBytes($target)
    if ([Convert]::ToBase64String($actual) -ne [Convert]::ToBase64String($desired)) {
        throw "Hook existente diferente, preservado: $target"
    }
    Write-Host 'Hook Docker já instalado; nenhuma alteração.'
    exit 0
}
$stream = [IO.File]::Open($target, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write)
try { $stream.Write($desired, 0, $desired.Length) } finally { $stream.Dispose() }
Write-Host 'Hook oficial de clang-format conectado ao Docker quality. Nenhum pacote instalado no Windows.'
