# Banco do Tabuleiro · PIX Imobiliário

App iOS local-first para controlar partidas físicas de jogos imobiliários. Saldos são fictícios, persistidos em SQLite no iPhone e não representam dinheiro real.

## MVP atual

- Criar partida local para 2–6 jogadores.
- Distribuir dinheiro inicial e registrar o livro de lançamentos.
- Fazer transferências internas, criar cobranças, cadastrar e comprar propriedades e registrar aluguel.
- Consultar painel, extrato, carteira de imóveis e resumo visual do tabuleiro.
- Tabuleiro 3D original em Blender/USDZ com fallback SceneKit para desenvolvimento e testes.

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

O GitHub Actions executa o build/teste no runner macOS, gera screenshots das telas principais e publica logs e resultados XCTest como artefatos.

## Blender

Requer Blender com suporte à exportação USD. A cena fonte, o preview e o USDZ são gerados por:

```sh
blender --background --python Scripts/generate_board_assets.py -- BancoDoTabuleiro/Art.scnassets
```

O USDZ é empacotado pelo Xcode a partir de `BancoDoTabuleiro/Art.scnassets/BoardScene.usdz`. Se ele não estiver presente, a tela usa uma cena SceneKit procedural.

## Roadmap

Veja [`ROADMAP.md`](ROADMAP.md) para escopo, marcos até a semana 9, critérios de aceite e diário das rodadas de teste/revisão visual.
