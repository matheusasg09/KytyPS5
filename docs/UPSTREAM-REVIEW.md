# Revisão do procedimento oficial, 2026-10-20

## Decisão de plataforma

Direção do fork reafirmada após a revisão: **Windows é o alvo principal de desenvolvimento e validação deste fork**. Docker Linux permanece como ambiente auxiliar de builds e regressões. Isso é uma escolha para o computador e objetivo do projeto, sem atribuir ao upstream uma preferência exclusiva que o README consultado não declara.

O [README oficial](https://github.com/KytyPS5/KytyPS5/blob/7b7f9a70c652afd6ec8ea8599884d9b4b3abc9f3/README.md) declara Windows e Linux como plataformas principais, ambas com testes frequentes. Não exige nem recomenda escolher Linux em vez de Windows. A tradução de código x86-64 e o renderer exigem CPU/ambiente compatíveis e uma GPU Vulkan 1.3 com driver adequado.

A escolha Docker Linux atende ao requisito inicial de isolar a toolchain sem mudar o backend existente. O README aceita pacotes da distribuição Linux e o procedimento usa Clang, CMake/Ninja, submódulos, launcher e instalação. O ambiente não é uma reprodução exata do runner oficial Ubuntu 24.04: usa Debian 13, Clang 19, Qt 6.8.2 e ccache. A CI usa Qt 6.10.3, sccache e IPO/LTO em Release. Qt 6.8.2 atende ao mínimo 6.8 do CMake e ao caminho de pacotes da distribuição permitido pelo README. Essas diferenças devem entrar na investigação de falhas sensíveis à toolchain; não foram escondidas nem tratadas como equivalência binária.

Inventário de leitura nesta revisão: Windows 11 Pro x64, Ryzen 7 5700X (8 cores/16 threads), cerca de 32 GiB RAM e NVIDIA GeForce RTX 5060, driver 617.42. O `vulkaninfo.exe` já existente confirmou API Vulkan 1.4.351 da GPU, acima do mínimo 1.3. Não foi instalado SDK, driver ou compilador. Isso comprova a API exposta pelo driver Windows, sem comprovar todas as extensões/features exigidas pelos jogos nem o runtime KytyPS5.

Para este computador, a recomendação técnica é:

1. Manter Docker Linux para builds e regressões de CPU, memória, filesystem e lógica de shaders.
2. Compilar a versão Windows em runner isolado usando o procedimento oficial.
3. Baixar o pacote completo para uma pasta própria do projeto e testar a GUI/Vulkan no Windows com a GPU física, sem instalar toolchain no host.
4. Exigir testes Windows e Linux para alterações em código compartilhado, conforme a política upstream.

Uma ISO é mídia de instalação, não um ambiente que o Docker Linux executa como Windows nativo. Uma VM acrescentaria sistema, armazenamento, licença e configuração de GPU. Só seria adequada para testes gráficos após comprovar Vulkan 1.3 no guest. O [suporte GPU do Docker Desktop](https://docs.docker.com/desktop/features/gpu/) documenta NVIDIA GPU-PV e workloads de computação no backend WSL 2; isso não comprova o Vulkan/desktop necessário ao emulador. [Windows containers](https://learn.microsoft.com/en-us/virtualization/windowscontainers/quick-start/lift-shift-to-containers) não oferecem uma sessão desktop interativa. Não foram criados VM, ISO, Docker Windows, passthrough ou alterações de Hyper-V/WSL.

Inspeção posterior das opções locais: hypervisor presente e VirtualMachinePlatform habilitado; os componentes Hyper-V, ferramentas de gerenciamento e Windows Sandbox estão desabilitados. Get-VM, VBoxManage, vmrun e QEMU não foram encontrados no PATH; os executáveis também não estavam nos caminhos usuais inspecionados. Isso não prova ausência em qualquer outro diretório. Nenhum desses componentes foi ativado, instalado ou iniciado.

Há dois caminhos Windows distintos: um runner fornece uma máquina Windows real para compilar/testar sem modificar o host; uma VM local permite ciclos locais de build e depuração de CPU, mas exige preparar hypervisor, sistema/licença e armazenamento. Em ambos, os testes gráficos podem usar o pacote completo no Windows físico com a RTX 5060, sem instalar compiladores ou Qt de desenvolvimento no host. Não é necessário passar a GPU à VM apenas para compilar. A criação de uma VM local ou ativação do Hyper-V depende de autorização específica, pois a instrução inicial proíbe essas mudanças globais. A autorização para executar o runner continua pendente; esta discussão não foi interpretada como aprovação.

## Conferência dos requisitos oficiais

| Área | Resultado da revisão |
| --- | --- |
| Histórico e base | Main oficial `7b7f9a70...` conferida novamente pela API; main local preservada. Alterações somente em develop. |
| C++ e CMake | C++20, Clang e targets originais preservados; nenhum C++ ou CMake oficial alterado. |
| Dependências | 14 submódulos fixados; FetchContent e FFmpeg conforme CMake oficial. Sem FFmpeg de sistema. |
| SDL | Seis backends exigidos pela CI confirmados no baseline; sem prometer acesso físico a áudio/controles pelo container. |
| Build | Debug e Release Linux compilados; instalação Release e ajuda CLI validadas. |
| Testes da CI Linux | Os 15 testes selecionados pelo workflow estão no headless. Release passou; falha Debug de fibers continua registrada. |
| Testes adicionais | Nova seleção extended-headless com 32 testes existentes passou em Release (2,32 s de execução após compilar). |
| Suíte completa | 57 testes Linux registrados; 25 fora da seleção de 32 ainda sem execução nesta preparação. `all` já compila kyty_tests e emulador corretamente; não foi necessário alterar essa lógica. |
| Formatação | Mirror/configuração originais e clang-format 22.1.3 agora executados em quality. Hook local conectado ao Docker, sem instalar Python ou pre-commit no host. |
| Análise estática | Ferramenta disponível; somente a amostra anterior foi executada. Não há aprovação global de clang-tidy. |
| Contribuições/IA | Nenhum PR/issue/comentário enviado ao upstream. Revisão e testes humanos, escopo de IA e problema concreto continuam obrigatórios para submissão. |
| Licenças | LICENSE, LICENSES, copyrights e código original preservados. Nenhum pacote de distribuição publicado. |

Conferência Git sem diferenças contra upstream/main em README, CMake, src, tests, licenças, hook config e workflow oficial. O único arquivo original alterado no preparo anterior foi .gitignore; novos ajustes continuam restritos à infraestrutura do fork. Não se afirma conformidade integral de execução: GPU, jogos, Windows e suíte completa ainda faltam.

## Ajustes locais realizados

- Dockerfile passou a ter targets dev e quality, compartilhando a base. quality acrescenta somente Python venv, pre-commit 4.7.0 e clang-format 22.1.3, com dependências de runtime na imagem.
- Compose fixa dev no target dev e acrescenta quality limitado a 1 CPU/2 GiB, usuário 1000, Git somente leitura, cache persistente, sem portas, capabilities, Docker socket ou credenciais.
- `scripts/install-hooks.ps1` conecta o hook ao Docker sem sobrescrever hooks diferentes. Setup completo constrói as duas imagens e instala esse shim; SkipImageBuild mantém apenas o bootstrap anterior.
- `scripts/format.py` usa o pre-commit oficial com seleção de arquivos explícita. Protege fontes parcialmente staged e nunca faz git add/stash. Cinco testes reais de integração passaram, incluindo falha de formatação, segunda execução correta, check sem escrita e preservação de índice/working copy.
- `scripts/test.sh Release extended-headless` compila e executa 32 testes oficiais existentes, sem mudar o conjunto headless padrão nem suprimir a falha Debug.

Imagens e containers desta revisão não alteram a validação anterior de remoção. Os novos containers ficam parados para inspeção; não estão incluídos na autorização de remoção anterior e não serão removidos automaticamente.

Setup completo com build pelo cache e instalação idempotente do hook passou no Windows PowerShell 5.1. O parser dos scripts, status e a simulação de sincronização/bootstrap também passaram após os ajustes. A configuração Compose e os containers foram conferidos quanto a UID, limites, mounts e root filesystem somente leitura. Evidências locais: `validation-review-*.log` e `.local/upstream-review-validation.json` com IDs/tamanhos das imagens e resultados, ignorados pelo Git. As camadas compartilhadas evitam duplicar a toolchain entre os serviços.

## Próximo teste Windows, preparado mas não executado

O fork `matheusasg09/KytyPS5` e sua main foram verificados. A API de permissões informa Actions enabled, mas a lista de workflows do fork estava vazia nesta revisão. Não foi iniciada autenticação nem alterada configuração da conta. É necessário habilitar/registrar o workflow herdado no fork antes de dispará-lo.

O [workflow original](https://github.com/KytyPS5/KytyPS5/blob/7b7f9a70c652afd6ec8ea8599884d9b4b3abc9f3/.github/workflows/build.yml) já tem workflow_dispatch. Sua execução manual em main constrói **Windows, Linux e macOS**, não apenas Windows. O job Windows usa windows-2022, ambiente MSVC x64, clang-cl, Ninja, glslang e Qt 6.10.3 MSVC 2022 x64, constrói launcher/testes, executa a seleção Windows e reúne o pacote com cmake --install.

Após autorização específica para habilitar e executar esse workflow no fork:

```powershell
gh workflow run build.yml --repo matheusasg09/KytyPS5 --ref main
gh run list --repo matheusasg09/KytyPS5 --workflow build.yml --limit 5
```

Acompanhar o run exato, exigir SHA de base esperado e resultado Windows bem-sucedido, baixar apenas KytyPS5-Windows-x64 para `.local/windows-runtime/<run-id>` e verificar os artefatos antes de executar. Esse teste usaria o código oficial já presente no fork; os commits locais de infraestrutura não precisam de push. Não se deve declarar que alterações futuras locais foram testadas por esse build da main.

O job de release é restrito ao repositório oficial e evento push: workflow_dispatch no fork não publica release. Os runners configurados são os padrões do GitHub; seu uso em repositório público é gratuito segundo a [documentação de cobrança](https://docs.github.com/en/billing/concepts/product-billing/github-actions). Artefatos/cache têm regras próprias de armazenamento e devem ser conferidos antes de iniciar; não habilitar cobrança ou recursos pagos. Não houve execução remota nesta revisão.

Sem acesso a uma GPU Vulkan no runner, um build Windows também não comprova renderização. O teste seguinte seria local com o pacote completo: ajuda CLI, GUI aberta, diagnóstico Vulkan e depois um caso legalmente disponível e reproduzível. Não há jogos, dumps ou materiais proprietários preparados neste projeto.

## Primeiro problema a investigar depois do baseline

`virtual_memory_allocation / SmallFiberStacksAndMigration` falha em Debug e passa em Release nesta toolchain Linux. O diagnóstico anterior encontrou cinco bytes alterados antes da pilha mínima fornecida de 512 bytes. A causa raiz permanece desconhecida. Não ampliar a pilha do teste, omitir o caso ou forçar Release para apresentar correção.

Uma investigação adequada deve reproduzir o caso na base oficial, comparar Debug/Release e toolchains/plataformas, analisar o caminho de troca de contexto em libKernel e somente então propor uma correção pequena com regressão. Trabalhar em fix/*, preservar main e executar os testes nas plataformas afetadas. Nenhuma correção no emulador foi implementada nesta revisão.
