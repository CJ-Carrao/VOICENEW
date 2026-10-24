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

Ordem de implementação: uma etapa por vez. Cada etapa só será marcada como concluída depois de implementada, testada e incluída no executável. Progresso inicial: **0 de 8 etapas concluídas**.

**Fora desta etapa:** ambiente reagindo automaticamente a elementos e modo laboratório. Não abrir o jogo automaticamente; validar sem janela.

- [ ] **1. Evoluções durante a partida**
  - Experiência por participação em combate, sem contar ataques a aliados ou criações próprias como experiência gratuita.
  - Linhas: Pikachu → Raichu; Charmander → Charmeleon → Charizard; Squirtle → Wartortle → Blastoise; Bulbasaur → Ivysaur → Venusaur.
  - Evolução exige experiência e matéria, com confirmação por comando de voz; mostrar requisitos quando faltar algo.
  - Preservar dono, equipe, proporção de vida, misturas, armas, poderes e recargas. Captura preserva experiência e evolução.
  - Modelos em blocos para cada evolução; Charizard com voo.
  - Validar evolução, custo, preservação de modificações e sincronização online.

- [ ] **2. Combos entre criaturas**
  - Água deixa o alvo molhado temporariamente; eletricidade aproveita esse estado.
  - Cipós prendem o alvo temporariamente; fogo pode combinar com os cipós.
  - Reações aplicadas às criaturas, sem simulação ambiental no terreno.
  - Efeitos visuais claros, limites de dano e duração para impedir combinações infinitas.
  - Validar aliados, escudos, Infinito e efeitos online.

- [ ] **3. Ordens para qualquer animal**
  - “Me siga”, “fique aqui”, “proteja minha casa”, “ataque aquele jogador”, “fuja das bombas” e “ataque só quem me atacar”.
  - Selecionar o animal pela mira ou pelo nome; indicar qual recebeu a ordem.
  - Respeitar equipe, dietas, captura e capacidades do animal.
  - Evitar percorrer todos os bichos a cada quadro; validar com muitas criaturas e online.

- [ ] **4. Fusões com poderes combinados**
  - Combinar habilidades das partes doadoras, com regra clara para cada parte.
  - Exemplos: Pikachu com corpo de dinossauro; borboleta com habilidade do Squirtle.
  - Mostrar habilidades resultantes e somar seus custos.
  - Limitar combinações repetidas e preservar a fusão na captura e na evolução.

- [ ] **5. Criaturas construindo coisas**
  - Formigas escavam túneis, castores constroem barragens e aranhas montam teias de armadilha.
  - Construções consomem matéria, levam tempo e têm limites de tamanho e frequência.
  - Respeitar blocos protegidos e interromper trabalhos quando a criatura morrer ou for capturada.
  - Validar construção e destruição sincronizadas na partida online.

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
