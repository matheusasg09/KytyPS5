<# Testa o script real em repositórios locais sintéticos. Git real; GitHub e Docker simulados.
   Não faz escrita de rede, não altera o checkout real e preserva os fixtures em .local/sync-tests.
   Execute com Windows PowerShell 5.1: powershell.exe -NoProfile -File scripts/test-sync.ps1 #>
[CmdletBinding()]
param()
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$OutputEncoding = [Console]::OutputEncoding
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$fixtures = Join-Path $root ('.local/sync-tests/' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $fixtures -Force
$gitExe = (Get-Command git.exe).Source
$global:KytyValidationCalls = 0
$global:KytyValidationExit = 0
function global:gh {
    '{"fork":true,"parent":{"full_name":"KytyPS5/KytyPS5"}}'
    $global:LASTEXITCODE = 0
}
function global:docker {
    if ($args[0] -eq 'info') {
        if ($args[2] -eq '{{.OSType}}') { 'linux' } else { 'x86_64' }
        $global:LASTEXITCODE = 0
    } elseif ($args -contains 'run') {
        $global:KytyValidationCalls++
        Write-Host 'Validação Docker simulada, sem executar build.'
        $global:LASTEXITCODE = $global:KytyValidationExit
    } else { 'Docker Compose mock'; $global:LASTEXITCODE = 0 }
}
function Run-Git {
    param([string]$At, [Parameter(ValueFromRemainingArguments=$true)][string[]]$GitArgs)
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $value = & $gitExe -C $At @GitArgs 2>&1
    $ErrorActionPreference = $previousPreference
    if ($LASTEXITCODE -ne 0) { throw "Git de fixture falhou: $value" }
    return ($value -join "`n").Trim()
}
function Commit-File {
    param([string]$At, [string]$File, [string]$Text)
    [IO.File]::WriteAllText((Join-Path $At $File), $Text)
    $null = Run-Git -At $At -GitArgs @('add','--',$File)
    $null = Run-Git -At $At -GitArgs @('commit','-m',"fixture: $File")
}
function New-Fixture {
    param([string]$Name, [switch]$Bootstrap)
    $base = Join-Path $fixtures $Name
    $null = New-Item -ItemType Directory -Path $base
    $official = Join-Path $base 'official'
    $work = Join-Path $base 'work'
    $null = New-Item -ItemType Directory -Path $official
    $null = Run-Git -At $official -GitArgs @('init','-b','main')
    $null = Run-Git -At $official -GitArgs @('config','user.name','matheusasg09')
    $null = Run-Git -At $official -GitArgs @('config','user.email','matheusasg09@gmail.com')
    $null = New-Item -ItemType Directory -Path (Join-Path $official 'scripts')
    foreach ($file in @('common.ps1','sync-upstream.ps1','setup.ps1','project.json')) {
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $official 'scripts')
    }
    [IO.File]::WriteAllText((Join-Path $official 'CMakeLists.txt'), '# fixture')
    [IO.File]::WriteAllText((Join-Path $official 'LICENSE'), 'fixture, not distributed code')
    # Empty .gitmodules is valid for git submodule update, but get-regexp needs an entry.
    [IO.File]::WriteAllText((Join-Path $official '.gitmodules'), "[submodule `"3rdparty/example`"]`n path = 3rdparty/example`n url = https://github.com/KytyPS5/example.git`n")
    Commit-File $official 'shared.txt' 'base'
    $null = Run-Git -At $official -GitArgs @('add','.')
    $null = Run-Git -At $official -GitArgs @('commit','-m','fixture scaffold')
    $null = Run-Git -At $base -GitArgs @('clone',$official,$work)
    $null = Run-Git -At $work -GitArgs @('config','user.name','matheusasg09')
    $null = Run-Git -At $work -GitArgs @('config','user.email','matheusasg09@gmail.com')
    $null = Run-Git -At $work -GitArgs @('remote','set-url','origin','https://github.com/matheusasg09/KytyPS5.git')
    if (-not $Bootstrap) { $null = Run-Git -At $work -GitArgs @('remote','add','upstream','https://github.com/KytyPS5/KytyPS5.git') }
    $null = Run-Git -At $work -GitArgs @('config','remote.origin.pushurl','DISABLED')
    if (-not $Bootstrap) { $null = Run-Git -At $work -GitArgs @('config','remote.upstream.pushurl','DISABLED') }
    $localUrl = $official.Replace('\','/')
    $null = Run-Git -At $work -GitArgs @('config',"url.$localUrl.insteadOf",'https://github.com/KytyPS5/KytyPS5.git')
    # get-url expands insteadOf, so the Git wrapper hides translation from validation only.
    $global:KytyMockWork = $work
    $global:KytyRealGit = $gitExe
    if (-not $Bootstrap) { $null = Run-Git -At $work -GitArgs @('switch','-c','develop') }
    return @{ Official=$official; Work=$work; Script=(Join-Path $work 'scripts/sync-upstream.ps1') }
}
function global:git {
    if (($args -contains 'get-url') -and ($args -notcontains '--push')) {
        if ($args[-1] -eq 'upstream') { 'https://github.com/KytyPS5/KytyPS5.git' }
        else { & $global:KytyRealGit @args; return }
        $global:LASTEXITCODE = 0
    } else { & $global:KytyRealGit @args }
}
function Expect-Failure {
    param([scriptblock]$Action, [string]$Pattern)
    try { & $Action; throw 'EXPECTED_FAILURE_MISSING' }
    catch {
        if ($_.Exception.Message -notmatch $Pattern) { throw }
        Write-Host "PASS bloqueio: $Pattern"
    }
}
$f = New-Fixture 'success'
Commit-File $f.Work 'personal.txt' 'custom'
$custom = Run-Git -At $f.Work -GitArgs @('rev-parse','HEAD')
Commit-File $f.Official 'upstream.txt' 'official improvement'
& $f.Script
$null = Run-Git -At $f.Work -GitArgs @('merge-base','--is-ancestor',$custom,'develop')
if ((Run-Git -At $f.Work -GitArgs @('branch','--show-current')) -ne 'develop') { throw 'Branch não restaurada' }
if ((Run-Git -At $f.Work -GitArgs @('rev-parse','main')) -ne (Run-Git -At $f.Official -GitArgs @('rev-parse','main'))) { throw 'Main não atualizada' }
if (-not (Test-Path (Join-Path $f.Work 'personal.txt'))) { throw 'Melhoria perdida' }
if ($global:KytyValidationCalls -ne 1) { throw 'Validação não invocada' }
Write-Host 'PASS merge real, main atualizada, commits pessoais preservados e validação chamada.'
& $f.Script
if ($global:KytyValidationCalls -ne 2) { throw 'Idempotência falhou' }
Write-Host 'PASS segunda sincronização sem novos commits.'
[IO.File]::WriteAllText((Join-Path $f.Work 'untracked.txt'), 'local')
Expect-Failure { & $f.Script } 'alterações locais'
$null = Run-Git -At $f.Work -GitArgs @('add','untracked.txt')
$null = Run-Git -At $f.Work -GitArgs @('commit','-m','fixture untracked retained')
$null = Run-Git -At $f.Work -GitArgs @('remote','set-url','origin','https://github.com/wrong/repo.git')
Expect-Failure { & $f.Script } 'Remote origin'
$null = Run-Git -At $f.Work -GitArgs @('remote','set-url','origin','https://github.com/matheusasg09/KytyPS5.git')
$global:KytyValidationExit = 7
Expect-Failure { & $f.Script -ValidateOnly } 'docker falhou'
$global:KytyValidationExit = 0
$f = New-Fixture 'conflict'
Commit-File $f.Work 'shared.txt' 'personal change'
$personal = Run-Git -At $f.Work -GitArgs @('rev-parse','HEAD')
Commit-File $f.Official 'shared.txt' 'official incompatible change'
$calls = $global:KytyValidationCalls
Expect-Failure { & $f.Script } 'Merge interrompido'
if (-not (Run-Git -At $f.Work -GitArgs @('diff','--name-only','--diff-filter=U'))) { throw 'Conflito não preservado' }
$null = Run-Git -At $f.Work -GitArgs @('merge-base','--is-ancestor',$personal,'develop')
if ($global:KytyValidationCalls -ne $calls) { throw 'Validou apesar do conflito' }
Expect-Failure { & $f.Script } 'alterações locais|Operação Git incompleta'
Write-Host 'PASS conflito preservado, sem descarte e sem teste indevido.'
$f = New-Fixture 'divergent-main'
$null = Run-Git -At $f.Work -GitArgs @('switch','main')
Commit-File $f.Work 'unwanted-main.txt' 'unexpected'
$mainBefore = Run-Git -At $f.Work -GitArgs @('rev-parse','main')
$null = Run-Git -At $f.Work -GitArgs @('switch','develop')
Commit-File $f.Official 'official.txt' 'new upstream'
Expect-Failure { & $f.Script } 'git falhou'
if ((Run-Git -At $f.Work -GitArgs @('rev-parse','main')) -ne $mainBefore) { throw 'Main divergente foi sobrescrita' }
Write-Host "PASS main divergente protegida. Fixtures preservados em $fixtures"
$f = New-Fixture 'ignored-collision'
Commit-File $f.Work '.gitignore' 'protected.txt'
[IO.File]::WriteAllText((Join-Path $f.Work 'protected.txt'), 'local ignored data')
Commit-File $f.Official 'protected.txt' 'upstream file'
Expect-Failure { & $f.Script } 'git falhou'
if ([IO.File]::ReadAllText((Join-Path $f.Work 'protected.txt')) -ne 'local ignored data') { throw 'Arquivo ignorado sobrescrito' }
Write-Host 'PASS arquivo local ignorado protegido contra sobrescrita.'
$f = New-Fixture 'setup-bootstrap' -Bootstrap
$setup = Join-Path $f.Work 'scripts/setup.ps1'
$before = Run-Git -At $f.Work -GitArgs @('rev-parse','HEAD')
& $setup -SkipImageBuild
& $setup -SkipImageBuild
if ((Run-Git -At $f.Work -GitArgs @('rev-parse','develop')) -ne $before) { throw 'Setup não preservou a base de develop' }
if ((Run-Git -At $f.Work -GitArgs @('branch','--show-current')) -ne 'main') { throw 'Setup trocou a branch atual' }
if ((Run-Git -At $f.Work -GitArgs @('config','branch.main.remote')) -ne 'upstream') { throw 'Setup não configurou tracking' }
Write-Host 'PASS setup em novo clone e segunda execução idempotente, sem mover branches existentes.'
