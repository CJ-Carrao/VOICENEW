---
title: Ordens, animais agressivos e construções
date: 2026-10-24
updated: 2026-10-24
tags:
  - lavoice
  - documentacao
---

# Ordens, animais agressivos e construções

Projeto: [[Projetos/copia-de-jogo|LAVOICE Lab]] · Relacionado: [[Projetos/lavoice-lab/tarefas|Lista de tarefas]] · [[Projetos/lavoice-lab/criatividade|Criatividade e colônias]] · [[Projetos/lavoice-lab/pokemon|Pokémon, evoluções e combos]] · [[Projetos/lavoice-lab/captura|Captura]]

Abra `jogar.cmd`. Crie animais com **V**; dê ordens com **B** ou pelo console **T**. As ordens funcionam nas 100 espécies atuais, incluindo dinossauros, Mahoraga, Pokémon, brainrots e criaturas com misturas.

## Dar uma ordem

Diga o nome do animal seguido da ordem, por exemplo **“cachorro, me siga”**. Se houver vários da mesma espécie, sua mira e a distância ajudam a escolher um. Também pode apontar diretamente para um animal seu e dizer só **“me siga”**. No singular, uma ordem seleciona um indivíduo, visível e a até 60 m; a mensagem confirma quem a recebeu. Animais mortos, capturados, ainda em montagem ou de outro jogador não podem receber ordens.

| Comando | Comportamento |
| --- | --- |
| Cachorro, me siga | Acompanha o treinador, mantendo espaço ao redor dele. |
| Cachorro, fique aqui | Guarda a posição, sem perseguir ou disparar automaticamente. |
| Cachorro, proteja minha casa | Mire na casa. Defende uma área de 10 m em torno dela; acompanha o ponto se for uma casa ambulante. Sem casa próxima, guarda sua posição atual. |
| Cachorro, ataque aquele jogador | Mire em um jogador ou criatura adversária. Persegue esse alvo; armas e habilidades usam o mesmo alvo. A dieta continua valendo. |
| Cachorro, fuja das bombas | Procura se afastar de bombas e granadas próximas. Sem ameaça próxima, acompanha você. |
| Cachorro, ataque só quem me atacar | Reage ao último agressor do treinador, por até 10 s; depois volta a acompanhá-lo. |
| Cachorro, volte ao normal | Cancela a ordem e retoma o comportamento original. |
| Cachorro, seja agressivo | Ataca alvos à frente, incluindo animais do próprio time, poupando o dono. |

As ordens usam o movimento que a criatura possui: aves voam, animais terrestres caminham. Elas não concedem teleporte, voo ou velocidade extra. Há desvio simples de obstáculos; não é um sistema de busca de caminhos para labirintos. Dietas continuam restringindo o que cada animal pode atacar. Durante uma ordem de seguir, ficar, fugir ou construir, armas montadas e caça automática deixam de procurar alvos por conta própria.

## Criaturas agressivas

Crie com **“quero um Mahoraga agressivo”**, **“quero um cachorro agressivo”** ou **“quero uma aranha agressiva”**. O modificador funciona em qualquer criatura, inclusive misturas.

Ela procura criaturas, jogadores e criações destrutíveis à sua frente, em um raio de 18 m. Sem alvo, patrulha para a frente em vez de ficar parada; aves continuam voando. Armas montadas não colidem com o próprio portador. Pode atacar seus outros animais; o próprio treinador fica fora da seleção e do dano direto de seus poderes e projéteis. Armas montadas seguem o alvo escolhido. A agressividade não aumenta vida, velocidade ou dano. Para controlá-la, dê outra ordem, como “Mahoraga, fique aqui”. A captura mantém o indivíduo; ao mudar de dono, a proteção passa a valer para o novo treinador.

## Animais construindo

Primeiro invoque o animal, depois mire no chão onde quer o trabalho e dê o comando pelo **B**. O local precisa estar a até 20 m do animal. Ele se aproxima e trabalha; a indicação acima dele mostra o progresso ou se falta matéria.

| Animal e comando | Trabalho | Custo e limites |
| --- | --- | --- |
| Formiga, cave um túnel | Remove terra do terreno aos poucos. Não escava casas, outros materiais nem blocos permanentes. | 0,3 de matéria por bloco efetivamente removido; até 96 por trabalho, 192 por formiga e 512 por equipe durante a partida. |
| Castor, construa uma barragem | Monta uma barreira física de troncos no estilo em blocos, com 220 de vida. | 4 s de trabalho no local; 32 de matéria; até 2 barragens ativas por castor e 6 por equipe. |
| Aranha, faça uma teia | Monta uma teia destrutível com 40 de vida. Inimigos que a atravessam ficam com 35% da velocidade por 1,2 s; aliados passam normalmente. | 2,5 s de trabalho no local; 16 de matéria; até 3 teias ativas por aranha e 8 por equipe. |

Também funciona “castor, construa aqui” ou simplesmente “construa aqui” apontando para o construtor. Cada comando inicia um trabalho, sem produção automática contínua. Há 8 s de recarga depois de terminar. A barragem é uma construção física; não simula rios ou inundação.

A matéria sai do treinador: escavação cobra por bloco; barragem e teia cobram ao concluir. Falta de matéria pausa o trabalho. Capturar, matar, remover o animal ou mandar outra ordem interrompe o trabalho sem criar construções depois. Terra já removida continua paga e removida. Barragens e teias prontas permanecem e podem ser destruídas; sua destruição libera espaço no limite de construções ativas.

No online, o servidor decide alvos, gastos, construção, escavação e armadilhas. Ordens, progresso, produtos, mudanças no terreno e destruição são sincronizados. Todos precisam usar a mesma versão do jogo.

## Comandos no plural

Segure B e diga **“cachorros, me sigam”**: todos os seus cachorros visíveis e a até 60 m recebem a ordem. Também aceita “cachoros me sigam”, “cachorros me siga” e “todos os cachorros venham comigo”. O comando informa quantas criaturas receberam a ordem. No singular, “cachorro me siga” continua escolhendo apenas um indivíduo.

Funciona nas 100 espécies: “pombos me sigam”, “dragões fiquem aqui”, “cachorros ataquem”, “cachorros protejam minha casa”, “cachorros fujam das bombas”, “cachorros ataquem só quem me atacar”, “cachorros voltem ao normal” e “cachorros sejam agressivos”. Com **“todos me sigam”**, você chama suas criaturas de todas as espécies. Capturadas, mortas, em montagem, distantes, ocultas ou de outro jogador ficam fora.

Ao mandar atacar, mire no jogador ou criatura inimiga. A dieta continua valendo. Os comandos de golpes específicos de Pokémon continuam funcionando. Construções permanecem ordens individuais para escolher o local de trabalho de cada construtor.