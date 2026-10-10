# Banco do Tabuleiro · PIX Imobiliário

App iOS local-first para controlar partidas físicas de jogos imobiliários. Saldos são fictícios, persistidos em SQLite no iPhone e não representam dinheiro real.

![Ícone original do Banco do Tabuleiro](BancoDoTabuleiro/Assets.xcassets/AppIcon.appiconset/AppIcon.png)

## MVP atual

- Criar partida local para 2–6 jogadores.
- Configurar a partida em duas etapas: nome e saldo inicial, depois cadastro visual dos jogadores com nome, cor e peça.
- Validar nomes vazios ou repetidos; adicionar e remover participantes de 2 a 6 antes de iniciar.
- Prévia opcional de acesso fintech em modo demonstração, sem coletar nem enviar credenciais.
- Distribuir dinheiro inicial e registrar o livro de lançamentos.
- Fazer transferências internas com estado de processamento local e comprovante; criar cobranças, cadastrar e comprar propriedades e registrar aluguel.
- Registrar créditos e pagamentos ao banco virtual (por exemplo, renda de passagem ou taxa da partida).
- Acompanhar o ranking ao vivo no painel e consultar a classificação completa, com saldo e imóveis separados.
- Passar rapidamente para o próximo jogador, confirmar a conta ativa e ocultar o saldo principal quando o iPhone circular pela mesa.
- Consultar o valor das cobranças pendentes antes de pagar.
- Definir a ordem dos jogadores e quem começa a partida.
- Ver o resultado final após encerrar a partida; empates compartilham a mesma posição.
- Consultar painel, extrato, carteira de imóveis e resumo visual do tabuleiro.
- Tabuleiro 3D original em Blender/USDZ com fallback SceneKit para desenvolvimento e testes.
- Posição visual de cada peça salva localmente e retomada ao reabrir a partida.
- Alternar o jogador ativo tocando no avatar; transferências, compras e cobranças usam esse contexto inicial.
- Apagar todas as partidas e os dados locais pelo menu da partida.
- Ícone original verde/dourado incluído no asset catalog iOS.

A tela **Privacidade e dados** explica que o MVP é local, sem login/rede/analytics, e que os saldos são moeda fictícia.

O ranking calcula patrimônio como saldo disponível mais preço de compra cadastrado dos imóveis. O valor aparece separado do saldo em dinheiro fictício; renda futura de aluguel não é contabilizada.

O MVP é hot-seat: participantes usam o mesmo iPhone. O código local identifica a sessão, mas não conecta outros aparelhos. Multiplayer entre dispositivos exige backend e fica fora desta fase.

## Abrir e testar

1. Abra `BancoDoTabuleiro.xcodeproj` no Xcode 16 ou posterior.
2. Selecione o scheme `BancoDoTabuleiro` e um simulador de iPhone.
3. Execute o app ou rode Product → Test.

Build local no macOS:

```sh
xcodebuild -project BancoDoTabuleiro.xcodeproj -scheme BancoDoTabuleiro \
  -destination 'platform=iOS Simulator,name=iPhone 16' CODE_SIGNING_ALLOWED=NO test
```

O GitHub Actions executa o build/teste no runner macOS, gera screenshots das telas principais e publica como artefatos o app de simulador sem assinatura, logs e resultados XCTest. O `.app` é voltado a simulador; instalação em iPhone físico/TestFlight exige assinatura Apple.

## Blender

Requer Blender 5.2+ com suporte à exportação USDZ. A cena fonte, o preview e o USDZ são gerados por:

```sh
blender --background --python Scripts/generate_board_assets.py -- BancoDoTabuleiro/Art.scnassets
```

O projeto inclui a cena fonte `Blender/PIX-Board-Studio.blend`, o preview `Blender/PIX-Board-preview.png` e o USDZ em `BancoDoTabuleiro/Art.scnassets/BoardScene.usdz`. O GitHub Actions regenera os três para revisão. Se o USDZ não estiver presente, a tela usa uma cena SceneKit procedural.

## Roadmap

Veja [`ROADMAP.md`](ROADMAP.md) para escopo, marcos até a semana 9, critérios de aceite e diário das rodadas de teste/revisão visual.
