# VOICENEW — mod H-6

## Instalar e jogar — v0.4.8

H6-v39: Godzilla remodelado, cinco kaijus gigantes, Neymar, Sans e seus poderes, DOOM Slayer/Crucible, Railcannon, Lança Simétrica, botas de velocidade e painel de custos/recargas. Inclui melhorias do Mahoraga, calibração Gojo/Sukuna e as novidades anteriores. Gameplay `voicenew-h6-lab-39`, protocolo 26; todos na partida devem atualizar. [Mudanças e validação](mod-h6/NOVIDADES.md) · [Ver os modelos](docs/galeria-v048/README.md).

Correções H6-v33: castelos reconhecidos como estrutura, nascimento de formigas sobre o piso, passagem de criaturas grandes e extração com colisões incrementais. Atualize pelo iniciador; todos no online precisam da mesma versão.

Baixe **[VOICENEW-Instalar.exe](https://github.com/CJ-Carrao/VOICENEW/releases/latest)**, instale o iniciador e clique em **Instalar jogo**. Ele baixa o jogo completo pelo nosso GitHub. Depois, use **Jogar**. Atualizações automáticas ficam ativadas; jogo fechado durante a troca e versão anterior preservada. Não requer Python ou Godot. [Guia do iniciador](launcher/LEIA-ME.md).

**LAVOICE por Tsomyst — Somyst Game Studio**, com [crédito ao autor](https://tsomyst.itch.io/lavoice) no rodapé do iniciador e arquivos de créditos originais preservados.

Os parágrafos abaixo documentam a publicação anterior v0.4.0, feita somente como patch. A distribuição pronta da v0.4.1 usa autorização relatada pelo mantenedor em 03/11/2026, condicionada aos créditos ao autor. A versão modificada não representa lançamento oficial.

Atualização **v0.4.0**, correspondente às alterações do Lab até **H6-v32**: castelos, menu Q, poderes no jogador e personagens, preservando as adições anteriores.

## Baixar a atualização

Abra [a release v0.4.0](https://github.com/CJ-Carrao/VOICENEW/releases/tag/v0.4.0) e baixe **VOICENEW-H6-Mod-v0.4.0.zip**. É um pacote de alterações para uma cópia local editável H-6, **não um executável pronto**. [Requisitos e aplicação](mod-h6/LEIA-ME.md).

A licença distribuída com a H-6 exige autorização escrita para redistribuir o jogo e o código extraído. Esta atualização não inclui o EXE oficial, runtime, arquivos originais de modelos ou modelos de voz. Obtenha o original pelos [canais do autor](https://tsomyst.itch.io/lavoice). O projeto não representa um lançamento oficial.

## Conteúdo

- Castelos de pedra, portão móvel, defesa/patrulha/vigia, reparos reais e cerco.
- Segurar **Q**, escolher ordem e destinatário por clique ou sujeito curto por voz; soltar Q envia. **B** mantém frases completas.
- 51 perfis para usar poderes de Gojo, Sukuna, Pokémon, Mahoraga e outras criações no jogador: clique usa e **R** troca.
- Cachorro Orelha refeito, Oliver Tree, Gojo/Sukuna com técnicas e disputa automática de domínios.
- Limite de 30 animais, misturas, captura, evoluções, táticas e comandos por jogador 1–4.

[Novidades e limites](mod-h6/NOVIDADES.md) · [Como funcionaria a atualização automática](ATUALIZACOES.md).

## Organização do repositório

**A atualização atual está em `mod-h6/`.** A pasta `game/` e os guias anteriores registram a versão H-4 já publicada; não são a fonte completa da H-6. [README histórico](docs/README-historico-h4.md).

O aplicador cria uma cópia nova e verifica os arquivos de entrada. O compilador usa o runtime/dependências da instalação original do usuário. Ambos usam somente a biblioteca padrão do Python. Gameplay atual `voicenew-h6-lab-39`, protocolo 26: todos na partida precisam da mesma versão.

Aplicação das 560 alterações numa base H-6 limpa, testes do pacote e duas instâncias ENet locais foram verificados em 04/11/2026. O iniciador já entrega atualizações. Sem teste de microfone físico, FPS ou rede entre PCs físicos. IA de interpretação ainda não integrada.
