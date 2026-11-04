---
title: IA local para interpretar pedidos do LAVOICE
date: 2026-10-26
tags:
  - lavoice
  - ia-local
  - testes
status: pesquisando
---

# IA local de interpretação

## Objetivo e escolhas do usuário

A IA deve interpretar frases livres para criações e ordens já suportadas pelo jogo. Não haverá uma consulta por passo de cada criatura, nem geração de novas habilidades nesta etapa. O problema relatado é a rigidez das frases em geral; artigos como “o” e “um” eram exemplos, não o escopo inteiro.

Preferências confirmadas em 2026-10-26: opção no menu **desativada por padrão**, instalação opcional por download, arquivos mantidos no PC após instalar, ativação separada da instalação, desligar descarrega o modelo e desinstalar remove seus arquivos. Deve funcionar offline depois do download. Estas funções **ainda não foram implementadas**.

## Resultado confirmado em 2026-10-26

Foram feitos testes reais de inferência, CPU apenas, no Ryzen 5 4600G (6 núcleos/12 threads, 16.530.731.008 bytes de RAM física), com quatro threads para inferência, contexto de 4.096 tokens, temperatura zero e raciocínio longo desligado. Runtime portátil llama.cpp b11909, sem serviço instalado no Windows. Nenhuma janela do jogo foi aberta e nenhum pedido foi materializado numa partida.

As respostas JSON foram passadas ao `PhraseParser` real, em Godot sem interface, e comparadas com a receita de uma frase de referência. Isso verifica espécie, quantidade, enxertos, munição, dieta e ordem; uma resposta que apenas parece boa não basta. Para pedidos não suportados ou negados, foi exigida recusa explícita com frase vazia. No caso de criação pela tecla B, o teste também exige recusa do modelo; o bloqueio normal do Forge continua sendo uma proteção separada.

### Mesmos 34 pedidos difíceis

| Configuração | Acertos de interpretação | Mediana após a primeira resposta | Primeira resposta |
| --- | --- | --- | --- |
| Qwen3-0.6B Q4_K_M, instruções | 13/34 | 1.51 s | 8.10 s |
| Qwen3-1.7B Q4_K_M, mesmas instruções | 15/34 | 1.98 s | 16.58 s |
| Qwen3-0.6B Q4_K_M, instruções + 8 exemplos | 16/34 | 1.86 s | 10.16 s |

O interpretador original acertou 10/34 nesta bateria específica. **Não é uma estimativa de acerto geral do jogo**: as frases foram escolhidas para exigir paráfrases, misturas, condições e recusas. As referências ficam no teste, não são entregues ao modelo junto de cada pedido. O prompt fornece vocabulário e padrões de comandos conhecidos; os oito exemplos usam outros pedidos.

Após ajustar as instruções com exemplos, foram avaliados também **12 pedidos reservados**, com novas combinações: IA 8/12, interpretador original 4/12. No total da última rodada, IA 24/46, original 14/46. Não houve treino ou ajuste de pesos. Não foram feitas novas alterações ao prompt após ver as respostas reservadas.

### Peso e demora

- Modelo 0,6B em disco: **396.705.472 bytes** (~397 MB). RAM residente do processo: cerca de **1,10 GiB** no fim; memória privada comprometida de cerca de 803 MiB. O carregamento do processo/modelo demorou ~1 s, mas o processamento inicial do prompt acrescentou 8–10 s até a primeira resposta. As respostas seguintes reutilizam o prefixo em cache e demoraram tipicamente 1,5–1,8 s.
- Modelo 1,7B em disco: **1.107.409.472 bytes** (~1,11 GB). Uma amostra do processo registrou **2.385.801.216 bytes de working set** (~2,22 GiB); não foi uma medição de pico. Mediana ~1,98 s e primeira resposta ~16,58 s. A rodada terminou antes de salvar a amostra automática de RAM; por isso a amostra é da inspeção do processo, não do JSON do benchmark.
- O runtime também ocupa espaço separado. Valores são desta máquina, com o jogo fechado; não são requisitos mínimos nem promessa de FPS. Os tempos são adicionais ao reconhecimento de voz. Não foram medidos FPS, disputa de CPU durante combate, microfone físico ou latência completa de fala até criação.

## Exemplos observados e conclusão da primeira etapa

Com exemplos, o 0,6B interpretou corretamente “Elefante, se eu sofrer um ataque me defende” e “Leão, se sua vida ficar baixa foge”. Também acertou quantidades e algumas misturas nas frases reservadas.

Porém, retirou a munição Pokébola de uma abelha com minigun, alterou uma criação encadeada cachorro→gato→pombo→rato e deixou passar negações/pedidos sem suporte. O 1,7B também perdeu condições e chegou a trocar “todos” por um cachorro. Resposta JSON válida não garantiu intenção correta.

**Conclusão: é viável rodar esses modelos localmente, mas este protótipo de tradução livre ainda não tem acerto suficiente para integrar ao jogo.** O 0,6B era uma escolha inicial para experimentar, não uma escolha validada. O 1,7B, com o mesmo prompt, não resolveu a qualidade de forma suficiente. Melhor próximo experimento: seleção restrita de intenções e preenchimento de parâmetros com validação, preservando comandos já entendidos, antes de liberar reescrita livre de qualquer frase. Ainda sem modelo definitivo.

## Arquivos e reprodução

Os modelos e o runtime **não foram copiados para o cofre**. Permanecem em `C:\Users\Calebe PC\AppData\Local\VOICENEW-AI-Test` para reutilização em testes. São arquivos portáteis de teste, sem autoinicialização; todos os servidores iniciados nesta sessão foram encerrados. A opção do menu e o instalador/desinstalador do jogo ainda não existem. O executável distribuído não foi alterado nem houve publicação no GitHub nesta etapa.

- Script: `C:\Tony\Projetos\lavoice-lab\tools\benchmark_local_interpreter.py`.
- Consulta ao parser: `game/tests/local_ai_parser_probe.gd`, sem carregar partida.
- Resultados completos e instruções usadas: `analysis/local-ai-qwen06/results.json`, `analysis/local-ai-qwen17/results.json` e `analysis/local-ai-qwen06-examples/results.json` no projeto. Logs e respostas brutas preservados nas mesmas pastas; `analysis` fica ignorado pelo Git.
- Versão do léxico observada: `b1d1c698`. Parâmetros, frases de referência e exemplos ficam no script. Para a última rodada: `python tools/benchmark_local_interpreter.py --few-shot --holdout --output analysis/local-ai-qwen06-examples`. `--rescore-only` reaproveita respostas sem nova inferência; preserve também os parâmetros de exemplos ao reavaliar.
- Download dos artefatos conferido por tamanho e SHA-256, registrado no `manifest.json` da pasta externa. SHA do 0,6B: `ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a`; do 1,7B: `b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897`.

## Pendências

- [x] Testar inferência real de dois tamanhos e conferir as receitas no parser.
- [x] Comparar instruções com/sem exemplos e separar 12 frases reservadas.
- [ ] Conseguir qualidade suficiente com validação de intenção, negação, quantidade e aninhamento.
- [ ] Avaliar transcrições reais e desempenho junto do jogo.
- [ ] Implementar instalação, ativação desativada por padrão e desinstalação no menu.
- [ ] Integrar requisição assíncrona com limite de tempo, cancelamento e checagem normal pelo servidor da partida.

## Fontes

- [Qwen3-0.6B original e licença Apache 2.0](https://huggingface.co/Qwen/Qwen3-0.6B).
- [Quantização de 0,6B testada](https://huggingface.co/unsloth/Qwen3-0.6B-GGUF) e [quantização de 1,7B testada](https://huggingface.co/unsloth/Qwen3-1.7B-GGUF).
- [Runtime Windows testado, llama.cpp b11909](https://github.com/ggml-org/llama.cpp/releases/tag/b11909) e [documentação do servidor](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md).

Relacionados: [[copia-de-jogo]] · [[Projetos/lavoice-lab/taticas-criaturas]] · [[2026-10-26]]

## Segunda etapa — campos e erro normal do jogo (2026-10-26)

### Preferência corrigida pelo usuário

Se não compreender o pedido inteiro, usar **o retorno de erro já existente no jogo**. Não criar uma mensagem literal “Não entendi”, abrir perguntas de esclarecimento ou solicitar confirmação. O protótipo representa a recusa com entrada vazia para o parser; o teste verifica `ok=false` e receita nula. Na integração, isso deve chegar à rota normal de falha do Forge, preservando o texto original como contexto, sem tentar novamente o pedido original parcialmente entendido. Os efeitos visuais/sonoros dessa rota não foram abertos nem testados nesta etapa.

### Implementado no protótipo de teste

- Modelo Qwen3-0.6B Q4_K_M reutilizado, sem novo download. Uma chamada extrai intenção e campos; a resposta não é uma frase livre.
- IDs limitados aos animais/objetos citados, usando o léxico real. Regras reconhecem a espécie principal, quantidade, plural e nomes de golpes antes de pedir os campos ao modelo. Por exemplo, “jato de água” é um golpe, não o avião chamado “jato”.
- Campos para criatura, cabeça, arma, cadeia de projéteis, dieta, transformação por pouca vida, ninho, alvo e golpe. Categorias limitam campos: uma formiga não pode ser confundida com a arma da criatura.
- Validações recusam perda de munição, troca na ordem dos projéteis, alteração de quantidade, alvo não citado, condição descartada, tipos JSON inválidos e campos desconhecidos. Um alvo/prey omitido só é preenchido quando a intenção já está definida e a fala cita exatamente **um** candidato compatível; dois candidatos não são adivinhados.
- Combinação conservadora com o interpretador atual: converte apenas o subconjunto de receitas representável nos campos e passa pelas mesmas validações. As respostas já entendidas nesse subconjunto têm prioridade, evitando substituir uma criação correta por um erro da IA.
- Não houve alteração na simulação, custos, Forge, menus ou executável. Os limites do protótipo (uma arma, até três níveis de projéteis e quantidade 1–8) não foram impostos ao jogo existente. Outras habilidades, modificadores e comandos fora desse subconjunto ainda exigem tratamento na integração para preservar o funcionamento atual.

### Resultado medido

Uma primeira rodada por campos expôs erros de singular/plural, papéis e condições. A revisão restringiu os campos por categoria e corrigiu essas validações. Foram produzidas respostas reais do modelo para **74 frases**: 46 do ensaio anterior, 16 combinações adicionais e 12 frases fixadas antes da revisão de inferência. As referências não foram enviadas ao modelo. As correções posteriores de validação e a combinação com o interpretador atual foram avaliadas **reaproveitando as respostas gravadas**, sem novas inferências e sem escolher saídas com base na resposta esperada.

| Configuração final | Pedidos válidos corretos | Recusas corretas | Pedidos válidos recusados | Interpretações erradas aceitas |
| --- | --- | --- | --- | --- |
| Campos + validação | 49/58 | 16/16 | 9 | 0 |
| Interpretador atual validado + campos | **54/58** | **16/16** | **4** | **0** |

No total, a combinação resolveu **70/74** casos (54 criações/ordens e 16 recusas). No conjunto anterior de 46, passou de 24/46 na reescrita livre com exemplos para **43/46** no protótipo combinado. No grupo adicional de 16: 15/16; no de 12: 12/12. Os resultados finais foram medidos após ajustes das regras nesta mesma bateria: **são regressões de desenvolvimento, não uma estimativa cega de precisão em falas de jogadores**. Zero interpretação errada nesta bateria não garante ausência de erros em frases novas.

Exemplos conferidos com receitas reais: abelha agressiva com minigun disparando Pokébolas; cadeia cachorro→gato→pombo→rato; casa que anda; misturas de cabeças; seguir em grupo; golpes de Pikachu/Squirtle; resgate condicionado; singular/plural; transporte de aliados. Respostas inválidas retornam falha, sem pedir esclarecimento.

Os quatro pedidos ainda recusados pelo conjunto final:

- “Eu queria que você me desse um cachorro, por favor”.
- “Formigas, arrumem a armadura do elefante”.
- “Meus gatos, venham atras de mim”.
- “Lobos, quero que voces venham atras de mim”.

### Desempenho e limites

Quatro threads de CPU, contexto 4.096, raciocínio longo desligado. Mediana das chamadas ao modelo após a primeira: **1,63 s**, percentil95 amostral **2,06 s**, primeira resposta **4,07 s** após o servidor já estar pronto; carregar o processo/modelo levou cerca de **0,96 s**. RAM residente no fim: cerca de **1,10 GiB**; pico observado cerca de **1,12 GiB**. A consulta ao modelo foi feita para todos os casos na coleta; a escolha híbrida foi reproduzida depois. Os **22/74** caminhos pelo interpretador atual mostram quais consultas poderiam ser evitadas, não uma medição de economia/FPS em partida. Validação/identificação em Python custou aproximadamente 57 ms de mediana nesta máquina, separadamente do tempo da chamada.

Sem teste de microfone físico, reconhecimento de áudio, FPS durante combate, multiplayer ou UI do instalador. Não foi iniciada uma partida. Ainda não é uma funcionalidade entregue no EXE ou um modelo validado para todos os pedidos do jogo. Todos os servidores locais usados foram encerrados; nenhum modelo ficou carregado por estes testes.

### Evidências e retomada

- Campos, esquema e conversão: `tools/local_interpretation_fields.py`.
- Avaliação: `tools/benchmark_local_fields.py`, usando o `game/tests/local_ai_parser_probe.gd` real.
- **20 verificações sem falhas**: `tools/test_local_interpretation_fields.py`, com receitas reais e recusas por munição ausente, cadeia alterada, dieta trocada por aparência, tipo JSON inválido, pedido negativo, criação pela tecla B e alvo ambíguo. Recusas verificadas com o retorno normal do parser.
- Resultado final: `analysis/local-ai-fields06-v2/results.json`. Respostas originais: `partial.json`. Resultados anteriores às correções: `results-before-guard-fixes.json` e `results-before-unique-target-fill.json` nessa pasta. Instruções/esquemas e validações preservados nos snapshots locais. A primeira rodada continua em `analysis/local-ai-fields06/results.json`.
- Para coletar novamente: `python tools/benchmark_local_fields.py --output analysis/local-ai-fields06-v2`. Para reaplicar validação sem inferência, acrescente `--rescore-only`; isso usa as regras atuais e não é uma nova amostra do modelo. Evitar sobrescrever as evidências acima: usar uma pasta nova em próximas coletas.

### Estado e próximos passos

- [x] Implementar e avaliar extração por campos, validação e combinação com o parser atual.
- [x] Usar falha normal em vez de esclarecimentos/mensagem nova.
- [x] Preservar respostas brutas e registrar limites dos resultados.
- [ ] Validar em outra bateria de frases/transcrições reais, sem ajustar as regras às respostas dessa bateria.
- [ ] Ampliar o subconjunto representável e preservar os demais comandos já suportados antes de interceptar V/B globalmente.
- [ ] Integrar serviço local assíncrono com cancelamento/tempo limite e decisão real de pular a IA para frases aceitas.
- [ ] Implementar instalar, ativar/desativar (padrão desligado) e desinstalar no menu; medir desempenho durante jogo.

Nenhuma publicação no GitHub ou recompilação do EXE foi realizada nesta etapa.


## Base atualizada — 27/10/2026

O jogo foi migrado para H-4, priorizando os originais: [[Projetos/lavoice-lab/atualizacao-h4]]. A IA continua como protótipo separado, sem integração ao executável/menu. Os 70/74 casos acima são históricos da base anterior e precisam de nova validação antes de integrar.
