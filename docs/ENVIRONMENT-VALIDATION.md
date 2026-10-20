# Validação do ambiente, 2026-10-20

## Escopo e origem

Projeto: `C:/Users/mathe/projetos/emulador-ps5`. A pasta estava vazia, sem Git e sem arquivos do usuário. Foi clonado o histórico completo de `https://github.com/KytyPS5/KytyPS5.git`, sem shallow clone do repositório principal, com seus 14 submódulos nas revisões oficiais. Referência inicial: `7b7f9a70c652afd6ec8ea8599884d9b4b3abc9f3`. A branch padrão foi conferida pela API GitHub e por `git ls-remote --symref`: `main`.

Foram lidos README completo (build, testes, contribuições e IA), CMake principal, configuração de terceiros, launcher, utilitários, workflow de CI, .gitmodules, configuração de formatação, GPL v2 e aviso MIT do Kyty original. Não havia AGENTS.md no upstream. Licenças, código C++ e workflow oficial foram preservados.

## Docker e host

- Windows AMD64; Git `2.56.0.windows.2`; Windows PowerShell `5.1.26100.9711`.
- Docker Desktop estava parado. Iniciado pelo comando existente `docker desktop start --timeout 120`, sem instalação, troca de backend ou configuração global.
- Engine `29.8.2`, Compose `5.5.1`, contexto `desktop-linux`, containers Linux x86-64; 16 CPUs e 16.730.976.256 bytes de memória disponíveis ao Engine.
- Imagem `kytyps5-dev:debian13` construída com sucesso. ID inicial usado pelos builds: `sha256:3d898ec2bffd157eb15edd3cf8538a8273e3d0f18baa90008f2dc709ea6e1a54`. Setup completo também executado no PowerShell com build pelo cache; ID atual: `sha256:323ab9c9ccbaab8af66f49ef203e88fa748f396534ff20e298e22f948ba9d988`, tamanho lógico 1.575.425.304 bytes. A imagem atual passou novamente no smoke de ferramentas, UID, arquitetura, scripts e persistência.
- Base Debian 13.1 slim fixada pelo digest do manifesto `sha256:a347fd7510ee31a84387619a492ad6c8eb0af2f2682b916ff3e643eb076f925a`.
- Compose validado. UID 1000 confirmado em execução; filesystem de imagem e metadados Git somente leitura, todas as capacidades removidas, no-new-privileges, nenhuma porta publicada ou credencial montada. Limites: 4 CPUs, 10 GiB, 512 PIDs.
- Não foram executados comandos WSL nem alterados Hyper-V, Docker global, serviços Windows ou política global de execução. `RemoteSigned` foi usado somente nos processos PowerShell que validaram os scripts locais.

## Ferramentas na imagem

Versões observadas: Clang/LLD `19.1.7`, CMake `3.31.6`, Ninja `1.12.1`, Qt `6.8.2`, glslang `15.2.0`, ccache `4.11.2`. Python, Git, pkg-config, headers C/C++, GDB, clang-format e clang-tidy estão na imagem. O manifesto completo de pacotes está no arquivo local ignorado `dependencies-manifest.local.txt`.

Bibliotecas de desenvolvimento incluídas: Qt Concurrent/Network/Widgets/DBus e Wayland, GL, X11/cursor/ext/fixes/input/randr/screensaver/xtst/xkbcommon, ALSA, PulseAudio, udev, DBus, Wayland e protocolos. A configuração confirmou os seis backends exigidos pela CI oficial: SDL_ALSA, SDL_PULSEAUDIO, SDL_WAYLAND, SDL_X11, SDL_LIBUDEV e SDL_DBUS, todos ON.

Vulkan-Headers, SPIRV-Tools/Headers, SDL3 e demais componentes fixados vêm do upstream. Dependências FetchContent e FFmpeg seguem commits/release definidos nos CMake oficiais. Nenhum SDK ou biblioteca do emulador foi instalado no host Windows.

## Git e simulação de atualização

- Autenticação GitHub válida para `matheusasg09`; nenhuma autenticação nova iniciada.
- Na inspeção inicial, `matheusasg09/KytyPS5` retornou 404. Após autorização explícita, o [fork público pessoal](https://github.com/matheusasg09/KytyPS5) foi criado. A API confirmou `fork: true`, parent `KytyPS5/KytyPS5`, proprietário `matheusasg09` e branch padrão `main`.
- `upstream`: `https://github.com/KytyPS5/KytyPS5.git`.
- `origin`: `https://github.com/matheusasg09/KytyPS5.git`, fork existente e verificado. Fetch concluído; `origin/main`, `upstream/main` e `main` apontavam para o commit oficial de base nesta conferência.
- Ambos os push URLs: `DISABLED`. Nenhum push, PR, issue, release ou execução Actions foi feito.
- `main` acompanha `upstream/main`; `develop` contém a infraestrutura pessoal. Convenções `feature/*`, `fix/*` e `experiment/*` documentadas sem criar branches vazias.
- Identidade local: `matheusasg09`, email já utilizado no projeto Agent Memory e associado à conta conforme inventário compartilhado. Nenhum token ou arquivo de credenciais foi aberto.

`scripts/test-sync.ps1` executa o script de sincronização real com Git real em fixtures locais. Somente respostas GitHub e execução Docker são simuladas; o teste de merge não equivale a um build real. Os fixtures ficam em `.local/sync-tests/`, sem qualquer exclusão automática.

Cenários validados: main por fast-forward; merge em develop preservando commit próprio; segunda execução idempotente; recusa de untracked/árvore suja; remoto incorreto; falha da validação propagada; conflito preservado e ausência de teste indevido; nova execução bloqueada durante conflito; main divergente protegida. A proteção de arquivos ignorados contra sobrescrita também faz parte da simulação.

Também foi validado o bootstrap em clone sintético sem upstream/develop: setup criou somente os metadados ausentes, configurou tracking de main e preservou os commits e a branch selecionada. A segunda execução foi idempotente. No checkout real, setup foi reexecutado com `-SkipImageBuild`, mantendo develop selecionada e os mesmos hashes de branch.

## Resultados de compilação e testes

Build Debug de `launcher` concluído com exit 0 em `kytyps5-debug-validation`. Emulador, launcher e updater foram confirmados como ELF 64-bit x86-64 Linux; `kyty_emulator --help` concluiu com exit 0. O updater compilado está em `/build/Debug/launcher/kyty_updater` (também no subdiretório `launcher/updater`). SHA-256 do emulador Debug inicialmente produzido: `193ee937153e6ea88d13b652b2dbf95a869e70f867aacd3fb1f6ca19f4bf2e96`.

Esse build ocorreu antes do commit da infraestrutura e identifica a base oficial com sufixo `dirty`, coerente com os arquivos locais novos, sem mudança no C++ do emulador.

Suite headless Debug: **14 de 15 passaram**, CTest exit 8, duração de execução 3,23 segundos após compilação. Falha em `virtual_memory_allocation`, caso `SmallFiberStacksAndMigration`: `fiber wrote outside its supplied stack`. Reproduzida com `virtual_memory_allocation_tests --fiber-only`, exit 1. Os fontes do teste, `src/libs/libKernel.cpp` e `src/libs/libs.h` estão idênticos a upstream/main.

GDB executou como pai do processo depurado com as restrições existentes, sem acrescentar capacidades. O breakpoint na verificação encontrou stack_size 512 e cinco bytes de guarda alterados, offsets 4083 a 4087, imediatamente antes do início da pilha fornecida no offset 4096, após o primeiro ciclo de fibers. Isso confirma a falha observada, sem estabelecer sua causa raiz. O teste passou em Release no mesmo ambiente. O resultado indica sensibilidade à configuração Debug neste baseline, sem provar que todo ambiente Debug apresenta o problema. O teste não foi desabilitado e nenhum C++ foi alterado.

Conferência remota de leitura: a [CI oficial do mesmo commit](https://github.com/KytyPS5/KytyPS5/actions/runs/39436671736) reporta success nos jobs Windows, Linux e macOS. Isso descreve o código e ambiente oficiais, não uma validação Windows deste fork. `test.sh` sem argumentos e `sync-upstream.ps1` usam Release por padrão para acompanhar a configuração da CI. Debug continua disponível explicitamente e sua falha não foi suprimida.

Uma análise estática amostral de `src/common/dateTime.cpp` com clang-tidy 19 e o compile database Debug concluiu com exit 0 e 37 diagnósticos `warning` no código oficial. Isso valida o funcionamento da ferramenta, não uma aprovação estática global. O script `analyze.sh` com avisos tratados como erro permanece disponível e não foi executado integralmente.

Build Release de `launcher` também concluiu com exit 0 em `kytyps5-release-validation`. Suite headless Release: **15 de 15 passaram**, CTest exit 0, duração de execução 1,98 segundos após compilação. `virtual_memory_allocation`, incluindo o caso de fibers que falhou em Debug, passou em 0,63 segundo. A suíte completa e os testes gráficos continuam sem validação.

`cmake --install /build/Release --prefix /build/Release/install` concluiu com exit 0. Emulador, launcher e updater instalados foram confirmados como ELF x86-64 Linux; o emulador instalado respondeu a `--help`. Qt/ICU e plugins foram copiados pelo install oficial. SHA-256 do emulador Release instalado (stripped): `1a685fc44fea368faa99183f9b414a0fdb02aae2df8dd9c17bcb97357799fc4a`. Isso não valida gráficos, portabilidade universal Linux ou execução Windows.

Avisos observados durante compilação: validação XML de protocolo Wayland fornecido pelo SDL, casts/alinhamento no Opus e avisos do C++ oficial. Não foram corrigidos por estarem fora do escopo de preparação do ambiente. Ambos os builds e seus links concluíram com sucesso.

## Scripts e persistência

- Setup completo, setup com `-SkipImageBuild`, status, início de shell por stdin fechado e relatório de limpeza executados no Windows PowerShell 5.1.
- Todos os scripts PowerShell passaram no parser dessa versão. Arquivos são UTF-8 BOM com CRLF; Bash usa LF e passou em `bash -n` dentro do container.
- `clean.ps1` executado somente em modo de relatório. Nenhum diretório, imagem, volume ou cache foi excluído. A remoção específica dos containers abaixo ocorreu em etapa separada, após autorização.
- Dois containers distintos, `kytyps5-persistence-a` e `kytyps5-persistence-b`, executaram `validate-container.sh`: UID 1000, ferramentas, acesso aos três volumes, marcador persistente e SHA-256 de CMakeLists.txt preservados entre containers. Abertura de `.git/HEAD` para escrita foi negada pelo mount somente leitura.
- Código persistente no Windows; builds, caches e logs persistentes em `kytyps5-dev_builds`, `kytyps5-dev_caches` e `kytyps5-dev_logs`.
- Persistência após **remoção** de containers comprovada: depois de remover os 12 containers autorizados, `kytyps5-post-removal-check` repetiu a validação, conferiu os hashes SHA-256 dos emuladores Debug e Release, executou `--help` do Release instalado e confirmou caches e logs. Exit 0; esse container também foi removido conforme autorizado. Código-fonte e metadados dos três volumes permaneceram intactos.

O [manifesto local de remoção](../.local/container-removal-manifest.json), ignorado pelo Git, registra a autorização e conclusão. Antes da remoção, os 12 containers parados foram revalidados por ID, estado, timestamps, tamanho, imagem e mounts, além do contexto Docker e hash do código. A API Docker 1.51 foi usada somente no processo de inspeção para obter os tamanhos exatos, sem alterar configurações. Foram removidos esses 12 containers e o container adicional de conferência, sem força nem exclusão de volumes: 212.992 bytes de camadas graváveis no total, sem estimativa de recuperação física adicional. Código, histórico, imagens e os três volumes foram preservados. Evidência do teste: `validation-post-removal.log`, local e ignorado pelo Git.

## Limites e pendências

O ambiente compila Linux x86-64, sem gerar `.exe` Windows. GPU/Vulkan em hardware, áudio real, controles, jogos, attach ptrace a processos alheios, suite gráfica completa e execução Windows não foram validados. GDB com processo filho foi validado no diagnóstico de fibers. Não foram montados GPU, pastas pessoais ou materiais proprietários PlayStation. A alternativa Windows por runner/VM isolado está em DEVELOPMENT.md; nenhum recurso remoto foi criado ou disparado.

O fork público pessoal está criado e verificado. As mudanças locais de `develop` continuam sem push. A sincronização foi validada por simulação e pelo modo `-Plan`; não foi necessário integrar commits oficiais novos, pois as três referências de `main` coincidiram na conferência após o fetch.

Arquivos adicionados: Dockerfile, compose.yaml, .dockerignore, .gitattributes, AGENTS.md, DEVELOPMENT.md, este relatório e scripts de setup, início, build, testes, análise, status, sincronização, simulação, limpeza e validação de persistência. Arquivo original modificado: somente .gitignore, com aviso datado para os arquivos locais ignorados.
