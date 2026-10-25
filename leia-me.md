---
title: LAVOICE Lab - projeto recuperado e editavel
date: 2026-10-23
tags:
  - lavoice
  - godot
  - desenvolvimento
updated: 2026-10-24
---

# LAVOICE Lab

Projeto: [[Projetos/copia-de-jogo|LAVOICE Lab]] · Relacionado: [[Projetos/lavoice-lab/criatividade|Criatividade, colônias e defesas]] · [[Projetos/lavoice-lab/correcoes.txt|Correções e testes do jogo]] · [[Projetos/lavoice-lab/tarefas|Próximas melhorias do jogo]]

> [!info] Controles atuais
> **V** cria por voz; **B** recebe somente comandos, como “Squirtle, ataque”; **T** abre o console. Use `jogar.cmd` para iniciar a versão atual. As seções de recuperação abaixo registram também versões anteriores.

Atualização das correções: use `jogar.cmd` ou `build\LAVOICE-Lab-Criaturas-Inteligentes.exe`. A lista de problemas relatados e suas correções está em [[Projetos/lavoice-lab/correcoes.txt|correcoes.txt.md]]. Todos os participantes de uma partida online precisam usar a mesma versão corrigida.

## Atualizacao: Pacote Caos

62 criacoes novas: 30 animais, 12 granadas que liberam criaturas, 12 bombas especiais e 8 armas. **F2** abre o catalogo dentro do jogo, com nomes, pedidos e efeitos. A lista completa esta em [[Projetos/lavoice-lab/novidades|Pacote Caos e primeiras novidades]].

A formiga foi refeita em blocos, e os novos animais receberam animacoes simples. Entre as adicoes estao granadas de formigas e galinhas, bombas nuclear, de neutrons, de gravidade e antigravidade, singularidade, meteoros, e a faca que corta o espaco. A versao anterior do executavel esta em `backups/before-chaos`.

Tenha materia, fale o pedido com V, aguarde a montagem e clique para usar/arremessar. O teste de voz usa audio sintetizado; a compatibilidade do microfone fisico continua sujeita as configuracoes do computador.

Base editavel recuperada da instalacao `F:\Games\LAVOICE`, com codigo, cenas, modelos, animacoes, sons, interface, dados, bot e sistemas de voz e multiplayer. O objetivo definido pelo usuario e preservar o jogo e permitir novas adicoes. A instalacao original nao foi modificada.

## Adicao: formiga

Em 2026-10-23 foi adicionada a criatura `ant`. Com materia disponivel, segure a tecla de criacao (V por padrao), diga **quero uma formiga** e solte. O console de texto aceita o mesmo pedido. Tambem reconhece **formiguinha**, **sauva** e os plurais, incluindo **quero tres formigas**. Modificadores existentes, como **formiga gigante**, continuam disponiveis.

O modelo tem cabeca, torax, abdomen, cintura, seis patas, duas antenas, olhos e mandibulas. Usa o movimento terrestre de perseguir inimigos das outras criaturas do jogo e a economia normal de materia. Arquivo visual: `game/data/models/ant.json`; cadastro, palavras e balanceamento estao nos respectivos catalogos. As novas palavras entram automaticamente nas hotwords do reconhecedor.

Verificado no projeto e na build: pedido de uma formiga, montagem, gasto de materia, modelo completo e deslocamento de aproximadamente 0,85 m em um segundo de teste. O executavel atualizado reconheceu a fala sintetizada **Quero uma formiga.** e criou a criatura. Evidencias em `analysis/ant-*`. O lexico atualizado tem 1.469 expressoes; o projeto tem 220 JSONs.

## Abrir

- **Jogar:** abra `jogar.cmd`, ou `build\LAVOICE-Lab-Jujutsu.exe`.
- **Editar:** abra `editar.cmd`. O editor Godot 4.7.2 ja esta em `tools\godot`.
- **Gerar outra versao depois de editar:** abra `recompilar.cmd`.
- **Projeto:** `game\project.godot`.
- **Preferencias, logs e saves da copia:** `%APPDATA%\LAVOICE-Lab`.

Mantenha as pastas `voice`, `licenses`, `x86_64` e as DLLs junto do executavel ao mover a build. O primeiro carregamento pode demorar para preparar os shaders. Para distribuir uma pasta completa, copie `build` inteira; o arquivo `.pck` separado e intermediario da recompilacao, pois o executavel tambem o contem.

## Onde adicionar coisas

| Parte | Caminho dentro de game |
| --- | --- |
| Cena da partida e regras | `scenes/main.gd`, `scenes/main.tscn` |
| Movimento e controles | `scenes/player/` |
| Robo, rig e animacao | `scenes/player/robot/`, `assets/characters/lavoice/` |
| Modelo com 137 animacoes | `assets/characters/lavoice/LAVOICE_base.glb` |
| Catalogo de objetos | `data/defs/`, `data/models/` |
| Palavras e frases em portugues | `data/lexicon/pt_br/` |
| Interpretacao dos pedidos | `scripts/language/` |
| Montagem de criacoes | `scripts/autoload/forge.gd`, `scripts/things/` |
| Mapas e terreno | `scenes/arena/`, `scripts/world/`, `data/world/` |
| Bot | `scripts/bot/`, `data/lexicon/pt_br/bot.json` |
| Menus e HUD | `scenes/menu/`, `scenes/ui/`, `scenes/intro/` |
| Reconhecimento e conversa por voz | `scripts/voice/`, `data/voice.json`, `voice/` |
| Multiplayer | `scripts/network/`, `data/network.json` |
| Balanceamento | `data/balance.json` |

Ao substituir o modelo GLB, atualize `glb_sha256` em `assets/characters/lavoice/validacao.json` com o SHA-256 do novo arquivo. O proprio jogo verifica isso antes de abrir conexoes. Jogadores devem usar a mesma build e os mesmos dados.

## Recuperacao

- Pacote embutido Godot formato 4, engine 4.7.2, com 761 entradas verificadas por checksum.
- REA 6.7.0 usado para inspecao inicial do executavel; essa versao publicada nao abriu o pacote embutido. A documentacao atual do REA tambem informa que sua leitura de PCK nao descriptografa nem decompila GDScript.
- Inspecao local do pacote e GDRE Tools 2.7.4 recuperaram 160 scripts GDScript, 264 recursos convertidos, 10 cenas textuais e 219 arquivos JSON. O modelo recuperado tem 137 animacoes, 35 meshes e um skin.
- `recovered` guarda a recuperacao inicial sem as adaptacoes da copia de trabalho. O relatorio original esta em `recovered\gdre_export.log`.
- `game` e a copia para editar. Nenhum dos 160 scripts de gameplay foi alterado durante a preparacao. Foram alterados o diretorio de dados do usuario em `project.godot` e o checksum do modelo recuperado em `validacao.json`; foram acrescentados o preset de exportacao e testes.
- `tools\runtime` guarda a parte de engine do executavel recebido e suas dependencias. A recompilacao usa essa mesma engine, com um novo pacote exportado a partir do projeto editavel.
- Os 36 componentes externos verificados contra o manifesto original, incluindo modelos de voz, bibliotecas e creditos, coincidiram em SHA-256.

## Verificacoes e limites

- Carregamento dos 160 scripts, 10 cenas e 219 JSONs; lexico com 1.461 expressoes e seis pedidos de criacao reconhecidos.
- Importacao e inicializacao de uma copia limpa, sem o cache de importacao recuperado.
- Executavel recompilado: treino, criacao de pistola, duelo, criacao de espada e atividade do bot.
- Reconhecedor offline: audio sintetizado em portugues, transcricao `Quero uma pistola.`.
- Duas instancias locais: autenticacao ENet, lobby, cores, pronto, voto de arena, entrada na partida e troca de snapshots de movimento.
- Evidencias, screenshots e resultados ficam em `analysis`. Identidade da build em `build\build-receipt.json`.

Essa recuperacao fornece a base real do jogo, mas nao comprova equivalencia integral de todas as situacoes. O GDRE marcou 81 conversoes como com perda porque os recursos foram recuperados de formatos exportados. Comentarios e formatacao originais do codigo nao foram recuperados. Nao foram testados todos os 137 clips individualmente, quatro jogadores, conexao entre PCs distantes ou microfone fisico. Steam nao estava disponivel na distribuicao recebida; o transporte testado foi ENet, como descrito no LEIA-ME original.

## Fontes das ferramentas

- [REA](https://github.com/morluto/rea)
- [Limites do REA para Godot PCK](https://github.com/morluto/rea/blob/main/docs/godot-pck.md)
- [GDRE Tools 2.7.4](https://github.com/GDRETools/gdsdecomp/releases/tag/v2.7.4)
- [Godot 4.7.2](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)

Contexto do vault: [[copia-de-jogo]], [[rea]], [[tony]].

## Atualização de criatividade

O executável inclui 76 criações novas, combinações de armas e criaturas, casa ambulante, campos de proteção especializados e colônias com predadores. Consulte [[Projetos/lavoice-lab/criatividade|criatividade.md]] e a aba COMBINAR do F2. A bomba de nêutrons agora remove blocos reais e faz uma cratera próxima.
