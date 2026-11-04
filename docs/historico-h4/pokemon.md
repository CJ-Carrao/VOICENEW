---
title: Pokémon e comandos de voz
date: 2026-10-24
updated: 2026-10-24
tags:
  - lavoice
  - documentacao
---

# Pokémon e comandos

Projeto: [[Projetos/copia-de-jogo|LAVOICE Lab]] · Relacionado: [[Projetos/lavoice-lab/captura|Pokébola e itens no chão]] · [[Projetos/lavoice-lab/jujutsu|Técnicas de Jujutsu e domínios]] · [[Projetos/lavoice-lab/tarefas|Próximas melhorias do jogo]]

Quatro companheiros em blocos, na aba **Pokémon** do catálogo. Crie com “quero um Pikachu”, “quero um Charmander”, “quero um Squirtle” ou “quero um Bulbasaur”. Os nomes “picachu” e “squitle” também funcionam.

Depois de invocar ou soltar da Pokébola, segure **B**, fale o comando e solte. **B** aceita apenas comandos: uma frase de criação dita nessa tecla não cria nada. **V** continua sendo a tecla para criar por voz. Também funciona pelo console **T**.

“Squirtle, ataque” ou “mande o Squirtle atacar” usam jato de água. “Pikachu, ataque”, “Charmander, ataque” e “Bulbasaur, ataque” usam respectivamente choque do trovão, brasa e chicote de cipó. Um toque rápido em **B** não ativa a coleta de blocos.

| Pokémon | Comando | Dano base | Alcance | Recarga |
| --- | --- | --- | --- | --- |
| Pikachu | “Pikachu, choque do trovão” | 30 | 18 m | 3,5 s |
| Pikachu | “Pikachu, ataque rápido” | 20 | 9 m | 2,5 s |
| Charmander | “Charmander, brasa” | 23 | 14 m | 2,8 s |
| Charmander | “Charmander, lança-chamas” | 40 | 17 m | 5,5 s |
| Squirtle | “Squirtle, jato de água” | 26 | 17 m | 3,2 s |
| Squirtle | “Squirtle, bolhas” | 20 | 13 m | 2,8 s |
| Bulbasaur | “Bulbasaur, chicote de cipó” | 28 | 11 m | 3,3 s |
| Bulbasaur | “Bulbasaur, folha navalha” | 32 | 17 m | 4,2 s |

“Pikachu, use o choque do trovão” também funciona, assim como os nomes ingleses dos golpes. A recarga é compartilhada entre os dois golpes daquele indivíduo. O comando aciona apenas um companheiro seu, disponível a até 60 metros, priorizando quem está pronto e mais perto. O golpe escolhe um inimigo ao alcance, favorece sua direção de mira e respeita paredes e dietas. Não cria outro Pokémon nem cobra novamente a invocação. Guardados na Pokébola, mortos e ainda em montagem não podem receber ordens. Capturar e soltar preserva o indivíduo e a recarga.

Os golpes têm dano real e efeitos próprios em blocos. Fogo pode queimar; ataque rápido inclui uma arrancada curta com colisão. Vantagens simplificadas entre estes Pokémon: elétrico contra água, água contra fogo, fogo contra planta e planta contra água dão 1,5× de dano; elementos iguais resistem. O Infinito continua protegendo contra golpes comuns; a adaptação do Mahoraga segue as regras existentes.

Custos base: Pikachu 100, Charmander 105, Squirtle 100 e Bulbasaur 105 de matéria. Aceitam armas, poderes, dietas e misturas. Uma cabeça de Pokémon em outro animal também leva seus comandos: “quero um cachorro com cara de Pikachu”, depois “Pikachu, choque do trovão”. Não há vozes dos personagens neste pacote.

## Combos entre criaturas

Os Pokémon também aceitam as [[Projetos/lavoice-lab/animais-ordens|ordens para animais]], como seguir, guardar uma casa e atacar um jogador específico. A ordem de atacar orienta também seus golpes; ordens de ficar, seguir, fugir e construir suspendem a busca automática por alvos. “Volte ao normal” libera o comportamento original.

Use os golpes no **mesmo animal inimigo**. Aponte para ele ao dar as ordens com **B**; os Pokémon escolhem um alvo visível ao alcance, favorecendo sua mira. As formas evoluídas e as misturas que possuem esses golpes também participam.

| Sequência | Efeito | Limites |
| --- | --- | --- |
| “Squirtle, jato de água” → “Pikachu, choque do trovão” | Água deixa o animal molhado por 4 s. Eletricidade consome a água e produz uma descarga em blocos, com 50% de dano extra. | Bônus de até 18 de dano; intervalo de 2 s por alvo entre descargas combinadas. Bolhas também molham. |
| “Bulbasaur, chicote de cipó” → “Charmander, brasa” | Cipós imobilizam o animal por 1,6 s. Fogo destrói os cipós, liberta o alvo e dá 35% de dano extra, com efeito de queima dos cipós. | Bônus de até 14 de dano; intervalo de 2 s por alvo entre reações de fogo. Lança-chamas também combina. |

Enquanto preso, o animal ainda pode atacar. Um novo enraizamento só pode ocorrer 6,6 s após o anterior: os cipós não renovam a prisão durante esse período. Folha navalha não prende. Os bônus passam pelas mesmas defesas do golpe original; dano completamente bloqueado não aplica nem consome os estados. Aliados e criações próprias não recebem os efeitos de combo.

Gotas azuis indicam água; faixas verdes indicam os cipós. Água e cipós expiram, a descarga consome a água e o fogo consome os cipós. Não há reação em cadeia nem dano extra em área: o combo afeta somente o animal atingido. Recargas dos golpes e custos de invocação continuam valendo; não há cobrança adicional para a reação. No online, o servidor controla dano, duração e efeitos. As reações não alteram o terreno.

## Evoluções durante a partida

Abra `jogar.cmd` para usar a versão local com evoluções. Segure **B** e diga **“Pikachu, progresso”** para consultar a experiência e os requisitos. Quando estiver pronto, diga **“Pikachu, evolua”**. Os mesmos comandos funcionam com o nome de cada Pokémon, inclusive formas evoluídas, ou pelo console **T**.

| Linha | Primeira evolução | Segunda evolução |
| --- | --- | --- |
| Pikachu → Raichu | 40 XP + 75 de matéria | Forma final |
| Charmander → Charmeleon → Charizard | 40 XP + 75 de matéria | Mais 90 XP + 140 de matéria |
| Squirtle → Wartortle → Blastoise | 40 XP + 75 de matéria | Mais 90 XP + 140 de matéria |
| Bulbasaur → Ivysaur → Venusaur | 40 XP + 75 de matéria | Mais 90 XP + 140 de matéria |

Cada 4 pontos de dano real a um inimigo rendem 1 XP, até 60 XP por alvo e por companheiro durante a vida daquele alvo. Dano bloqueado, excesso de dano sobre a vida restante, aliados e criações próprias não rendem experiência. Armas e projéteis produzidos pelo companheiro também podem contribuir. Evoluir consome o XP indicado e a matéria; o saldo de XP fica guardado. O jogo informa o que falta ao tentar evoluir.

A evolução conserva o mesmo indivíduo, dono, equipe, proporção de vida, misturas, armas, munição, poderes e recargas. Não recupera vida gratuitamente. A Pokébola conserva a forma e a experiência; guardado, o Pokémon não recebe ordens nem evolui. Uma cabeça de Charmander em um cachorro evolui a cabeça e mantém o corpo de cachorro. Os sete modelos evoluídos seguem o estilo de blocos; Charizard ganha voo quando seu corpo evolui.

As formas evoluídas usam os mesmos nomes de golpes de sua família, com dano maior: por exemplo, **“Raichu, choque do trovão”**, **“Charizard, lança-chamas”** e **“Blastoise, jato de água”**. Também podem ser invocadas diretamente por um custo maior no catálogo. No online, evolução, XP, forma, vida e recargas são controlados pelo servidor e sincronizados; todos precisam atualizar o jogo.

Pesquisa para aparência, tipos e golpes: [Pikachu — Pokédex oficial](https://sg.portal-pokemon.com/pokedex/0025/), [Charmander — Pokédex oficial](https://sg.portal-pokemon.com/pokedex/0004/), [Squirtle — Pokédex oficial](https://sg.portal-pokemon.com/pokedex/0007/), [Bulbasaur — Pokédex oficial](https://sg.portal-pokemon.com/pokedex/0001/), [cartas oficiais FireRed & LeafGreen](https://assets.pokemon.com/assets/cms/pdf/tcg/carddex/EX_FireRed_and_LeafGreen.pdf), e fichas de movimentos de [Pikachu](https://pokemondb.net/pokedex/pikachu), [Charmander](https://pokemondb.net/pokedex/charmander), [Squirtle](https://pokemondb.net/pokedex/squirtle), [Bulbasaur](https://pokemondb.net/pokedex/bulbasaur). “Choque do trovão”, “jato de água” e “folha navalha” mantêm nomes populares em português; traduções variam entre jogos, anime e cartas. Valores de dano, alcance e recarga são adaptações para este jogo. Geometria própria, sem importar modelos ou áudios.
