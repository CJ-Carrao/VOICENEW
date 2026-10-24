---
title: Buracos negros, Azul, Vermelho e Vazio Roxo
date: 2026-10-24
updated: 2026-10-24
tags:
  - lavoice
  - documentacao
---

# Buracos, Azul, Vermelho e Vazio Roxo

Projeto: [[Projetos/copia-de-jogo|LAVOICE Lab]] · Relacionado: [[Projetos/lavoice-lab/jujutsu|Técnicas de Jujutsu e domínios]] · [[Projetos/lavoice-lab/criatividade|Criatividade, colônias e defesas]]

Abra `jogar.cmd` para usar o executável atualizado. Fale com V ou digite com T, espere a montagem e clique para lançar a criação. Todos na partida online precisam desta versão.

| Pedido | Matéria base | Efeito |
| --- | ---: | --- |
| Quero um buraco negro | 150 | Puxa e comprime criaturas e jogadores próximos; desgasta blocos no núcleo. |
| Quero um buraco branco | 150 | Repele e causa dano na área. |
| Quero o Azul | 100 | Atrai e esmaga alvos num raio de 7 m; comprime blocos perto do centro. |
| Quero o Vermelho | 160 | Repele com o dobro da força e dano por pulso do Azul. |
| Quero Vazio Roxo | 290 | Projétil com 220 de dano por alvo, que abre um túnel real nos blocos. |

“Quero fazio roxo” também funciona. “Invocar um buraco negro”, “invocar o Azul” e “quero o vermelhor” são aceitos. O catálogo tem uma aba ESPAÇO. Os preços são a base: desconto de novidade, repetição e modificadores continuam valendo.

Buraco negro e buraco branco se anulam ao colidir, produzindo uma única explosão que atinge alvos e quebra blocos. Azul e Vermelho se fundem num único Vazio Roxo; o Roxo segue a direção do Vermelho e pertence ao jogador que o lançou. As combinações funcionam entre criações do mesmo jogador ou de adversários. Dois Azuis, dois Vermelhos ou dois buracos da mesma cor não provocam essa reação.

As esferas se movem e seus campos acompanham o ponto da criação. Negro e branco duram até sete segundos; Azul e Vermelho, seis. Ao terminar, o campo produz uma explosão menor. O Roxo atravessa alvos e cenário por até quatro segundos, atingindo cada alvo apenas uma vez. O lançador é poupado pelo próprio campo; suas criaturas podem ser atingidas. Escudos de gravidade reduzem as forças e o dano dos campos, e proteção espacial reduz o dano do Roxo.

O efeito usa o visual de blocos do jogo. Colisões são verificadas ao longo do deslocamento para evitar atravessamento entre projéteis rápidos. A fusão substitui duas esferas por uma, sem multiplicar entidades; dano em multidões é distribuído entre quadros. As interações são decididas pelo anfitrião e usam a criação, remoção e efeitos já sincronizados pelo jogo.

Verificação automática em `game/tests/spatial_powers.gd`: pedidos e erro de digitação, cores de animais preservadas, atração, repulsão, proporção 1:2, anulação negro/branco, fusão Azul/Vermelho em movimento, direção e dono do Roxo, ausência de fusão entre iguais, dano em criaturas, remoção de blocos reais e expiração dos campos. Relatório em `analysis/spatial-powers.json`.

Validação adicional: o teste de poderes também passou no motor nativo do executável. O teste online de dois processos (`network_smoke.gd --test-spatial`) verificou a criação de um único Roxo no anfitrião e no cliente.
