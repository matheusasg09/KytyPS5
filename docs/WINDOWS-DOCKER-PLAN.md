# Windows 11 e Docker: requisitos e bloqueios verificados

**CANCELADO pelo usuário em 2026-10-20.** Não executar este plano. O ambiente principal voltou a ser Docker Linux; este rascunho está fora do fluxo ativo e aguarda somente confirmação separada para exclusão física.

Estado em 2026-10-20: **planejamento e leitura concluídos; ambiente Windows ainda não provisionado**. Não foi trocado backend, reinstalado Docker, ativado Hyper-V/Containers ou instalado SDK no host. O ambiente Linux existente fica preservado.

## Documentação oficial lida integralmente

A leitura desta revisão cobre a documentação textual de primeira parte disponível no checkout oficial `7b7f9a70c652afd6ec8ea8599884d9b4b3abc9f3`, conferido novamente como main pela API:

- README.md completo: status, contribuição, formatação, arquitetura, requisitos, builds Windows/Linux/NixOS/Fedora/macOS, regressões, VS Code, execução, updater, IA e licença.
- docs/notification-localization.md completo, único documento Markdown adicional oficial em docs nesse commit. Os demais Markdown locais são documentação criada neste fork.
- LICENSE completo e LICENSES/Kyty-MIT.txt completo, preservados.
- .github/workflows/build.yml completo, incluindo os três jobs, empacotamento e proteção de release.
- .github/ISSUE_TEMPLATE/kytyps5-game-emulation.yaml completo, com critérios e evidências dos relatos.
- .pre-commit-config.yaml, .vscode/settings.json, .vscode/launch.json e .coderabbit.yaml completos.

Não havia CONTRIBUTING/BUILDING separados. A API indica wiki habilitada, mas o endereço /wiki consultado redirecionou ao repositório, sem páginas de instruções acessíveis. Esta declaração de leitura não inclui todos os fóruns, issues, Discord, documentação de cada dependência, nem os manuais externos de ISA; esses materiais devem ser consultados quando a investigação específica os exigir.

## Arquitetura local proposta com Docker

**Windows 11 físico para execução gráfica + container Windows Server Core para compilação**. O container não seria um desktop Windows 11, nem uma ISO. O [upstream](https://github.com/KytyPS5/KytyPS5/blob/7b7f9a70c652afd6ec8ea8599884d9b4b3abc9f3/README.md) admite Windows 10 1803 ou posterior e sua CI compila em windows-2022; Windows Server Core é uma opção para as ferramentas, enquanto o pacote seria testado no Windows 11 físico com sua RTX 5060.

A Microsoft [documenta Build Tools em containers](https://learn.microsoft.com/en-us/visualstudio/install/build-tools-container?view=vs-2022), incluindo Server Core 2022. Isso estabelece uma rota possível, não garante que toda a toolchain Kyty/Qt já tenha sido validada nesse container. A imagem e o build precisam ser implementados/testados no engine Windows antes de chamar o ambiente de pronto. Compatibilidade da base e isolamento devem seguir a [matriz Windows containers](https://learn.microsoft.com/en-us/virtualization/windowscontainers/deploy-containers/version-compatibility).

Dentro da imagem, preparar VS/Build Tools 2022 com ferramentas C++ e clang-cl, Windows SDK, Git, CMake >= 3.22.1, Ninja, Python 3, glslang e Qt 6 MSVC 2022 x64 (Concurrent/Network/Widgets). Usar Qt 6.10.3 para acompanhar a CI. O compilador cl.exe não é aceito pelo projeto. O exemplo de VS Code cita Qt 6.11.0, mas o README pede ajustar o caminho à instalação; isso não torna 6.11.0 obrigatório.

O código permaneceria no projeto Windows e seria montado no container, sem credenciais e com Git protegido. Debug/Release, caches e logs ficariam em volumes próprios Windows; volumes e binários Linux existentes não podem ser reutilizados como builds Windows. Usar ContainerUser em runtime, recursos limitados, sem portas, privilégios, Docker socket ou pastas pessoais. As restrições e permissões Windows precisam ser validadas com os recursos efetivamente suportados pelo engine, sem copiar opções exclusivas de Linux.

Após compilar launcher, executar os testes Windows oficiais e instalar o pacote completo, transferir os artefatos para uma pasta do projeto no host e validar CLI, GUI e Vulkan na GPU real. Isso não exige instalar Qt/SDK/compiladores no host. Containers Windows não oferecem a sessão desktop interativa necessária para validar a GUI, conforme a [Microsoft](https://learn.microsoft.com/en-us/virtualization/windowscontainers/quick-start/lift-shift-to-containers).

## Bloqueio concreto da instalação atual

- Docker CLI e processos Desktop foram encontrados em C:/Users/mathe/AppData/Local/Programs/DockerDesktop. A instalação usual em C:/Program Files/Docker/Docker não existe.
- docker desktop engine ls mostrou somente linux; docker info confirmou Linux x86-64 no contexto desktop-linux.
- VirtualMachinePlatform está habilitado; Hyper-V e Containers estão desabilitados.
- A [documentação Docker atual](https://docs.docker.com/desktop/setup/install/windows-install/#installation-modes) estabelece que instalação por usuário não suporta Windows containers. Essa capacidade requer instalação para todos os usuários. A troca de modalidade exige desinstalar/reinstalar; não é apenas alterar compose.yaml.

Portanto, antes de implementar essa rota local seria necessário autorizar uma exceção às proibições iniciais de reinstalar Docker e alterar sua configuração global. Não foi presumida autorização a partir da pergunta sobre Windows 11.

Sequência proposta para uma migração, se escolhida:

1. Inventariar dados/serviços existentes e preparar um plano específico de preservação. Fazer e verificar backups necessários antes de qualquer desinstalação. Não presumir que o instalador preserve imagens, volumes ou configurações.
2. Com autorização específica, migrar a instalação para todos os usuários e habilitar Hyper-V/Containers conforme documentação. Elevação UAC e possível reinicialização exigem participação/coordenação do usuário; não reiniciar automaticamente.
3. Disponibilizar o engine Windows e validar um container base compatível. A alternância de engines afeta a disponibilidade dos containers Linux, inclusive outros projetos. Não apagar os recursos existentes.
4. Implementar e construir a imagem Windows do projeto, preparar volumes e adaptar também o hook de formatação, que atualmente chama o serviço Linux quality. Não trocar o engine e deixar o hook apontando para uma imagem Linux incompatível.
5. Executar a compilação Debug/Release, os testes possíveis, persistência, permissões e pacote Windows 11 antes de migrar os comandos cotidianos para esse ambiente.

Essa migração não foi autorizada nem executada. Não existe Dockerfile/compose Windows declarado validado nesta etapa.

## Windows 11 completo iniciado pelo Docker

O [Dockur](https://github.com/dockur/windows) inicia uma VM QEMU dentro de um container Linux. É possível gerenciar Windows 11 com Docker dessa maneira, mas isso continua sendo virtualização, não um container desktop Windows nativo. Sua documentação pede KVM/virtualização aninhada para desempenho adequado.

Foi feito um teste pelo Docker existente, sem iniciar WSL manualmente, baixar ISO, montar socket ou conceder privilégios. A tentativa de criar um container mínimo com bind somente leitura de /dev/kvm foi recusada pelo daemon: `bind source path does not exist: /dev/kvm`. A criação falhou antes de gerar container. Resultado completo em .local/windows11-preflight.json, ignorado pelo Git.

Dockur expõe uma opção KVM=N para emulação por software. Ela não comprova viabilidade de desempenho para uma toolchain pesada e não foi usada como atalho para instalar Windows. A opção GPU depende de render node e configuração própria; suporte Vulkan 1.3 no guest permanece sem verificação. Não baixar/instalar Windows nem tratar uma chave genérica como licença válida.

## Preparação segura já disponível

scripts/windows-build.ps1 contém a seleção de targets/testes Windows da CI e o procedimento CMake original, com Release/Debug, instalação e logs separados. O modo -Plan é de leitura. A execução real exige toolchain previamente preparada no Windows isolado e o marcador operacional KYTY_ISOLATED_WINDOWS_BUILD=1; o script não instala ferramentas nem habilita recursos do host. O marcador não é mecanismo de isolamento ou segurança.

```powershell
powershell.exe -NoProfile -ExecutionPolicy RemoteSigned -File .\scripts\windows-build.ps1 -Plan
```

Depois de um ambiente Windows isolado validado, o mesmo script poderá executar Build, Test, Install ou All, dentro dele. Não há build Windows validado por enquanto. O parser PowerShell, modo de plano e bloqueio de execução no host foram conferidos; isso não valida compilação nem funcionamento do script na futura imagem.

Sem migrar/reinstalar Docker, instalar toolchain no host ou criar VM, a alternativa continua sendo compilar em runner Windows isolado e executar o pacote no Windows 11 físico. Essa alternativa segue o procedimento da CI, mas não equivale a instalar um desktop Windows 11 no runner. Nenhuma execução remota foi iniciada.
