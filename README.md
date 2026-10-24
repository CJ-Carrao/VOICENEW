# VOICENEW

Jogo de criatividade por voz para Windows, desenvolvido a partir do projeto LAVOICE Lab. Crie animais, armas, construções e habilidades, misture suas partes e dê comandos aos companheiros.

## Baixar e jogar

1. Abra [Releases](https://github.com/CJ-Carrao/VOICENEW/releases/latest).
2. Baixe o arquivo **VOICENEW-Windows.zip**.
3. Extraia o ZIP inteiro e abra **jogar.cmd** dentro da pasta **VOICENEW**.

Mantenha as pastas de voz, licenças e bibliotecas junto do executável. O pacote inclui os modelos necessários ao reconhecimento de voz offline. O repositório é privado: é preciso ter acesso para baixar os arquivos.

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

## Créditos

Créditos da base LAVOICE, engine, bibliotecas, fontes e reconhecimento de voz em [game/CREDITOS.txt](game/CREDITOS.txt). As licenças das dependências também acompanham a versão para jogar.
