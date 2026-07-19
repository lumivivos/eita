-- core/ficha.lua
-- A "estrutura do ser": atributos e Força de Vontade de um personagem.
-- (ver sistemas.md > Atributos e > Força de Vontade)
--
-- Combate, transformações e testes vão operar sobre uma ficha. Por enquanto
-- cobre só o que já está definido no design.

local niveis = require("core.niveis")

local ficha = {}
ficha.__index = ficha

-- Os 6 atributos gerais. Escala 0..10 (0 é reservado ao All-Being; ver design).
ficha.ATRIBUTOS = {
  "forca", "vitalidade", "agilidade", "carisma", "inteligencia", "vontade",
}

-- Nomes bonitos pra exibição (o motor usa a chave; a UI usa o rótulo).
ficha.ROTULOS = {
  forca = "Força",
  vitalidade = "Vitalidade",
  agilidade = "Agilidade",
  carisma = "Carisma",
  inteligencia = "Inteligência",
  vontade = "Força de Vontade",
}

-- Modo de regeneração por raça (ver sistemas.md > Combate). Cada raça cura de
-- um jeito diferente, e o modo puxa o recurso-preço da raça:
--   "passiva"  -> regenera sozinho, de graça (lobisomem)
--   "escolha"  -> ação deliberada, custa Sangue (vampiro)
--   "magia"    -> via magia, gera Quebras/risco (mago)
--   "nenhuma"  -> não regenera; modo hardcore (humano)
-- A Abominação NÃO entra aqui: é outra categoria de existência (ver lore.md /
-- a nota em HP_BASE). Terá regras próprias, não "regeneração de mortal".
ficha.REGEN_POR_RACA = {
  lobisomem = "passiva",
  vampiro = "escolha",
  mago = "magia",
  humano = "nenhuma",
}

-- Cria uma ficha nova.
--   attrs = tabela {forca=?, vitalidade=?, ...}. Faltando algum, assume 2
--           (humano adulto comum, o "chão" da escala). Exceção: vontade começa
--           em 5 (escala própria; ver design).
--   raca  = "humano" (padrão), "vampiro", "lobisomem", "mago".
--           (A Abominação é outra categoria de existência — ver lore.md — e não
--            é tratada como raça mortal comum aqui.)
-- Inicializa os recursos ESPECÍFICOS de raça (Fúria/Umbra, Sonhos/Quebras,
-- Sangue/Geração...) na ficha `self`, dado `attrs` (mesma tabela de
-- ficha.nova). Extraído à parte pra ser reaproveitado tanto na criação
-- (ficha.nova) quanto numa transformação posterior (ficha:transformar_raca) —
-- ver data/racas.lua: vampiro/mago não são pontos de partida, só destinos.
local function iniciar_recursos_raca(self, attrs)
  -- Fúria (só lobisomem; ver sistemas.md > Recursos por Raça > Fúria).
  -- Diferente de Vontade: não tem base/pool separados, o valor É o gasto
  -- (como o Sangue do vampiro). nil pras demais raças (não tem Fúria).
  if self.raca == "lobisomem" then
    self.furia = ficha.FURIA_INICIAL
    -- Umbra: conexão/sintonia com Gaia e os espíritos da natureza (ver
    -- sistemas.md > Recursos por Raça > Umbra). Diferente de Fúria: NÃO se
    -- gasta, é um valor OCULTO que só sobe (como perícia — sobe por uso,
    -- aqui por quests específicas de Gaia). Só lobisomem tem; nenhuma outra
    -- raça pode ganhar Umbra.
    self.umbra = ficha.UMBRA_INICIAL
  elseif self.raca == "mago" then
    -- Sonhos & Quebras (só mago; ver sistemas.md > Recursos por Raça).
    -- Sonhos = mana (sem teto, mas nunca abaixo de SONHOS_MINIMO). Quebras =
    -- preço acumulado por falha feia de conjuração (0-10; 10 = Cemitério dos
    -- Sonhos, permadeath).
    -- Sonhos inicial = o que já foi CONQUISTADO antes de virar mago (matar,
    -- explorar, quest — ver ficha:ganhar_conquista), nunca abaixo do piso
    -- SONHOS_INICIAL. Quem nunca conquistou nada ainda começa exatamente no
    -- piso (preso, sem conseguir gastar nada — ver sistemas.md; é o preço de
    -- virar mago sem ter feito nada antes).
    self.sonhos = math.max(ficha.SONHOS_INICIAL, self.conquistas or 0)
    self.quebras = 0
    -- Conceitos mágicos aprendidos (ids de data/conceitos.lua) e magias
    -- fundidas a partir deles (ver seção Conceitos & Fusão adiante). Começam
    -- vazios: o mago nasce sabendo NADA e escolhe o que aprender ao subir.
    self.conceitos = {}          -- id_do_conceito -> true (conjunto)
    self.magias_fundidas = {}    -- lista de magias criadas (ver magia.fundir)
    -- Créditos de conceito ainda não gastos (ganha 1 a cada N níveis; ver
    -- CONCEITO_A_CADA_N_NIVEIS). Escolher QUAL conceito é ação do jogador.
    self.conceitos_pendentes = 0
  elseif self.raca == "vampiro" then
    -- Sangue & Geração (só vampiro; ver sistemas.md > Recursos por Raça).
    -- Sangue = poder/sustento (gasto em estigmas e Elevação). Geração =
    -- distância de Caim (quanto MENOR, mais forte); diablerizar reduz.
    self.sangue = ficha.SANGUE_INICIAL
    -- attrs.geracao permite fixar (ex.: NPCs específicos); jogador começa
    -- entre 6-8 — quem cria a ficha escolhe onde nessa faixa (sem random
    -- aqui dentro, pra manter ficha.nova determinística; ver design).
    self.geracao = attrs.geracao or 7
  end
end

function ficha.nova(attrs, raca)
  attrs = attrs or {}
  local self = setmetatable({}, ficha)
  self.raca = raca or "humano"
  self.atributos = {}
  for _, nome in ipairs(ficha.ATRIBUTOS) do
    -- vontade tem chão próprio (5); os demais, 2.
    local padrao = (nome == "vontade") and 5 or 2
    self.atributos[nome] = attrs[nome] or padrao
  end
  -- Força de Vontade tem DUAS camadas (ver design):
  --   base  = atributo "vontade" -> resistência mental (estável, é o máximo)
  --   pool  = pontos gastáveis pra rerrolar; começa cheio (= base)
  self.vontade_pool = self.atributos.vontade
  -- Conquistas: contador UNIVERSAL (toda raça acumula, mesmo quem nunca vira
  -- mago) — matar algo, explorar, completar quest, etc, cada evento soma 1
  -- (ver ficha:ganhar_conquista). Tem que existir ANTES de
  -- iniciar_recursos_raca: o mago usa esse acumulado como Sonhos inicial (ver
  -- lá embaixo) — as conquistas de quando ainda era humano/lobisomem "viram"
  -- Sonhos no momento da transformação (ecoa lore.md > Magos: os Sonhos já
  -- observam quem é apto antes da pessoa saber).
  self.conquistas = attrs.conquistas or 0
  iniciar_recursos_raca(self, attrs)
  -- Humanidade é UNIVERSAL — todo ser tem (ver sistemas.md > Humanidade). O
  -- número em si (0-10) e as marcações valem pra qualquer raça; o que é só do
  -- vampiro é o EFEITO (debuffs por Humanidade baixa — ainda ⚪). Todos começam
  -- em 7: 10 não é ponto de partida (seria o Sagrado de graça — ver
  -- elegivel_sagrado), é conquista rara.
  self.humanidade = ficha.HUMANIDADE_INICIAL
  -- Marcações rumo à PRÓXIMA queda de Humanidade (acumula até
  -- MARCACOES_POR_HUMANIDADE, aí cai 1 e zera). Começa em 0.
  self.marcacoes = 0
  self.pericias = {}   -- nome -> nível (sobem por uso; vazio no início)
  -- Nível de personagem (1..10, mesmo teto dos atributos). Sobe por EXP (raro).
  self.nivel = attrs.nivel or 1
  self.exp = 0   -- EXP acumulado RUMO ao próximo nível (zera ao subir)
  -- Forma atual. Só o lobisomem transforma; começa (e todos ficam) em "humanoide".
  self.forma = "humanoide"
  -- Besta: a "força animadora" que TODO ser tem (ver sistemas.md > Estigmas
  -- > Besta). Igual em todos (10) — a diferença de poder vem dos atributos, não
  -- da Besta. Alvo do estigma Besta do vampiro (remover/absorver ⚪). Zerá-la
  -- = "só carne". Universal de propósito: qualquer criatura pode ser alvo.
  self.besta = ficha.BESTA_INICIAL
  -- HP começa cheio.
  self.hp = self:hp_max()
  -- Sincroniza o estado inicial do Sagrado (ver _atualizar_sagrado). Sem isto,
  -- uma ficha criada JÁ em Humanidade 10 (ex.: NPC santo) só reconheceria o
  -- Sagrado na próxima mudança de Humanidade — aqui garante que o ponto de
  -- partida já está correto.
  self:_atualizar_sagrado()
  return self
end

-- Transforma uma ficha JÁ EXISTENTE em outra raça (ver data/racas.lua:
-- vampiro/mago não são pontos de partida, só destinos — chega-se a eles
-- vivendo, não escolhendo na criação). Ao contrário de ficha.nova, PRESERVA
-- tudo que o personagem já é (atributos, nível/exp, perícias, Humanidade,
-- HP, forma, Besta, Vontade) — só a raça muda, e com ela os recursos
-- específicos dela (iniciados do zero, como se nascessem agora).
--   nova_raca = "vampiro" ou "mago" (as duas transformações jogáveis hoje).
--   attrs     = opcional; só usado por campos específicos da raça (ex.:
--               {geracao = N} pro vampiro — ver iniciar_recursos_raca).
-- Recusa (false + motivo) se a transformação violar a lore: vampiro e
-- lobisomem NUNCA viram mago — os Sonhos só buscam quem ainda é humano (ou
-- animal), nunca quem já é outra coisa sobrenatural (ver lore.md > Raças).
-- Devolve true em qualquer transformação aceita.
function ficha:transformar_raca(nova_raca, attrs)
  if nova_raca == "mago" and (self.raca == "vampiro" or self.raca == "lobisomem") then
    return false, "vampiro e lobisomem nunca viram mago (ver lore.md > Raças)"
  end
  self.raca = nova_raca
  iniciar_recursos_raca(self, attrs or {})
  -- HP_BASE de humano/vampiro/mago é o mesmo (10), então não há reajuste de
  -- teto aqui — mas clampar é seguro caso isso mude no futuro.
  self.hp = math.min(self.hp, self:hp_max())
  return true
end

-- Teto de nível de personagem (mesma régua dos atributos).
ficha.NIVEL_MAX = 10

-- ---- Progressão: EXP e níveis ---------------------------------------------

-- Ganha EXP rumo ao próximo nível. Devolve QUANTOS níveis "estouraram"
-- (ficaram prontos pra subir). NÃO aplica os pontos de atributo sozinho —
-- subir de nível é uma ESCOLHA do jogador (quais 2 atributos), então isto só
-- acumula e sinaliza. O EXP que sobra fica guardado rumo ao nível seguinte.
--
-- Devolve: n_prontos = quantas vezes cruzou o limiar (0 se nenhum).
function ficha:ganhar_exp(quanto)
  local prontos = 0
  self.exp = self.exp + (quanto or 0)
  while not niveis.no_teto(self.nivel + prontos) do
    local custo = niveis.custo_degrau(self.nivel + prontos)
    if self.exp >= custo then
      self.exp = self.exp - custo
      prontos = prontos + 1
    else
      break
    end
  end
  self.niveis_pendentes = (self.niveis_pendentes or 0) + prontos
  return prontos
end

-- Há níveis conquistados aguardando o jogador distribuir os pontos?
function ficha:tem_nivel_pendente()
  return (self.niveis_pendentes or 0) > 0
end

-- Sobe UM nível pendente, aplicando +1 em DOIS atributos diferentes.
-- `attr_a` e `attr_b` são chaves de atributo (ex.: "forca", "agilidade").
-- Regras (ver design): precisam ser DIFERENTES; não passam do teto 10; e o
-- nível não passa de MAX. Devolve true se subiu, false + motivo se recusou.
function ficha:subir_nivel(attr_a, attr_b)
  if not self:tem_nivel_pendente() then
    return false, "sem nível pendente"
  end
  if niveis.no_teto(self.nivel) then
    return false, "já no teto"
  end
  if attr_a == attr_b then
    return false, "os dois pontos devem ir em atributos diferentes"
  end
  if self.atributos[attr_a] == nil or self.atributos[attr_b] == nil then
    return false, "atributo inválido"
  end
  if self.atributos[attr_a] >= 10 or self.atributos[attr_b] >= 10 then
    return false, "atributo no teto (10)"
  end
  self.atributos[attr_a] = self.atributos[attr_a] + 1
  self.atributos[attr_b] = self.atributos[attr_b] + 1
  self.nivel = self.nivel + 1
  self.niveis_pendentes = self.niveis_pendentes - 1
  -- Mago: a cada N níveis, ganha um crédito pra aprender um conceito novo
  -- (ver Conceitos & Fusão). Concedido AQUI, ao cruzar o nível, pra alinhar
  -- com "subir de nível é um fenômeno" — descobrir uma nova verdade do mundo.
  if self.raca == "mago" and self.nivel % ficha.CONCEITO_A_CADA_N_NIVEIS == 0 then
    self.conceitos_pendentes = (self.conceitos_pendentes or 0) + 1
  end
  return true
end

-- ---- Conquistas (universal — toda raça acumula) ---------------------------
-- Contador de eventos "vividos de verdade": matar algo, explorar um local,
-- completar uma quest, etc. UNIVERSAL — toda ficha tem, mesmo quem nunca vira
-- mago (humano/lobisomem/vampiro acumulam do mesmo jeito, só não usam pra
-- nada ainda). É a via de progressão dos Sonhos do mago (ver
-- iniciar_recursos_raca): o que já foi conquistado ANTES de virar mago vira o
-- Sonhos inicial; e se JÁ é mago, cada conquista nova vira Sonhos na hora.
-- Cada conquista vale exatamente 1, INDEPENDENTE de quanto EXP aquele mesmo
-- evento também conceda (EXP e conquista são contadores separados, mesmo
-- compartilhando o gatilho) — mantém Sonhos numa escala pequena e densa,
-- sem herdar a escala grande do EXP (que chega a centenas).

-- Quantas conquistas o personagem já teve (nunca desce).
function ficha:conquistas_atual()
  return self.conquistas or 0
end

-- Registra uma conquista. `quanto` (opcional, padrão 1) existe só por
-- flexibilidade futura — hoje todo chamador deve passar 1 (ou nada), já que
-- "cada conquista vale 1" é a regra confirmada.
function ficha:ganhar_conquista(quanto)
  quanto = quanto or 1
  self.conquistas = (self.conquistas or 0) + quanto
  -- Se já é mago, a conquista vira Sonhos IMEDIATAMENTE (a via real de
  -- progressão do recurso — ver sistemas.md > Sonhos). Se ainda não é mago,
  -- só acumula no contador universal, que "destrava" como Sonhos no momento
  -- de virar (ver iniciar_recursos_raca). recarregar_sonhos já é seguro pra
  -- quem não tem Sonhos (nil-safe, vira no-op).
  self:recarregar_sonhos(quanto)
  return self.conquistas
end

-- HP base por raça MORTAL. Padrão 10; lobisomem é mais resistente (15).
-- NOTA: a Abominação NÃO entra aqui de propósito. Ela não é um mortal — é
-- outra categoria de existência (o auge do poder da obra, "ser 4D", supera a
-- Mundus; ver lore.md). Está fora da régua mortal e terá tratamento próprio
-- quando/se for implementada. Não colocar base "mortal" nela.
ficha.HP_BASE = {
  humano = 10,
  lobisomem = 15,
  vampiro = 10,
  mago = 10,
}
ficha.HP_BASE_PADRAO = 10

-- HP máximo = base_da_raça + Vitalidade*2 (ver sistemas.md). SECRETO na UI.
function ficha:hp_max()
  local base = ficha.HP_BASE[self.raca] or ficha.HP_BASE_PADRAO
  return base + self.atributos.vitalidade * 2
end

-- Defesa passiva = Vitalidade + 2 (ver sistemas.md).
function ficha:defesa()
  return self.atributos.vitalidade + 2
end

-- Aplica dano (nunca deixa HP abaixo de 0). Devolve o HP restante.
function ficha:sofrer(dano)
  self.hp = math.max(0, self.hp - (dano or 0))
  return self.hp
end

-- Aplica dano de FONTE SAGRADA (ver core/sagrado.lua). Diferente de sofrer():
-- a ferida deixa uma marca (`dano_sagrado`) que TRAVA um pedaço do teto de
-- cura SOBRENATURAL (regen passiva, Sangue, magia...) — só cura de jeito
-- mundano (ex.: Medicina — ⚪, ainda não implementada) reduz a marca em si
-- (ver reduzir_dano_sagrado). A marca nunca passa do teto de HP.
function ficha:sofrer_sagrado(dano)
  self:sofrer(dano)
  self.dano_sagrado = math.min(self:hp_max(), (self.dano_sagrado or 0) + (dano or 0))
  return self.hp
end

-- Quanto de dano sagrado ainda está "travado" (não curável por meios
-- sobrenaturais).
function ficha:dano_sagrado_atual()
  return self.dano_sagrado or 0
end

-- Reduz a marca de dano sagrado (cura MUNDANA — ex.: Medicina, tempo — ainda
-- ⚪, só o mecanismo existe). Nunca abaixo de 0.
function ficha:reduzir_dano_sagrado(quanto)
  self.dano_sagrado = math.max(0, (self.dano_sagrado or 0) - (quanto or 0))
  return self.dano_sagrado
end

-- Teto que a cura SOBRENATURAL não pode passar (hp_max menos o que estiver
-- travado por dano sagrado). Cura mundana (fora do escopo de hoje) ignoraria
-- isto e usaria hp_max direto. Nunca negativo: se o hp_max CAIR depois da
-- ferida (ex.: reverter Elevação de Vitalidade), dano_sagrado pode ficar
-- "acima" do hp_max atual — sem o clamp, math.min(negativo, hp+cura) faria
-- uma "cura" reduzir o HP.
function ficha:teto_cura_sobrenatural()
  return math.max(0, self:hp_max() - self:dano_sagrado_atual())
end

-- O modo de regeneração desta ficha ("passiva"/"escolha"/"magia"/"nenhuma").
function ficha:modo_regen()
  return ficha.REGEN_POR_RACA[self.raca] or "nenhuma"
end

-- Regenera HP. Nunca passa do teto de cura SOBRENATURAL (ver
-- teto_cura_sobrenatural — dano sagrado trava uma parte). Só cura se a raça
-- regenera (modo ≠ "nenhuma"). NOTA: o custo/preço de cada modo (Sangue do
-- vampiro, Quebras do mago) será aplicado pela camada que CHAMA isto, quando
-- os recursos de raça existirem — aqui só tratamos o HP. Devolve o HP após
-- regenerar.
function ficha:regenerar(quanto)
  if self:modo_regen() ~= "nenhuma" then
    self.hp = math.min(self:teto_cura_sobrenatural(), self.hp + (quanto or 0))
  end
  return self.hp
end

-- Quanto esta ficha recupera passivamente por turno de combate.
-- Só o lobisomem (regen "passiva") cura sozinho: teto(nível / 2). Demais = 0
-- (vampiro/mago regeneram por escolha/magia, não de graça; humano não regenera).
function ficha:regen_por_turno()
  if self:modo_regen() == "passiva" then
    return math.ceil(self.nivel / 2)
  end
  return 0
end

-- Aplica a regeneração passiva de um turno (o combate chama isto por turno).
-- Devolve quanto curou (0 se não houver).
function ficha:regenerar_turno()
  local cura = self:regen_por_turno()
  if cura > 0 then
    local antes = self.hp
    self.hp = math.min(self:teto_cura_sobrenatural(), self.hp + cura)
    return self.hp - antes
  end
  return 0
end

-- Está vivo?
function ficha:vivo()
  return self.hp > 0
end

-- Valor de um atributo.
function ficha:attr(nome)
  return self.atributos[nome] or 0
end

-- Nível de uma perícia (0 se nunca usada/aprendida).
function ficha:pericia(nome)
  return self.pericias[nome] or 0
end

-- ---- Perícias (aptidões mundanas, sobem por uso) ---------------------------
-- Ver sistemas.md > Perícias. Perícia ≠ poder de raça — sobe por USO, rápido
-- (diferente de atributo, que sobe por nível/EXP). Cada perícia tem seu
-- próprio "grind" (quantos usos pra subir 1 nível), catalogado em
-- data/pericias.lua; perícia fora do catálogo usa o padrão abaixo. Sem teto
-- (perícia não segue a régua 0-10 dos atributos; teto ainda não definido).

ficha.PERICIA_USOS_PADRAO = 5  -- grind padrão pra perícia sem entrada no catálogo (provisório)

-- Quantos usos essa perícia precisa pra subir 1 nível. Consulta
-- data/pericias.lua sob demanda (mesmo padrão de forma_atual com
-- data/formas, pra evitar dependência circular no topo do arquivo).
local function pericia_grind(nome)
  local cat = require("data.pericias")
  local entrada = cat[nome]
  return (entrada and entrada.grind) or ficha.PERICIA_USOS_PADRAO
end

-- Registra 1 uso de uma perícia. QUALQUER tentativa conta, mesmo um erro —
-- "cada uso... faz progredir" (ver sistemas.md), não só sucesso. Acumula um
-- contador de uso por perícia; ao bater o grind daquela perícia, sobe 1
-- nível e ZERA o contador (mesmo padrão de ficha:marcar_humanidade — acumula
-- até o limiar, aí converte e reinicia). Devolve true se subiu de nível
-- agora (pra quem chama decidir se narra a evolução — ver sistemas.md:
-- "a evolução É anunciada", gatilho de texto ainda ⚪, só o mecanismo existe).
function ficha:usar_pericia(nome)
  if not nome then return false end
  self.pericias_uso = self.pericias_uso or {}
  self.pericias_uso[nome] = (self.pericias_uso[nome] or 0) + 1
  if self.pericias_uso[nome] >= pericia_grind(nome) then
    self.pericias_uso[nome] = 0
    self.pericias[nome] = (self.pericias[nome] or 0) + 1
    return true
  end
  return false
end

-- ---- Formas (lobisomem) ---------------------------------------------------

-- Está em forma humana/base?
function ficha:eh_humanoide()
  return self.forma == "humanoide"
end

-- Assume uma forma.
function ficha:transformar(id_forma)
  self.forma = id_forma
end

-- Dados da forma atual (tabela de data/formas.lua). Carregado sob demanda pra
-- evitar dependência circular no topo.
function ficha:forma_atual()
  return require("data.formas")[self.forma]
end

-- A forma atual pode empunhar armas? (Lupino/Bestial não.)
function ficha:usa_armas()
  local f = self:forma_atual()
  return f == nil or f.usa_armas ~= false
end

-- Bônus de dano concedido pela forma atual (0 se humano/humanoide).
function ficha:bonus_dano_forma()
  local f = self:forma_atual()
  return (f and f.bonus_dano) or 0
end

-- Bônus de acerto concedido pela forma atual — soma no teste de ataque
-- (0 se humano/humanoide/lupino).
function ficha:bonus_acerto_forma()
  local f = self:forma_atual()
  return (f and f.bonus_acerto) or 0
end

-- ---- Fúria (lobisomem) -----------------------------------------------------
-- Recurso ativo gasto em combate (ver sistemas.md > Recursos por Raça >
-- Fúria). Ativar dá um buff de N turnos (dano/acerto sempre; redução de dano
-- tomado só nos níveis mais altos) à custa de RISCO DE FRENESI: quanto mais
-- você gasta de uma vez e quanto MENOS Fúria sobra, mais perigoso. Começa em
-- 5, teto 10 (mas só dá pra gastar até FURIA_GASTO_MAX por ativação, mesmo
-- tendo mais que isso sobrando). Recarrega em lua cheia / momentos de
-- estresse (dano crítico etc.) / a cada novo dia — gatilhos concretos ainda
-- não existem no motor (não há calendário/lua ainda), por isso só a função
-- de recarregar está pronta, sem ninguém chamando-a automaticamente ainda.
-- SEM TURNOS EXTRAS — decisão de design: o recurso só afeta dano/acerto/
-- redução de dano, nunca ações a mais por turno.

ficha.FURIA_INICIAL = 5
ficha.FURIA_MAX = 10
ficha.FURIA_GASTO_MAX = 5   -- teto de quanto gastar POR ATIVAÇÃO (não é o teto da Fúria)
ficha.FURIA_DURACAO_TURNOS = 3

-- Tabela de nível (1..5) -> bônus de dano. NÃO é linear/cumulativa: cada
-- nível tem seu próprio valor fixo, e 4/5 ficam travados no valor do 3
-- (não continuam somando dano) — o que eles ganham a mais é redução de dano
-- tomado, não mais dano (ver FURIA_TABELA_REDUCAO).
ficha.FURIA_TABELA_DANO = { [1] = 3, [2] = 4, [3] = 5, [4] = 5, [5] = 5 }

-- Redução de dano TOMADO (tipo armadura temporária — não afeta chance de ser
-- acertado, só quanto dói) nos níveis 4 e 5. 1..3 não reduzem nada.
ficha.FURIA_TABELA_REDUCAO = { [4] = 3, [5] = 5 }

-- Quanto de Fúria resta (nil se a raça não tem Fúria — só lobisomem tem).
function ficha:furia_atual()
  return self.furia
end

-- Gasta `quanto` de Fúria. Recusa (devolve false) se a raça não tiver Fúria
-- ou não houver saldo suficiente — nunca deixa negativo.
function ficha:gastar_furia(quanto)
  if not self.furia or not quanto or quanto <= 0 or quanto > self.furia then
    return false
  end
  self.furia = self.furia - quanto
  return true
end

-- Restaura Fúria (nunca passa do teto). Quem chama decide o motivo e a
-- quantidade (lua cheia, dano crítico, novo dia — ver sistemas.md).
function ficha:recarregar_furia(quanto)
  if not self.furia then return nil end
  self.furia = math.min(ficha.FURIA_MAX, self.furia + (quanto or 0))
  return self.furia
end

-- Risco de Frenesi (0..1) ao gastar `quanto` de Fúria, calculado ANTES do
-- gasto acontecer de fato (chame isto pra decidir/avisar, depois gastar_furia
-- pra efetivar). PROVISÓRIO — fórmula simples que já respeita as duas regras
-- de design confirmadas: sobe com o quanto se gasta de uma vez, desce quanto
-- mais Fúria total o personagem tem. `risco = quanto / furia_atual`, ou seja,
-- gastar TUDO de uma vez (quanto == furia atual) sempre bate 100%. Ajustar a
-- fórmula depois de jogar umas lutas de teste (ver tabela em testes.lua).
function ficha:risco_frenesi(quanto)
  if not self.furia or not quanto or quanto <= 0 or self.furia <= 0 then
    return 0
  end
  return math.min(1, quanto / self.furia)
end

-- Ativa o buff de Fúria por FURIA_DURACAO_TURNOS turnos (versão PROVISÓRIA —
-- ver sistemas.md > Fúria). `quanto` é o NÍVEL (1..5, teto FURIA_GASTO_MAX
-- independente de quanta Fúria total o personagem tenha) e também é o custo
-- em Fúria gasta. Gastar 1 = empurrãozinho seguro; gastar tudo de uma vez =
-- surto de força bruta com Frenesi quase garantido (ver risco_frenesi). Se
-- não tiver saldo ou passar do teto de gasto, não ativa (devolve false).
-- Reativar enquanto já está ativo SUBSTITUI o nível e reinicia a duração
-- (não acumula/estende).
function ficha:ativar_furia(quanto)
  if not quanto or quanto > ficha.FURIA_GASTO_MAX then
    return false
  end
  if not self:gastar_furia(quanto) then
    return false
  end
  self.furia_nivel = quanto
  self.furia_turnos_restantes = ficha.FURIA_DURACAO_TURNOS
  return true
end

-- O buff de Fúria está ativo agora?
function ficha:furia_buff_ativo()
  return (self.furia_turnos_restantes or 0) > 0
end

-- Bônus de ACERTO do buff de Fúria (provisório: -1 fixo enquanto ativo,
-- não escala por nível).
function ficha:bonus_acerto_furia()
  return self:furia_buff_ativo() and -1 or 0
end

-- Bônus de DANO do buff de Fúria (provisório: ver FURIA_TABELA_DANO).
function ficha:bonus_dano_furia()
  if not self:furia_buff_ativo() then return 0 end
  return ficha.FURIA_TABELA_DANO[self.furia_nivel] or 0
end

-- Redução de dano TOMADO pelo buff de Fúria (provisório: ver
-- FURIA_TABELA_REDUCAO — só níveis 4 e 5 reduzem algo).
function ficha:bonus_reducao_dano_furia()
  if not self:furia_buff_ativo() then return 0 end
  return ficha.FURIA_TABELA_REDUCAO[self.furia_nivel] or 0
end

-- Avança 1 turno na duração do buff de Fúria (quem chama decide QUANDO um
-- "turno" termina — ver core/combate_ui.lua e jogo2d/main.lua, chamado uma
-- vez por rodada de combate). Sem efeito se não houver buff ativo. Devolve
-- quantos turnos restam.
function ficha:passar_turno_furia()
  if (self.furia_turnos_restantes or 0) <= 0 then
    return 0
  end
  self.furia_turnos_restantes = self.furia_turnos_restantes - 1
  if self.furia_turnos_restantes <= 0 then
    self.furia_nivel = nil
  end
  return self.furia_turnos_restantes
end

-- ---- Frenesi (consequência da Fúria) --------------------------------------
-- Versão MÍNIMA (ver sistemas.md > Fúria): quando o risco "dá", o lobisomem
-- perde o CONTROLE por FRENESI_DURACAO_TURNOS — o jogo passa a agir por ele
-- (ataca no automático; sem esquivar/fugir/habilidades). As versões ricas
-- (atacar aliados, dizimar vilarejo) ficam pra quando existir esse conteúdo.

ficha.FRENESI_DURACAO_TURNOS = 2

-- Rola o risco de Frenesi pra um gasto `quanto` (usa risco_frenesi). Devolve
-- true se o Frenesi DISPAROU. `rng` opcional (float [0,1)) pra testes. Só
-- decide — NÃO entra em frenesi sozinho (quem chama narra e chama entrar_frenesi).
function ficha:rolar_frenesi(quanto, rng)
  local risco = self:risco_frenesi(quanto)
  if risco <= 0 then return false end
  local r = rng or math.random
  return r() < risco
end

-- Entra em Frenesi (perde o controle por FRENESI_DURACAO_TURNOS turnos).
function ficha:entrar_frenesi()
  self.frenesi_turnos_restantes = ficha.FRENESI_DURACAO_TURNOS
end

-- Está em Frenesi agora (sem controle)?
function ficha:em_frenesi()
  return (self.frenesi_turnos_restantes or 0) > 0
end

-- Avança 1 turno de Frenesi. Devolve quantos turnos ainda restam (0 = recuperou
-- o controle). Chamado uma vez por rodada, como passar_turno_furia.
function ficha:passar_turno_frenesi()
  if (self.frenesi_turnos_restantes or 0) <= 0 then
    return 0
  end
  self.frenesi_turnos_restantes = self.frenesi_turnos_restantes - 1
  return self.frenesi_turnos_restantes
end

-- ---- Atordoado (efeito de status genérico) ---------------------------------
-- Perde a vez por completo — DIFERENTE de Frenesi (que ainda age, só sem
-- controle). Usado pela Dominatio por ora; genérico o bastante pra qualquer
-- fonte futura (não é exclusivo de raça nenhuma — qualquer ficha pode ficar
-- atordoada, mesmo que hoje só Dominatio cause isso).

function ficha:atordoar(turnos)
  self.atordoado_turnos_restantes = turnos or 0
end

function ficha:atordoado()
  return (self.atordoado_turnos_restantes or 0) > 0
end

-- Avança 1 turno de atordoamento. Chamado uma vez por rodada, como
-- passar_turno_furia/passar_turno_frenesi.
function ficha:passar_turno_atordoado()
  if (self.atordoado_turnos_restantes or 0) <= 0 then
    return 0
  end
  self.atordoado_turnos_restantes = self.atordoado_turnos_restantes - 1
  return self.atordoado_turnos_restantes
end

-- ---- Umbra (lobisomem) -----------------------------------------------------
-- Conexão/sintonia com Gaia e os espíritos da natureza (ver sistemas.md >
-- Recursos por Raça > Umbra). NÃO é um recurso gasto como Fúria — é um valor
-- OCULTO (o jogador nunca vê o número, só sente narrativamente — mesma regra
-- das perícias comuns: "visibilidade segue a agência"). Só sobe; não existe
-- ação que o reduza. Só lobisomem tem; nenhuma outra raça pode ganhar Umbra.
-- O que Umbra alta desbloqueia na prática (artefatos espirituais, poderes
-- xamânicos) ainda não está definido/implementado — só o valor em si.

ficha.UMBRA_INICIAL = 1
ficha.UMBRA_MAX = 10

-- Quanto de Umbra o personagem tem (nil se a raça não pode ter Umbra).
function ficha:umbra_atual()
  return self.umbra
end

-- Aumenta Umbra (nunca passa do teto). PROVISÓRIO: pensado pra ser chamado
-- ao completar quests específicas de Gaia (ainda não existem no jogo) — por
-- ora, só o mecanismo de aumentar existe, sem gatilho automático ligado a
-- conteúdo. Sem efeito (devolve nil) se a raça não tiver Umbra.
function ficha:ganhar_umbra(quanto)
  if not self.umbra then return nil end
  self.umbra = math.min(ficha.UMBRA_MAX, self.umbra + (quanto or 0))
  return self.umbra
end

-- ---- Sonhos & Quebras (mago) ------------------------------------------------
-- Ver sistemas.md > Recursos por Raça. Sonhos = mana, gasta por magia
-- (SEM TETO, mas nunca abaixo de SONHOS_MINIMO — o mago não "seca" de vez).
-- Quebras = preço acumulado por falha feia de conjuração (0-10; core/magia.lua
-- cuida de quando/quanto Quebras uma falha gera). Só mago tem os dois.

ficha.SONHOS_INICIAL = 1
ficha.SONHOS_MINIMO = 1
ficha.QUEBRAS_MAX = 10

-- Quanto de Sonhos o mago tem agora (nil se a raça não tiver Sonhos).
function ficha:sonhos_atual()
  return self.sonhos
end

-- Gasta `quanto` de Sonhos. Recusa (devolve false) se a raça não tiver Sonhos
-- ou se o gasto derrubasse abaixo do mínimo (1) — nunca "seca" de vez.
function ficha:gastar_sonhos(quanto)
  if not self.sonhos or not quanto or quanto <= 0 then
    return false
  end
  if self.sonhos - quanto < ficha.SONHOS_MINIMO then
    return false
  end
  self.sonhos = self.sonhos - quanto
  return true
end

-- Restaura Sonhos (sem teto). Quem chama decide quanto (descanso, etc — o
-- gatilho concreto ainda não existe no motor, só o mecanismo).
function ficha:recarregar_sonhos(quanto)
  if not self.sonhos then return nil end
  self.sonhos = self.sonhos + (quanto or 0)
  return self.sonhos
end

-- Quantas Quebras o mago tem (nil se a raça não tiver Quebras).
function ficha:quebras_atual()
  return self.quebras
end

-- Ganha Quebras (nunca passa do teto 10). Quem chama (core/magia.lua) decide
-- quanto, com base em `magia.quebras_por_falha`.
function ficha:ganhar_quebras(quanto)
  if not self.quebras then return nil end
  self.quebras = math.min(ficha.QUEBRAS_MAX, self.quebras + (quanto or 0))
  return self.quebras
end

-- Reduz Quebras (nunca abaixo de 0). Diferente de Corrupção (que só sobe),
-- Quebras pode baixar com o tempo sem tomar mais — taxa exata ⚪, só o
-- mecanismo existe (ver sistemas.md).
function ficha:reduzir_quebras(quanto)
  if not self.quebras then return nil end
  self.quebras = math.max(0, self.quebras - (quanto or 0))
  return self.quebras
end

-- Bateu no teto de Quebras -> Cemitério dos Sonhos, permadeath (ver lore.md).
function ficha:no_cemiterio_dos_sonhos()
  return (self.quebras or 0) >= ficha.QUEBRAS_MAX
end

-- ---- Conceitos & Fusão (mago — spellmaking) --------------------------------
-- Ver sistemas.md > Conceitos & Fusão. O mago aprende CONCEITOS (tijolos de
-- data/conceitos.lua), 1 crédito a cada N níveis, e FUNDE conceitos aprendidos
-- em magias suas (core/magia.fundir faz a conta de custo/dif; aqui a ficha só
-- guarda o que se sabe e o que se criou). Só mago tem isto.

ficha.CONCEITO_A_CADA_N_NIVEIS = 2   -- 1 conceito novo a cada 2 níveis

-- Já sabe este conceito?
function ficha:conhece_conceito(id)
  return self.conceitos ~= nil and self.conceitos[id] == true
end

-- Há crédito de conceito pra gastar (subiu de nível e ainda não escolheu)?
function ficha:tem_conceito_pendente()
  return (self.conceitos_pendentes or 0) > 0
end

-- Aprende um conceito, gastando um crédito pendente. Recusa (false + motivo)
-- se a raça não for mago, se não houver crédito, ou se já souber o conceito.
function ficha:aprender_conceito(id)
  if not self.conceitos then
    return false, "esta raça não aprende conceitos"
  end
  if not self:tem_conceito_pendente() then
    return false, "sem crédito de conceito"
  end
  if self:conhece_conceito(id) then
    return false, "já conhece este conceito"
  end
  self.conceitos[id] = true
  self.conceitos_pendentes = self.conceitos_pendentes - 1
  return true
end

-- Funde conceitos JÁ APRENDIDOS numa magia e a GUARDA na ficha. `ids` é uma
-- lista de ids de conceitos; `nome` é o rótulo que o jogador dá à criação.
-- `catalogo` é data/conceitos.lua (injetado pra manter a ficha sem dependência
-- direta de data; a UI passa require("data.conceitos")). Recusa (nil + motivo)
-- se a raça não funde, se a lista for vazia, ou se algum conceito não for
-- conhecido. Delega o cálculo de custo/dif a core/magia.fundir.
function ficha:fundir_magia(ids, nome, catalogo)
  if not self.magias_fundidas then
    return nil, "esta raça não funde magias"
  end
  if not ids or #ids == 0 then
    return nil, "nenhum conceito escolhido"
  end
  local conceitos = {}
  for _, id in ipairs(ids) do
    if not self:conhece_conceito(id) then
      return nil, "conceito não conhecido: " .. tostring(id)
    end
    local c = catalogo[id]
    if not c then
      return nil, "conceito inexistente no catálogo: " .. tostring(id)
    end
    -- Garante que o id viaja junto (magia.fundir usa c.id pra registrar a
    -- composição), mesmo que o catálogo não o repita dentro da entrada.
    c = { id = id, nome = c.nome, peso = c.peso, dif = c.dif, tags = c.tags }
    conceitos[#conceitos + 1] = c
  end
  local magia = require("core.magia")
  local nova, motivo = magia.fundir(conceitos, nome)
  if not nova then
    return nil, motivo
  end
  self.magias_fundidas[#self.magias_fundidas + 1] = nova
  return nova
end

-- ---- Sangue, Geração & Humanidade (vampiro) --------------------------------
-- Ver sistemas.md > Recursos por Raça. Sangue é gasto direto (como Fúria,
-- sem base/pool separados). Teto SEMPRE 10 pro jogador — geração NÃO reduz
-- o teto (só Caim e os Iluminados escapam da régua 0-10; ver seção 4).

ficha.SANGUE_INICIAL = 5
ficha.SANGUE_MAX = 10
ficha.HUMANIDADE_INICIAL = 7   -- universal: todo ser começa em 7 (10 = Sagrado, não é ponto de partida)
ficha.HUMANIDADE_MAX = 10

-- Alimentar-se (ver Sangue > Alimentação): beber sem matar dá SANGUE_POR_GOLE;
-- sugar até a morte dá SANGUE_POR_MORTE (mais), mas deixa 1 MANCHA (marcação
-- de Humanidade — ver alimentar).
ficha.SANGUE_POR_GOLE = 2
ficha.SANGUE_POR_MORTE = 3

-- Metabolismo: o vampiro perde SANGUE_POR_DIA de Sangue a cada "dia" só de
-- existir (ver passar_dia). Sangue 0 -> Frenesi de fome (ver alimentar/
-- passar_dia). Gatilho de "dia" ainda não existe no jogo (sem calendário),
-- só o mecanismo.
ficha.SANGUE_POR_DIA = 1

-- Cura por escolha (modo_regen "escolha"): gasta 1 Sangue e cura HP conforme a
-- GERAÇÃO — mais perto de Caim, mais cura por gota. Mesma régua de faixas do
-- multiplicador de Elevação (ver cura_por_sangue). Números = balanceamento
-- provisório, afinar jogando.
ficha.CURA_SANGUE_CUSTO = 1

-- Humanidade & Marcações (ver sistemas.md): atos sombrios não tiram Humanidade
-- na hora — deixam UMA marcação. A cada MARCACOES_POR_HUMANIDADE, cai 1 de
-- Humanidade e a contagem ZERA (não vaza). Diablerie é a exceção (tira direto).
ficha.MARCACOES_POR_HUMANIDADE = 3

function ficha:sangue_atual()
  return self.sangue
end

-- Gasta `quanto` de Sangue. Recusa se a raça não tiver Sangue ou não houver
-- saldo suficiente.
function ficha:gastar_sangue(quanto)
  if not self.sangue or not quanto or quanto <= 0 or quanto > self.sangue then
    return false
  end
  self.sangue = self.sangue - quanto
  return true
end

-- Restaura Sangue (nunca passa do teto 10). Uso interno/genérico; a via
-- narrativa de ganhar Sangue é ficha:alimentar (beber de uma vítima).
function ficha:recarregar_sangue(quanto)
  if not self.sangue then return nil end
  self.sangue = math.min(ficha.SANGUE_MAX, self.sangue + (quanto or 0))
  return self.sangue
end

-- Alimentar-se de uma vítima. `ate_a_morte` = sugou até matar: dá mais Sangue
-- (SANGUE_POR_MORTE) MAS deixa 1 mancha de Humanidade (matar corrói — ver
-- marcar_humanidade). Beber sem matar (padrão) dá SANGUE_POR_GOLE e não mancha.
-- Devolve o Sangue após alimentar (nil se a raça não tem Sangue).
function ficha:alimentar(ate_a_morte)
  if not self.sangue then return nil end
  if ate_a_morte then
    self:recarregar_sangue(ficha.SANGUE_POR_MORTE)
    self:marcar_humanidade("sugar_ate_a_morte")
  else
    self:recarregar_sangue(ficha.SANGUE_POR_GOLE)
  end
  return self.sangue
end

-- Quanto de HP uma gota de Sangue cura, conforme a GERAÇÃO (mesma régua de
-- faixas da Elevação — mais perto de Caim, mais cura). Provisório.
function ficha.cura_por_geracao(geracao)
  geracao = geracao or 8
  if geracao <= 0 then return 10
  elseif geracao <= 2 then return 8
  elseif geracao <= 4 then return 6
  elseif geracao <= 6 then return 4
  else return 2 end
end

-- Cura por ESCOLHA (modo_regen "escolha"): gasta 1 Sangue -> cura HP conforme
-- a geração (cura_por_geracao). Nunca passa do teto de HP. Recusa (false +
-- motivo) se não tiver Sangue, ou se não houver saldo pra pagar. Devolve
-- true + quanto curou.
function ficha:curar_com_sangue()
  if not self.sangue then
    return false, "esta raça não cura com Sangue"
  end
  if not self:gastar_sangue(ficha.CURA_SANGUE_CUSTO) then
    return false, "sem Sangue suficiente"
  end
  local cura = ficha.cura_por_geracao(self.geracao)
  local antes = self.hp
  self.hp = math.min(self:teto_cura_sobrenatural(), self.hp + cura)
  return true, self.hp - antes
end

-- Passa um "dia": metabolismo consome SANGUE_POR_DIA. Se o Sangue chega a 0, a
-- fome vence -> Frenesi sem controle (reaproveita entrar_frenesi). Gatilho de
-- "dia" real ainda não existe (sem calendário); só o mecanismo. Devolve o
-- Sangue restante (nil se a raça não tem Sangue).
function ficha:passar_dia()
  if not self.sangue then return nil end
  self.sangue = math.max(0, self.sangue - ficha.SANGUE_POR_DIA)
  if self.sangue <= 0 then
    self:entrar_frenesi()
  end
  return self.sangue
end

function ficha:geracao_atual()
  return self.geracao
end

function ficha:humanidade_atual()
  return self.humanidade
end

-- Ganha/perde Humanidade (0-10). UNIVERSAL — todo ser tem Humanidade. O que é
-- só do vampiro é o EFEITO de tê-la baixa (debuffs — ainda ⚪); o número e as
-- marcações valem pra qualquer raça.
function ficha:ganhar_humanidade(quanto)
  if not self.humanidade then return nil end
  self.humanidade = math.min(ficha.HUMANIDADE_MAX, self.humanidade + (quanto or 0))
  self:_atualizar_sagrado()
  return self.humanidade
end

function ficha:perder_humanidade(quanto)
  if not self.humanidade then return nil end
  self.humanidade = math.max(0, self.humanidade - (quanto or 0))
  self:_atualizar_sagrado()
  return self.humanidade
end

-- Quantas marcações há rumo à próxima queda de Humanidade (nil se a raça não
-- tem Humanidade mecânica).
function ficha:marcacoes_atual()
  return self.marcacoes
end

-- Marca a Humanidade por um ato sombrio (`id_mancha` = entrada de
-- data/manchas.lua; todo ato vale 1 marcação). Ao atingir
-- MARCACOES_POR_HUMANIDADE, cai 1 de Humanidade e a contagem ZERA (não vaza o
-- excedente). Diablerie NÃO passa por aqui (é a exceção — tira direto).
-- UNIVERSAL — qualquer ser pode ser marcado (todos têm Humanidade); só o
-- efeito de Humanidade baixa é do vampiro (⚪). Devolve true se a marcação
-- converteu numa queda de Humanidade, false se só acumulou.
function ficha:marcar_humanidade(id_mancha)
  if not self.humanidade then return nil end
  -- Registra qual foi o último ato que marcou (pra narrativa/log: "marcado por
  -- roubar"). Todo ato vale 1; o id não muda o cálculo, mas importa pra contar
  -- a história — e liga ao catálogo data/manchas.lua.
  self.ultima_mancha = id_mancha
  self.marcacoes = (self.marcacoes or 0) + 1
  if self.marcacoes >= ficha.MARCACOES_POR_HUMANIDADE then
    self.marcacoes = 0
    self:perder_humanidade(1)
    return true
  end
  return false
end

-- Chegar a Humanidade 10 (QUALQUER ser, não só vampiro) concede o poder
-- Sagrado (ver lore.md > Eden). v0 PROVISÓRIO: único requisito é Humanidade
-- — mais requisitos virão depois.
function ficha:elegivel_sagrado()
  return (self.humanidade or 0) >= ficha.HUMANIDADE_MAX
end

-- ---- Sagrado (ver lore.md > Eden) -------------------------------------------
-- Fé verdadeira e intensa gera Sagrado — independe de raça/religião,
-- UNIVERSAL (qualquer ser pode ter). HISTERESE de propósito, pra não "piscar"
-- com flutuação pequena de Humanidade: GANHA ao bater 10 (elegivel_sagrado);
-- só PERDE se cair abaixo de 9 (8 ou menos) — ficar exatamente em 9 mantém o
-- que já tinha. Chamado automaticamente sempre que a Humanidade muda.
--
-- NÍVEL (1-5): depois de ter o Sagrado, ações boas o sobem — a mesma "fonte"
-- de pontos que subiria Humanidade, mas como ela já está no teto (10), o
-- ganho vira nível de Sagrado em vez (ver sistemas.md). O nível começa em 1
-- na primeira vez que o Sagrado é concedido (não reseta se ele oscilar
-- depois — perder e reconquistar o Sagrado não perde o nível já treinado).
function ficha:_atualizar_sagrado()
  if not self.humanidade then return end
  if self:elegivel_sagrado() then
    if not self.sagrado_obtido then
      self.sagrado_nivel = self.sagrado_nivel or 1
    end
    self.sagrado_obtido = true
  elseif self.humanidade < 9 then
    self.sagrado_obtido = false
  end
end

-- Tem o Sagrado agora? (já foi concedido e não caiu abaixo de 9 depois)
function ficha:tem_sagrado()
  return self.sagrado_obtido == true
end

ficha.SAGRADO_NIVEL_MAX = 5

-- Nível de Sagrado (1-5; nil se nunca teve o Sagrado concedido).
function ficha:sagrado_nivel_atual()
  return self.sagrado_nivel
end

-- Sobe o nível de Sagrado (ações boas, DEPOIS de já ter o Sagrado — ver
-- sistemas.md; gatilho de conteúdo ainda ⚪, só o mecanismo existe). Recusa
-- (nil) se nunca teve o Sagrado concedido. Nunca passa de SAGRADO_NIVEL_MAX.
function ficha:ganhar_sagrado(quanto)
  if not self.sagrado_nivel then return nil end
  self.sagrado_nivel = math.min(ficha.SAGRADO_NIVEL_MAX, self.sagrado_nivel + (quanto or 0))
  return self.sagrado_nivel
end

-- Diablerizar: consome outro vampiro. Baixa a própria geração até (no
-- mínimo) a geração da vítima, e custa 1 de Humanidade FIXO (sempre, não
-- importa o resto — ver sistemas.md). `geracao_vitima` é só o número (não a
-- ficha inteira, pra não acoplar isto a um combate/cena específico).
function ficha:diablerizar(geracao_vitima)
  if not self.geracao then return false, "esta raça não tem geração" end
  self.geracao = math.min(self.geracao, geracao_vitima)
  self:perder_humanidade(1)
  return true
end

-- ---- Estigmas gerais (vampiro) -------------------------------------------
-- Todo vampiro tem os 3 estigmas gerais (ver lore.md > Vampiros):
--   Dominatio  — comandar/dominar a mente pelo olhar (fraca contra alvos
--                mais fortes). Mecânica/fórmula do teste ainda ⚪.
--   Besta      — manipula a "Besta": a força animadora que todo ser tem (não
--                é alma, mas parecido — sem ela você é só carne). Remover,
--                absorver, e resistir melhor ao próprio Frenesi. Mecânica
--                ainda ⚪ (só a resistência a Frenesi tem gancho pronto,
--                ver ficha:em_frenesi/entrar_frenesi — falta ligar o bônus).
--   Elevação   — IMPLEMENTADA (ver abaixo): buff temporário em TODOS os
--                atributos FÍSICOS de uma vez (Força, Vitalidade, Agilidade
--                juntas), além do teto normal de 10.

-- Atributos que a Elevação buffa (todos, sempre juntos — não dá pra escolher
-- só um).
ficha.ELEVACAO_ATRIBUTOS = { forca = true, vitalidade = true, agilidade = true }
ficha.ELEVACAO_CUSTO = 1              -- sempre exatamente 1 Sangue (fixo)
ficha.ELEVACAO_DURACAO_TURNOS = 2

-- Multiplicador de Elevação por geração — quanto MENOR a geração (mais perto
-- de Caim), maior o bônus por Sangue gasto (ver sistemas.md):
--   8-7 -> x1 · 6-5 -> x2 · 4-3 -> x3 · 2-1 -> x4 · 0 (Caim, teórico) -> x5
function ficha.multiplicador_elevacao(geracao)
  geracao = geracao or 8
  if geracao <= 0 then return 5
  elseif geracao <= 2 then return 4
  elseif geracao <= 4 then return 3
  elseif geracao <= 6 then return 2
  else return 1 end
end

-- Ativa Elevação: buffa Força, Vitalidade E Agilidade AO MESMO TEMPO (não é
-- escolha de um só). Gasta SEMPRE 1 Sangue (custo fixo, diferente de Fúria).
-- O bônus (multiplicador de geração) é somado direto nos 3 atributos de
-- verdade — PODE passar do teto 10, só enquanto ativo. Dura
-- ELEVACAO_DURACAO_TURNOS turnos e reverte sozinho. Recusa (false + motivo)
-- se já houver uma Elevação ativa ou faltar Sangue.
function ficha:ativar_elevacao()
  if not self.sangue then
    return false, "esta raça não tem Sangue"
  end
  if self:elevacao_ativa() then
    return false, "já há uma Elevação ativa"
  end
  if not self:gastar_sangue(ficha.ELEVACAO_CUSTO) then
    return false, "sem Sangue suficiente"
  end
  local bonus = ficha.multiplicador_elevacao(self.geracao)
  for attr in pairs(ficha.ELEVACAO_ATRIBUTOS) do
    self.atributos[attr] = self.atributos[attr] + bonus
  end
  self.elevacao_bonus = bonus
  self.elevacao_turnos_restantes = ficha.ELEVACAO_DURACAO_TURNOS
  -- Elevar Vitalidade aumenta o teto de HP (hp_max lê o atributo). O HP atual
  -- sobe JUNTO na hora, senão o bônus de HP fica inacessível (um teto que
  -- você nunca alcança). Cada ponto de Vitalidade vale 2 de HP (ver hp_max).
  self.hp = self.hp + bonus * 2
  return true, bonus
end

-- Há uma Elevação ativa agora?
function ficha:elevacao_ativa()
  return (self.elevacao_turnos_restantes or 0) > 0
end

-- Avança 1 turno da Elevação. Ao expirar, REVERTE o bônus dos 3 atributos
-- automaticamente. Chamado uma vez por rodada, como passar_turno_furia.
function ficha:passar_turno_elevacao()
  if (self.elevacao_turnos_restantes or 0) <= 0 then
    return 0
  end
  self.elevacao_turnos_restantes = self.elevacao_turnos_restantes - 1
  if self.elevacao_turnos_restantes <= 0 then
    for attr in pairs(ficha.ELEVACAO_ATRIBUTOS) do
      self.atributos[attr] = self.atributos[attr] - self.elevacao_bonus
    end
    self.elevacao_bonus = nil
    -- O teto de HP caiu (Vitalidade voltou ao normal) — clampa o HP atual
    -- pra não sobrar HP "fantasma" acima do novo máximo.
    self.hp = math.min(self.hp, self:hp_max())
  end
  return self.elevacao_turnos_restantes
end

-- ---- Besta (força animadora universal / estigma do vampiro) -------------
-- TODO ser tem Besta = 10 (a força animadora; ver sistemas.md > Estigmas >
-- Besta). Igual em todos — não é fonte de poder, é o que te mantém "mais que
-- carne". O estigma Besta (só vampiro) manipula a Besta: hoje só ACALMAR a
-- própria (resistir ao Frenesi); remover/absorver a dos outros ficam ⚪.

ficha.BESTA_INICIAL = 10
ficha.BESTA_MAX = 10
ficha.ACALMAR_CUSTO_SANGUE = 1        -- custo pra acalmar a própria Besta
ficha.ACALMAR_DURACAO_TURNOS = 3

-- Quanta Besta a criatura tem agora (todo ser tem; nunca é nil).
function ficha:besta_atual()
  return self.besta
end

-- Zerar a Besta = "só carne" (ver lore). Só a checagem; o efeito (morte/
-- catatonia) fica pra quem implementar remover/absorver.
function ficha:so_carne()
  return (self.besta or 0) <= 0
end

-- Acalma a PRÓPRIA Besta: gasta Sangue e fica IMUNE ao Frenesi por uns
-- turnos (mesmo com Sangue 0 — ver em_risco_frenesi_vampiro). Só vampiro
-- (precisa de Sangue). Recusa (false + motivo) se não tiver Sangue ou já
-- estiver acalmando. Reativar não empilha.
function ficha:acalmar_besta()
  if not self.sangue then
    return false, "esta raça não domina a Besta"
  end
  if self:besta_acalmada() then
    return false, "a Besta já está acalmada"
  end
  if not self:gastar_sangue(ficha.ACALMAR_CUSTO_SANGUE) then
    return false, "sem Sangue suficiente"
  end
  self.besta_acalmada_turnos = ficha.ACALMAR_DURACAO_TURNOS
  return true
end

-- A Besta está acalmada agora (folga anti-Frenesi ativa)?
function ficha:besta_acalmada()
  return (self.besta_acalmada_turnos or 0) > 0
end

-- Avança 1 turno do acalmar. Chamado uma vez por rodada, como os outros
-- passar_turno_*. Devolve quantos turnos restam.
function ficha:passar_turno_besta()
  if (self.besta_acalmada_turnos or 0) <= 0 then
    return 0
  end
  self.besta_acalmada_turnos = self.besta_acalmada_turnos - 1
  return self.besta_acalmada_turnos
end

-- ---- Frenesi do vampiro (gatilho — reaproveita o Frenesi do lobisomem) -----
-- Diferente do lobisomem (chance rolada ao gastar Fúria), o Frenesi do
-- vampiro é DETERMINÍSTICO: dispara quando o Sangue chega a 0 (a fome
-- vence). Reaproveita o MESMO estado de Frenesi (entrar_frenesi/em_frenesi/
-- passar_turno_frenesi, 2 turnos) — só o gatilho muda. Versão mínima; será
-- reformulada (atacar aliados, fugir pro vilarejo, reputação) quando esse
-- conteúdo existir.
-- O estigma Besta (ver acalmar_besta) dá IMUNIDADE total ao Frenesi
-- enquanto acalmada (mesmo com Sangue 0) — reaproveita a mesma duração de 3
-- turnos, sem precisar de um contador à parte.
function ficha:em_risco_frenesi_vampiro()
  if not self.sangue then return false end
  if self:besta_acalmada() then return false end
  return self.sangue <= 0
end

-- ---- Força de Vontade -----------------------------------------------------

-- Defesa mental: SEMPRE usa a base (o atributo cheio), estável. Gastar o pool
-- pra rerrolar NÃO reduz isto (ver o exemplo no design: base 6 defende com 6
-- mesmo com pool em 5).
function ficha:defesa_mental()
  return self.atributos.vontade
end

-- Quanto de pool ainda há pra rerrolar.
function ficha:vontade_disponivel()
  return self.vontade_pool
end

-- Tenta gastar 1 ponto do pool (pra rerrolar). Devolve true se conseguiu.
function ficha:gastar_vontade()
  if self.vontade_pool > 0 then
    self.vontade_pool = self.vontade_pool - 1
    return true
  end
  return false
end

-- Recarrega o pool (por coisas de "sentido" — quem chama decide quanto).
-- Nunca ultrapassa a base. Recarga é lenta/rara de propósito (o motor não
-- recarrega sozinho; eventos específicos chamam isto).
function ficha:recarregar_vontade(quanto)
  quanto = quanto or 1
  local max = self.atributos.vontade
  self.vontade_pool = math.min(max, self.vontade_pool + quanto)
  return self.vontade_pool
end

return ficha
