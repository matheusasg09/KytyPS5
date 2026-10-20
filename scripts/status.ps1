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
Write-Host 'origin é um destino planejado até a criação e verificação do fork. Consulte DEVELOPMENT.md.'
