<# Diagnóstico de leitura, sem iniciar ou alterar serviços. #>
[CmdletBinding()]
param()
. "$PSScriptRoot/common.ps1"
Assert-Project
Write-Host "Projeto: $script:ProjectRoot"
Invoke-Checked -Command git -Arguments @('-C', $script:ProjectRoot, 'status', '--short', '--branch')
Invoke-Checked -Command git -Arguments @('-C', $script:ProjectRoot, 'remote', '-v')
Invoke-Checked -Command git -Arguments @('-C', $script:ProjectRoot, 'branch', '-vv')
Invoke-Checked -Command git -Arguments @('-C', $script:ProjectRoot, 'submodule', 'status', '--recursive')
Assert-Docker
Invoke-Compose -Arguments @('ps', '--all')
Write-Host 'Remotos e branches estão listados acima. O setup bloqueia push; envios exigem autorização. Consulte DEVELOPMENT.md.'
