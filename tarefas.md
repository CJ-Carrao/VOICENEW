---
title: Próximas melhorias do jogo
date: 2026-10-24
updated: 2026-10-24
tags:
  - lavoice
  - planejamento
---

# Próximas melhorias do jogo

Projeto: [[Projetos/copia-de-jogo|LAVOICE Lab]] · Relacionado: [[Projetos/lavoice-lab/pokemon|Pokémon e comandos de voz]] · [[Projetos/lavoice-lab/criatividade|Criatividade, colônias e defesas]] · [[Projetos/lavoice-lab/leia-me|Guia do LAVOICE Lab]]

Cada etapa só será marcada como concluída depois de implementada, testada e incluída no executável. Progresso: **4 de 8 etapas concluídas**. As etapas 3 e 5 foram feitas juntas por pedido do usuário. Próxima etapa pendente: **fusões com poderes combinados**.

**Fora desta etapa:** ambiente reagindo automaticamente a elementos e modo laboratório. Não abrir o jogo automaticamente; validar sem janela.

- [x] **1. Evoluções durante a partida**
  - Experiência por participação em combate, sem contar ataques a aliados ou criações próprias como experiência gratuita.
  - Linhas: Pikachu → Raichu; Charmander → Charmeleon → Charizard; Squirtle → Wartortle → Blastoise; Bulbasaur → Ivysaur → Venusaur.
  - Evolução exige experiência e matéria, com confirmação por comando de voz; mostrar requisitos quando faltar algo.
  - Preservar dono, equipe, proporção de vida, misturas, armas, poderes e recargas. Captura preserva experiência e evolução.
  - Modelos em blocos para cada evolução; Charizard com voo.
  - Validar evolução, custo, preservação de modificações e sincronização online.
  - Concluída: sete formas evoluídas em blocos, XP por dano real com limite por alvo, comandos “nome, progresso” e “nome, evolua”. Primeira evolução: 40 XP + 75 de matéria; segunda: 90 XP + 140 de matéria.
  - Validado: sete evoluções, requisitos e custos, vida proporcional, armas e munição, poderes, misturas, captura, comandos anteriores e evolução comandada pelo segundo jogador em partida online.
  - Disponível em `build/LAVOICE-Lab-Evolucoes.exe`, aberto pelo `jogar.cmd`. Não foi aberta uma janela do jogo durante os testes.

- [x] **2. Combos entre criaturas**
  - Água deixa o alvo molhado temporariamente; eletricidade aproveita esse estado.
  - Cipós prendem o alvo temporariamente; fogo pode combinar com os cipós.
  - Reações aplicadas às criaturas, sem simulação ambiental no terreno.
  - Efeitos visuais claros, limites de dano e duração para impedir combinações infinitas.
  - Validar aliados, escudos, Infinito e efeitos online.
  - Concluída: água molha por 4 s; eletricidade consome o estado com bônus de 50%, limitado a 18 de dano. Cipós prendem por 1,6 s; fogo consome os cipós com bônus de 35%, limitado a 14 de dano.
  - Proteções: 2 s entre reações iguais por alvo; 6,6 s entre enraizamentos; sem renovar prisão, atingir aliados ou gerar reações em cadeia. Defesas reduzem o golpe inteiro, incluindo o bônus.
  - Validado: golpes reais, duração, limites, movimento terrestre e voo, captura, aliados, Infinito, adaptação, escudos e comandos com estados e efeitos sincronizados entre dois jogadores. Evoluções e domínios continuam passando nos testes.
  - Disponível em `build/LAVOICE-Lab-Combos.exe`, aberto pelo `jogar.cmd`. Instruções em [[Projetos/lavoice-lab/pokemon|Pokémon e combos]].

- [x] **3. Ordens para qualquer animal**
  - “Me siga”, “fique aqui”, “proteja minha casa”, “ataque aquele jogador”, “fuja das bombas” e “ataque só quem me atacar”.
  - Selecionar o animal pela mira ou pelo nome; indicar qual recebeu a ordem.
  - Respeitar equipe, dietas, captura e capacidades do animal.
  - Evitar percorrer todos os bichos a cada quadro; validar com muitas criaturas e online.
  - Concluída para as 99 espécies: seguir, ficar, proteger casa (inclusive ambulante), atacar jogador indicado, fugir de bombas, retaliar e voltar ao normal. Seleção pela mira ou pelo nome, com confirmação do animal escolhido.
  - Também concluído o pedido adicional: “quero um Mahoraga agressivo”, com modificador para qualquer criatura e comando “seja agressivo”. Procura alvos à frente, inclusive animais aliados, e poupa o treinador do dano direto de poderes e projéteis.
  - Validado: espécies, restrições de dono, dieta, armas montadas, voo, captura, retaliação, proteção do dono e atualização de ordens em um grupo de 80 animais. Ordens e estado sincronizados entre dois jogadores.
  - Disponível em `build/LAVOICE-Lab-Ordens.exe`, aberto pelo `jogar.cmd`. Guia: [[Projetos/lavoice-lab/animais-ordens|Ordens e animais construtores]].

- [ ] **4. Fusões com poderes combinados**
  - Combinar habilidades das partes doadoras, com regra clara para cada parte.
  - Exemplos: Pikachu com corpo de dinossauro; borboleta com habilidade do Squirtle.
  - Mostrar habilidades resultantes e somar seus custos.
  - Limitar combinações repetidas e preservar a fusão na captura e na evolução.

- [x] **5. Criaturas construindo coisas**
  - Formigas escavam túneis, castores constroem barragens e aranhas montam teias de armadilha.
  - Construções consomem matéria, levam tempo e têm limites de tamanho e frequência.
  - Respeitar blocos protegidos e interromper trabalhos quando a criatura morrer ou for capturada.
  - Validar construção e destruição sincronizadas na partida online.
  - Concluída por comando: formigas escavam terra por 0,3 de matéria por bloco; castores constroem barragens de 220 de vida em 4 s por 32 de matéria; aranhas constroem teias de 40 de vida em 2,5 s por 16 de matéria.
  - Limites: até 96 blocos por túnel, 192 por formiga e 512 por equipe; 2 barragens por castor e 6 por equipe; 3 teias por aranha e 8 por equipe. Recarga de 8 s entre trabalhos concluídos. Teias deixam os corpos atravessarem e reduzem a velocidade de inimigos para 35% por 1,2 s.
  - Validado: custo real, falta de matéria, blocos protegidos, limites, armadilhas contra inimigos, cancelamento por captura/morte/ordem nova, criação, progresso, remoção de terra e destruição em partida online.
  - Disponível em `build/LAVOICE-Lab-Ordens.exe`, aberto pelo `jogar.cmd`. O jogo não foi aberto em janela durante os testes.

- [ ] **6. Armas com efeitos criativos**
  - Raio que envelhece criaturas temporariamente.
  - Raio que troca cabeças entre criaturas.
  - Granada que inverte equipes por alguns segundos.
  - Definir alcance, recarga, custo e resistências; restaurar corretamente os efeitos temporários.
  - Evitar duplicar criaturas ou perder armas, equipe original e conteúdo de Pokébolas.

- [ ] **7. Personalidade e vínculo das criaturas**
  - Medo, confiança no treinador e proteção de companheiros.
  - Comando para cuidar da criatura e melhorar o vínculo.
  - Rejeição de ordens perigosas com indicação visível do motivo; evitar desobediência aleatória constante.
  - Preservar vínculo na captura e evolução; impedir que a personalidade quebre dietas e ordens explícitas.

- [ ] **8. Chefes de misturas em cooperação**
  - Primeiro chefe: T-Rex com asas de dragão e adaptação do Mahoraga.
  - Os dois jogadores enfrentam o chefe juntos, com vida e dificuldade ajustadas ao grupo.
  - Golpes anunciados, janelas para contra-atacar e recompensas limitadas.
  - Invocação controlada e validação de vitória, derrota e desconexão de um jogador.

## Regra de conclusão de cada etapa

- Implementar apenas a etapa atual, mantendo as demais pendentes.
- Verificar o comportamento principal, balanceamento e interação com captura e misturas.
- Verificar a partida online quando a etapa alterar ações ou estado de criaturas.
- Atualizar executável e instruções; então marcar a etapa como concluída e avançar.
