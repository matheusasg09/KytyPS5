# Desenvolvimento do fork KytyPS5

Estas instruções se aplicam ao projeto em C:/Users/mathe/projetos/emulador-ps5.
Leia também as políticas globais e C:/Users/mathe/projetos/AGENTS.md.

- Leia README.md, DEVELOPMENT.md, CMakeLists.txt, src/utils.cmake e os módulos afetados antes de editar.
- Preserve C++20, Clang, padrões existentes, avisos de copyright e licenças. Não faça refatorações amplas sem necessidade.
- Para C++ use somente o formatador oficial 22.1.3 pelo serviço quality e o hook conectado por scripts/install-hooks.ps1. Não use clang-format da imagem dev nem formate o repositório inteiro. Preserve índices e arquivos parcialmente staged; nunca burle o hook.
- Não instale compiladores, Qt, SDKs ou dependências no Windows. Use Docker e o backend existente, sem configurar WSL ou alterar Docker globalmente.
- Trabalhe em develop ou feature/*, fix/* e experiment/*. Nunca implemente mudanças cotidianas em main, que acompanha upstream/main.
- Preserve o histórico oficial. Sincronize por scripts/sync-upstream.ps1. Não use reset --hard, rebase, amend, force push, descarte de conflitos ou escolha automática de um lado.
- Não faça push, publique releases, abra issues/PRs ou crie repositórios sem autorização explícita. Ambos os push URLs ficam bloqueados por padrão.
- Priorize estabilidade, compatibilidade Windows/Linux e desempenho. Acrescente regressões focadas quando viável e documente alterações arquiteturais.
- Compile com bash scripts/build.sh Debug e execute bash scripts/test.sh Release headless pelo serviço dev, seguindo a configuração de testes da CI oficial. Para alterações relevantes, valide também o build Release e testes Debug. O baseline Debug desta preparação apresenta a falha de fiber documentada em docs/ENVIRONMENT-VALIDATION.md; não a desabilite para aparentar sucesso.
- O conjunto headless não valida GPU, Vulkan em hardware, jogos ou suite completa. Não declare sucesso desses recursos a partir de um build ou de --help.
- A revisão Windows/Linux está em docs/UPSTREAM-REVIEW.md. Os 32 testes extended-headless passaram em Release; continuam sendo apenas parte dos 57 registrados. Uma ISO/VM não garante GPU Vulkan. Não crie VM, troque backend ou dispare runners sem a autorização aplicável.
- Não execute builds simultâneos para respeitar o orçamento de recursos. FetchContent Debug usa /cache/deps; Release e análise usam árvores separadas /cache/deps-Release e /cache/deps-Analysis-*.
- Alterações gráficas exigem validação adicional em ambiente com GPU Vulkan 1.3. Binários Linux são ELF, não executáveis Windows.
- Revise mudanças de dependências, .gitmodules, CMake e scripts de download antes de executá-las. Não monte credenciais, Docker socket, pastas pessoais ou arquivos proprietários de PlayStation.
- Antes de limpar artefatos ou remover containers, obtenha confirmação separada para os alvos exatos. clean.ps1 começa somente com relatório.
- Antes do commit, revise o diff, execute verificações pertinentes e confirme a identidade matheusasg09 com email já verificado. Faça commits locais somente das mudanças pretendidas.

## Arquitetura a estudar conforme a tarefa

- CPU e carregamento: src/loader, src/kernel, src/emulator.cpp.
- GPU e comandos: src/graphics/guest_gpu; backend Vulkan: src/graphics/host_gpu.
- Tradução de shaders: src/graphics/shader/recompiler, frontend, IR, passes e backend SPIR-V.
- Memória: src/kernel e gerenciamento de páginas, imagens e buffers em src/graphics/host_gpu.
- Sistemas e filesystem: src/libs, src/kernel, src/common.
- Interface: src/launcher e src/updater; regressões: tests.

## Política oficial de IA e contribuições

Leia a seção AI Use do README antes de preparar contribuição externa. IA pode auxiliar pesquisa e desenvolvimento, mas o humano precisa entender, revisar e testar o código. Comunicação no repositório oficial, incluindo descrições de PR, comentários de código e issues, deve vir do colaborador humano, não de agente autônomo. Não envie contribuições automaticamente.

Contribuições assistidas devem declarar o escopo de IA e a revisão/testes humanos. O upstream exige correção focada em bug ou problema concreto de jogo, com evidências; PRs genéricos ou amplos podem ser fechados. Esta infraestrutura é para o fork pessoal e não constitui uma contribuição pronta ao upstream.
