# VOICENEW — mod H-6

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

O aplicador cria uma cópia nova e verifica os arquivos de entrada. O compilador usa o runtime/dependências da instalação original do usuário. Ambos usam somente a biblioteca padrão do Python. Gameplay `voicenew-h6-lab-32`, protocolo 24: todos na partida precisam da mesma versão.

Aplicação numa base H-6 limpa, recompilação, testes do pacote e duas instâncias locais foram verificados em 03/11/2026. Sem teste de microfone físico, FPS ou rede entre PCs. IA de interpretação e atualização automática ainda não estão integradas.
