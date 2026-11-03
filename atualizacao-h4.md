---
title: Atualização original H-4 no LAVOICE Lab
date: 2026-10-27
updated: 2026-11-03
publicacao: github-v0.3.2
tags:
  - lavoice
  - atualizacao
status: pesquisando
integracao: validada-localmente
---

# H-4 como base atual

Projeto: [[Projetos/copia-de-jogo|LAVOICE Lab]] · [[Projetos/lavoice-lab/leia-me|Guia]]

Em 27/10/2026, o usuário pediu priorizar a atualização original. A base atual é a H-4 oficial, com nossas adições integradas por comparação entre a recuperação anterior, o Lab e a nova versão. Em conflitos de conteúdo original, os modelos e comportamentos novos tiveram prioridade.

Abra `C:\Tony\Projetos\lavoice-lab\jogar.cmd`, que aponta para `build/H4-Lab/LAVOICE-Lab-H4-v28.exe`. Ao mover o jogo, copie a pasta **H4-Lab inteira**, incluindo voz, licenças e bibliotecas. O atalho `Jogar VOICENEW.lnk` também foi atualizado. O jogo não foi aberto com janela nesta etapa.

## Preservado e integrado

- 172 modelos da H-4, incluindo 35 com rig, e as 137 animações originais do personagem. O esqueleto original foi preservado em `game/assets/characters/lavoice/LAVOICE_base.native.scn`; o GLB recuperado permanece como referência editável.
- Animações de caminhada oficiais têm prioridade; movimento antigo fica como alternativa para criaturas extras sem rig. Captura, evolução e remontagem não duplicam animadores.
- Bombas oficiais, portais, diagnóstico de voz e destruição em ondas com crateras e limites de trabalho da H-4. Camadas de colisão de armadilhas e portais foram separadas.
- Pokémon, dinossauros, misturas, Jujutsu, captura, colônias, ordens pelo B, equipes, transporte, transformações e demais adições do Lab preservados. Bombas por espécie agora reconhecem todas as 100 espécies públicas verificadas.
- **“Quero uma bomba nuclear”** usa a bomba oficial H-4. A versão anterior continua disponível como **“bomba nuclear do lab”**. Também existem Little Boy, Fat Man e Tsar Bomba oficiais.

## Verificações e limites

Importação, exportação e carregamento do pacote embutido no EXE passaram. Testes sem janela verificaram modelos oficiais por hash, animações, interpretação em português/inglês, crateras incrementais, bombas em multidões, captura, evolução, combos, domínios, ordens e táticas. Rede local com duas instâncias verificou lobby, criação de partida e replicação das táticas, inclusive usando o pacote exportado. A bomba atômica oficial também foi testada contra 64 criaturas agrupadas: nenhuma sobrevivente e nenhum erro no teste. Evidências em `analysis/h4-*.log` (arquivos locais ignorados pelo Git).

Protocolo do Lab: **24 / voicenew-h4-lab-28**. Todos na partida precisam desta mesma versão modificada. Compatibilidade com APK oficial, Steam, internet entre PCs e microfone físico não foi validada; não presumir crossplay oficial. Inspeção visual em partida ainda depende de teste do usuário.

A IA local de interpretação continua **protótipo separado**, sem opção no menu nem integração ao EXE. O resultado 70/74 registrado em [[Projetos/lavoice-lab/ia-local|IA local]] pertence à base anterior; exige revalidação na H-4.

## Origem, preservação e publicação

- [Página oficial](https://tsomyst.itch.io/lavoice) e [anúncio H-4](https://tsomyst.itch.io/lavoice/devlog/1733033/lavoice-h-4-atomic-bombs-rebuilt-models-more).
- ZIP Windows conferido: 546.328.641 bytes; SHA256 `bf826853c6089b3a0bb05363ccde8ec4128966e2716b479eec690436b243f52b`. Proveniência e hashes dos modelos em `game/data/upstream_h4_manifest.json`.
- Download, recuperação e candidato mantidos fora do cofre: `C:\Users\Calebe PC\Documents\VOICENEW-Upstream-H4`. Não são dependências para executar a build.
- Instalação original `F:\Games\LAVOICE` preservada. Código anterior na referência Git local `backup/pre-h4-20261027`; EXE antigo `build/LAVOICE-Lab-Criaturas-Inteligentes.exe` mantido.
- EXE da primeira integração H-4 (preservado como `LAVOICE-Lab-H4.exe`): 121.939.224 bytes; SHA256 `c6fb0cbd73786fe776a01d45331c43872824057771f5008401a52b51eb3f9d6f`. Recibo de empacotamento ao lado do executável.
- **Sem commit, push ou release nesta etapa**. O GitHub continua com a versão anterior; esta integração está pronta localmente.

- [x] Integrar H-4 com prioridade aos originais e preservar extensões.
- [x] Gerar executável e atualizar lançadores.
- [x] Validar recursos, explosões e rede local sem abrir a janela do jogo.
- [ ] Conferir visualmente com o usuário e testar microfone/rede entre PCs.
- [x] Publicar a H-4 no GitHub quando solicitado — v0.3.0 em 02/11/2026.


## Extensões adaptadas à H-4 — 27/10/2026

Segundo pedido do usuário: aplicar os recursos novos também às nossas criações. Atualizados **26 modelos**: 12 bombas especiais, bomba por espécie, 12 granadas de criaturas e granada de troca de equipe. Usam as silhuetas originais da bomba atômica/granada H-4, com acabamento e identificação de cores próprios. Modelos oficiais permanecem intactos; efeitos, custos, proteções e funções das variantes foram preservados.

O alcance de efeitos especiais agora inclui todas as criações dentro da esfera, inclusive multidões acima do limite de 128 resultados da física e corpos recém-criados antes da sincronização. Dano especial de nêutrons, eletricidade, gelo e gravidade entra na fila limitada por quadro usada pelas explosões, preservando a bomba até acabar o trabalho. Raios visuais da tempestade têm orçamento de 12; todos os alvos recebem o efeito. A nuclear do Lab usa crateras em ondas da H-4, sem duplicar seu efeito de cogumelo. A animação alternativa das criaturas extras agora pausa quando capturadas ou paralisadas, acompanhando o comportamento das animações oficiais.

Teste específico passou com **150 criaturas por bomba**, nas quatro variantes de dano especial: nêutrons, tempestade, gelo e gravidade. Todos os 600 alvos foram processados; criaturas fora do alcance e aliados dos efeitos seletivos sobreviveram. Os 26 modelos foram montados e receberam limites físicos válidos. Testes de captura/animação, nuclear com 160 alvos, bomba por espécie, táticas e integridade da H-4 também passaram. Esses testes não substituem inspeção visual do usuário.

Executável da etapa de bombas (agora anterior): `build/H4-Lab/LAVOICE-Lab-H4-Atualizado.exe`, 122.009.512 bytes, SHA256 `25d332e898009faf75cc96fc1ed7d1635bcd3fee7f905d7bc848e1562971dcb8`. `jogar.cmd` e o atalho apontam para ele. O usuário estava jogando o EXE anterior: o processo foi preservado; as alterações entram na próxima abertura pelo atalho. Gameplay `voicenew-h4-lab-25`, protocolo RPC 24; ambos os jogadores precisam da nova build. Sem IA local integrada e sem publicação no GitHub nesta etapa.


## Criaturas, arsenal e interações — 27/10/2026

Após o usuário perguntar pelo restante, a revisão foi estendida ao catálogo:

- **Animação:** 101 criaturas verificadas (100 públicas + chefe privado), com 35 rigs originais preservados e 66 rigs extras adaptados ao `CreatureAnimator` da H-4. A forma original dos extras foi mantida; pernas recebem articulações e fases de passada, asas compartilham pivôs, e cabeça/olhos/boca se movem juntos. Verity e criaturas sem membros ganham oscilação discreta. A casa ambulante também usa quatro pernas articuladas, com passeio e desvio de parede validados.
- **Misturas:** o rig é reconstruído sobre a geometria final, evitando olhos, pés ou cabeça de outro animal ficarem soltos. Evolução, troca de cabeça e transformação refazem o animador sem duplicá-lo. Verificados Pokémon, 10 brainrots, 30 misturas deles, 32 seções de dinossauros e híbridos entre elefante/cachorro/trex.
- **Arsenal:** mais 11 modelos adaptados ao arsenal oficial: faca espacial, martelos de gravidade/trovão, machado de gelo, espada de fogo, três lançadores de criaturas, projetor de escudos, raio de envelhecimento e de troca de cabeça. Posições de empunhadura e saída herdadas das bases oficiais; cores distinguem as funções. Custos e definições de ataques preservados.
- **Defesas:** as quatro bombas atômicas oficiais agora são reconhecidas como ameaça nuclear pelos escudos do Lab, sem alterar as definições originais. Resistência efetiva de um escudo nuclear testada por dano real.
- **Poderes:** o Vermelho deixou de descartar alvos após 16 criaturas; teste com 32 alvos terminou sem sobreviventes. Alcance de cratera alinhado ao dano de quatro metros. Cortes espaciais consideram o volume mundial de estruturas giradas. Vazio Roxo, buracos negro/branco, colisões, domínios e técnicas passaram pelos testes existentes; não foram redesenhados como modelos genéricos.

Validação final sem janela: catálogo/rigs, armas, escudos, cortes e Vermelho também passaram usando o **EXE exportado**. Captura/rejeição, sete evoluções, transformações, táticas, progresso, poderes espaciais, fidelidade dos ataques JJK e clash de domínios passaram. Teste de rede com duas instâncias do novo EXE concluiu lobby e partida com replicação de táticas. Integridade dos 172 modelos oficiais e 137 animações preservada. Registros locais em `analysis/h4-rest-*.log`; eventual falha inicial do Verity foi corrigida antes do empacotamento. Testes automatizados não são aprovação visual do usuário nem medição de FPS com multidões.

**Build atual:** `build/H4-Lab/LAVOICE-Lab-H4-v26.exe`, 122.048.244 bytes; SHA256 `a699816923a4dcc152527cc943b9517c429278195eddc93db593269276a7713f`. Lançadores e recompilação apontam para ela; builds anteriores preservadas. Gameplay `voicenew-h4-lab-26`, protocolo RPC 24. Todos no online precisam desta versão. Nenhuma janela do jogo foi aberta, e nenhuma release foi publicada. IA local continua fora do jogo/menu.


## Publicação confirmada — 02/11/2026

A pedido do usuário, código enviado à `main` e pacote Windows publicado como **v0.3.0**, marcado como release mais recente. Os registros anteriores de ausência de publicação descrevem as etapas de 27/10; este é o estado atual confirmado.

- [Release v0.3.0](https://github.com/CJ-Carrao/VOICENEW/releases/tag/v0.3.0) · [Baixar o jogo completo](https://github.com/CJ-Carrao/VOICENEW/releases/download/v0.3.0/VOICENEW-Windows.zip).
- Commit do código da build: `91693734f03e77debf4bc06a3464c1d796a8b675`.
- ZIP: 564.034.400 bytes, 34 entradas; SHA256 `a234b41ff9d0ee60f3403db23d80c6a661de9789b3f874c51e7b6553c93153f8`. Arquivo `SHA256SUMS.txt` publicado junto. Tamanho e digest retornados pelo GitHub conferidos com o pacote local, e release consultada sem autenticação.
- Inclui EXE v26, voz offline, licenças e bibliotecas; não inclui modelos GGUF ou ativação da IA experimental. Ferramentas e relatório do protótipo estão no código-fonte, separados da integração do jogo.
- EXE conferido pelo recibo e teste automatizado repetido em 02/11: 101 criaturas animadas, 11 armas, quatro bombas nucleares, Vermelho com 32 alvos e corte em estrutura girada, sem falhas. ZIP validado por CRC. Sem abrir o jogo com janela.
- `Jogar VOICENEW.lnk` (atalho local) e `Novo(a) Documento de Texto.txt` (nota do usuário) ficaram fora do envio. Instalações, ferramentas binárias, caches, modelos de IA e arquivos privados de análise também não entraram no Git.

Extraia o pacote inteiro e execute `VOICENEW/jogar.cmd`. Todos os participantes online precisam desta build. Permanecem pendentes avaliação visual, microfone físico e rede entre PCs.


## Limite de animais e jogador escolhido — 02/11/2026

Pedidos adicionais do usuário: reduzir o acúmulo de criaturas e permitir escolher o jogador que elas atacam.

- **30 animais vivos por jogador**, somando espécies, criações em montagem, criaturas equipadas/montadas, capturadas e descendentes de armas, granadas, invocações e ninhos. Pedidos em grupo passam por conferência antes de cobrar matéria; não criam parcialmente um grupo acima da capacidade. Animais removidos/mortos liberam vaga. Armas e projéteis sem animais continuam utilizáveis.
- Transferência de dono, captura e coleta de Pokébola cheia respeitam a capacidade de destino. Encantamento temporário reserva a vaga de retorno no dono anterior para evitar gerar criaturas neutras por falta de espaço.
- **V:** “quero pombos que só ataquem o jogador 4”. **B:** “pombos ataquem só o jogador 3”. Valem números e nomes por extenso de 1 a 4, para todas as espécies; não escolhem outro alvo se o jogador estiver ausente/morto. O próprio treinador é protegido.
- A seleção acompanha deslocamento, mordidas, armas montadas e descendentes. É persistida nas ordens e replicada pelo servidor; outros animais e jogadores não recebem dano desses ataques.
- Testes: 400 frases (100 espécies × quatro jogadores), recusa do 31º sem gasto, grupos, geração por arma/invocação, liberação de vaga, donos independentes, captura/transferência e herança do alvo. Captura, ordens coletivas, progressão, construtores e aviões passaram. Duas instâncias reais verificaram recusa do pedido remoto e sincronização do alvo em 30 criaturas.

Build v27: `build/H4-Lab/LAVOICE-Lab-H4-v27.exe`, gameplay `voicenew-h4-lab-27`, protocolo 24. Limitar animais reduz uma fonte de carga; não houve medição de FPS ou garantia de ausência de lag. Nenhuma janela aberta nesta etapa. O patch é distribuído como v0.3.1; ver confirmação de publicação abaixo.


### Publicação do limite e alvos confirmada

[Release v0.3.1](https://github.com/CJ-Carrao/VOICENEW/releases/tag/v0.3.1) publicada em 02/11/2026 e conferida como mais recente sem autenticação. Código da build: `dcfc68c824b8bf3bd985eb7411b6b7a12bcf6442`. ZIP Windows completo com 564.040.291 bytes; SHA256 `8f6bd737a780ef8685802ca53d80edd6a27b90c481b0b8595f396f379b18be52`, confirmado no GitHub. EXE v27: 122.054.816 bytes, SHA256 `da5a8723004cb11d0a8631df4dfe86a370ae8338b9e438c1c50ce7c7efa186a7`.

A bateria de limite/alvos passou também no executável exportado. Duas instâncias desse mesmo pacote confirmaram recusa do 31º animal remoto e propagação da ordem para 30 formigas. Lançadores locais atualizados. Todos devem usar v0.3.1 (gameplay 27); a v0.3.0 é histórica. Sem IA integrada e sem abertura de janela nesta etapa.


## Eliminar ou explodir os próprios animais — 03/11/2026

Pedido do usuário implementado com comandos por B (também aceitos pelo console e pelo caminho normal de voz):

- “mate todos os animais” / “elimine todos os meus bichos”.
- “mate todos os elefantes”.
- “quero que todos os elefantes se explodam” / “exploda todos os elefantes”.
- “quero que todos os animais se explodam”.

A seleção é sempre **dos animais do jogador que falou**, em todo o mapa, incluindo criaturas montadas, capturadas e em montagem. Filtro por espécie usa a identidade atual da criatura, não apenas sua cabeça misturada. Animais inimigos e chefes privados não são selecionados. A operação ignora a resistência/Infinito dos próprios animais porque é uma ordem de descarte, e libera suas vagas no limite de 30. Uma segunda operação do mesmo dono aguarda o término da anterior; atores pendentes param de produzir/atacar.

Na detonação, raio e dano são calculados pelas dimensões físicas já escaladas da criatura, incluindo tamanho, largura/altura e ajustes de enxerto. Limites: raio 0,75–8 m e dano 8–130. Usa explosão/crateras reais da H-4, com desgaste de escudos e regras normais de combate; **a explosão pode causar dano colateral**, embora o comando não selecione animais dos outros. Para capturados, o ponto da explosão é a Pokébola. Fontes e seus pais são retidos até concluir a fila para uma morte em cadeia não apagar detonações pendentes. Trabalho por quadro limitado e máximo nativo de seis explosões por segundo por jogador preservado; 30 animais detonam em sequência.

Validação sem janela: 200 frases (100 espécies × matar/explodir), variantes naturais, preservação da bomba seletiva original, seleção por dono/espécie, capturados, liberação de vagas, tamanho pequeno/grande, 30 detonações completas e enxerto sobrevivendo à remoção do pai. Passou no EXE exportado. Captura e limites/alvos anteriores passaram novamente. Duas instâncias reais do novo EXE validaram comando remoto, remoção das 30 criaturas e 30 explosões concluídas no servidor. Microfone físico, FPS e rede entre PCs não medidos.

Build: `build/H4-Lab/LAVOICE-Lab-H4-v28.exe`; gameplay 28, protocolo 24. Recibo e pacote atualizados; lançadores mantêm a abertura manual. Patch distribuído como v0.3.2; confirmação de publicação registrada abaixo.


### Publicação dos comandos de descarte confirmada — 03/11/2026

[Release v0.3.2](https://github.com/CJ-Carrao/VOICENEW/releases/tag/v0.3.2) publicada e conferida sem autenticação como mais recente. Código da build `e0655ed60f0b661192f66fe60085654534a12b75`. ZIP Windows completo: 564.045.517 bytes, SHA256 `8a528f35f14a4d74442b10a3522eb5a19445ff26bfef70db164a0d327b9aaa7d`, igual ao digest retornado pelo GitHub. EXE v28: 122.060.704 bytes, SHA256 `68b7e1d5a1e7ff79b92905e9941404df54a7bf382795341ff1964b044530531a`.

Testes do pacote e rede local passaram, incluindo comando remoto pelo B e 30 explosões efetivamente executadas no servidor. Atalho e `jogar.cmd` apontam para v28; todas as pessoas da partida precisam atualizar. Builds e releases anteriores preservadas como histórico. Sem abertura de janela e sem mudança na IA local, que continua fora do jogo.
