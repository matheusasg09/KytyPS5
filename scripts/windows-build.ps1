<# Pipeline Windows conforme README/CI oficiais. Não instala ferramentas.
   -Plan é somente leitura e funciona no host. A execução exige um Windows
   isolado identificado por KYTY_ISOLATED_WINDOWS_BUILD=1, toolchain já preparada
   e ambiente x64 do VS 2022. Esse marcador é uma proteção operacional, não uma
   fronteira de segurança. O container Windows ainda não foi provisionado. #>
[CmdletBinding()]
param(
    [ValidateSet('Debug','Release')][string]$Configuration = 'Release',
    [ValidateSet('Build','Test','Install','All')][string]$Operation = 'All',
    [string]$QtRoot = $env:QT_ROOT_DIR,
    [string]$BuildRoot = 'C:\build',
    [string]$LogRoot = 'C:\logs',
    [ValidateRange(1,4)][int]$Jobs = 4,
    [switch]$Plan
)
throw 'Preparação Windows cancelada pelo usuário. Use o serviço Docker Linux dev e scripts/build.sh ou scripts/test.sh.'
. "$PSScriptRoot/common.ps1"
Assert-Project
$build = Join-Path $BuildRoot $Configuration
$testTargets = @('audio_out2_port_tests','pad_haptics_tests','controller_settings_tests',
    'host_input_tests','ime_dialog_tests','lru_cache_tests','virtual_memory_allocation_tests',
    'shader_recompiler_compute_tests','resource_tracking_tests','scalar_provenance_tests',
    'resource_materialization_tests','shader_vertex_metadata_tests','archive_file_tests','avplayer_file_tests')
$pattern = '^(audio_out2_port|pad_haptics|controller_settings|host_input|ime_dialog|lru_cache|resource_tracking|scalar_provenance|resource_materialization|shader_vertex_metadata|archive_file|avplayer_file|virtual_memory_allocation)$'
if ($Plan) {
    Write-Host "Windows $Configuration, operação $Operation; fonte: $script:ProjectRoot"
    Write-Host "Build: $build; instalação: $build/install; logs: $LogRoot; jobs: $Jobs"
    Write-Host 'Pré-requisitos: Windows isolado, VS 2022 x64, clang-cl, Windows SDK, CMake >= 3.22.1, Ninja, Git, Python, glslang e Qt MSVC x64.'
    Write-Host 'Release usa IPO/LTO como a CI. Test seleciona os 13 testes da CI Windows; não valida GPU ou jogos.'
    Write-Host 'Somente plano. Nenhum diretório, configuração, build ou instalação foi alterado.'
    exit 0
}
if ($env:KYTY_ISOLATED_WINDOWS_BUILD -ne '1') {
    throw 'Execução bloqueada no host. Use somente o Windows isolado preparado, com KYTY_ISOLATED_WINDOWS_BUILD=1.'
}
if ($env:VSCMD_ARG_TGT_ARCH -notin @('x64','amd64')) {
    throw 'Abra o ambiente x64 Native Tools do VS 2022 no Windows isolado antes de executar.'
}
foreach ($tool in @('cmake.exe','ctest.exe','ninja.exe','clang-cl.exe','git.exe','python.exe','glslangValidator.exe')) {
    if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) { throw "Ferramenta ausente no ambiente isolado: $tool" }
}
$cmake = & cmake.exe --version
if ($LASTEXITCODE -ne 0 -or $cmake[0] -notmatch 'cmake version (\d+\.\d+\.\d+)') { throw 'Versão CMake inválida.' }
if ([version]$Matches[1] -lt [version]'3.22.1') { throw 'CMake 3.22.1 ou superior necessário.' }
if (-not $QtRoot -or -not (Test-Path (Join-Path $QtRoot 'lib/cmake/Qt6/Qt6Config.cmake'))) {
    throw 'Informe -QtRoot com o Qt MSVC 2022 x64 do Windows isolado; a CI usa 6.10.3.'
}
$source = [IO.Path]::GetFullPath($script:ProjectRoot).TrimEnd('\') + '\'
foreach ($root in @($BuildRoot,$LogRoot)) {
    $resolved = [IO.Path]::GetFullPath($root).TrimEnd('\') + '\'
    if ($resolved.StartsWith($source,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'Build e logs devem ficar fora da árvore de fontes, nos volumes próprios.'
    }
}
$modules = Get-GitText -Arguments @('submodule','status','--recursive')
if (($modules -split "`n") | Where-Object { $_ -match '^[-+U]' }) { throw 'Submódulos ausentes ou fora das revisões fixadas. Prepare-os no Git do host.' }
$dirtyModules = Get-GitText -Arguments @('submodule','foreach','--recursive','--quiet','git status --porcelain')
if ($dirtyModules) { throw 'Submódulos com alterações locais. Nenhum checkout será forçado.' }
$null = New-Item -ItemType Directory -Path $build,$LogRoot -Force
$log = Join-Path $LogRoot ((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmss') + "-windows-$Configuration-$Operation-$PID.log")
$null = Start-Transcript -LiteralPath $log
try {
    $ipo = if ($Configuration -eq 'Release') { 'ON' } else { 'OFF' }
    Invoke-Checked -Command cmake.exe -Arguments @('-S',$script:ProjectRoot,'-B',$build,'-G','Ninja',
        "-DCMAKE_BUILD_TYPE=$Configuration",'-DCMAKE_C_COMPILER=clang-cl','-DCMAKE_CXX_COMPILER=clang-cl',
        "-DCMAKE_PREFIX_PATH=$QtRoot","-DCMAKE_INTERPROCEDURAL_OPTIMIZATION=$ipo",'-DBUILD_TESTING=ON',
        '-DKYTY_BUILD_ORIGIN=Fork','-DKYTY_BUILD_REPOSITORY=matheusasg09/KytyPS5')
    if ($Operation -in @('Build','All','Install')) {
        Invoke-Checked -Command cmake.exe -Arguments @('--build',$build,'--parallel',"$Jobs",'--target','launcher')
    }
    if ($Operation -in @('Test','All')) {
        Invoke-Checked -Command cmake.exe -Arguments (@('--build',$build,'--parallel',"$Jobs",'--target') + $testTargets)
        Invoke-Checked -Command ctest.exe -Arguments @('--test-dir',$build,'--output-on-failure','--no-tests=error','--timeout','180','-j','1','-R',$pattern)
    }
    if ($Operation -in @('Install','All')) {
        Invoke-Checked -Command cmake.exe -Arguments @('--install',$build,'--prefix',"$build/install")
    }
    Write-Host "Operação Windows concluída. Log: $log. Gráficos e jogos não validados."
} finally {
    $null = Stop-Transcript
}
