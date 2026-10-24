# Correções da lista de problemas

Executável: `C:\Tony\Projetos\lavoice-lab\build\LAVOICE-Lab-Corrigido.exe`.
O atalho `jogar.cmd` abre essa versão. A versão anterior fica preservada.
Para online, todos os jogadores precisam usar a versão corrigida.

- Dragão, morcego, borboleta, helicóptero, pomba, avião e abelha têm deslocamento horizontal e controle de altura; voadores não ficam presos no chão nem sobem indefinidamente.
- A casa ambulante tem caminhada própria, mantém as pernas animadas e muda de direção ao encostar em paredes ou criaturas, sem depender de perseguir um adversário. “Casa que caminha”, “casa que anda”, “casa andante” e “casa com pernas” usam o mesmo modelo ambulante. O pedido e a montagem completos também são testados em `walking_house.gd`.
- O pato não recebe dano de contato contínuo de aliados ou do chão enquanto come. A dieta procura a espécie pedida e poupa as demais; aceita as 69 espécies cadastradas. “Só coma formigas” inclui a rainha.
- “Só ataque”, “só ataca” e “só atacar” também escolhem a espécie alvo, assim como “só coma” e “só comer”. O elefante persegue dragões e usa o alcance real dos corpos para atingir os que voam baixo. Armas, habilidades e projéteis obedecem à seleção; alvos de outras espécies são poupados, e alvos da mesma equipe podem ser caçados. Sem presa, o animal aguarda. A regra foi exercitada em 9.522 pedidos entre as 69 espécies e no ataque de cada uma delas.
- Animais podem carregar armas que disparam outros animais armados. As armas e seus projéteis continuam funcionando nas combinações. Animais lançados ficam vivos e podem receber tiros.
- Misturas aceitam cabeça, corpo, patas, asas e cauda de outros animais, com partes cúbicas dos modelos do jogo. Cabeças herdam habilidades, patas alteram velocidade e asas dão voo. Exemplo: “quero uma formiga com asas de borboleta”.
- Não há mais teto de população que apague os animais antigos, inclusive no online e nos ninhos. Criaturas produzidas não expiram após 60 segundos. Aviões e elefantes retornam ao limite do mapa em vez de desaparecer.
- O elefante recebe dano de rifle, inclusive do criador. Possui 220 de vida e caiu após 17 impactos de rifle padrão no teste.
- O escudo anti rifle fica à direita e abaixo da mira, com o centro livre. A proteção balística custa 14 de matéria adicional e reduz o dano cinético em 85%; receber ataques ainda desgasta o escudo.
- A coleta do cliente dá resposta visual imediata e atualizações do terreno são enviadas até 30 vezes por segundo. Matéria e remoção real dos blocos continuam confirmadas pelo anfitrião.

Os custos das armas, dos animais disparados e das misturas continuam sendo somados. Ninhos gastam matéria para cada animal; produzir para quando falta matéria ou morre a rainha. Não há limite artificial de população, mas criar muitas entidades continua exigindo mais do computador.

Validação automática sem janela: `reported_regressions.gd`, `creativity_rules.gd`, `recovery_smoke.gd` e `chaos_catalog.gd`. Relatórios em `analysis`. Os testes cobrem composição nas 69 espécies, movimento dos sete voadores, casa ambulante, predação física, armas aninhadas, população acima do limite antigo, persistência, dano real de rifle, mira livre e resposta visual da coleta sem criar matéria no cliente.

Ao regenerar o conteúdo com os geradores de pacotes, aplique `tools/fix_gameplay_regressions.py` por último para manter as regras e o catálogo atualizados. `recompilar.cmd` gera o executável corrigido sem iniciá-lo.
