# Desenvolvimento isolado do KytyPS5

Ambiente preparado em 2026-10-20 a partir de `KytyPS5/KytyPS5`, commit `7b7f9a70c652afd6ec8ea8599884d9b4b3abc9f3`, branch oficial **main**. Consulte `docs/ENVIRONMENT-VALIDATION.md` para resultados observados e pendências. O código do emulador não foi alterado.

## Pré-requisitos e início

No Windows são usados somente Git, GitHub CLI, PowerShell e o Docker Desktop existentes. Compiladores, bibliotecas e ferramentas de diagnóstico ficam na imagem. Não configure WSL, Hyper-V, SDKs ou outro backend. Se o Engine estiver parado, inicie o Docker Desktop existente; `docker desktop start` usa sua configuração atual. O serviço exige Linux x86-64.

Na raiz, em PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\setup.ps1
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\status.ps1
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\start.ps1
```

`setup.ps1` valida o checkout e os remotos, acrescenta remotos/branches locais ausentes em um novo clone, bloqueia push, configura main para acompanhar upstream/main, atualiza submódulos nas revisões fixadas e constrói a imagem. Não move branches existentes nem troca sua branch atual. Não cria o fork nem instala nada no host. `start.ps1` abre um shell; `exit` encerra o processo. Não existe serviço permanente. Containers encerrados são retidos por padrão, pois sua exclusão exige autorização separada. Após autorização específica para containers descartáveis, é possível usar `docker compose run --rm dev`.

O Windows PowerShell 5.1 desta máquina usa política de execução restrita. Os comandos acima aplicam `RemoteSigned` somente ao processo atual, sem mudar a política do usuário ou do sistema. Os scripts usam UTF-8 com BOM para preservar acentos no PowerShell 5.1. Com uma sessão que já permite scripts locais, também é possível invocá-los diretamente.

## Estrutura e persistência

- Código e histórico: esta pasta Windows, bind mount em `/workspace`. Git interno em `/workspace/.git` é somente leitura para o container; operações Git do projeto ocorrem no Windows.
- Imagem: `Dockerfile`, base oficial Debian 13.1 slim fixada por digest; `.dockerignore` permite somente o Dockerfile no contexto de build. O código e credenciais não entram na imagem.
- Serviço: `compose.yaml`, projeto `kytyps5-dev`, UID/GID 1000, 4 CPUs, 10 GiB RAM, sem swap extra, 512 PIDs, sem capacidades, sem portas e sem Docker socket.
- Volume `kytyps5-dev_builds`: `/build/Debug`, `/build/Release`, `/build/Analysis-Debug`, `/build/Analysis-Release` e instalações opcionais.
- Volume `kytyps5-dev_caches`: `/cache/ccache` (limite 2 GiB), `/cache/deps` (FetchContent Debug), `/cache/deps-Release` e `/cache/deps-Analysis-*`. FetchContent guarda fontes e builds auxiliares; cada configuração tem sua própria árvore para evitar misturar bibliotecas Debug/Release. Downloads FFmpeg ficam no volume de build por configuração.
- Volume `kytyps5-dev_logs`: `/logs`, logs de build, configuração e testes com data UTC e PID.
- `.local/`: evidências auxiliares locais e simulações Git, ignoradas pelo Git.

O filesystem da imagem é somente leitura; `/tmp` e a home são temporários. O bind do projeto permite editar código, mas não expõe a home Windows. Encerrar ou remover um container não remove o código no host nem volumes nomeados. Isso não equivale a isolamento de segurança absoluto. CMake e dependências executam código durante a configuração: revise novas origens antes de usar.

## Dependências

Clang/LLD e headers C/C++, CMake, Ninja, Git, Python, pkg-config, glslang, Qt 6 (Core, Concurrent, Network, Widgets, DBus e suporte Wayland), bibliotecas de desenvolvimento SDL para ALSA, PulseAudio, X11, Wayland, udev e DBus. Vulkan-Headers, SDL3, SPIRV-Tools/Headers, VMA, fmt, Tracy, spdlog, LibAtrac9, JSON, ImGui, xxHash e magic_enum vêm dos submódulos fixados pelo upstream.

CMake busca Opus, OpenXR SDK, xbyak, Zydis/zycore, zstd e ZArchive em commits definidos em `3rdparty/CMakeLists.txt`. FFmpeg estático vem do release do commit do submódulo `KytyPS5/ext-ffmpeg-core`; não é instalado FFmpeg do sistema. Não são necessários BIOS, firmware, jogos ou chaves Sony para compilar/testar o conjunto headless.

Extras de desenvolvimento dentro da imagem: ccache, clang-tidy, clang-format, GDB e file. Este ambiente não instala Qt nem compiladores no host. A versão de clang-format da distribuição difere do hook oficial `v22.1.3`: não formate o repositório inteiro e use o hook oficial em ambiente isolado antes de submeter C++ ao upstream. Nenhum hook que instale dependências no Windows foi ativado.

O digest da base e os commits externos fixam entradas importantes, mas apt usa os repositórios Debian correntes e o download FFmpeg do upstream não fixa SHA-256 no CMake. A receita é reproduzível operacionalmente, não um build hermético ou idêntico byte a byte. Guarde o manifesto `dpkg-query -W`, ID da imagem e checksums dos artefatos ao comparar builds. Mudanças upstream podem exigir reconstruir a imagem.

## Build, testes e análise

```powershell
docker compose build
docker compose run --no-deps -T dev bash scripts/build.sh Debug
docker compose run --no-deps -T dev bash scripts/build.sh Release
docker compose run --no-deps -T dev bash scripts/test.sh Debug headless
docker compose run --no-deps -T dev bash scripts/test.sh Release headless
docker compose run --no-deps -T dev bash scripts/analyze.sh Debug
```

`build.sh` constrói `launcher`, que depende do emulador e updater. Para um alvo específico, acrescente seu nome, por exemplo `bash scripts/build.sh Debug bit_array_tests`. Todos os scripts localizam a raiz. Use `bash scripts/...` para funcionar também com arquivos vindos do Windows sem depender do bit executável. `CMAKE_BUILD_PARALLEL_LEVEL` aceita 1 a 4. Execute operações de build em sequência para respeitar o orçamento de recursos e evitar dois processos na mesma configuração.

`test.sh headless` compila e executa explicitamente os 15 testes escolhidos na CI Linux oficial: áudio de porta, haptics, controles, host input, IME, LRU, rastreamento de memória, páginas, recursos, proveniência, materialização, metadados de shader, arquivos de archive/avplayer e memória virtual. Não exige jogos ou uma GPU passada ao container. `ctest` falha se nenhum teste for encontrado. Logs persistem mesmo quando a compilação falha.

```powershell
docker compose run --no-deps -T dev bash scripts/test.sh Debug all
```

`all` constrói `kyty_tests` e o emulador, executando todos os testes registrados. Inclui testes Vulkan com hardware e testes amplos que recompilam o emulador em vários executáveis. Pode consumir muito mais tempo e armazenamento, ou falhar por falta de GPU. Não é a validação padrão. Testes Darwin somente se aplicam a macOS.

Sem argumentos, `test.sh` usa **Release**, como a CI oficial. `build.sh` e `analyze.sh` usam Debug por padrão. O teste headless de memória virtual também recompila grande parte do emulador, portanto a primeira execução da suíte pode demorar. No baseline Debug desta preparação, 14 de 15 passaram e `SmallFiberStacksAndMigration` falhou por escrita antes da pilha de 512 bytes. A falha permanece visível quando se pede Debug; consulte o relatório para diagnóstico e comparação Release. Nenhum teste foi omitido para contornar esse resultado.

`analyze.sh` habilita o recurso nativo `KYTY_ENABLE_CLANG_TIDY` em diretório separado. As regras oficiais tratam avisos como erros; falhas existentes são possíveis. Não se apresenta a existência desse script como análise estática aprovada.

Para instalar os artefatos **Linux** dentro do volume:

```powershell
docker compose run --no-deps -T dev cmake --install /build/Release --prefix /build/Release/install
docker compose run --no-deps -T dev /build/Release/kyty_emulator --help
```

O build Debug contém símbolos. GDB existe no container, mas depuração com ptrace pode ser limitada pelas capacidades/seccomp. Não são concedidos `SYS_PTRACE` ou modo privilegiado automaticamente. Para erros de compilação, leia o primeiro erro do log, confira submódulos com `status.ps1` e versões de ferramentas no container. Corrija a causa sem apagar caches indiscriminadamente.

## Git, branches e Codex

`upstream` aponta para `https://github.com/KytyPS5/KytyPS5.git`; `origin` aponta para o [fork pessoal](https://github.com/matheusasg09/KytyPS5), criado com autorização explícita e verificado em 2026-10-20. A API confirmou proprietário, vínculo com o upstream, visibilidade pública e branch padrão `main`; o fetch de origin confirmou o mesmo commit oficial de base. O clone inicial veio do repositório oficial, preservando integralmente seu histórico, e foi conectado ao fork sem necessidade de reclonar. Forks de repositórios públicos mantêm a visibilidade pública, conforme a [documentação do GitHub](https://docs.github.com/en/pull-requests/reference/forks#visibility-of-forks). As alterações locais de `develop` ainda não foram enviadas.

`main` acompanha `upstream/main` e permanece sem customizações. `develop` contém a infraestrutura pessoal. Prefixos `feature/*`, `fix/*` e `experiment/*` são convenções, não branches vazias criadas sem uma tarefa.

```powershell
git switch develop
git switch -c feature/nome-da-funcionalidade
codex
```

Inicie Codex na raiz para carregar `AGENTS.md`. O agente deve ler a arquitetura antes de editar e executar builds/testes pelo Docker. Faça commits locais pequenos e completos; integre branches por merge revisado e autorizado. Não envie automaticamente ao GitHub. Os dois remotos têm push URL `DISABLED`, proteção local contra envio acidental; ela não substitui revisão nem pode ser removida por scripts automáticos.

As configurações `.vscode` originais pressupõem uma toolchain Windows. Neste ambiente, use o editor para editar o checkout e execute CMake, compilação, testes e análise pelos scripts Docker, sem instalar essa toolchain no host.

## Sincronização com o original

```powershell
git switch develop
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\sync-upstream.ps1 -Plan
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\sync-upstream.ps1
```

O plano não faz fetch ou merge. A execução exige árvore limpa, nenhum merge/rebase pendente, remotos exatos, fork verificado via GitHub CLI e Docker disponível. Faz fetch de upstream, confirma a branch padrão remota, exige main ancestral de upstream/main, atualiza main somente por fast-forward, volta a develop e usa merge normal. Não faz rebase, reset, stash, push, limpeza nem força submódulos. A integração preserva os commits personalizados como ancestrais. A validação padrão usa Release, como a CI; `-Configuration Debug` mantém disponível a validação diagnóstica Debug.

Se main tiver commits próprios, a operação para em vez de sobrescrevê-los. Se houver conflito, o script deixa a operação e os arquivos para inspeção, lista os conflitos e não executa testes. Analise `git status`, `git diff` e a diferença oficial/pessoal. Resolva APIs, arquitetura e dependências preservando a intenção dos dois lados. Revise, `git add` nos arquivos resolvidos e `git commit` para concluir o merge. Nunca escolha globalmente ours/theirs. Quando a solução não for evidente, registre a decisão necessária.

Switches e merges usam `--no-overwrite-ignore` para proteger também arquivos locais ignorados. Uma falha na atualização de main pode deixar essa branch selecionada; consulte o estado antes de continuar e volte a develop somente quando o checkout estiver seguro. O script não força a troca de branch nem descarta arquivos para se recuperar.

Depois de um merge resolvido, atualize os submódulos via `setup.ps1 -SkipImageBuild`, após revisar novos URLs, e valide:

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\sync-upstream.ps1 -ValidateOnly
```

Falha de teste após merge não desfaz commits. Os hashes e logs ficam disponíveis para diagnóstico. O relatório mostra commits incorporados e o resultado do conjunto headless, sem afirmar compatibilidade gráfica. O script de simulação descrito no relatório exercita essa lógica em repositórios sintéticos; não altera o histórico real nem usa o GitHub para escrever.

## Reconstrução e limpeza segura

```powershell
docker compose build --pull
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\clean.ps1 -Configuration Debug
```

Reconstruir a imagem mantém volumes e código. Para ignorar o cache da imagem, `docker compose build --no-cache`; isso não limpa volumes. `clean.ps1` apenas mostra tamanho/alvo. Após autorização separada, `clean.ps1 -Configuration Debug -Execute` pede confirmação interativa e remove somente `/build/Debug` do volume próprio, recusando containers ativos. Não exclui fontes, logs, cache compartilhado, imagens ou volumes. `-WhatIf` impede a exclusão. O download FFmpeg daquela configuração precisará ser refeito.

Não use `docker system prune`, `docker volume prune`, `docker compose down -v` nem remoção geral de containers. Para limpar caches ou containers parados, primeiro identifique nomes/IDs e tamanhos, confirme ausência de uso e obtenha autorização para cada alvo. Logs não têm rotação interna de arquivos; revise seu volume periodicamente antes de qualquer remoção.

## Linux, Windows e gráficos

Este Docker Linux produz ELF Linux x86-64. Eles não executam nativamente no Windows. O projeto usa Vulkan 1.3 e espera GPU e drivers adequados em runtime. Não foram montados `/dev/dri`, dispositivos GPU, servidores X/Wayland, áudio ou controles do host. Docker Desktop não comprova passthrough Vulkan de GPU apenas por estar em modo Linux. Mesa/headers e o sucesso de testes CPU não comprovam renderização.

O pacote Linux foi compilado no Debian 13 e usa glibc/libstdc++ dinâmicos. A cópia de Qt/ICU feita pelo install não o transforma em binário estático universal; execução fora da imagem exige uma distribuição com bibliotecas e ABI compatíveis.

Para testar gráficos Linux, use um host Linux ou VM Linux com GPU Vulkan 1.3 efetivamente validada e artefatos compatíveis. Para testar no Windows, produza binários Windows separadamente e execute-os no Windows com o driver Vulkan da GPU. Não instale dependências de build no host atual.

A alternativa menos invasiva para Windows é um runner Windows isolado, seguindo o job `windows-2022` de `.github/workflows/build.yml`: Visual Studio/Build Tools 2022 com ambiente x64 e clang-cl, CMake, Ninja, Python, glslang e Qt 6.10.3 MSVC 2022 x64. Use os mesmos comandos de configure/build/install do README, trocando apenas o diretório de saída. Preserve os fontes e licenças correspondentes. Uma VM Windows separada também serve, mas não foi criada/configurada. Cross-compilation MinGW não é o caminho validado da CI e não foi apresentada como equivalente a clang-cl/Windows SDK.

O workflow original foi preservado e não disparado. Criar fork, habilitar/executar Actions, enviar código e consumir runner pago exigem as autorizações aplicáveis. No fork público, o workflow original não publica releases, pois o job de release é restrito a `KytyPS5/KytyPS5`. Verifique custos e política antes de execução. Nenhuma execução remota Windows foi feita nesta preparação.

## Licenciamento e contribuições

Fontes oficiais: [README](https://github.com/KytyPS5/KytyPS5/blob/main/README.md), [GPL v2](https://github.com/KytyPS5/KytyPS5/blob/main/LICENSE), [aviso MIT original](https://github.com/KytyPS5/KytyPS5/blob/main/LICENSES/Kyty-MIT.txt), [workflow](https://github.com/KytyPS5/KytyPS5/blob/main/.github/workflows/build.yml) e CMake do checkout fixado.

KytyPS5 declara `GPL-2.0-only`. Preserve LICENSE, copyrights, avisos de ausência de garantia e `LICENSES/Kyty-MIT.txt`, além das licenças de terceiros. Ao modificar e distribuir, identifique arquivos e datas de alteração, mantenha o trabalho derivado sob GPL v2 e forneça o fonte correspondente completo, incluindo scripts de build, pela modalidade aplicável da seção 3. Não apresente o fork como release oficial nem imponha restrições adicionais. Uso local sem distribuição não exige publicação geral do fork. A distribuição de binários, bibliotecas estáticas e Qt exige preservar também as condições e avisos dos componentes incluídos; o install oficial reúne parte dessas licenças, mas isso não substitui uma revisão do pacote a redistribuir.

Não inclua firmware, BIOS, jogos, dumps, chaves criptográficas ou material proprietário PlayStation em Git, volumes de testes ou imagens. As regressões aqui não precisam deles.

O README oficial exige PRs focados em bug/problema concreto de jogo, evidência, revisão humana e testes nas plataformas afetadas. IA pode auxiliar desenvolvimento, mas a comunicação enviada ao projeto oficial precisa vir do colaborador humano; contribuições assistidas precisam declarar o escopo e revisão/testes humanos. Esta infraestrutura não foi submetida ao upstream. Leia novamente as políticas vigentes antes de qualquer contribuição.
