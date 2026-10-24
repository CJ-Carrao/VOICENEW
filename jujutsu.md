# Técnicas de Jujutsu

Use `jogar.cmd`, que aponta para `build/LAVOICE-Lab-Jujutsu.exe`. A versão anterior aberta permanece preservada. Os participantes do online precisam atualizar a versão. Fale com V ou digite com T; as técnicas estão na aba JUJUTSU do catálogo. Ferramentas ficam na mão: clique para atacar ou ativar um domínio. Com o domínio do Gojo ou do Sukuna equipado, também diga ou digite “expansão de domínio” para ativá-lo. O personagem anuncia em áudio e legenda “Expansão de domínio! Vazio Infinito!” ou “Expansão de domínio! Santuário Malevolente!”, conforme a técnica equipada. O comando não cria um domínio gratuito e respeita a recarga. Infinito, cura, adaptação e defesas funcionam enquanto equipados. Animais usam as próprias técnicas automaticamente.

| Pedido | Matéria base | Regra no jogo |
| --- | ---: | --- |
| Quero Mahoraga | 240 | Invocação de 380 de vida; aprende com exposições e tem roda visível. |
| Quero Infinito / ilimitado / barreira do Gojo | 120 | Barreira pessoal ativa 16 s, seguida de 8 s de recarga. |
| Quero corte do Sukuna | 95 | Corte de 24 m e 32 de dano; Infinito bloqueia. |
| Quero corte do mundo | 260 | Corte espacial de 100 de dano, atravessa Infinito e abre passagem nos blocos; recarga de 4,5 s. |
| Quero Fuga / flecha de fogo | 160 | Linha de fogo, 65 de dano e recarga de 3 s. |
| Quero Flash Negro | 85 | Golpe de 3,8 m, 55 de dano e recarga de 3 s. |
| Quero cura reversa | 100 | Recupera 6 de vida a cada 1,5 s, até o máximo. |
| Quero Santuário Malevolente | 280 | Domínio de 9 m por 6 s; cortes de acerto garantido, recarga de 18 s. |
| Quero Vazio Infinito | 270 | Domínio de lentidão de 9 m por 6 s, recarga de 18 s. |
| Quero domínio simples | 75 | Reduz 85% do dano garantido do Santuário e protege da lentidão do Vazio Infinito. |
| Quero amplificação de domínio | 110 | Ataques comuns atravessam o Infinito; outras técnicas e o próprio Infinito ficam suspensos enquanto a amplificação está ativa. |

Os preços incluem a mesma economia de novidade e modificadores do restante do jogo. Poderes em animais têm custo adicional por animal, inclusive em pedidos de vários animais. A adaptação custa 220 adicionais; Azul, Vermelho e Roxo custam respectivamente 100, 160 e 290 adicionais. As demais técnicas usam seu preço base como adicional.

Exemplos de combinações:

- Quero um cachorro com a habilidade do Mahoraga.
- Quero uma pistola com infinito.
- Quero um pato com infinito.
- Quero um elefante com corte do Sukuna.
- Quero uma galinha com a habilidade do Vazio Roxo.
- Quero um cachorro com a habilidade do Mahoraga com infinito.
- Quero um dragão com cura reversa.

Todas as 70 espécies, incluindo a invocação Mahoraga, aceitam modificadores de técnica. O modificador atua no animal real; ele não é trocado pelo modelo de Mahoraga. O comportamento de dieta continua limitando os alvos dos ataques. Se combinar várias técnicas ofensivas no mesmo animal, a prioridade é Roxo, Vermelho, Azul, domínio, corte do mundo, corte comum, Fuga e Flash Negro; adaptação e cura são passivas. A amplificação impede lançar outras técnicas durante sua janela ativa.

Mahoraga aprende após três exposições à mesma técnica, separadas por pelo menos 0,8 s. A roda gira; depois disso, recebe 80% menos dano daquele tipo. Mudar de corte para fogo exige nova adaptação. Um golpe fatal antes da adaptação ainda mata. Ao tentar atravessar ou atacar o Infinito, aprende a vencê-lo; o cachorro adaptado passa a acertar o jogador protegido. Cortes do mundo e acertos garantidos de domínio também atravessam a barreira. Domínios inimigos sobrepostos anulam seus acertos garantidos na disputa. Domínio simples oferece uma resposta mais barata, e a adaptação também pode superar a lentidão do Vazio Infinito.

O Vazio Roxo mantém a fusão Azul + Vermelho e o pedido direto, incluindo “fazio roxo”. Tem três órbitas de blocos luminosos, aura pulsante e rastro. Agora apaga blocos num raio real de 2,2 m ao longo de todo o trajeto, inclusive entre posições de quadros rápidos, sem depender da resistência a explosões. Células permanentes do mapa são preservadas. A remoção é distribuída entre quadros para evitar concentrar toda a destruição num único instante.

Verificações em `game/tests/jujutsu_powers.gd`: composições, 70 espécies, cachorro adaptado atingindo jogador com Infinito, troca do tipo de ataque contra adaptação, domínio simples, recarga da barreira, cura limitada e túnel contínuo em blocos fortes. `network_smoke.gd --test-jujutsu` verifica a transmissão da adaptação ao segundo jogador. Relatórios em `analysis`.

As regras de duração, custos e dano são adaptações para este jogo. A pesquisa de referência inclui [Mahoraga e sua adaptação](https://jujutsu-kaisen.fandom.com/wiki/Eight-Handled_Sword_Divergent_Sila_Divine_General_Mahoraga), [o corte espacial do Santuário](https://jujutsu-kaisen.fandom.com/wiki/Shrine) e [a combinação Azul/Vermelho em Roxo](https://jujutsu-kaisen.fandom.com/wiki/Hollow_Technique%3A_Purple).
