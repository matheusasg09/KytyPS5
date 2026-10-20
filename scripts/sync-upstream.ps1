<# Atualiza main por fast-forward e integra em develop por merge. Nunca faz push.
   -Plan consulta Git sem fetch ou alteração. -ValidateOnly testa a integração existente.
   Não apaga nem aborta conflitos automaticamente. #>
[CmdletBinding()]
param([switch]$Plan, [switch]$ValidateOnly, [ValidateSet('Debug','Release')][string]$Configuration = 'Release')
. "$PSScriptRoot/common.ps1"
Assert-Project
Assert-Clean
$official = $script:Settings.officialBranch
$develop = $script:Settings.developmentBranch
foreach ($remote in @('origin','upstream')) {
    $url = Get-GitText -Arguments @('remote', 'get-url', $remote)
    if ($url -cne $script:Settings.$remote) { throw "Remote $remote diferente do esperado. Revise sua configuração local." }
    $pushUrls = Get-GitText -Arguments @('remote', 'get-url', '--push', '--all', $remote)
    if ($pushUrls -ne 'DISABLED') { throw "Push de $remote deve estar bloqueado por padrão." }
}
$current = Get-GitText -Arguments @('branch', '--show-current')
if ($current -ne $develop) { throw "Execute em $develop. Branch atual: $current" }
foreach ($branch in @($official,$develop)) { $null = Get-GitText -Arguments @('rev-parse', '--verify', "refs/heads/$branch") }
if ($Plan) {
    Write-Host "Plano: fetch upstream; fast-forward $official; merge $official em $develop; submódulos; testes $Configuration. Nenhum push."
    exit 0
}
Assert-Docker
$before = Get-GitText -Arguments @('rev-parse', $develop)
if (-not $ValidateOnly) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) { throw 'GitHub CLI necessária para verificar o fork.' }
    $forkText = & gh api repos/matheusasg09/KytyPS5
    if ($LASTEXITCODE -ne 0) { throw 'Fork pessoal ainda não disponível. Nenhuma branch foi alterada.' }
    $fork = $forkText | ConvertFrom-Json
    if (-not $fork.fork -or $fork.parent.full_name -cne 'KytyPS5/KytyPS5') { throw 'origin não é o fork esperado.' }
    Invoke-Checked -Command git -Arguments @('-C', $script:ProjectRoot, 'fetch', '--no-recurse-submodules', 'upstream')
    $remoteHead = Get-GitText -Arguments @('ls-remote', '--symref', 'upstream', 'HEAD')
    if ($remoteHead -notmatch "ref: refs/heads/$official\s+HEAD") { throw 'A branch principal oficial mudou. Revise project.json.' }
    Invoke-Checked -Command git -Arguments @('-C', $script:ProjectRoot, 'merge-base', '--is-ancestor', $official, "upstream/$official")
    Invoke-Checked -Command git -Arguments @('-C', $script:ProjectRoot, 'switch', '--no-overwrite-ignore', $official)
    Invoke-Checked -Command git -Arguments @('-C', $script:ProjectRoot, 'merge', '--no-overwrite-ignore', '--ff-only', "upstream/$official")
    Invoke-Checked -Command git -Arguments @('-C', $script:ProjectRoot, 'switch', '--no-overwrite-ignore', $develop)
    & git -C $script:ProjectRoot merge --no-overwrite-ignore --no-edit $official
    if ($LASTEXITCODE -ne 0) {
        & git -C $script:ProjectRoot diff --name-only --diff-filter=U
        throw 'Merge interrompido. Resolva os conflitos, revise e faça commit. Nenhuma alteração foi descartada.'
    }
    # Recusa protocolos externos ou caminhos fora de 3rdparty antes de baixar novos módulos.
    $entries = Get-GitText -Arguments @('config', '-f', '.gitmodules', '--get-regexp', '^submodule\..*\.(path|url)$')
    foreach ($entry in ($entries -split "`n")) {
        if ($entry -match '\.url\s+(.+)$' -and $Matches[1] -notmatch '^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\.git)?$') { throw 'Nova origem de submódulo exige revisão.' }
        if ($entry -match '\.path\s+(.+)$' -and $Matches[1] -notmatch '^3rdparty/[A-Za-z0-9_-]+$') { throw 'Caminho de submódulo exige revisão.' }
    }
    Invoke-Checked -Command git -Arguments @('-C', $script:ProjectRoot, 'submodule', 'sync', '--recursive')
    # Git também interrompe checkout de módulos se houver mudanças conflitantes. Nunca usa --force.
    Invoke-Checked -Command git -Arguments @('-C', $script:ProjectRoot, '-c', 'protocol.allow=never', '-c', 'protocol.https.allow=always', 'submodule', 'update', '--init', '--recursive', '--jobs', '4')
}
Invoke-Checked -Command git -Arguments @('-C', $script:ProjectRoot, 'merge-base', '--is-ancestor', $before, $develop)
Write-Host 'Commits incorporados:'
Invoke-Checked -Command git -Arguments @('-C', $script:ProjectRoot, 'log', '--oneline', "$before..$develop")
Invoke-Compose -Arguments @('run', '--no-deps', '-T', 'dev', 'bash', 'scripts/test.sh', $Configuration, 'headless')
Write-Host 'Integração validada pelo conjunto headless. Gráficos e suite completa não foram validados. Nenhum push executado.'
