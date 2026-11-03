# Maneiras de atualizar o jogo

Implementado na v0.4.1: [iniciador próprio com Velopack](launcher/LEIA-ME.md), instalação do jogo pronto pelo GitHub, atualizações automáticas opcionais, integridade e preservação da versão anterior. A release principal contém apenas o instalador; os downloads auxiliares ficam separados. As opções abaixo são o histórico da comparação anterior à implementação.

## 1. Iniciador próprio usando GitHub Releases

Proposta recomendada para este projeto: abrir um iniciador pequeno que compara a versão instalada com um manifesto publicado junto da release, baixa as alterações, verifica integridade e as aplica com o jogo fechado. Depois abre o jogo, preservando configurações e saves. Pode haver opção de perguntar antes ou atualizar automaticamente.

O iniciador deve reutilizar os arquivos originais locais e não republicá-los. Como a entrega H-6 atual é um pacote de alterações de fonte, o fluxo ainda precisa automatizar a aplicação e a recompilação local; publicar no GitHub sozinho não atualiza instalações existentes. Uma evolução pode evitar baixar novamente voz e dependências que não mudaram.

## 2. Aplicativo itch.io com butler

O aplicativo itch.io gerencia as atualizações dos projetos instalados por ele. Butler permite publicar versões e atualizações incrementais. Quem baixa um ZIP diretamente pelo navegador não recebe esse mecanismo. Exige preparar a distribuição do pacote permitido e usar o aplicativo.

Fontes: [atualizações no aplicativo](https://itch.io/docs/itch/integrating/updates.html), [publicação com butler](https://itch.io/docs/butler/pushing.html).

## 3. Instalador com Velopack

Velopack fornece instalação e atualização de aplicativos, com suporte a fontes como GitHub Releases. Exige integrar o iniciador/atualizador, gerar os pacotes próprios do framework e preparar o fluxo de aplicação das alterações.

Fontes: [documentação do Velopack](https://docs.velopack.io/), [fontes de atualização](https://docs.velopack.io/integrating/update-sources).

Para começar, um botão “Atualização disponível” com aplicação controlada no iniciador é mais simples de testar. A atualização deve acontecer antes de abrir o jogo ou depois de fechá-lo, sem interromper partidas.
