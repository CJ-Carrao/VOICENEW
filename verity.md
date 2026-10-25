---
title: Verity, a bolinha amarela
date: 2026-10-25
updated: 2026-10-25
tags:
  - lavoice
  - criaturas
---

# Verity

Projeto: [[Projetos/copia-de-jogo|LAVOICE Lab]] · Relacionado: [[Projetos/lavoice-lab/animais-ordens|Ordens das criaturas]] · [[Projetos/lavoice-lab/captura|Pokébola]] · [[Projetos/lavoice-lab/jujutsu|Poderes de Jujutsu]]

Use V e diga **“quero um Verity”**. Também reconhece “veriti”, “verite” e “bolinha amarela”. É uma criatura flutuante com sorriso e olhos pretos, modelada em 46 peças no estilo em blocos do jogo. Custo base de 85 de matéria, 65 de vida e velocidade 4 m/s.

Ao ser invocado, acompanha automaticamente o dono, buscando uma posição lateral e elevada para não ocupar a mira. Os olhos piscam e o corpo oscila suavemente. As ordens funcionam com B ou texto T: “Verity, fique aqui”, “Verity, me siga”, “Verity, seja agressivo” e as demais ordens comuns. “Verity, volte ao normal” restaura o acompanhamento. “Veritys, me sigam” comanda os seus Veritys visíveis e próximos.

Perto do dono (até 5 m), cura 4 de vida a cada 4 segundos quando ele está abaixo de 60% da vida máxima, sem ultrapassar esse patamar. A recarga pertence ao dono e é compartilhada entre os Veritys; criar ou capturar outros não multiplica a cura. Capturado, morto, paralisado ou distante não cura. É uma adaptação de suporte para este jogo, não uma reprodução de todas as ações da série.

Aceita Pokébola, armas e poderes. Exemplos: “quero um Verity com uma AK 47”, “quero um Verity com infinito”, “quero um cachorro com cara de Verity”. A captura preserva o indivíduo e a ordem; as réplicas online exibem o companheiro, enquanto a autoridade do servidor decide movimento e cura.

Referência: o personagem amarelo, flutuante e sorridente da série de terror Minecraft *Something*, de ThatMob, conforme [Verity — Know Your Meme](https://knowyourmeme.com/memes/subcultures/verity-minecraft-arg). A aparência foi recriada com geometria própria do jogo.

Verificação sem abrir janela em `game/tests/verity_companion.gd`: nomes, misturas, arma, poder, movimento real, comandos, cura sem acumular, limite de cura, captura, soltura e apresentação de réplica. `group_animal_orders.gd` verificou também os comandos coletivos das 100 espécies atuais.