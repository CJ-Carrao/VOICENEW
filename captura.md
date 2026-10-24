# Pokébola e itens no chão

Abra `jogar.cmd`. Todos os jogadores do online precisam atualizar. A Pokébola está na aba CAPTURA do catálogo e custa 38 de matéria base, antes dos descontos de novidade.

1. Peça “quero uma pokébola” ou “quero uma bola de captura”.
2. Clique para arremessar contra uma criatura. Ao acertar, ela pode entrar ou rejeitar a bola.
3. Em caso de captura, a criatura desaparece do cenário, a bola treme e o botão fica verde. A bola cai no chão.
4. Mire na bola, aproxime-se e pressione **E**. Sua arma atual cai no chão, preservando munição e melhorias; a bola fica na mão.
5. Clique para arremessar a bola cheia. A criatura original sai, passa para o seu time e volta a agir. A bola fica vazia e pode ser recuperada.

**G** solta o item atual. **E** também recupera as armas e outros itens que os jogadores soltaram. É preciso mirar num item próximo, a até 4 m, sem uma parede no caminho. Não se pega diretamente a arma que outro jogador ainda segura. O nome e o conteúdo da bola aparecem na indicação de coleta e na mão.

A chance de captura aumenta quando a criatura está ferida. Criaturas maiores e saudáveis são mais difíceis; até uma tentativa favorável pode ser rejeitada. Uma rejeição deixa a criatura livre e faz a bola saltar, com efeito vermelho. O Infinito ativo também pode impedir a captura. A bola vazia é recuperável após falhar.

Cada bola guarda uma criatura. Não captura jogadores nem armas soltas. Pode capturar animais, dinossauros e misturas, incluindo criaturas armadas e com habilidades. Vida, anatomia, munição, habilidades e progresso da adaptação são preservados: não se cria uma cópia da receita. Dentro da bola, a criatura fica invisível, sem colisão, sem atacar ou continuar produzindo animais. Outra bola não pode capturar a mesma criatura de novo enquanto ela está guardada.

Soltar uma bola cheia com G mantém a criatura dentro; arremessá-la com o clique libera a criatura. Ao destruir ou reciclar uma bola cheia, seu ocupante é liberado. Captura, posse dos itens, mudança de equipe e soltura são confirmadas pelo anfitrião no online.

Verificação em `game/tests/capture_items.gd`: captura e rejeição, arremesso com colisão real, troca e recuperação da arma, conservação da criatura original e da munição, pausa das habilidades e da produção, mistura com T. rex e Mahoraga, proteção do Infinito e liberação após destruição da bola. `network_smoke.gd --test-capture` verifica a bola cheia, a arma caída e a criatura liberada para o segundo jogador. Relatórios em `analysis`.
