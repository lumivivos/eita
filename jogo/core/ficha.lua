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
    self.sonhos = ficha.SONHOS_INICIAL
    self.quebras = 0
    -- Conceitos mágicos aprendidos (ids de data/conceitos.lua) e magias
    -- fundidas a partir deles (ver seção Conceitos & Fusão adiante). Começam
    -- vazios: o mago nasce sabendo NADA e escolhe o que aprender ao subir.
    self.conceitos = {}          -- id_do_conceito -> true (conjunto)
    self.magias_fundidas = {}    -- lista de magias criadas (ver magia.fundir)
    -- Créditos de conceito ainda não gastos (ganha 1 a cada N níveis; ver
    -- CONCEITO_A_CADA_N_NIVEIS). Escolher QUAL conceito é ação do jogador.
    self.conceitos_pendentes = 0
  end
  self.pericias = {}   -- nome -> nível (sobem por uso; vazio no início)
  -- Nível de personagem (1..10, mesmo teto dos atributos). Sobe por EXP (raro).
  self.nivel = attrs.nivel or 1
  self.exp = 0   -- EXP acumulado RUMO ao próximo nível (zera ao subir)
  -- Forma atual. Só o lobisomem transforma; começa (e todos ficam) em "humanoide".
  self.forma = "humanoide"
  -- HP começa cheio.
  self.hp = self:hp_max()
  return self
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

-- O modo de regeneração desta ficha ("passiva"/"escolha"/"magia"/"nenhuma").
function ficha:modo_regen()
  return ficha.REGEN_POR_RACA[self.raca] or "nenhuma"
end

-- Regenera HP. Nunca passa do máximo. Só cura se a raça regenera (modo ≠
-- "nenhuma"). NOTA: o custo/preço de cada modo (Sangue do vampiro, Quebras do
-- mago) será aplicado pela camada que CHAMA isto, quando os recursos de raça
-- existirem — aqui só tratamos o HP. Devolve o HP após regenerar.
function ficha:regenerar(quanto)
  if self:modo_regen() ~= "nenhuma" then
    self.hp = math.min(self:hp_max(), self.hp + (quanto or 0))
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
    self.hp = math.min(self:hp_max(), self.hp + cura)
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
