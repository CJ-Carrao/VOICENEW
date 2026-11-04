---
title: Fusões, armas criativas, vínculo e chefes
date: 2026-10-25
updated: 2026-10-25
tags:
  - lavoice
  - criatividade
  - cooperativo
---

# Criatividade completa

Projeto: [[Projetos/copia-de-jogo|LAVOICE Lab]] · [[Projetos/lavoice-lab/tarefas|Lista das oito etapas]] · [[Projetos/lavoice-lab/pokemon|Pokémon]] · [[Projetos/lavoice-lab/animais-ordens|Ordens]]

Use **V** para criar, **B** para dar comandos e **T** para escrever. O executável atual é aberto por `jogar.cmd`. Os dois participantes precisam da mesma versão para jogar online.

## Fusões com habilidades

- “Quero um Pikachu com corpo de tiranossauro rex e habilidade do Squirtle.”
- “Quero uma borboleta com habilidade do Squirtle.”
- “Quero um cachorro com cabeça de Mahoraga.”
- “Quero um cachorro com corpo de dragão.”

Cabeça, corpo, asas, cauda e patas de doadores com poderes podem acrescentar as habilidades dos Pokémon, técnicas de Jujutsu ou o sopro do dragão. As patas continuam determinando a velocidade; asas continuam permitindo voo. A criatura mantém seus poderes originais. Misturar uma parte de um animal sem poder especial altera sua anatomia e as capacidades físicas já suportadas.

Até **três doadores diferentes** acrescentam habilidades. Repetir o mesmo doador em várias partes não acumula o poder. O acréscimo por doador é o maior valor entre **35 de matéria** e **60% do preço base do doador**, além do custo normal das partes. O pedido mostra os poderes herdados e seu custo. Com a mira na criatura, diga **“habilidades da fusão”** para consultar novamente.

Os golpes herdados de Pokémon aceitam os comandos do Pokémon doador: uma borboleta com habilidade do Squirtle pode receber **“Squirtle, jato d'água”**. Quando a criatura recebe ordem de atacar ou está agressiva, alterna seus conjuntos de golpes, respeitando alvo, dieta e uma recarga compartilhada de pelo menos 2,5 s. A evolução do Pokémon principal e a captura preservam a fusão, vínculo e recargas. Habilidades emprestadas do corpo não permitem evoluir uma parte gratuitamente.

## Armas criativas

| Pedido | Custo base | Efeito |
| --- | ---: | --- |
| “Quero raio de envelhecimento” | 95 | Um alvo visível a até 24 m: fica acinzentado e 45% mais lento por 6 s. Recarga 5 s; imunidade a renovação por 14 s desde o acerto. |
| “Quero raio de troca de cabeças” | 145 | Duas criaturas inimigas próximas da mira e a até 24 m trocam a aparência das cabeças por 8 s. Recarga 12 s; proteção de 16 s contra outra troca. |
| “Quero granada que troca equipes” | 180 | Arremesse: após 2 s, converte até oito criaturas inimigas visíveis num raio de 5 m por 6 s. Proteção de 18 s contra nova conversão. |

As trocas preservam o indivíduo: vida, armas, poderes, evolução e conteúdo das Pokébolas. A troca de cabeças é visual; não concede outro conjunto de poderes de graça. Não é possível evoluir enquanto estiver sob troca de cabeça ou de equipe. O retorno é automático. Capturar encerra as alterações antes de transferir a posse, evitando que o efeito devolva depois uma criatura já capturada ao dono antigo.

Aliados, criaturas guardadas, chefes, Infinito e a adaptação do Mahoraga resistem a essas três ferramentas. Os raios respeitam paredes. Não há duplicação de criaturas nem troca de inventários de bolas.

## Personalidade e vínculo

Cada criatura começa com vínculo **35/100**. Perder vida aumenta o medo, que cai com o tempo. Seu estado é tranquilo, confiante ou assustado. A confiança não provoca desobediência aleatória.

- Mire numa criatura sua a até 15 m e diga **“cuidar da criatura”**, **“fazer carinho”** ou **“cuidar do cachorro”**. Custa **8 de matéria**, cura até 5 de vida, acrescenta 10 de vínculo e reduz 25 de medo. Recarga de 4 s por criatura.
- **“Vínculo da criatura”** consulta confiança, medo e personalidade.
- Com vínculo **60**, **“proteja seus companheiros”** manda defender seus animais atacados nas proximidades. O defensor respeita sua dieta e pode receber outra ordem normalmente.
- Uma criatura com menos de 15% de vida, medo de pelo menos 70 e vínculo abaixo de 50 pode recusar uma nova ordem de atacar ou ficar agressiva. A resposta explica o motivo. Seguir, ficar, recuar e cuidar continuam disponíveis.

Captura e evolução preservam vínculo e medo. Cuidar não ressuscita criaturas. Não é necessário manter uma rotina de alimentação para que os comandos comuns funcionem.

## Chefe cooperativo: Quimera Adaptativa

É um T-Rex alado em blocos com adaptação do Mahoraga. Para iniciar, diga **“desafio cooperativo”**. O outro jogador deve dizer **“aceitar desafio”** em até 30 s. O iniciador paga **300 de matéria** somente quando a invocação acontece. Em Treino, o mesmo pedido inicia a versão solo.

Durante o confronto, os participantes e suas criaturas ficam aliados contra o chefe. Não é preciso mudar de time permanentemente. A vida é **600 no solo** ou **950 para dois jogadores**; o dano aumenta 15% para o segundo participante. O chefe voa, alterna golpes de área e investidas e se adapta aos tipos de dano.

O círculo no chão e o aviso sobre o chefe anunciam o próximo ataque com **1,1 s** de antecedência. Saia da área; depois do golpe, ele fica vulnerável por **1,6 s**, recebendo 50% mais dano. Ataques têm limites de alvos e não produzem uma cascata de explosões de terreno.

Há **180 s** para vencer. A vitória dá **120 de matéria por participante**, uma única vez; o excesso vira matéria no chão. Todos mortos ou tempo esgotado resultam em derrota. A desconexão de um participante cancela o desafio. Ao terminar, a aliança acaba e o chefe é removido. A recarga entre desafios concluídos é de **60 s**. O chefe não pode ser capturado ou convertido para evitar invocações baratas por troca de posse.

**“Status do desafio”** mostra o estado. **“Cancelar desafio”** cancela um convite ainda não iniciado.

## Verificação

Testes sem janela: `creative_progression.gd` verifica herança, custo, recarga compartilhada, evolução, captura, uso real do raio, restauração de cabeças e equipes, proteção dos companheiros, custo do cuidado, vitória, derrota, cancelamento e recompensa única. Regressões de evoluções, ordens, construtores e domínios também foram executadas.

`network_smoke.gd --test-progression` usa dois processos: poderes e vínculo, troca de cabeças, conversão e retorno de equipe, convite aceito pelo segundo jogador, chefe com vida ajustada, proteção entre aliados e fim do desafio. A aparência final ainda deve ser conferida durante uma partida; o jogo não foi aberto em janela.
