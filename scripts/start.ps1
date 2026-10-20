<# Abre shell sem serviço permanente. O container parado é retido; sua remoção exige confirmação. #>
[CmdletBinding()]
param()
. "$PSScriptRoot/common.ps1"
Assert-Project
Assert-Docker
Invoke-Compose -Arguments @('run', '--no-deps', 'dev', 'bash')
