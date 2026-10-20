<# Prepara somente o checkout existente e a imagem. Não cria fork, faz push ou instala ferramentas no host. #>
[CmdletBinding()]
param([switch]$SkipImageBuild)
. "$PSScriptRoot/common.ps1"
Assert-Project
Assert-Docker
# Reconstitui somente metadados locais ausentes em novos clones do fork.
$remotes = @(Get-GitText -Arguments @('remote')) -join "`n"
foreach ($remote in @('origin','upstream')) {
    if (($remotes -split "`n") -contains $remote) {
        if ((Get-GitText -Arguments @('remote','get-url',$remote)) -cne $script:Settings.$remote) {
            throw "Remote $remote diferente do projeto esperado. Nenhum URL será substituído."
        }
    } else {
        Invoke-Checked -Command git -Arguments @('-C',$script:ProjectRoot,'remote','add',$remote,$script:Settings.$remote)
    }
    Invoke-Checked -Command git -Arguments @('-C',$script:ProjectRoot,'config',"remote.$remote.pushurl",'DISABLED')
}
& git -C $script:ProjectRoot show-ref --verify --quiet "refs/remotes/upstream/$($script:Settings.officialBranch)"
if ($LASTEXITCODE -ne 0) {
    Invoke-Checked -Command git -Arguments @('-C',$script:ProjectRoot,'fetch','--no-recurse-submodules','upstream')
}
foreach ($branch in @($script:Settings.officialBranch,$script:Settings.developmentBranch)) {
    & git -C $script:ProjectRoot show-ref --verify --quiet "refs/heads/$branch"
    if ($LASTEXITCODE -ne 0) {
        $base = "upstream/$($script:Settings.officialBranch)"
        if ($branch -eq $script:Settings.developmentBranch) { $base = $script:Settings.officialBranch }
        Invoke-Checked -Command git -Arguments @('-C',$script:ProjectRoot,'branch',$branch,$base)
    }
}
Invoke-Checked -Command git -Arguments @('-C',$script:ProjectRoot,'branch',"--set-upstream-to=upstream/$($script:Settings.officialBranch)",$script:Settings.officialBranch)
$dirty = Get-GitText -Arguments @('submodule', 'foreach', '--recursive', '--quiet', 'git status --porcelain')
if ($dirty) { throw 'Submódulo com alterações locais. Preparação interrompida.' }
Invoke-Checked -Command git -Arguments @('-C', $script:ProjectRoot, '-c', 'protocol.allow=never', '-c', 'protocol.https.allow=always', 'submodule', 'update', '--init', '--recursive', '--jobs', '4')
if (-not $SkipImageBuild) { Invoke-Compose -Arguments @('build') }
Write-Host 'Preparação concluída. Nenhuma branch existente foi movida. Desenvolva em develop ou em uma branch de trabalho.'
