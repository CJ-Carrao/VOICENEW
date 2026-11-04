---
title: Dinossauros e misturas
date: 2026-10-24
updated: 2026-10-24
tags:
  - lavoice
  - documentacao
---

# Dinossauros e misturas

Projeto: [[Projetos/copia-de-jogo|LAVOICE Lab]] · Relacionado: [[Projetos/lavoice-lab/criatividade|Criatividade, colônias e defesas]] · [[Projetos/lavoice-lab/brainrots|Brainrots em blocos]] · [[Projetos/lavoice-lab/pokemon|Pokémon e comandos de voz]]

Abra `jogar.cmd` para usar a atualização. No online, todos precisam desta versão. O catálogo tem a aba DINOS.

O tiranossauro rex ganhou um modelo em blocos próprio para misturas. Também estão disponíveis tricerátops, estegossauro, braquiossauro, espinossauro, anquilossauro, parassaurolofo e diplodoco. “Velociraptor” chama o raptor existente.

Exemplos de pedidos:

- Eu quero um elefante com cara de cachorro.
- Eu quero um cachorro com cara de tiranossauro rex.
- Quero um pato com cabeça de tricerátops.
- Quero um elefante com corpo de espinossauro.
- Quero um cachorro com patas de braquiossauro.
- Quero um cachorro com cauda de anquilossauro.
- Quero um tiranossauro rex com cara de cachorro com uma AK47.
- Quero um cachorro com cara de tiranossauro rex com a habilidade do Mahoraga.
- Quero um cachorro que só ataque tiranossauro rex.

“Cara”, “rosto” e “cabeça” substituem de fato as peças da cabeça, ajustando o tamanho ao animal que recebe a parte. A mistura também funciona no sentido inverso: dinossauros podem receber partes dos outros animais. Corpo, patas e cauda usam o mesmo sistema existente. As partes têm custo adicional; armas, dietas e habilidades continuam sendo combináveis.

| Dinossauro | Matéria base | Vida | Velocidade |
| --- | ---: | ---: | ---: |
| Tiranossauro rex | 130 | 280 | 3,2 |
| Tricerátops | 100 | 260 | 2,4 |
| Estegossauro | 95 | 240 | 1,8 |
| Braquiossauro | 145 | 340 | 1,5 |
| Espinossauro | 135 | 280 | 2,7 |
| Anquilossauro | 115 | 300 | 1,7 |
| Parassaurolofo | 80 | 190 | 3,0 |
| Diplodoco | 140 | 320 | 1,8 |

Os descontos de novidade e demais modificadores continuam valendo. Os modelos são originais em blocos, com cabeças, olhos, mandíbulas, pernas e caudas identificadas para a composição. Chifres e gola do tricerátops acompanham a cabeça; placas do estegossauro e vela do espinossauro acompanham o corpo; clava do anquilossauro acompanha a cauda.

Verificações: `game/tests/dinosaur_mixes.gd` cobre os pedidos acima, substituição visual real, custo, armas, Mahoraga, dieta e movimento, além das quatro partes dos oito dinossauros. `network_smoke.gd --test-dinosaurs` verifica a cabeça de T. rex e a adaptação do Mahoraga chegando ao segundo jogador. Relatórios em `analysis`. `tools/add_dinosaur_pack.py` regenera este pacote sem remover os poderes dos pacotes anteriores.
