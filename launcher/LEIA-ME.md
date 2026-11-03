# Iniciador VOICENEW

Na [release mais recente](https://github.com/CJ-Carrao/VOICENEW/releases/latest), baixe **VOICENEW-Instalar.exe**. Instale, abra o VOICENEW e clique em **Instalar jogo**. O iniciador baixa o jogo completo do nosso GitHub e confere o tamanho e SHA-256 antes de ativá-lo. Não precisa de Python, Godot, login ou chave de API.

**LAVOICE por Tsomyst — Somyst Game Studio.** Crédito clicável no rodapé, com link para [o jogo original](https://tsomyst.itch.io/lavoice). Os créditos e licenças do jogo permanecem no pacote. As alterações VOICENEW são um projeto separado do lançamento oficial.

## Uso

- Jogar abre apenas o jogo instalado; instalar/atualizar nunca inicia uma partida.
- Atualizar automaticamente ao abrir fica ativado. A primeira instalação começa pelo botão Instalar jogo.
- A atualização aguarda o jogo ser fechado. Uma falha preserva a versão instalada.
- Configurar permite apontar para um EXE já existente.
- Abrir pasta mostra a versão ativa. Dados do iniciador ficam em `%LocalAppData%/VOICENEW-Data`; as configurações do jogo permanecem em sua localização habitual.
- A versão anterior permanece no disco. `versao-anterior.json` registra seu caminho; é possível selecioná-lo em Configurar.

## Publicação

A release principal contém **somente VOICENEW-Instalar.exe**, além dos arquivos de código-fonte que o próprio GitHub mostra. A pré-release `componentes-v041` guarda os downloads usados pelo iniciador: jogo completo, manifesto `game-update.json`, pacotes Velopack e `releases.win.json`. Ela é pública e auxiliar, não exige downloads manuais.

O endereço dessa alimentação é estável. Em atualizações futuras, publique primeiro o novo ZIP com SHA-256 e mantenha os pacotes anteriores; atualize o manifesto e o feed Velopack somente após todos os arquivos estarem disponíveis. Incremente a versão do pacote e do manifesto. Apenas enviar um commit à main não atualiza o jogo.

Para recompilar o iniciador: SDK .NET 8 e `vpk` 1.2.161. Execute `empacotar.ps1`, podendo indicar `-Dotnet`, `-Vpk`, `-Version` e `-Output`. Os jogadores não precisam dessas ferramentas. Instalador por usuário, sem exigir administrador, com .NET incluído.

Diagnósticos sem abrir o jogo: `VOICENEW.exe --self-test`, `--check arquivo.json` e `--preview imagem.png`. `VOICENEW_DATA_DIR` permite isolar dados de testes. Não distribua suas configurações pessoais, credenciais, fontes recuperadas ou caches junto do iniciador.
