# VOICENEW

**Base local atual: H-4 oficial**, priorizando os recursos originais e preservando as adições do Lab. Abra `jogar.cmd` ou `build/H4-Lab/LAVOICE-Lab-H4-v28.exe`. [Integração, testes e limites](atualizacao-h4.md). A versão **v0.3.2** reúne a base H-4 e nossas adições; baixe o pacote completo nas Releases. A IA local de interpretação ainda é um protótipo separado e não está ativada no jogo.

Jogo de criatividade por voz para Windows, desenvolvido a partir do projeto LAVOICE Lab. Crie animais, armas, construções e habilidades, misture suas partes e dê comandos aos companheiros.

## Baixar e jogar

1. Abra [Releases](https://github.com/CJ-Carrao/VOICENEW/releases/latest).
2. Baixe o arquivo **VOICENEW-Windows.zip**.
3. Extraia o ZIP inteiro e abra **jogar.cmd** dentro da pasta **VOICENEW**.

Mantenha as pastas de voz, licenças e bibliotecas junto do executável. O pacote inclui os modelos necessários ao reconhecimento de voz offline. O repositório e os downloads são públicos.

## Limite e escolha de alvo

Cada jogador pode ter **até 30 animais vivos**, incluindo capturados e os gerados por armas ou ninhos. Ao atingir o limite, novas criações de animais são bloqueadas; remover ou perder um animal libera uma vaga. Pedidos em grupo que ultrapassem o limite são recusados antes da cobrança.

- Pelo **V**: “quero pombos que só ataquem o jogador 4”.
- Pelo **B**: “pombos ataquem só o jogador 3”.

Comandos adicionais pelo **B**, somente para os seus animais:

- “mate todos os animais” — elimina todos os seus animais vivos, inclusive capturados.
- “mate todos os elefantes” — elimina só os seus elefantes.
- “quero que todos os elefantes se explodam” — sacrifica os seus elefantes com explosões proporcionais ao tamanho.
- “quero que todos os animais se explodam” — faz o mesmo com todas as suas espécies.

A seleção é por dono; explosões causam dano normal ao redor e destroem blocos. As detonações são distribuídas no tempo para respeitar o orçamento de efeitos.

Vale para todas as espécies e para jogadores de 1 a 4. A criatura ignora outros jogadores e animais; se o alvo estiver ausente ou morto, aguarda sem escolher outra vítima. Não pode atacar o próprio treinador. Todos na partida precisam da mesma versão.

## Controles principais

| Tecla | Ação |
| --- | --- |
| V, segurando | Pedir uma criação por voz |
| B, segurando | Dar comandos por voz, sem criar itens |
| T | Abrir console de texto |
| E | Pegar um item do chão |
| G | Soltar o item equipado |
| Clique esquerdo | Usar arma, habilidade ou arremessar |
| F2 | Consultar o catálogo de criações |

Exemplos: “quero um cachorro com cara de tiranossauro rex”, “quero um Pikachu” e, depois, pelo B, “Pikachu, choque do trovão”. Para usar o Vazio Infinito, crie e equipe a técnica e dê o comando “expansão de domínio”.

## Conteúdo desta versão

- Animais e dinossauros com misturas de cabeça, corpo, patas, asas e cauda.
- Brainrots em blocos, quatro Pokémon e oito golpes por comando.
- Pokébolas, captura com possibilidade de rejeição e recuperação de itens do chão.
- Armas, bombas, defesas, colônias e dietas seletivas.
- Mahoraga, Infinito, técnicas do Gojo e Sukuna e expansões de domínio.
- Vazio Infinito com esfera fechada, interior cósmico e paralisia de inimigos; Santuário Malevolente com altar e cortes na área.
- Evoluções dos Pokémon por experiência de combate e matéria, com comandos como “Pikachu, progresso” e “Pikachu, evolua”.
- Combos entre criaturas: água com eletricidade, cipós com fogo e prisão temporária com proteção contra aprisionamento contínuo.
- Ordens para todos os animais, modo agressivo que poupa o treinador, formigas escavando, castores construindo barragens e aranhas montando teias.
- Ordens coletivas como “cachorros me sigam”, adaptação progressiva do Mahoraga e reversão de feitiço para cura.
- Raios do Ryu e Yuta com disputa de feixes, Verity e revisão dos golpes de Black Flash, Cleave, Dismantle e Fuga.
- Clash de domínios com anulação dos acertos na área sobreposta, vitória ou empate e quebra das barreiras.
- Espada espacial com fenda curva próxima, passagem pelo Infinito e corte real dos blocos.
- Fusões com poderes herdados, raio de envelhecimento, troca temporária de cabeças e granada de inversão de equipe.
- Confiança e medo das criaturas, cuidado e proteção de companheiros.
- Chefe cooperativo com aceite dos participantes, aliança temporária, golpes anunciados e recompensa limitada.
- Defesa automática do treinador e retaliação ao agressor, transporte de companheiros e torres, reparos por formigas e ordens condicionais.
- Transformações com pouca vida que preservam armas e poderes; escudos que convertem tiros em borboletas, com energia limitada.
- Partidas online. Todos os participantes precisam usar a mesma versão.

## Código e documentação

O projeto Godot fica em [game/project.godot](game/project.godot). O executável e os modelos grandes de reconhecimento de voz são distribuídos em Releases; caches, backups e resultados temporários ficam fora do Git.

Para editar ou recompilar, é necessário preparar a engine e as dependências locais usadas pelos scripts; elas não vêm no clone do repositório. Consulte o [guia do projeto](leia-me.md).

- [Pokémon e comandos](pokemon.md)
- [Jujutsu e domínios](jujutsu.md)
- [Captura e itens](captura.md)
- [Dinossauros e misturas](dinossauros.md)
- [Brainrots](brainrots.md)
- [Criatividade, defesas e colônias](criatividade.md)
- [Ordens e animais construtores](animais-ordens.md)
- [Próximas tarefas](tarefas.md)
- [Fusões, armas criativas, vínculo e chefes](criatividade-completa.md)
- [Equipes, regras por voz, defesa automática e transformações](taticas-criaturas.md)

## Créditos

Créditos da base LAVOICE, engine, bibliotecas, fontes e reconhecimento de voz em [game/CREDITOS.txt](game/CREDITOS.txt). As licenças das dependências também acompanham a versão para jogar.
