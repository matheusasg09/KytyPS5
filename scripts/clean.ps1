<# Por padrão lista alvos. -Execute exige confirmação interativa e limpa somente diretórios de build permitidos.
   Não exclui volumes, imagens, caches, logs ou código. O agente pede autorização no chat antes de -Execute. #>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
param([ValidateSet('Debug','Release','Analysis-Debug','Analysis-Release')][string]$Configuration = 'Debug', [switch]$Execute)
. "$PSScriptRoot/common.ps1"
Assert-Project
Assert-Docker
Write-Host "Alvo exato: volume kytyps5-dev_builds, /build/$Configuration"
Invoke-Compose -Arguments @('run','--no-deps','-T','dev','du','-sh',"/build/$Configuration")
if (-not $Execute) { Write-Host 'Somente relatório. Nenhum arquivo excluído.'; exit 0 }
$running = & docker ps -q --filter label=com.docker.compose.project=kytyps5-dev
if ($LASTEXITCODE -ne 0 -or $running) { throw 'Há containers ativos do projeto, ou a consulta falhou. Limpeza bloqueada.' }
if ($PSCmdlet.ShouldProcess("kytyps5-dev_builds:/build/$Configuration", 'Excluir somente este diretório de build')) {
    Invoke-Compose -Arguments @('run','--no-deps','-T','dev','python3','scripts/clean-build.py',$Configuration)
}
