# Banco do Tabuleiro — Roadmap de desenvolvimento

Produto iOS local-first para acompanhar partidas físicas de jogos imobiliários. O app usa moeda fictícia, não movimenta dinheiro real e mantém os dados financeiros em SQLite no iPhone.

## Parâmetros aprovados

- iPhone nativo com SwiftUI; alvo inicial iOS 17+.
- Uma partida compartilhada por jogadores no mesmo iPhone (hot-seat); sem sincronização entre aparelhos no MVP.
- SQLite como fonte de verdade local; valores guardados como inteiros e operações registradas em livro de dupla entrada.
- 2–6 jogadores por partida, apelidos e cores, sem cadastro obrigatório.
- Visual premium original: verde profundo, marfim e dourado, alinhado à imagem de referência.
- Blender para tabuleiro e peças originais, exportados em USDZ e exibidos no app.
- Sem marcas, nomes de propriedades ou arte proprietária de jogos comerciais.
- GitHub Actions para build e testes em simulador macOS, revisão visual e artefatos.
- A pasta `START` é referência de implementação; este projeto permanece independente.

## Roadmap por semanas

| Semana | Marco | Entregas | Saída esperada | Estado |
|---|---|---|---|---|
| 0 | Produto e arquitetura | Escopo P0, identidade, regras de partida, arquitetura SQLite/CI | Decisões registradas neste documento | Concluída |
| 1 | Fundação | Xcode project, navegação, tema, estrutura, Git e CI base | App compila em simulador e workflow roda | Build iOS e workflow passaram no run 380065 |
| 2 | Domínio e persistência | Migrações SQLite, partidas, jogadores, contas, livro de lançamentos | Testes de integridade, idempotência e reabertura | 12 XCTest passaram no run 380065 |
| 3 | Fluxo de partida e banco | Criar partida, painel, saldos, participantes, extrato | Fluxo local completo e persistente | Implementado; 10 testes de UI passaram no run 380065 |
| 4 | PIX Imobiliário | Transferência, cobrança pendente, confirmação e aluguel | Pagar, receber e rejeitar saldo insuficiente | Fluxos P0 cobertos por XCTest e UI tests no run 380065 |
| 5 | Imóveis e tabuleiro | Cadastro/compra de imóveis, histórico, cena Blender/USDZ e posição local das peças | Propriedade e visual 3D integrados | `.blend`, USDZ e preview gerados; cena carregada no simulador no run 380065 |
| 6 | Regras e acabamento | Encerramento, resumo, acessibilidade, erros, privacidade local, apagar dados e estados vazios | MVP P0 funcional e polido | Resumo, disclosure local, exclusão, Reduzir Movimento, ícone e Dynamic Type implementados; auditoria VoiceOver manual pendente |
| 7 | Testes funcionais | XCTest, testes de interface, persistência e concorrência local | Fluxos principais cobertos automaticamente | 11 unit tests + 8 UI tests passaram no run 379686 |
| 8 | Rodadas visuais | Capturas no simulador, análise de telas, correções de layout | Artefatos revisados e regressões corrigidas | Doze prints revistos; run 380065 verde; onboarding e ranking capturados; `.app` publicado |
| 9 | Estabilização | QA final, documentação, CI verde, app de simulador e pacote para teste | Build candidato a teste | Build e 12+10 testes verdes; resta auditoria VoiceOver em aparelho e decidir assinatura/TestFlight |

> As semanas são marcos de execução, não uma promessa de calendário. Cada rodada deve atualizar o estado, descobertas, resultados dos testes, observações dos prints e próximo passo recomendado.

## Escopo P0

1. Criar e retomar partidas locais.
2. Configurar nome, 2–6 jogadores, saldo inicial e moeda virtual.
3. Distribuir o saldo inicial uma única vez.
4. Consultar saldo, jogadores e extrato.
5. Fazer transferências virtuais com revisão antes da confirmação e registrar créditos/pagamentos ao banco.
6. Criar cobranças e registrar o pagamento de aluguel.
7. Cadastrar propriedades genéricas, comprar imóvel disponível e manter titularidade histórica.
8. Encerrar uma partida e consultar resumo financeiro.
9. Exibir tabuleiro e peças próprias em 3D; animações são visuais e não substituem as regras do tabuleiro físico.
10. Funcionar sem rede e manter os dados após reiniciar o app.
11. Explicar armazenamento local/moeda fictícia e permitir apagar todas as partidas.

## Arquitetura de referência

```text
PIX IMOBILIARIO/
├── BancoDoTabuleiro.xcodeproj/
├── BancoDoTabuleiro/
│   ├── App/
│   ├── Domain/
│   ├── Data/SQLite/
│   ├── Features/{Home,Bank,Transfers,Properties,Statement,Board}/
│   ├── DesignSystem/
│   └── Art.scnassets/
├── BancoDoTabuleiroTests/
├── BancoDoTabuleiroUITests/
├── Blender/
├── Scripts/
└── .github/workflows/
```

SQLite terá `games`, `players`, `accounts`, `transactions`, `transaction_entries`, `properties`, `property_ownership` e `payment_requests`. Cada operação altera contas e cria lançamentos dentro da mesma transação SQL. O banco da partida funciona como contraparte da distribuição inicial e das taxas. IDs de idempotência evitam duplicação local; restrições impedem saldo negativo e titularidades simultâneas.

O cliente local não fornece as garantias de autorização de um servidor multiplayer. Um código exibido na partida não é credencial de acesso remoto. Entrada em outros iPhones, autenticação e saldo compartilhado ficam para uma etapa com backend.

## GitHub Actions e revisão visual

- Runner macOS com Xcode e simulador de iPhone; build sem assinatura.
- Testes de domínio/SQLite e UI em modo previsível.
- Artifacts por execução: screenshots individuais, contact sheet, vídeo de navegação quando disponível, logs e resultados XCTest.
- Publicar o `.app` iOS Simulator não assinado para baixar e testar no simulador local; não é instalável em iPhone físico sem assinatura.
- Capturas prioritárias: painel com atividade de demonstração, PIX, movimentação do banco, cobrança, imóveis, extrato e tabuleiro.
- Pipeline de Blender separado ou etapa não bloqueante enquanto o export USDZ estiver sendo estabilizado; validar carregamento de USDZ no teste iOS quando disponível.
- Após cada execução: registrar link/status do run, observações visuais e correção priorizada aqui.

## Critérios de aceite do MVP

- CI compila o app e executa testes no simulador de iPhone.
- Partida e extrato sobrevivem a fechar e reabrir o app.
- Uma transferência gera lançamentos balanceados; valor inválido e saldo insuficiente não alteram o saldo.
- Repetir a mesma chave de idempotência não duplica a operação.
- Compra de imóvel debita e atribui titularidade atomicamente.
- Cobrança só movimenta saldo quando paga e não pode ser paga duas vezes.
- O app identifica claramente saldo e pagamentos como virtuais.
- VoiceOver, Dynamic Type e Reduzir Movimento têm suporte nos fluxos principais.
- Screenshots do Actions são revisados em cada rodada visual e regressões são corrigidas antes da semana 9.

## Pós-MVP

- Multiplayer entre dispositivos com backend como autoridade, identidade de convidado, códigos de convite, sincronização e transações atômicas no servidor.
- QR Code para cobrança, exportação/compartilhamento de resumo, casas/hotéis, hipoteca, empréstimos e falência.
- TestFlight/App Store após configurar assinatura, privacidade, exclusão e retenção de dados.

## Diário de execução

| Data | Semana/marco | Mudança ou teste | Resultado / evidência | Próximo passo |
|---|---|---|---|---|
| 2026-10-09 | 0 → 1 | Roadmap criado; confirmados hot-seat, SQLite local, Blender e CI iOS | Pasta-alvo continha apenas a imagem de referência; Xcode/Swift/Blender não estão instalados neste Linux; GitHub CLI autenticado | Criar app, testes e workflow macOS; preparar execução remota |
| 2026-10-09 | Rodada 1 · base, dados e telas P0 | Criados Xcode project/scheme, app SwiftUI, tema premium, painel, criação de partida, seleção persistida do jogador ativo, transferências, cobranças, imóveis, extrato e tabuleiro SceneKit com fallback | Script Blender passou `ast.parse`; schema e migração v1→v2 executados em SQLite em memória; YAML do Actions válido. Repo privado criado e código enviado. Run [37949315535](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37949315535) não iniciou jobs: annotation do GitHub informa pagamento/spending limit. Nenhum print ou build disponível; Xcode/Swift também não existem neste host. | Resolver billing do GitHub Actions; repetir o run, analisar logs/prints e corrigir o primeiro erro de build/teste |
| 2026-10-09 | Rodada 2 · revisão local e integridade | Adicionada seleção persistente do jogador ativo; operações bloqueadas após encerrar; retry de cobrança paga retorna a operação original; XCTest cobre saldo do livro, idempotência e retomada de jogador; refinados identificadores de UI | Simulação SQLite em memória validou migrações v1→v2, saldo/lançamentos balanceados, seleção ativa e cobrança; Blender Python AST, YAML Actions e referências/caminhos do Xcode project passaram. Repo atualizado localmente; Actions segue bloqueado por billing. | Enviar rodada 2 ao repositório; obter build e capturas após desbloqueio de billing |
| 2026-10-09 | Rodada 3 · operações do banco e extrato | Incluídos créditos e débitos ao banco; distribuição inicial agora gera lançamento equilibrado por jogador; extrato mostra sinal e data/hora por perspectiva; adicionado print do PIX ao workflow; gerados tabuleiro e dados no Blender 5.2.2 | Preview local revisado; USDZ reimportado no Blender e os seis nós de peça e os dados confirmados. AST Blender, schema/migração SQLite, saldo de abertura por jogador, índice de titularidade, YAML Actions e referências do Xcode project passaram. Run [37951754540](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37951754540) não iniciou steps devido ao billing/spending limit; não há build ou prints do simulador. | Regularizar billing; repetir XCTest e revisar as cinco telas quando os runners voltarem a iniciar |
| 2026-10-09 | Rodada 4 · movimento persistido | Posição de cada peça passou a salvar em SQLite, avançar em 20 casas e continuar após reabrir; o tabuleiro oculta peças não usadas pela partida | Migrações SQLite v1→v3 e wrap de posição validados localmente; round-trip USDZ confirmou 6 peças, 2 dados e prédio central. XCTest de avanço/volta criado, ainda não executado. Run [37952242672](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37952242672) foi bloqueado antes dos steps por billing/spending limit; sem prints ou build iOS. | Regularizar billing; revisar movimento/restauração e capturas no primeiro run macOS possível |
| 2026-10-09 | Rodada 5 · workflow_dispatch | Executada nova tentativa manual, run [37954408138](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37954408138) | Mesmo bloqueio de billing/spending limit antes de qualquer step. Manter o projeto no repositório não altera a disponibilidade dos runners. | Retomar build, XCTest e revisão de prints quando a conta permitir iniciar Actions |
| 2026-10-09 | Rodada 6 · repositório público | Visibilidade alterada a pedido do usuário; runners iniciaram. Runs [37955262257](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37955262257) e [37956421521](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37956421521) trouxeram os primeiros erros reais | Corrigidos: Blender precisava de `libegl1`; `GameStore.repository` precisava ser mutável no catch; Blender também precisava do caminho absoluto do binário na mesma etapa. No run 379564 o Blender e o build iOS passaram; os XCTest pararam em `@testable import` porque faltava `ENABLE_TESTABILITY`. As cinco capturas foram geradas e inspecionadas. | Habilitar testability, enriquecer fixture visual e rodar os testes novamente |
| 2026-10-09 | Rodada 7 · primeira revisão visual real | App compilou no simulador; contact sheet real revisada; `ENABLE_TESTABILITY=YES` e fixture visual com PIX/aluguel/compra/crédito; workflow ampliado para sete telas, incluindo Banco e Cobrança | No run [37956421521](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37956421521), Blender e build iOS passaram; XCTest foi bloqueado antes da execução por `@testable import` sem testability. A contact sheet mostrou telas limpas e coerentes, mas dashboard/extrato exibiam só a distribuição inicial; a fixture nova corrige isso. | Fazer push da correção de testability/fixture; executar XCTest e revisar o contact sheet atualizado |
| 2026-10-09 | Rodada 8 · CI e revisão da primeira contact sheet | Corrigido `ENABLE_TESTABILITY`; fixture de revisão agora mostra operações variadas; workflow captura 7 telas, incluindo PIX, Banco e Cobrança | Run [37958242842](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37958242842) passou: Blender, build, 10 unit tests, 5 UI tests e captura de prints. O extrato truncava a descrição do PIX; agora permite duas linhas e usa um motivo de demonstração mais curto. | Revalidar o ajuste visual e avançar nos checks de acessibilidade |
| 2026-10-09 | Rodada 9 · polimento visual e acessibilidade | Painel compacto; descrições PIX em até duas linhas; animação 3D respeita Reduzir Movimento; saldo principal escala com Dynamic Type; ícone original criado | Run [37962399376](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37962399376) passou: Blender, build, 10 unit tests, 5 UI tests e sete capturas. Contact sheet revisada; linha PIX completa e três atividades cabem melhor no painel. | Validar ícone/testes de exclusão e Dynamic Type no próximo run; fechar QA da semana 9 |
| 2026-10-09 | Rodada 10 · exclusão local e acessibilidade | Incluído fluxo de apagar partidas e tela de privacidade local; UI tests para Dynamic Type XXXL, labels e exclusão; saldo escalável; ícone original | Run [37965226115](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37965226115) compilou app e Blender; teste UI não compilou porque `XCUIElementQuery.lastMatch` não existe. Corrigido com identificador dedicado `confirm-delete-local-data`. | Reexecutar os testes e revisar sete telas |
| 2026-10-09 | Rodada 11 · CI verde com acessibilidade e ícone | AppIcon integrado; exclusão local e verificação Dynamic Type nos testes | Run [37966551702](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37966551702) passou: Blender, build, 11 unit tests e 7 UI tests. | Revisar artefatos e concluir auditoria manual de VoiceOver |
| 2026-10-09 | Rodada 12 · rótulos acessíveis | XCTest verifica rótulos de PIX, seleção de jogador e tab bar | Run [37968666498](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37968666498) passou: 11 unit tests e 8 UI tests; contact sheet de sete telas revista. | Fechar semana 9 com auditoria VoiceOver no aparelho e revisão da identidade final |
| 2026-10-09 | Rodada 13 · disclosure de privacidade | Tela local explica SQLite/offline/moeda virtual; botão acessível e ação de fechar; UI test cobre aviso | Run [37970793308](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37970793308) passou: 11 unit tests e 9 UI tests. | Repetir a revisão visual com as telas de privacidade e texto ampliado |
| 2026-10-09 | Rodada 14 · revisão visual acessível | Workflow captura também Privacidade e Dynamic Type XXXL | A captura XXXL revelou atalhos, contagem de jogadores e nomes comprimidos; painel passou a grade 2×2 com saldo empilhado. O UI test percorre a página até localizar o atalho. | Revalidado em run posterior; seguir estabilização final |
| 2026-10-09 | Rodada 15 · validação de acessibilidade | Corrigido o UI test para percorrer o painel em Dynamic Type grande; captura e artifact de prints mantidos | Run [37979988213](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37979988213) passou com 11 unit tests, 9 UI tests e nove capturas. | Publicar o build de simulador e fechar checklist |
| 2026-10-09 | Rodada 16 · entrega de simulador | Workflow publica `PIX-app-ios-simulator` junto com logs, XCTest e capturas | Run [37992330567](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37992330567) verde; 11 unit tests + 9 UI tests; app não assinado disponível como artifact. | Auditoria manual em aparelho e assinatura/TestFlight são dependências de lançamento |
| 2026-10-09 | Rodada 17 · ajuste final de texto ampliado | Revisão dos nove prints encontrou tagline truncada no topo em Dynamic Type XXXL; texto passou a usar duas linhas em tamanhos de acessibilidade | Run [37994275194](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37994275194) passou: 11 unit tests + 9 UI tests. Print XXXL revisado; tagline completa e layout regular preservado. | Auditoria manual VoiceOver em aparelho; preparar assinatura se a distribuição TestFlight for desejada |
| 2026-10-09 | Rodada 18 · semântica VoiceOver | A posição de cada jogador no tabuleiro e o jogador ativo agora são anunciados semanticamente; UI tests verificam valores e rótulos | Run [37995845602](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37995845602) passou: 11 unit tests + 9 UI tests; artefatos de app, capturas e XCTest publicados. | Auditoria manual de navegação/rotor VoiceOver em iPhone; preparar assinatura se houver TestFlight |
| 2026-10-09 | Rodada 19 · onboarding, jogadores e ranking | Criação em duas etapas; nomes distintos; cor/peça por jogador; ranking ao vivo e final com saldo/imóveis separados, empates compartilhados; workflow captura as três novas telas | Run [38004174524](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/38004174524) passou: 12 unit tests + 10 UI tests e 12 capturas. Revisão visual apontou que o cartão do ranking empurrava as ações principais para baixo. | Reposicionar a prévia abaixo dos atalhos e reduzir a altura das linhas do painel |
| 2026-10-09 | Rodada 20 · hierarquia do painel | Prévia compacta do ranking movida para depois dos atalhos, mantendo PIX/Banco/Cobrar visíveis antes da classificação | Run [38006511339](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/38006511339) passou: 12 unit tests + 10 UI tests, build e 12 capturas; o painel revisado mostra os atalhos antes do ranking. | Auditoria VoiceOver em iPhone e decisão de assinatura/TestFlight |
| 2026-10-09 | Rodada 21 · acesso de demonstração e comprovante PIX | Prévia fintech opcional sem credenciais; progresso da operação local, comprovante com saldos e referência; três novas capturas | Implementação e testes adicionados; run de validação pendente. | Confirmar 12 unit tests + 12 UI tests e revisar acesso, processamento e comprovante |

### Registro detalhado da rodada 1

- `BancoDoTabuleiro/Data/SQLite/SQLiteGameRepository.swift`: schema versionado (migrações 1–3), seleção do jogador ativo e posição de peça persistidas, contas do banco e jogadores, lançamentos com sinais opostos, saldo inteiro, transações SQL atômicas com `BEGIN IMMEDIATE`, chaves de idempotência, compra de imóvel, cobranças, exclusão local e estado encerrado.
- `BancoDoTabuleiro/Features/`: primeira implementação SwiftUI dos fluxos de partida, painel, PIX, cobranças, carteira de imóveis, extrato e resumo final.
- `BancoDoTabuleiro/Features/Board/BoardView.swift`: tela 3D SceneKit, movimento visual de peças e fallback procedural se o USDZ não estiver no bundle.
- `Scripts/generate_board_assets.py`: fonte Blender para tabuleiro, propriedades genéricas, seis peças, dados, cena `.blend`, preview e export USDZ.
- `Blender/PIX-Board-Studio.blend`, `Blender/PIX-Board-preview.png` e `BancoDoTabuleiro/Art.scnassets/BoardScene.usdz`: primeira geração real feita e inspecionada com Blender 5.2.2 neste host.
- `BancoDoTabuleiroTests/` e `BancoDoTabuleiroUITests/`: testes iniciais de saldo, idempotência, fundos insuficientes, compra/aluguel, cobrança, encerramento e fluxos visuais.
- `.github/workflows/ios-visual-review.yml`: geração Blender, build, XCTest, capturas do simulador e upload de artefatos no runner macOS.
- **Bloqueio externo:** Actions não iniciou os steps devido ao billing/spending limit da conta. O artefato `PIX-prints-iphone` não foi produzido; nenhuma tela foi marcada como aprovada sem inspeção visual real.
- **Revisão local:** o verificador Python de referências Xcode inicialmente tratou `SQLiteGameRepositoryTests.swift` e `BankFlowUITests.swift` como caminhos relativos à raiz; eles são relativos aos grupos XCTest próprios do projeto. Não é um arquivo ausente; a estrutura foi conferida no `.pbxproj` e no diretório.
