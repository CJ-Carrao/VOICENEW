# VOICENEW — alterações H-6 / v0.4.0

Este pacote reúne as alterações do Lab até a build **H6-v32**. Ele contém código próprio, modelos próprios e instruções de alteração dos arquivos locais. Não contém o jogo completo, o executável oficial, seu runtime, modelos originais nem os modelos grandes de voz.

A distribuição H-6 traz uma licença que exige autorização escrita para redistribuir o jogo e o código extraído. Este pacote não concede direitos sobre o LAVOICE nem representa um lançamento oficial. Obtenha o original pelos [canais do autor](https://tsomyst.itch.io/lavoice) e respeite seus termos.

## Requisitos

- Uma base **editável H-6 Windows** já preparada localmente, correspondente à recuperação GDRE 2.7.4. O pacote não extrai nem descriptografa o jogo e não fornece chaves.
- A distribuição oficial H-6 completa, com `LAVOICE.exe`, `voice`, `licenses`, `x86_64` e DLLs.
- Python 3.10 ou posterior e editor Godot **4.7.2** para recompilar.
- Espaço para uma cópia nova do projeto e uma pasta nova do jogo. As entradas não são modificadas.

Base oficial verificada: ZIP SHA256 `b8893ed9d66799a7ecf7f0e6011d89de2a3b497201878f839bfb3af168b72078`.

## Aplicar

Execute dentro desta pasta, ajustando somente os caminhos de exemplo:

```powershell
python aplicar_mod.py --base "C:\Jogos\LAVOICE-H6-editavel" --saida "C:\Jogos\VOICENEW-projeto"
```

O aplicador confere os arquivos de entrada antes de copiar, rejeita versões diferentes e cria a saída separadamente. Recursos originais necessários são copiados da sua própria base; modelos adaptados são derivados dos arquivos locais.

Depois, recompile usando o runtime e dependências da sua instalação original:

```powershell
python recompilar_mod.py --projeto "C:\Jogos\VOICENEW-projeto" --godot "C:\Ferramentas\Godot\Godot_v4.7.2-stable_win64_console.exe" --original-exe "C:\Jogos\LAVOICE-H6\LAVOICE.exe" --saida "C:\Jogos\VOICENEW"
```

Abra `jogar.cmd` na pasta de saída. O processo de compilação não abre a janela do jogo. Mantenha a pasta completa ao mover a instalação. A saída contém arquivos do original obtidos localmente: não redistribua o resultado sem as autorizações necessárias.

## Uso

- V: criar por voz. T: texto. B: frases completas de comando.
- Segurar Q: escolher ordem e destinatário; clicar no nome ou falar apenas o sujeito; soltar Q envia. Esc cancela.
- “Quero um castelo medieval de pedra”: posicionar a prévia e confirmar. Há versões pequena, normal e grande.
- “Quero ter os poderes do Gojo”, “do Sukuna” ou “do Pikachu”: equipe; clique usa e R troca o golpe.

No online, todos precisam da mesma versão: gameplay `voicenew-h6-lab-32`, protocolo 24. O limite é de 30 criaturas por jogador. IA de interpretação continua sendo um protótipo separado, sem integração ao jogo.

[Novidades](NOVIDADES.md) · [Maneiras de atualizar automaticamente](../ATUALIZACOES.md).
