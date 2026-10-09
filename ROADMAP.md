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
| 1 | Fundação | Xcode project, navegação, tema, estrutura, Git e CI base | App compila em simulador e workflow roda | Código criado; primeiro run bloqueado pelo billing da conta |
| 2 | Domínio e persistência | Migrações SQLite, partidas, jogadores, contas, livro de lançamentos | Testes de integridade, idempotência e reabertura | Implementado; execução XCTest pendente |
| 3 | Fluxo de partida e banco | Criar partida, painel, saldos, participantes, extrato | Fluxo local completo e persistente | Primeira versão implementada; revisão visual pendente |
| 4 | PIX Imobiliário | Transferência, cobrança pendente, confirmação e aluguel | Pagar, receber e rejeitar saldo insuficiente | Primeira versão implementada; execução XCTest pendente |
| 5 | Imóveis e tabuleiro | Cadastro/compra de imóveis, histórico, cena Blender/USDZ e posição local das peças | Propriedade e visual 3D integrados | `.blend`, preview e USDZ gerados/inspecionados localmente; carregar no iPhone continua pendente |
| 6 | Regras e acabamento | Encerramento, resumo, acessibilidade, erros e estados vazios | MVP P0 funcional e polido | Planejada |
| 7 | Testes funcionais | XCTest, testes de interface, persistência e concorrência local | Fluxos principais cobertos automaticamente | Planejada |
| 8 | Rodadas visuais | Capturas no simulador, análise de telas, correções de layout | Artefatos revisados e regressões corrigidas | Planejada |
| 9 | Estabilização | QA final, documentação, CI verde e pacote para teste | Build candidato a teste em aparelho | Planejada |

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
- Capturas prioritárias: início/configuração, painel, PIX, imóveis, extrato e tabuleiro.
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
| 2026-10-09 | Rodada 6 · repositório público | Visibilidade alterada a pedido do usuário; run [37954867996](https://github.com/socialbot114-cell/pix-imobiliario-ios/actions/runs/37954867996) iniciou runners | Job Blender parou com exit 127 ao chamar `blender --version` no mesmo step em que adicionou o path; correção local faz chamada explícita ao binário extraído. Job iOS iniciou e ainda está em andamento. | Confirmar build/teste iOS do run atual e push da correção Blender; revisar capturas quando o run terminar |

### Registro detalhado da rodada 1

- `BancoDoTabuleiro/Data/SQLite/SQLiteGameRepository.swift`: schema versionado (migrações 1 e 2), seleção persistida do jogador ativo, contas do banco e jogadores, lançamentos com sinais opostos, saldo inteiro, transações SQL atômicas com `BEGIN IMMEDIATE`, chaves de idempotência, compra de imóvel, cobranças e estado encerrado.
- `BancoDoTabuleiro/Features/`: primeira implementação SwiftUI dos fluxos de partida, painel, PIX, cobranças, carteira de imóveis, extrato e resumo final.
- `BancoDoTabuleiro/Features/Board/BoardView.swift`: tela 3D SceneKit, movimento visual de peças e fallback procedural se o USDZ não estiver no bundle.
- `Scripts/generate_board_assets.py`: fonte Blender para tabuleiro, propriedades genéricas, seis peças, dados, cena `.blend`, preview e export USDZ.
- `Blender/PIX-Board-Studio.blend`, `Blender/PIX-Board-preview.png` e `BancoDoTabuleiro/Art.scnassets/BoardScene.usdz`: primeira geração real feita e inspecionada com Blender 5.2.2 neste host.
- `BancoDoTabuleiroTests/` e `BancoDoTabuleiroUITests/`: testes iniciais de saldo, idempotência, fundos insuficientes, compra/aluguel, cobrança, encerramento e fluxos visuais.
- `.github/workflows/ios-visual-review.yml`: geração Blender, build, XCTest, capturas do simulador e upload de artefatos no runner macOS.
- **Bloqueio externo:** Actions não iniciou os steps devido ao billing/spending limit da conta. O artefato `PIX-prints-iphone` não foi produzido; nenhuma tela foi marcada como aprovada sem inspeção visual real.
- **Revisão local:** o verificador Python de referências Xcode inicialmente tratou `SQLiteGameRepositoryTests.swift` e `BankFlowUITests.swift` como caminhos relativos à raiz; eles são relativos aos grupos XCTest próprios do projeto. Não é um arquivo ausente; a estrutura foi conferida no `.pbxproj` e no diretório.
