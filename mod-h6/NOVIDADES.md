# H6-v39 — kaijus, crossover e custos/recargas visíveis (v0.4.8)

Godzilla remodelado: focinho reptiliano, mandíbula e dentes, olhos âmbar com pupilas visíveis, braços curtos, cauda longa curvada e crista dorsal serrilhada. Tem 120 m, animação nativa e sopro atômico realinhado à boca.

- Kaijus gigantes: Godzilla, Kong, King Ghidorah, Mothra e Rodan, com ataques próprios, ordens, captura, armas e misturas.
- Neymar e bola de futebol; Sans, ossos brancos/azuis, Gaster Blaster, gravidade/alma azul e KARMA; DOOM Slayer e Crucible; Railcannon elétrica; Lança Simétrica; botas de velocidade.
- Poderes do Sans para o jogador: peça “quero ter os poderes do Sans”; selecione a luva, clique usa e R troca o poder.
- Mahoraga analisa fenômenos após sobreviver ao contato e continua aprendendo ao longo do tempo; Gojo e Sukuna calibrados em duelos de desenvolvimento.
- Painel mostra custo real por uso, recarga base, contagem compartilhada, técnica que iniciou a espera, bloqueios e duração do Infinito/domínio. Exemplo: após Vazio Infinito o kit do Gojo espera 28 s; trocar com R não elimina a espera. Os golpes do Gojo continuam custando 0 de matéria por uso, com compra do kit paga.
- Clique recusado por uma técnica bloqueada não emite sinal de disparo bem-sucedido. Preservados carregadores/recargas, armas sem cobrança por tiro, limite de 30 criaturas por jogador e as dez ideias da expansão v35.

Arte original em blocos; não foram importados modelos dos jogos citados.

Gameplay `voicenew-h6-lab-39`, protocolo 26: todos na partida precisam atualizar. Jogo 0.4.8; instalador preservado em 0.4.1, com créditos clicáveis ao autor.

Validação: três cenários de porte/combate/integração na fonte e no pacote final v39, duas instâncias ENet do pacote, inicialização nativa por 90 quadros sem janela, ZIP/EXE por SHA-256/CRC e aplicação limpa de 560 operações de código sem diferenças. Cenários de poderes pessoais/Sans também reexecutados no pacote final para publicação. Prévias dos modelos inspecionadas; aparência/animação em janela, FPS, microfone físico e rede entre PCs físicos não aferidos. IA de interpretação continua sem integração.

**LAVOICE por Tsomyst — Somyst Game Studio**: https://tsomyst.itch.io/lavoice. Créditos e licenças preservados.

# H6-v36 — expansão criativa e munição sem cobrança (v0.4.5)

- Armas não consomem matéria por disparo. Minigun de buracos negros continua atirando com saldo zero. Mantidos carregadores, recargas e limites de produção; projéteis gratuitos não devolvem matéria.
- Inclui a expansão H6-v35: fusões de poderes, curadores e funções na base, evasão/cobertura por ataques repetidos, armas condicionais, montarias com habilidades, evolução por feitos, invasões de cinco ondas, invenções salvas, duplas coordenadas e mimetizador temporário.
- Comandos, custos e regras no CRIATIVIDADE.txt junto do jogo. Limite de 30 criaturas por jogador, produção de colônias paga, custos de criação e recargas preservados.
- Corrigida herança de habilidades do Squirtle em misturas, mantendo armas e transformação.
- Gameplay voicenew-h6-lab-36, protocolo 25: todos na partida devem atualizar. O instalador permanece 0.4.1; o jogo é 0.4.5.

Validação v36: teste de munição na fonte e pacote final (12 disparos, três variantes, saldos 0/500), regressão de granada condicional/colônias pagas/invenções e aplicação limpa das 518 operações de fonte. Os testes ampliados da expansão e rede com duas instâncias foram realizados na v35. Não repetidos rede e boot nativo na v36; aparência/FPS e microfone físico não aferidos. IA de interpretação continua sem integração.

**LAVOICE por Tsomyst — Somyst Game Studio**: https://tsomyst.itch.io/lavoice. Créditos e licenças preservados.

# H6-v34 — combate e transporte (v0.4.3)

- Black Flash continua um golpe físico preciso: novos ramos 3D com núcleo escuro e halo vermelho, pulso breve e impacto no contato. Sem projétil ou dano à distância; precisão, zona e Infinito preservados. Efeito em duas malhas de instâncias para reduzir criação de objetos.
- Fuga: flecha visualmente maior, explosão de 8 m/140 de dano base, incêndio e coluna de chamas. Preparação 0,45 s mantida; recarga 8 s no item e 8,5 s no Sukuna. Custo base 260, inclusive como habilidade de criatura; versão de poderes pessoais 351. São adaptações de balanceamento, não medidas do anime.
- Passageiros atacam durante o transporte: alvo próprio ou do transportador, respeitando ordens, dieta e jogador escolhido. A locomoção fica com o transportador; o passageiro mantém ataques e armas. Voadores aproximam a carga para o alcance de contato.
- Não há desembarque automático no inimigo. B “pombo carregue a tartaruga”; depois B “pombos ataquem o inimigo”. Para desembarcar, B “pombo solte a carga”. Use um pombo grande para ter capacidade. Permanecem limites de peso, um passageiro e velocidade reduzida.

Referências: [Black Flash](https://jujutsu-kaisen.fandom.com/wiki/Black_Flash), [episódio oficial Nonstandard](https://www.crunchyroll.com/watch/G4VUQMWDZ/nonstandard) e [flecha contra Mahoraga](https://jujutsu-kaisen.fandom.com/wiki/Sukuna_vs._Mahoraga). Não foram copiados modelos, áudios ou cenas do anime. O item Fuga continua uma adaptação independente, sem exigir os votos/requisitos completos do mangá.

## H6-v33 — correções de bases (v0.4.2)

- Castelos reconhecidos como chão e obstáculos nas consultas das criações.
- Ninhos e formigas sobre o piso; nascimentos procuram espaço livre de paredes e portões.
- Entrada maior e salão central com espaço para criaturas grandes. Portão considera o tamanho do animal ao abrir.
- Rotas por etapas para alinhar o corpo antes de atravessar, também ao seguir o jogador. Guardas e cerco preservados.
- Extração atualiza apenas colisões de partes atingidas, com trabalho limitado por etapa, mantendo destruição real e reparos. Otimização medida sem janela; FPS visual ainda não medido.

## Conteúdo anterior H6-v32

- Integração à base oficial H-6, com cordas, jetpack, invisibilidade, singularidade e sincronização dos portais. Os recursos oficiais vêm da instalação local do usuário.
- Cachorro Orelha refeito com pelagem escura e orelhas caídas; Oliver Tree, Gojo e Sukuna em blocos. Gojo/Sukuna alternam técnicas, priorizam seu rival e disputam domínios, inclusive invocados pelo mesmo dono.
- 51 perfis para usar poderes no jogador: JJK, Pokémon, adaptação, fogo, voo, cura, construção, escavação e ninhos. Passivas só no equipamento selecionado e recargas preservadas.
- Castelos pequeno/normal/grande, pátio e torres ocos, montagem gradual, portão móvel, guarda, patrulha, vigias, recuo, reparos pagos de blocos e cerco.
- Menu Q com dez ordens e escolha por Todos, espécie ou indivíduo mirado. Sujeito curto por voz ou clique imediato; B mantém frases completas.
- Preservados captura, misturas, evoluções, comandos, limite de 30 criaturas, seleção de jogador 1–4 e descarte/detonação dos próprios animais.

As rotas do castelo são preparadas para sua geometria. Prefira terreno plano; não há navegação universal por labirintos construídos depois. Não foram medidos FPS, microfone físico ou rede entre PCs.

O pacote é de alterações, não um EXE pronto. Consulte [LEIA-ME](LEIA-ME.md) para aplicação local.
