# Sistemas & Mecânicas — Documento de Design

> Este arquivo é a **fonte da verdade** das regras do jogo. A lore vive em `lore.md`;
> aqui vive *como o jogo funciona*. O código deve sempre seguir este documento.
> Status de cada sistema: 🟢 definido · 🟡 em discussão · ⚪ a definir.

## Fluxo de produção (importante)

Duas frentes que compartilham o **mesmo cérebro**:

- **`jogo/core/` = a LÓGICA** (regras, fórmulas, combate, ficha, dado...). Lua puro,
  sem apresentação. Fonte única da verdade — usada pelas duas versões abaixo.
- **`jogo/` (console) = LABORATÓRIO.** Onde toda mecânica/conteúdo nasce e é testada
  primeiro (rápido e barato; validada por `jogo/testes.lua`). UI de texto; não precisa
  caprichar. É ferramenta de prototipagem interna.
- **`jogo2d/` (LÖVE2D) = PRODUTO.** A versão visual que sai pro público. Recebe a lógica
  já pronta e validada, e cuida só da apresentação (desenho, sprites, input, telas).

**Ciclo de qualquer novidade:** (1) criar/testar a lógica no `core/` via console →
(2) validar que funciona e é divertido → (3) plugar a camada visual no `jogo2d/`.
Nunca prototipar direto no visual (caro/lento); o console existe pra isso.
>
> **Já implementado e validado em código** (`jogo/core/`, testado em `jogo/testes.lua`):
> fórmula de teste (atributo + habilidade + 1d3 com vacilo), Força de Vontade
> (base/pool), ficha de atributos e o relógio de tempo. As tabelas de probabilidade
> do teste conferem com a sensação pretendida.

---

## 0. Filosofia de Design (princípios-guia)

Estes princípios valem pra TODOS os sistemas abaixo. Toda mecânica nova deve respeitá-los.

1. **Mundo vivo e reativo, não estático.** O mundo simula, não apenas espera o jogador.
   O tempo passa, NPCs mudam de estado, e o mundo continua acontecendo mesmo sem o
   jogador presente.

2. **Cada coisa importa.** Escolhas ecoam. Detalhes aparentemente pequenos (gênero,
   uma decisão, quanto tempo você demorou) alteram interações. Nada é decorativo.

3. **Escopo aberto / extensível desde já.** É um protótipo de um jogo que será grande.
   Preferir sempre soluções data-driven e modulares: adicionar conteúdo novo (um NPC,
   um local, um evento, um estado) NÃO deve exigir reescrever o motor. Dados separados
   da lógica.

4. **Não entregar a mecânica na cara.** O jogador aprende o mundo vivendo, não lendo
   tooltips. Evitar números explícitos e explicações diretas quando possível; preferir
   que ele *sinta* as consequências pela narrativa. (Ex.: a escolha inicial "homem ou
   monstro" não revela o que cada uma significa.)

---

## 1. Criação de Personagem  🟡

**Abordagem escolhida: "nascer sem nada" / emergente.** Não há tela de criação
separada. O jogador já começa jogando; quem o personagem é vai sendo forjado pela
vivência. A "criação" acontece dentro da ficção, não numa tela de configuração.

O que já está decidido:
- **Origem:** primeira escolha do jogo — "Deseja ser um monstro ou um homem?"
  Define o ponto de partida (homem = humano; monstro = lobisomem), sem revelar
  ao jogador o que isso implica. O destino permanece aberto (transformações vêm depois).
- **Números existem.** É um jogo, não um simulador de vida — há atributos/stats reais
  no motor. Mas seguindo o princípio 4, o jogador não precisa vê-los crus: motor
  pensa em números, jogador sente em narrativa.
- **Idade inicial: 18 anos (adulto).** Mas o PERSONAGEM não sabe a própria idade
  (não há registro, família ou passado que lhe diga) — reforça o "random jogado no
  mundo". Nasce/desperta já adulto; nada de infância jogável.

A definir (com calma, um de cada vez):
- De onde vêm os atributos iniciais (crescem por uso? primeiras cenas definem? híbrido?).
- Quais atributos existem.
- Se o "nascer" é literal ou metafórico (como a abertura apresenta o despertar).
- **Gênero (homem/mulher):** importa — num mundo medieval, certas interações mudam
  conforme o gênero do personagem. (Detalhar quais e como.)
- Nome / identidade inicial.

---

## 2. Tempo  🟢

Objetivo: o mundo não é estático — o tempo passa e as coisas mudam com ele.

**Regras definidas:**
- **Relógio global linear e infinito.** Um único contador interno que só cresce.
  Não cicla em dias/horas. É apenas um número que soma o custo das ações.
- **Ações fazem o tempo passar.** Cada ação tem um **custo de tempo** (um inteiro
  pequeno; a maioria = 1, ações mais longas custam mais). Ao executar a ação, o
  custo é somado ao relógio global.
- **O tempo é INVISÍVEL ao jogador.** Nunca se mostra "dia X" ou "hora Y". O tempo
  só existe para gerar consequências. No máximo, NPCs *reagem* a ele — reclamam se
  o jogador demorou, comentam, mudam de humor/estado.
- Como é invisível e só interno, não há preocupação com "peso" ou formato — é só um
  acumulador.

**Vira código como:** `core/tempo.lua` — um relógio INSTANCIÁVEL (`tempo.novo()`,
`:agora()`, `:avancar(custo)`), não um singleton de módulo. Cada mundo/sessão
tem o seu; ninguém compartilha relógio à toa. As ações declaram seu custo nos
dados, não no motor. (Ainda não conectado ao jogo jogável — só ao core e aos
testes; falta uma ficha/masmorra/main chamar `:avancar()` de verdade.)

---

## 3. NPCs & Mundo Reativo  🟢

Objetivo: NPCs com vida própria — mudam de estado conforme o tempo que as ações do
jogador consomem. O mundo "não esperou" o jogador.

**Regras definidas:**
- Cada NPC muda de estado por **acúmulo**: ele avança quando o relógio (ou um contador
  próprio alimentado pelo tempo) atinge um **limiar**. Ao cruzar o limiar, o NPC pode
  mudar de **lugar, posição, ação, humor, disponibilidade**, etc.
- As transições podem **ramificar**: o próximo estado depende de **condições** — o que
  o jogador fez, se uma quest foi concluída, reputação, gênero, etc. Não é um trilho
  fixo A→B→C; pode ser A→B ou A→D dependendo do estado do mundo.

**Modelo de dados (rascunho, pra manter escopo aberto):** um NPC é uma tabela com
uma lista de estados; cada estado tem um limiar de tempo para transicionar e uma ou
mais transições possíveis, cada transição com uma condição opcional e o estado-destino.
(Formato exato a detalhar quando formos implementar.)

**Exemplo ilustrativo (não é a lore, só pra fixar a ideia):** um comerciante começa
"na feira". Se o jogador demora além do limiar, ele transiciona: se a quest dele foi
entregue → "em casa, satisfeito"; se não → "foi embora, irritado" (e reclama na
próxima vez que o jogador o encontrar).

---

## 4. Atributos & Ficha  🟡

### Atributos gerais (todos os personagens têm)
- **Força**
- **Vitalidade**
- **Agilidade**
- **Carisma**
- **Inteligência**
- **Força de Vontade** (ver subseção própria abaixo — tem mecânica especial)

### Atributos secundários (por raça)
Cada raça tem um par de secundários — e cada par é um eixo de **poder vs. preço**,
espelhando o tema central da lore ("todo poder cobra algo").

- 🩸 **Vampiro — Sangue & Humanidade.** Sangue = poder/sustento; Humanidade = o quanto
  de pessoa ainda resta. (Tensão clássica: usar/beber poder tende a corroer a humanidade.)
- 🐺 **Lobisomem — Fúria & Umbra.** Fúria = o lado Caos, o frenesi, a besta;
  Umbra = o lado espiritual ligado a Gaia, controle. Reflete a lore (lobisomens lutam
  contra o Caos e adoram Gaia — Fúria é o Caos interno, Umbra é a Gaia).
- 🌌 **Mago — Sonhos & Quebras.** Sonhos = recurso (a mana da Mundus); Quebras = o preço
  acumulado por rasgar a realidade. Quebras é o contador que leva ao Cemitério dos
  Sonhos (dano → envelhecimento → morte → banimento), conforme a lore da raça.
- 🧍 **Humano — página em branco.** Sem secundários. Só os 5 gerais e a fragilidade
  mortal. É o **modo hardcore** (diegético): você é apenas um humano num mundo de
  monstros. Em compensação, é o único que pode se tornar QUALQUER coisa (vampiro ou
  mago) — página em branco = potencial puro.
- 👹 **Abominação — Ego & Corrupção.** Raça super rara / lendária / secreta (endgame;
  "dificilmente um jogador consegue ser"). Ego = a identidade/mente tentando se manter
  coesa; Corrupção = o "erro divino" consumindo você. O ápice de poder da obra.

### Escala dos atributos (0–10) — cada ponto importa MUITO

A escala é curta e densa de propósito: nada de inflação de níveis. Subir 1 ponto é
um EVENTO — costuma significar cruzar uma fronteira qualitativa, não "+1 de dano".
A régua é medida pela humanidade como chão, e o sobrenatural ocupa quase toda ela.

```
0   = a INEXISTÊNCIA. Só o All-Being tem 0 (ver abaixo).
1   = criança humana
2   = humano adulto comum   <- toda a humanidade comum vive aqui
3+  = já é SOBRENATURAL (fora do que um humano pode ser)
5   = referência: o Ael (o "auge" no início da obra)
10  = TETO do jogador e dos mortais em geral
```

**O 0 é a ausência de algo — e a ausência não existe no universo.** A escala mede
*presença*: quão intensamente algo existe. Mas o universo é plenitude por definição —
sempre há algo (matéria, energia, o vácuo, que ainda é algo). Não existe "lugar" onde
não haja nada. Por isso nenhum ser que *está* no universo pode ter 0: estar no universo
já é ser algo. Todo ser real tem no mínimo 1.

A **única** exceção é o **All-Being** — a única ausência que existe, porque ele "reside
na inexistência", *fora* do universo (ver `lore.md`). Ele não é 0 por ser fraco; ele é
a ausência total que o cosmos, sendo pura presença, não comporta. O 0 é o furo na régua,
ocupável só por quem está fora de tudo.

Design: se o jogador algum dia vir um ser com atributo **0**, é sinal de horror absoluto
— encontrou o inominável, não um fraco.

**O teto do jogador é 10.** Nenhum personagem jogável passa de 10.

**Acima de 10 = só lendas.** Ultrapassam a régua mortal: Caim, Mundus, Null, e 4 dos
5 protagonistas. Exceção: **o Ael NÃO passa de 10** — é o único humano comum, preso à
escala mortal. (Isso conta a tragédia dele pela própria matemática: os outros
protagonistas estouram a escala e viram cósmicos; ele continua um humano excepcional
e por isso "vira o mais fraco".)

**Consequência de design:** o humano (página em branco) vive travado no 1–2 — não
alcança o sobrenatural sem se transformar. A escala inteira acima dele é território de
monstros. Reforça o "modo hardcore".

### Os protagonistas como evento raríssimo
Os 5 protagonistas da web-novel podem aparecer no jogo como um **evento MUITO raro**
(encontrar uma lenda 10+ andando pelo mundo). Dá a sensação de ser um "random" num
mundo onde os mitos existem de verdade. Memorável — e perigoso.

### Testes de atributo

Filosofia: testes existem e têm **aleatoriedade** (dado → tensão), mas não são triviais
nem punitivos. Se o atributo é suficiente para o feito, você passa **na maioria das
vezes** (não sempre — ainda há chance de falhar); se é insuficiente, fica improvável.

**Dificuldade ancorada em feitos físicos concretos, não em números abstratos.** Para
definir a dificuldade de uma tarefa, pergunta-se "que façanha real isso exige?" e o
patamar de atributo sai daí. Isso mantém "cada ponto importa muito" e é intuitivo de
balancear. Exemplos de Força:
- Arrombar uma porta emperrada → basta **Força 2** (humano comum passa quase sempre).
- Levantar ~1 tonelada → exige **Força 4** (já é sobrenatural; lembre: 3+ é fora do humano).

### A fórmula do teste (definida)

    resultado = atributo + 1d3   (comparado com a dificuldade da tarefa)
    passa se  resultado ≥ dificuldade

- **Dado = 1d3.** Pequeno de propósito: o atributo domina, a sorte é só tempero
  (bate com "quero que os dados importem bem pouco"). Mas...
- **O dado é rolado em QUALQUER teste, sempre** — nada de sucesso automático. Até a
  tarefa mais boba tem o friozinho do "vai que...". (O caos é divertido.)
- **Bônus real do dado, por face:** dado **1 → +0** (vacilo), dado **2 → +1**,
  dado **3 → +2**. Ou seja, o bônus é **0, 1 ou 2** (cada um ~33%). Não é intuitivo,
  mas tudo bem: **o cálculo nunca é mostrado ao jogador** — ele só vê "conseguiu" ou
  "vacilou". Internamente é o que balanceia melhor. Bônus contido (0–2) reforça ainda
  mais que "o atributo domina, a sorte é só tempero".
- **O 1 é o vacilo:** um terço das vezes você não ganha bônus algum. Garante que até
  personagens fortes possam falhar em tarefas triviais num azar (o brutamontes de
  Força 4 que não abre a porta quando tira 1). Ninguém é imune ao vacilo.

Interação com a **Força de Vontade**: o vacilo (dado 1) é o momento clássico pra decidir
queimar 1 de vontade e rerrolar. Os dois sistemas se reforçam.

**Exemplo (porta difícil, dif 5):** Força 4 → tira 1: 4+0=4 (FALHA); tira 2: 4+1=5 (passa);
tira 3: 4+2=6 (passa). Falha ~1 a cada 3 tentativas.

### Força de Vontade (atributo especial)

**Escala própria, diferente dos outros atributos.** Não segue a régua "2 = humano comum":
o jogador **começa com 5** (máximo 10). Todo mundo nasce com uma resiliência mental
razoável (não se começa "sem alma"). Como o pool começa cheio (= base), o jogador arranca
com **~5 rerrolagens** de colchão contra o RNG.

**Não tem habilidades** e **não sobe como os outros atributos** (nem por uso, nem pela
distribuição de 2 pontos por nível). Sobe pela sua própria via, **devagar e rara** — a
definir como exatamente (eventos de sentido? marcos da história?).

Funciona em **duas camadas** — pense em "base" (o máximo) e "pool" (o atual), como HP e
HP-máximo:

- 🛡️ **Defesa mental → usa sempre a BASE (estável).** A resistência a ataques mentais
  (medo, Dominatio vampírica, frenesi, horror do All-Being, loucura) é sempre o valor
  cheio. NÃO oscila quando você gasta vontade para rerrolar.
- 🎲 **Rerrolar dados → gasta do POOL (temporário).** Você pode queimar 1 ponto do pool
  para rerrolar um teste, reduzindo o peso do RNG e dando agência sobre a sorte. O gasto
  é temporário e não afeta a defesa mental.

  *Exemplo:* base 6, pool cheio 6. Gasta 1 rerrolando → pool = 5, mas a defesa mental
  continua **6** (o gasto não mexe na base).

**Recarga é LENTA e difícil — de propósito** (diferente do HP). "Dor mental cura mais
devagar que dor física." HP volta trivialmente (descanso, comida, tempo). O pool de
Vontade só recupera com coisas de *sentido* — superar um medo, um propósito cumprido,
uma vitória real, um vínculo. Isso torna cada rerrolagem uma decisão pesada: você está
queimando um recurso que demora muito pra voltar. Num mundo que esmaga psicologicamente,
a resiliência mental é o recurso mais escasso e valioso.

A definir: quais ações exatas recarregam o pool e quanto; custo fixo (1) por rerrolagem
ou variável; se há teto de rerrolagens por teste.

### Progressão: dois eixos que sobem de formas diferentes

O jogo tem **duas** trilhas de crescimento, deliberadamente assimétricas:

> **Nota de intenção (importante pro futuro):** subir de nível NÃO é "só +1 nível".
> É um **fenômeno** — um evento raro e significativo em que o personagem *descobre mais
> de si* e **sintoniza alma + corpo + universo** (ecoa a lore: "o criador é uma sintonia
> com o universo"; "a Mundus e o universo são um só"). Cada nível é um passo nessa
> harmonização crescente com a existência. No futuro, subir deve ter peso NARRATIVO —
> uma cena/revelação, não uma tela seca de stats. Por isso é deliberadamente raro e o EXP
> não sobe sozinho. A mecânica atual (core/) é só o esqueleto numérico disso.

**1. Atributos → sobem por NÍVEL (via EXP). BEM difícil.** (implementado: core/niveis.lua)
- Ganha-se EXP de combate, quests, exploração, etc. **Fontes de EXP** (valor é dado de
  cada fonte, data-driven): combate comum **5–10**; combate difícil **até 100**;
  exploração **20–100**; quests **10..sem teto** — a fonte PRINCIPAL, curada a dedo.
  (Consequência: não se sobe farmando trombadinha; o caminho é quest/exploração.)
- **Curva CRESCENTE** (nível 1→10, teto). Custo do degrau: 2→100, 3→250, 4→450, 5→700,
  ... 10→2700 (incremento cresce +50 a cada degrau). Subir é difícil desde o começo e
  o topo é uma epopeia.
- Cada nível concede **2 pontos de atributo**, mas **não se pode colocar os 2 no mesmo
  atributo** — tem que espalhar (+1 em dois atributos diferentes). Focar um atributo só
  ao máximo exige vários níveis. Protege a escala e evita "furar" o teto 10 rápido.
- **Ganhar EXP não sobe o nível sozinho** — sinaliza um nível "pronto"; o jogador escolhe
  quando e como distribuir os 2 pontos (evita subir no meio de um combate; respeita a
  escolha de build). EXP que sobra fica acumulado rumo ao próximo.

**2. Habilidades → sobem por USO. RÁPIDO.**
- Cada uso de uma habilidade a faz progredir; o ganho é **rápido** (ex.: ~2 usos de
  Intimidação já sobem).
- Motivo: é uma aventura narrativa de mundo vivo — não dá pra farmar/cheesar (ficar
  repetindo a mesma ação). As oportunidades são pontuais e escassas, então o ganho
  rápido compensa. Se subisse devagar, a habilidade nunca upava.
- Sensação old school: você vira um especialista habilidoso rápido (intimidar, arrombar,
  rastrear...), mas ficar de fato mais forte/rápido (atributo) é raro. **Perícia ≠ poder.**

### Fórmula do teste de HABILIDADE

    resultado = atributo-base + nível da habilidade + 1d3(→ 0/1/2)
    passa se resultado ≥ dificuldade

- Conta uma história do personagem: **talento bruto** (atributo, sobe devagar) +
  **prática** (habilidade, sobe rápido) + **acaso** (dado).
- Ex.: Carisma baixo + Intimidação alta = o sujeito sem graça que aprendeu a assustar
  na marra. Carisma alto + Intimidação baixa = o carismático nato, cru em ameaçar.
- ⚠️ **Balanceamento:** como soma DOIS valores (atributo + habilidade), o resultado
  cresce mais rápido que um teste de atributo puro. Ancorar as dificuldades de testes
  de habilidade mais alto que as de atributo puro. (Cuidar no balanceamento.)

### Valores iniciais por raça (em construção)
- 🐺 **Lobisomem:** começa com **Força 3** (já sobrenatural — coerente com a raça bestial).
- (demais raças/atributos a definir)

A definir: o resto dos valores iniciais por raça.

---

## 4.5. Perícias  🟢

> **Nota de nomenclatura:** o que aqui chamamos de **PERÍCIA** (Esgrima, Intimidação...)
> era antes chamado de "habilidade". Renomeado pra não confundir com o menu
> **"Habilidades"** do combate (ver 6), que é outra coisa: as manobras/ações especiais
> do turno (formas do lobisomem, ataque a pontos vitais, etc.). Resumo:
> **Perícia** = aptidão treinada que entra nos testes; **Habilidade** = ação de combate.

Perícias são **aptidões mundanas aprendidas** (Intimidação, Furtividade, Esgrima,
Rastreio, Escalada, Mentira...). Entram no teste como
`atributo-base + nível da perícia + 1d3` (ver 4).

**Regras definidas:**
- **Perícia ≠ poder de raça.** Uma perícia depende apenas de ter um corpo humanoide +
  um cérebro funcional. NÃO é superpoder, NÃO depende de fisiologia especial. Virar
  vampiro/mago/lobisomem **não** concede perícias novas — concede *disciplinas/recursos
  de raça*, que são um sistema SEPARADO (ver 5). Suas perícias continuam sendo suas,
  humanas, independentes do que você virou.
- **Lista curada, porém INVISÍVEL ao jogador.** O motor conhece um conjunto fechado de
  perícias (você controla o que existe → balanceável). Mas o jogador **não vê** uma
  lista nem os níveis. Contraste com os atributos:
  - **Atributos são VISÍVEIS** — o jogador os controla (distribui por nível), então
    precisa vê-los.
  - **Perícias são OCULTAS** — sobem sozinhas por uso, o jogador não as controla
    diretamente. A visibilidade segue a agência.
- **A evolução É anunciada.** Embora o nível seja oculto, quando uma perícia sobe o
  jogo avisa de forma narrativa (ex.: "você está ficando mais convincente ao ameaçar"),
  sem mostrar número. O jogador sente o progresso sem ver a planilha.
- **Sobem por uso, rápido** (~2 usos), pelos motivos já registrados em 4 (não dá pra
  farmar num mundo vivo; oportunidades são escassas).

**Como o motor sabe qual perícia subir:** cada ação/teste no conteúdo do jogo declara
qual perícia (interna) ela exercita. Ao testar, o motor identifica "isto foi um teste
de Intimidação" e incrementa o uso daquela perícia — tudo nos bastidores.

### Organização das perícias por atributo-base

As perícias são catalogadas pela categoria = **atributo-base que testam** (isso é
só organização; não muda a mecânica — a perícia sempre funciona como
`atributo-base + nível + 1d3`). Cada perícia tem seu **grind próprio** (quantos usos
para subir), definido MANUALMENTE — perícias diferentes sobem em ritmos diferentes
(ex.: Intimidação ~2 usos; Esgrima bem mais lenta, "não sobe a cada 2 espadadas",
porque dominar uma arma é ofício de anos). O grind reflete o realismo de cada perícia.

**Força**
- Arquearia — arcos de guerra medievais têm draw weight altíssimo; puxar é força bruta
  repetida (o longbowman inglês). Por isso: Força, não Agilidade.
- Artes marciais
- Acrobacia
- Atletismo
- Esportes

**Agilidade**
- Furtividade
- Furtar
- Arrombar
- Esgrima — combate com arma branca no jogo é técnica/precisão/timing, não força bruta.
- Armas de Haste
- (Nota: "Reflexos" foi deliberadamente NÃO incluída — seria redundante, já que é
  praticamente a definição do próprio atributo Agilidade.)

**Vitalidade**
- Tolerância — resistir a debuffs de dor e afins (aguentar castigo físico sem penalidade).
  Espelha a defesa mental da Força de Vontade, mas pro corpo: Tolerância resiste ao que
  ataca o CORPO (dor); defesa mental resiste ao que ataca a MENTE.
  (A definir: sobe por uso como habilidade normal — "endurece apanhando" — ou é uma
  resistência fixa que usa o valor base direto, como a defesa mental?)

**Carisma**
- Manipulação — dobrar o outro aos seus fins (frio, calculado).
- Intimidação — pela força/medo.
- Persuasão — pela razão/apelo honesto.
- Empatia — entender e ler as emoções alheias; conectar-se.
- Etiqueta — portar-se bem (protocolo, nobreza, causar boa impressão). Num mundo com
  Conselho/nobreza, abre portas que a força não abre.

**Inteligência**
- Ciência — método/empirismo; raro e valioso num mundo medieval.
- Ocultismo — conhecimento das verdades ocultas do mundo (vampiros, linhagens, Caim,
  deuses-conceito, o All-Being...). Saber a lore proibida. Poderoso e perigoso.
- Alquimia — poções, venenos, transmutação.
- Medicina — tratar ferimentos pela via HUMANA (cura sobrenatural é rara — era a
  disciplina extinta dos Sanatio; ver lore.md). O jeito mundano de curar.
- Investigação — juntar pistas, deduzir, notar o que está errado.

**Força de Vontade** — NÃO tem habilidades. É um atributo passivo/especial: define-se
apenas pelas suas funções (defesa mental + pool de rerroll). Ver a subseção própria em 4.

Categorias fechadas para o protótipo. **A definir por habilidade:** o atributo-base já
está dado pela categoria; falta o *grind* (usos→nível) de cada uma — definido manualmente,
varia por habilidade (ex.: Intimidação rápida; Esgrima lenta).

## 5. Recursos por Raça  🟡 (em construção, um par por vez)

Cada raça/existência sobrenatural tem um **par recurso & preço** (ver seção 4,
Atributos secundários) — o recurso é o que você gasta pra fazer coisas, o preço
é o que acumula como consequência. Os pares:

- 🩸 Vampiro — **Sangue & Humanidade**
- 🐺 Lobisomem — **Fúria & Umbra**
- 🌌 Mago — **Sonhos & Quebras**
- 👹 Abominação — **Ego & Corrupção**

**Escala do lado "recurso" (Sangue, Sonhos, Fúria, Ego):** mesma régua 0–10 dos
atributos gerais, MAS com um teto que pode ser menor que 10 dependendo do
indivíduo (ex.: um vampiro de geração baixa/"ralé" pode ter Sangue máximo 2,
não 10 — o teto varia por geração/linhagem, não é fixo pra raça inteira).
Exceção: **Ego não segue essa lógica.** Não é treinado nem tem teto variável —
todo Abominação **começa direto no 10** (é o poder mais forte que existe; não
faz sentido ele "subir").

### Ego & Corrupção (Abominação) — definido

- **Ego fixo em 10.** Não sobe por uso nem por nível; nasce no teto.
- **Usar o poder do Ego sobe Corrupção.** Mecanicamente, **custo fixo por uso**
  (a lore explica o preço como proporcional ao tamanho do que você nega ao
  destino, mas por gameplay foi simplificado pra um custo fixo — mais simples
  de balancear).
- **Corrupção é estritamente uma via — nunca desce.** Não existe cura,
  redenção ou reset. É um relógio que só anda pra frente.
- **Corrupção atinge 10 → morte permanente, total, sem volta.** Narrativamente
  é a fábula do personagem sendo apagada até a origem — a ponto de ele nunca
  ter existido. Não é "game over" comum: é permadeath de verdade (ver lore.md
  > Abominação/Ego).

### Humanidade — definido

**Todo ser TEM um valor de Humanidade** (0–10), mas ela só importa
mecanicamente de dois jeitos:
1. **Pro vampiro**, é o recurso-preço de verdade — afeta como ele joga (ver
   abaixo).
2. **Pra qualquer um** (humano, vampiro, mago, lobisomem...), é o número
   escondido que checa a elegibilidade ao poder **Sagrado** ao chegar em 10
   (ver `lore.md`: fé verdadeira e intensa gera Sagrado, independente de
   raça/religião — Humanidade 10 é a condição pra isso acontecer).

Pras raças que não são vampiro, Humanidade não gera os efeitos sociais abaixo
— quem cuida da vida social/percepção alheia delas é a **Reputação** (seção 7,
ainda ⚪), um sistema separado.

**Efeitos abaixo valem só pro VAMPIRO:**
- **Vampiro jogador começa em 7** no momento do Abraço. Antes disso, como
  humano, ações da campanha já podem subir ou descer esse valor — o Abraço não
  reseta pra um número fixo do nada, 7 é só o ponto de partida assumido pro
  protótipo.
- **Desce por:** diablerizar (**-1 fixo, permanente**, todo diablerie custa
  isso não importa o resto), matar sem motivo, e ações maldosas em geral
  (acumula tipo um contador — ex.: roubar também conta).
- **Sobe por:** age bondosamente (não detalhado ainda quanto/quais ações
  específicas contam — a definir quando a campanha for escrita).
- **Efeito gradual, narrativo (não é um "game over" ao zerar):** quanto mais
  baixa, menos empático o vampiro fica, mais distante das pessoas, mais os
  outros notam que tem algo estranho nele, mais difícil ser uma criatura
  sociável à noite. Segue o princípio "sinta pela narrativa" (ver Filosofia de
  Design).

### Sangue (Vampiro) — definido

- **Teto sempre 10**, igual aos atributos gerais — **geração NÃO reduz o teto**
  pro jogador (só Caim e os Iluminados da Sanatio escapam da régua 0-10 de
  vez, como lendas > 10; ver seção 4). Geração baixíssima/"ralé" com teto 2-3
  é coisa raríssima de NPC, não acontece com jogador.
- **Pool inicial: 5** (metade do teto).
- **Geração do jogador começa entre 6 e 8.** Não tem limite superior — quanto
  maior o número, mais "ralo"/fraco/próximo de humano o sangue fica (na régua
  extrema, tão diluído que o vampiro nem precisa mais se alimentar nem
  consegue transformar ninguém — muito além de 8, não é preocupação agora).
- **Diablerie baixa a geração** de quem consome até (no mínimo) a geração de
  quem foi consumido.
- **Cura gasta Sangue** (`ficha:modo_regen() == "escolha"`) e a quantidade de
  HP por ponto **escala inversamente com a geração** (mais perto de Caim =
  cura mais por ponto). Número exato é fator de balanceamento — fica ⚪ por
  ora, só a regra qualitativa já está valendo.

### Fúria (Lobisomem) — definido (qualitativamente; números ⚪)

- **Recurso ativo, gasto em combate.** Ao gastar, buffa os próprios ataques
  (dano/acerto/redução de dano) — quanto mais gasta de uma vez, maior o benefício.
  (Cogitou-se dar turnos extras, mas foi DESCARTADO por balanceamento — turno extra
  desequilibra combate por turnos; ver a decisão detalhada mais abaixo.)
- **Risco: Frenesi.** Gastar Fúria SEMPRE tem chance de gerar Frenesi (nunca é
  100% seguro), e esse risco:
  - **sobe** com o quanto é gasto NUMA jogada só (gastar muito de uma vez é
    mais arriscado que gastar pouco);
  - **desce** conforme a Fúria do personagem é mais alta (mais Fúria = mais
    controle, mais seguro gastar o mesmo tanto).
  - **Não é cumulativo dentro da mesma luta** — não tem "memória" de turnos
    anteriores; cada gasto é avaliado isolado, sem histórico pesando.
- **Frenesi (efeito):** perde o controle — pode atacar aliados, fugir da
  batalha, ou (fora de combate/escala maior) até dizimar um vilarejo.
- **Filosofia:** "tentador e recompensador" — poder real na mão, com um risco
  real, não decorativo.
- **Não tem base/pool separados como Vontade** — é o próprio atributo sendo
  gasto direto (como o Sangue do vampiro). Começa em **5**, teto **10**.
- **Recarrega em lua cheia, em momentos de estresse (dano crítico ou situações
  específicas) e a cada novo dia.** Implementado no motor só a função de
  recarregar (`ficha:recarregar_furia`) — os GATILHOS concretos (calendário,
  fases da lua, detectar "dano crítico") ainda não existem, porque o jogo
  ainda não tem sistema de dias/lua. Ninguém chama a função sozinho ainda.
- **Fórmula de risco (PROVISÓRIA, `core/ficha.lua:risco_frenesi`):**
  `risco = quanto_gasto / furia_atual` (antes do gasto), capado em 100%.
  Gastar tudo de uma vez sempre bate 100%. Já respeita as duas regras acima;
  ajustar depois de sentir jogando (tabela de probabilidade em `testes.lua`).
- **Buff de combate IMPLEMENTADO, versão PROVISÓRIA pra testar o recurso**
  (menu Habilidades, nas duas UIs). O jogador escolhe um NÍVEL de 1 a
  **`FURIA_GASTO_MAX` = 5** (teto por ativação — mesmo tendo mais de 5 de
  Fúria sobrando, não dá pra gastar mais que 5 de uma vez). O custo em Fúria
  é igual ao nível. **Dura `FURIA_DURACAO_TURNOS` = 3 turnos** (não é mais
  "só o próximo ataque" — ativar de novo enquanto já ativo SUBSTITUI nível e
  reinicia a duração, não acumula). **Sem turnos extras** — decidido que o
  recurso só afeta dano/acerto/redução de dano, nunca ações a mais.
  - **Tabela por nível, NÃO linear/cumulativa** (`ficha.FURIA_TABELA_DANO` /
    `FURIA_TABELA_REDUCAO`):

    | nível | dano  | acerto | dano tomado |
    |-------|-------|--------|--------------|
    | 1     | +3    | -1     | —            |
    | 2     | +4    | -1     | —            |
    | 3     | +5    | -1     | —            |
    | 4     | +5    | -1     | -3           |
    | 5     | +5    | -1     | -5           |

    O acerto é sempre -1 (não escala). O dano trava em +5 a partir do nível 3
    — o que os níveis 4 e 5 compram a mais é redução de dano TOMADO (tipo
    armadura temporária: não muda se te acertam, só quanto dói), não mais
    dano. É essa dualidade (ataque puro nos níveis baixos, ataque+defesa nos
    altos) que diferencia Fúria de Sangue — Sangue é recurso
    controlado/administrado (geração, disciplinas), Fúria é aposta com risco
    real (Frenesi) e a decisão de "quanto arriscar" a cada ativação.
  - O -1 de acerto reduz a MARGEM (que entra no dano total) — o efeito
    líquido no dano geralmente é um pouco menor que o bônus bruto da tabela,
    e em ataques na borda pode até empurrar de "total" pra "parcial" (pior).
    Intencional pela fórmula existente, não um erro.
  - **Frenesi IMPLEMENTADO (versão mínima), nas duas UIs.** Ao ativar Fúria,
    rola-se o risco (`ficha:rolar_frenesi`, sobre a Fúria atual, ANTES do gasto).
    Se disparar, o personagem **entra em Frenesi** (`entrar_frenesi`) e perde o
    CONTROLE por `FRENESI_DURACAO_TURNOS` = 2 turnos: o jogo ataca no automático
    (sem menu/esquiva/fuga) até passar. As versões ricas — atacar aliados, fugir,
    dizimar vilarejo — ficam pra quando existir esse conteúdo (não há aliados nem
    vilarejos jogáveis ainda).

### Umbra (Lobisomem) — implementado (esqueleto; conteúdo dos poderes ⚪)

- **Funciona como uma PERÍCIA, não como Fúria.** Não se gasta — só sobe, nunca
  desce. Representa a conexão/sintonia do lobisomem com a Umbra, o plano onde
  ficam Gaia e os espíritos da natureza (Gaia é, na prática, a religião dos
  lobisomens). Umbra alta destrava artefatos espirituais e poderes xamânicos
  (lista concreta ainda ⚪ — nenhum poder específico definido/implementado).
- **Escala 0–10, igual aos outros.** Todo lobisomem jogador **começa em 1**.
  Nenhuma outra raça pode ter Umbra (nem ganhar depois — é exclusivo da
  raça, ao contrário de Sangue/Sonhos que são consequência de uma
  transformação e por isso, em tese, outra raça poderia um dia adquirir).
- **Sobe por quests específicas de Gaia** (`ficha:ganhar_umbra`) — versão
  PROVISÓRIA: o método existe e funciona, mas nenhuma quest de verdade chama
  ele ainda (não há conteúdo de campanha ligado a isso). Comparável ao
  `core/tempo.lua`: mecanismo pronto, gatilho de conteúdo pendente.
- **REGRA GERAL DE VISIBILIDADE (vale pra todos os recursos secundários, não
  só Umbra):** "visibilidade segue a agência" (mesmo princípio já usado pras
  perícias comuns, seção 4.5). Fúria é VISÍVEL porque o jogador a controla
  ativamente (escolhe quanto gastar a cada ativação). Umbra, Humanidade e
  Quebras são OCULTAS — ninguém vê o número bruto, nem o vampiro vê sua
  própria Humanidade — porque sobem/descem como consequência de ações, não
  por escolha direta de "gastar X agora". O jogador sente o efeito pela
  narrativa (ex.: fica mais estranho, mais forte em rituais), nunca lê o
  valor cru.

### Sonhos (Mago) — implementado

- **Recurso ativo, é a mana.** Gasto pra manipular a realidade (ver `lore.md`
  > Magos). **Sem teto** (diferente de Sangue/Fúria), mas **nunca abaixo de
  1** (`ficha.SONHOS_MINIMO`) — o mago não "seca" de vez. Começa em **1**.
  `ficha:gastar_sonhos` / `ficha:recarregar_sonhos` / `ficha:sonhos_atual`.

### Quebras (Mago) — implementado (esqueleto do motor; conteúdo dos debuffs ⚪)

- **Sobe em FALHA FEIA de conjuração** (`core/magia.lua:conjurar`) — não é
  qualquer falha. Fórmula do teste: `sonhos_atual (DEPOIS de pagar o custo)
  + vontade + 1d3`, comparado com a `dif` da magia. Falha = resultado < dif.
  - **INTENCIONAL: magia cara é mais difícil de acertar.** Como o Sonhos que
    SOBRA (pós-custo) entra no teste, gastar muito te deixa "no limite" e
    derruba a própria chance. Somado ao fato de que falha feia de magia cara
    gera MAIS Quebras, a magia poderosa pune duas vezes (difícil de acertar +
    dói mais ao errar). É a lore em mecânica ("quanto maior o rasgo, mais a
    realidade cobra") e premia o mago comedido — que acumula Sonhos antes da
    magia grande — em vez do afoito (ecoa "os melhores magos usam magia de
    forma mínima").
  **Falha FEIA** = errou por MAIS que metade da dificuldade (arredondada pra
  baixo) — errar por pouco ("quase passei") não gera Quebras.
- **Quantidade de Quebras por falha feia escala com o CUSTO da magia**, em
  degraus de 5 (`magia.quebras_por_falha`): custo 1-5 → 1 Quebra; 6-10 → 2;
  11-15 → 3; sucessivamente. Magia mais cara falhada dói mais.
- **Pode DESCER com o tempo** (`ficha:reduzir_quebras`), diferente da
  Corrupção (que só sobe) — se o mago passa um tempo sem tomar Quebras
  novas, ela se reduz sozinha (taxa/gatilho exatos ⚪, só o mecanismo existe).
- **Teto 10 → Cemitério dos Sonhos, permadeath total** (`ficha:no_cemiterio_dos_sonhos`;
  ver `lore.md` > Mundus/Cemitério dos Sonhos) — mesmo desfecho fatal do
  Ego/Corrupção, mas chegar lá é reversível ao longo do caminho (Quebras
  desce), diferente da Corrupção (que nunca desce).
- **Efeito é ALEATÓRIO, mas a gravidade escala com quanto se ganha DE UMA
  VEZ** (não com o total acumulado): 1 Quebra ganha de uma vez é sempre algo
  leve — dano ou um debuff (alucinação/envelhecimento). Ganhar 2+ de uma vez
  (magia mais cara falhada feio) pode ser bem maior — incluindo o
  **Paradoxo**: um clone maligno do próprio mago se forma e ataca a reputação
  do jogador (não o personagem em si — é meta, mira o jogador). Lista de
  debuffs possíveis: dano, alucinações, envelhecimento, pesadelos, Paradoxo.
  A definir: tabela de sorteio exata (chance de cada um por quantidade
  ganha) — ainda NÃO implementado, só o número de Quebras ganhas está pronto.

### `core/magia.lua` e `data/magias.lua` — motor pronto, conteúdo em aberto

`core/magia.lua` resolve uma conjuração (espelha `core/combate.lua`):
`magia.conjurar(conjurador, feitico, rng)` devolve se conjurou, se foi falha
feia, e quantas Quebras gerou (já aplicadas na ficha). `data/magias.lua` é o
catálogo data-driven (`nome`, `custo`, `dif` por magia) — **propositalmente
vazio**, o conteúdo das magias é criativo e fica por conta de quem escreve.

## 6. Combate por Turnos  🟢 (esqueleto)

Objetivo do protótipo: um combate MÍNIMO jogável — você e um inimigo alternando turnos.
Mesma mecânica pra jogador e inimigos (simétrica). Reaproveita o motor de teste (seção 4).

### Ações do jogador no turno
- **Atacar**
- **Esquivar** (teste de Agilidade)
- **Fugir**
- *(NÃO há "Defender" — a defesa é passiva/automática: bloquear já acontece sozinho
  quando o atacante não supera a defesa; ver abaixo.)*

### Defesa (passiva, do alvo)
- **Defesa = Agilidade + 2** (talvez +1 — decidir jogando qual "sente" melhor).
- **Armadura NÃO dá defesa.** Armadura apenas **reduz o dano tomado** (lógica pura:
  não te faz mais difícil de acertar, te faz sofrer menos quando acertam).

### Resolução do ataque
Rola-se o teste de ataque (mesma fórmula da seção 4):

    ataque = atributo + habilidade_da_arma + 1d3

Compara-se com dois números: a **diff da arma** (piso) e a **defesa do alvo** (teto).
Cada arma tem uma **diff própria e SECRETA** (analisar a arma não a revela). Faixas:

    ataque ≤ diff_da_arma          → ERRO (0 dano) — nem manejou o golpe
    diff < ataque ≤ defesa_alvo    → PARCIAL (dano muito reduzido; anti-frustração)
    ataque  >  defesa_alvo         → ACERTO TOTAL (dano cheio, escala com o sucesso)

Regras dos empates (ambos os limiares são "estritamente maior"):
- Tirar exatamente a **diff da arma** = ainda é ERRO (precisa passar dela).
- Tirar exatamente a **defesa** = PARCIAL, não total ("a defesa ganha os empates").

*Exemplo:* adaga diff 1, inimigo defesa 3.
`0–1` → 0 dano · `2` → parcial · `3` → parcial (empate, defesa ganha) · `4+` → total.

### Dano (no ACERTO TOTAL)

    dano = dano_base_da_arma + margem + atributo_utilizado
    margem = ataque − defesa (o quanto superou)

- Liga o dano ao personagem (um forte bate muito mais forte com a mesma arma).
- A margem adiciona imprevisibilidade (raspão vs. golpe perfeito) — evita o "5 de dano
  todo turno".
- **Dano PARCIAL (implementado):** `floor((dano_base + atributo + bonus_forma) * 0.25)`,
  mínimo 1 (sem a margem — é um golpe raso, não escala com o quanto passou da diff).
  Constante em `core/combate.lua` (`FRACAO_PARCIAL`).

### HP e regeneração
- **HP = base_da_raça + (Vitalidade × 2).** Base padrão **10**; o **lobisomem** é mais
  resistente: base **15**. (Vampiro/mago/humano = 10.) Ex.: humano Vit 2 → 10+4 = 14;
  lobisomem Vit 2 → 15+4 = 19. O **HP é SECRETO** (o jogador não vê número nem barra;
  sente pela narrativa, como as perícias).
- **Raças sobrenaturais se REGENERAM — mas cada uma de um jeito** (e o modo puxa o
  recurso-preço da raça):
  - 🐺 **Lobisomem — PASSIVA.** Regenera sozinho, de graça, a cada turno de combate:
    **teto(nível / 2)** de HP por turno (nível de personagem, 1–10). Ex.: nível 1–2 → 1;
    3–4 → 2; …; 9–10 → 5. O mais resistente.
  - 🧛 **Vampiro — ESCOLHE.** Regenerar é uma ação deliberada e custa **Sangue** (o recurso
    dele). Controla a cura, mas paga por ela.
  - 🌌 **Mago — via MAGIA, com cuidado.** Curar-se é rasgar a realidade → acumula **Quebras**
    (o preço). Exagerar leva a dano/envelhecimento/morte/Cemitério dos Sonhos. Regeneração
    poderosa, porém perigosa.
- **Humano NÃO regenera** = o modo HARDCORE na prática. Mesmo HP, mas cada ponto perdido
  fica. Precisa ser cirúrgico: evitar dano, não trocar golpes. Sua única "cura" é a
  habilidade **Medicina** (Inteligência) — a via humana e trabalhosa de se tratar.

**Esquivar (implementado):** teste de Agilidade (dificuldade 4, `core/teste.lua`); se
passa, cancela o contra-ataque do inimigo naquele turno (`combate_ui.lua`).

A definir: ritmo/taxa exata de recarga da regeneração fora do combate; lista completa
de armas (dano base + diff secreta + atributo de cada) além do que já existe em
`data/armas.lua`.

## 6.5. Formas do Lobisomem  🟡 (esqueleto no menu "Habilidades")

Acessadas pelo menu **Habilidades** em combate. A lista é dinâmica: em forma humana
mostra as feras; transformado, mostra "Humanóide" (voltar). Transformar consome o turno.

- **Humanóide** — forma humana/base.
- **Crino** — bípede humanoide (o "homem-lobo"). **Pode usar armas** (tem mãos hábeis).
- **Lupino** — lobo grande, quadrúpede. **NÃO usa armas** (ataca com o corpo).
- **Bestial** — algo maior e torto, tipo wendigo bestial. **NÃO usa armas** (ataca com o corpo).

As formas NÃO têm o mesmo peso. Humanóide e Lupino são as formas "base" (equivalentes
em poder — diferem só no formato social: humanóide entre humanos, lupino entre lobos).
Crino e Bestial são as formas de COMBATE, mais poderosas.

Efeito mecânico FINAL pretendido (buffs E debuffs multi-atributo por forma):
- 🦌 **Bestial**: +Agilidade, +acerto, **−Inteligência**.
- 🧍‍🦰 **Crino**: +dano, **−controle / Força de Vontade**.
- 🐺 **Lupino** e 🧍 **Humanóide**: formas base, sem bônus de combate.

Efeito mecânico PROVISÓRIO (implementado agora, só pra testar):
- Crino e Bestial: **+2 de acerto** (soma no teste, facilita superar a defesa → mais
  acertos totais) e **+2 de dano**. Lupino e Humanóide: sem bônus.
- Lupino/Bestial, por não usarem armas, atacam com **arma natural** (garras base 3 /
  presas base 4). No protótipo, usam garras por padrão.

A definir: os buffs/debuffs multi-atributo por forma; a escala por Fúria (substituirá
os bônus fixos).

## 6.7. Interação com Cenas (primário → secundário)  🟢

Gramática de interação do jogo (fora de combate). Cada cena é um conjunto de
**objetos observáveis**; a interação é hierárquica em dois níveis:

- **PRIMÁRIO — observar (grátis).** Olhar/examinar/aproximar-se de um objeto. Quase
  nunca gasta tempo (exceções pontuais, ex.: combate). Serve pra entender o ambiente,
  descobrir o que existe e **destravar** as ações secundárias daquele objeto.
- **SECUNDÁRIO — agir (custa tempo).** Bater, revirar, quebrar, pegar, forçar... Quase
  sempre gasta 1 ação (avança o relógio). É o que muda o estado do mundo.

Fluxo: o jogador vê a **lista de objetos** → escolhe um pra **olhar** (grátis: descreve +
revela as ações possíveis nele) → aparece o **submenu de ações** daquele objeto (essas
custam tempo) → após olhar/agir, volta à lista de objetos. Navegar/observar é sempre
livre; só a ação secundária faz o tempo andar.

Os secundários **evoluem com o estado**: ex., "Bater na parede" (inútil) vira "Bater com
o martelo" (progride) depois que o jogador acha o martelo. O mesmo objeto oferece ações
diferentes conforme o que se tem/sabe.

Recompensa pensar antes de agir (examinar tudo de graça, planejar, executar certeiro) e
pune o afobado (sair revirando/batendo gasta ações preciosas à toa). Primeira cena a usar
isto: a Masmorra (tutorial). É o molde pras cenas futuras.

## 7. Reputação  ⚪
_A definir._

## 8. Transformações (destino do personagem)  ⚪
_(humano → vampiro/mago; lobisomem → vampiro = Abominação) — a definir._
