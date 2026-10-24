---
title: Criatividade, colônias e defesas
date: 2026-10-24
updated: 2026-10-24
tags:
  - lavoice
  - documentacao
---

# Criatividade, colônias e defesas

Projeto: [[Projetos/copia-de-jogo|LAVOICE Lab]] · Relacionado: [[Projetos/lavoice-lab/dinossauros|Dinossauros e misturas]] · [[Projetos/lavoice-lab/captura|Pokébola e itens no chão]] · [[Projetos/lavoice-lab/jujutsu|Técnicas de Jujutsu e domínios]]

Abra `jogar.cmd` para usar a versão atual. **F2** mostra o catálogo e uma aba **COMBINAR** com exemplos. Segure **V**, fale e solte; **T** aceita os mesmos pedidos por texto. Espere a montagem terminar antes de usar. Para jogar online, todos precisam desta mesma versão. Veja também [[Projetos/lavoice-lab/animais-ordens|Ordens, animais agressivos e construções]].

## Pedidos para experimentar

- Quero uma arma que faça um escudo anti bomba de nêutrons.
- Quero um jacaré que use uma AK47.
- Quero uma casa ambulante.
- Quero uma casa ambulante anti bomba de nêutrons.
- Quero uma parede anti bomba nuclear.
- Quero uma formiga rainha que faça um ninho.
- Quero um pato que só coma formigas.
- Quero uma raposa que só coma ratos.
- Quero um tamanduá.
- Quero uma abelha rainha.
- Quero uma colmeia.
- Quero um galinheiro.
- Quero um pato com uma pistola que atira formigas com uma pistola.
- Quero um lobo que só coma capivaras.
- Quero um pato com cabeça de um dragão.
- Quero uma formiga com asas de borboleta.
- Quero uma capivara misturada com um pato.
- Quero um elefante que só ataque dragões.
- Quero um dragão que só coma elefantes.
- Quero um elefante que só ataque dragões com uma pistola.

Essas regras se combinam: criaturas podem carregar armas reais, casas podem andar e receber proteção, e animais podem receber dietas específicas. As armas acopladas em criaturas miram automaticamente, gastam munição e aumentam o custo da criação. A casa tem porta e interior oco. As possibilidades usam o vocabulário e as regras disponíveis no jogo; uma frase totalmente nova ainda pode precisar de uma nova regra.

## Defesas e custos

| Proteção | Matéria base | Ameaça correspondente | Matéria base |
| --- | ---: | --- | ---: |
| Escudo anti bombas | 24 | Granada comum | conforme o pedido |
| Escudo anti nêutrons | 38 | Bomba de nêutrons | 210 |
| Escudo anti bombas nucleares | 48 | Bomba nuclear | 240 |
| Escudo anti gravidade | 34 | Bomba de gravidade | 110 |
| Escudo anti cortes espaciais | 60 | Faca que corta o espaço | 180 |

O escudo comum reduz explosões comuns, mas o pulso de nêutrons atravessa. O escudo de nêutrons reduz esse dano em 90%; ele não dá proteção universal. A defesa nuclear reduz dano nuclear em 85%, a gravitacional reduz força e dano gravitacionais em 85%, e a espacial reduz cortes em 75%.

Campos protegem aliados próximos, num raio padrão de **3,5 m**, e não somam reduções quando sobrepostos. Absorver dano desgasta o escudo; a proteção acaba quando ele quebra. Escudos gerados por armas pagam matéria por unidade, com limite de **três campos gerados ativos por equipe**. O campo protege criaturas e jogadores; não torna o terreno indestrutível.

Os modificadores também funcionam em outros objetos: uma parede ou casa com proteção custa o objeto mais a proteção escolhida. Quantidade, tamanho, armas acopladas e comportamentos aumentam o preço. A primeira criação recebe o desconto de novidade do jogo; repetição pode encarecer o pedido. Os preços acima são a base mostrada no F2.

Bombas fortes foram encarecidas: singularidade 220, hipotética de gravidade 145, meteoros 160. A faca espacial custa 180, tem alcance e intervalo de uso limitados. Granadas de criaturas custam a carga completa mais o mecanismo.

## Colônias e predadores

A formiga rainha custa **85** e constrói um ninho de **30**, usando a sua matéria. Um ninho por rainha. O ninho cria uma formiga a cada cinco segundos, pagando o custo dela, sem limite de população e sem prazo para desaparecer. Sem matéria, a produção espera. Quando a rainha morre, o ninho para de produzir.

O pato com a dieta “só coma formigas” procura formigas e rainhas, inclusive da sua própria equipe. Ele caminha até a presa e morde; poupa galinhas e outras espécies. Sem presas, para de caçar. O tamanduá já vem com essa dieta. Também existem dietas de insetos, ratos e galinhas.

“Que só ataque”, “que só ataca”, “que só atacar”, “que só coma” e “que só comer” escolhem uma espécie alvo para qualquer uma das 69 espécies cadastradas. O animal procura a espécie pedida, caminha ou voa até ela e ataca quando está ao alcance do corpo. Animais grandes consideram o tamanho da presa para conseguir atingir, por exemplo, um dragão voando baixo. Um animal terrestre precisa que a presa esteja ao seu alcance, ou de uma arma para atingir alvos mais altos. Sem a espécie alvo, ele aguarda e poupa as outras criaturas e jogadores. As armas e habilidades acopladas respeitam a mesma seleção, inclusive os disparos que já saíram da arma. A regra também vale para alvos da própria equipe.

A abelha rainha mantém a colmeia. O galinheiro produz galinhas sem exigir rainha. Toda produção ecológica paga matéria por animal, sem limite de população. Dietas específicas aceitam todas as espécies cadastradas, além dos grupos de insetos, formigas, ratos e galinhas.

## Explosão de nêutrons

Agora há clarão azul, fragmentos cúbicos, impacto próximo que quebra estruturas e remove blocos reais do cenário, além do pulso mais distante contra criaturas. A cratera é menor que a da bomba nuclear. São efeitos e regras de ficção do jogo.

## Verificação

Referências de origem e de alvo agora são descartadas quando o objeto correspondente é apagado. O dano e os efeitos validam o alvo antes de testar seu tipo. A regressão inclui a cadeia cachorro → gato → pombo → rato e uma nuclear arremessada pelo sistema de mãos, com o objeto original já removido antes da detonação; os testes anteriores de multidões criavam a bomba diretamente no mundo.

A bomba seletiva custa **290 de matéria base** e aceita qualquer uma das 69 espécies cadastradas. Exemplo: **“quero uma bomba que mate todas as borboletas”**; troque borboletas por elefantes, dragões ou outro animal do catálogo. Após arremessada, detona em três segundos e elimina os animais daquela espécie que existirem no mapa, de ambas as equipes, inclusive os distantes. Poupa outras espécies, jogadores e terreno. A eliminação é feita em pequenos grupos, sem gerar uma explosão por animal. Animais criados depois do pulso podem voltar a aparecer.

Explosões comuns e nucleares que atingem multidões também distribuem o dano e a remoção dos corpos entre quadros. A explosão continua removendo blocos do terreno; animais atingidos não ficam limitados aos primeiros 128 resultados da consulta de colisão.

Criações em cadeia, como “minigun que atire aviões que atirem elefantes”, agora compartilham um ritmo de produção. Quando há muita coisa sendo criada, novos animais e veículos aguardam; os existentes permanecem. Disparos que precisam esperar não gastam munição. Granadas entregam toda a carga em etapas, e efeitos de bombas especiais são espaçados para reduzir picos de trabalho. A minigun com balas comuns mantém sua velocidade normal. Isso reduz a sobrecarga, mas populações muito grandes continuam exigindo mais do computador.

Os testes verificam o catálogo de 76 modelos, frases compostas, armas especiais, bombas, proteção, gasto de matéria, produção sem limite de população, morte da rainha, dieta seletiva, animais armados, locomoção da casa e remoção de blocos pela bomba de nêutrons. As regressões do documento têm um teste específico em `game/tests/reported_regressions.gd`; os relatórios locais ficam em `analysis`.
