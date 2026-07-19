-- core/magia.lua
-- Resolução de uma conjuração (ver sistemas.md > Sonhos & Quebras). Lógica
-- pura, sem UI — devolve um resultado detalhado pra a camada de tela narrar.
-- Espelha core/combate.lua na estrutura (mesmo espírito: motor separado da
-- apresentação).

local dado = require("core.dado")

local magia = {}

-- Quantas Quebras uma FALHA FEIA de uma magia de determinada dificuldade
-- gera. Escala em degraus de 5: dif 1-5 -> 1 Quebra, 6-10 -> 2, 11-15 -> 3,
-- e sucessivamente (ver sistemas.md). Escala pela DIFICULDADE, não pelo
-- custo — desde que toda magia custe sempre 1 Sonho (ver magia.CUSTO_FUSAO),
-- é a dificuldade que carrega o tamanho/ambição de uma magia. Uma fusão
-- muito ambiciosa (dif alta) que falha feio pode gerar Quebras suficientes
-- pra matar o mago na hora (Cemitério dos Sonhos) — intencional: o mago é
-- "armadilha", pode tentar qualquer coisa, mas o preço de errar escala com
-- o quanto ele tentou alcançar, não com o quanto pagou.
function magia.quebras_por_falha(dif_magia)
  return math.ceil(dif_magia / 5)
end

-- ---- Fusão de conceitos (spellmaking) --------------------------------------
-- O mago funde CONCEITOS aprendidos (tijolos de data/conceitos.lua) numa magia
-- sua (ver sistemas.md > Conceitos & Fusão). NÃO há escola de magia nem lista
-- de feitiços: o único limite é ter os conceitos aprendidos e ter Sonhos pra
-- pagar. Este é o único lugar que decide o custo/dif de uma magia — o resto do
-- motor (magia.conjurar) trata a magia fundida igual a qualquer outra entrada.

-- Toda magia fundida custa SEMPRE isto em Sonhos, não importa quantos
-- conceitos entrem na fusão nem quão ambiciosa seja. O preço de "pedir
-- demais" nunca aparece no custo — aparece inteiro na DIFICULDADE (ver
-- abaixo). É o que torna o mago "armadilha": tentar qualquer coisa custa
-- pouco, mas fundir/tentar algo grande demais pode ter uma dificuldade
-- praticamente impossível de bater (sem limite superior — ver
-- magia.quebras_por_falha pro preço de errar feio numa fusão assim).
magia.CUSTO_FUSAO = 1

-- Penalidade por COMPLEXIDADE: fundir mais conceitos numa mesma magia é mais
-- instável. O 1º conceito não penaliza; cada conceito ADICIONAL soma isto à
-- dificuldade (não ao custo, que é sempre fixo — ver magia.CUSTO_FUSAO;
-- provisório — afinar depois de jogar; ver sistemas.md).
magia.PENALIDADE_POR_CONCEITO_EXTRA = 1

-- Funde uma lista de conceitos (entradas de data/conceitos.lua, cada uma com
-- `peso` e `dif`) numa magia. `nome` é opcional (rótulo que o jogador dá à sua
-- criação). Devolve uma tabela no MESMO formato que magia.conjurar espera
-- (`custo` + `dif`), mais metadados da fusão:
--   {
--     nome        = string,
--     custo       = SEMPRE magia.CUSTO_FUSAO (fixo; não escala com nada),
--     dif         = Σ (peso + dif de cada conceito) + penalidade de complexidade,
--     conceitos   = { ids... } (referência do que a compõe),
--     tags        = { tags únicas de todos os conceitos },
--   }
-- Devolve nil + motivo se a lista estiver vazia (não dá pra fundir nada).
-- NOTA: `peso` do conceito não paga mais custo (que é sempre 1) — ele agora
-- soma na DIFICULDADE junto com `dif`. Um conceito "pesado" (ex.: Átomo/
-- nuclear) fica mais difícil de conjurar, não mais caro — o preço de forças
-- brutas é inteiramente em chance de sucesso.
function magia.fundir(conceitos, nome)
  if not conceitos or #conceitos == 0 then
    return nil, "nenhum conceito pra fundir"
  end

  local dif = 0
  local ids, tags, tags_vistas = {}, {}, {}
  for _, c in ipairs(conceitos) do
    dif = dif + (c.dif or 0) + (c.peso or 0)
    ids[#ids + 1] = c.id or c.nome
    for _, t in ipairs(c.tags or {}) do
      if not tags_vistas[t] then
        tags_vistas[t] = true
        tags[#tags + 1] = t
      end
    end
  end

  -- Cada conceito ALÉM do primeiro adiciona instabilidade (só à dificuldade).
  local extras = (#conceitos - 1) * magia.PENALIDADE_POR_CONCEITO_EXTRA
  dif = dif + extras

  return {
    nome = nome or "Magia sem nome",
    custo = magia.CUSTO_FUSAO,
    dif = dif,
    conceitos = ids,
    tags = tags,
  }
end

-- Reduz a DIFICULDADE em 2 pra cada Sonho EXTRA pago além do custo da magia
-- (ver magia.conjurar, parâmetro `sonhos_extra`). Sem teto — o mago pode
-- sempre pagar mais pra forçar o acerto, desde que tenha Sonhos (que não têm
-- teto). NOTA: isso empurra em direção OPOSTA à regra já existente de que o
-- Sonhos que SOBRA (pós-custo) entra na base do teste — pagar mais Sonhos
-- extra reduz a meta a bater, mas também reduz seu próprio Sonhos restante
-- (logo sua própria base). É um gasto de dois gumes, de propósito: força
-- bruta tem preço nos dois lados da conta, não só na meta.
magia.REDUCAO_DIF_POR_SONHO_EXTRA = 2

-- Conjura uma `feitico` (entrada de data/magias.lua — precisa de `custo` e
-- `dif`) usando o `conjurador` (ficha de mago). `rng` opcional pra testes
-- determinísticos. `sonhos_extra` (opcional, padrão 0) é quanto o conjurador
-- ESCOLHE pagar A MAIS além do custo da magia, na hora de conjurar (não na
-- fusão) — cada ponto extra reduz a dificuldade em REDUCAO_DIF_POR_SONHO_EXTRA
-- (ver acima).
--
-- Fórmula do teste (ver sistemas.md):
--   resultado = sonhos_atual (DEPOIS de pagar custo + sonhos_extra) + vontade + 1d3
--   dif_efetiva = dif da magia − (sonhos_extra × REDUCAO_DIF_POR_SONHO_EXTRA)
--   passa se resultado >= dif_efetiva
-- Falha FEIA (gera Quebras) = errou por MAIS que metade da dif EFETIVA
-- (arredondada pra baixo). Falha leve ("quase passei") não gera Quebras.
-- Quebras geradas escalam com a DIFICULDADE ORIGINAL da magia (feitico.dif,
-- antes da redução por sonhos_extra) — o custo é sempre 1 (ver
-- magia.CUSTO_FUSAO), então é a dificuldade que carrega o tamanho/ambição da
-- fusão. A "segurança extra" paga não compra desconto no tamanho da queda se
-- ainda assim falhar feio (ver magia.quebras_por_falha).
--
-- Devolve tabela:
--   {
--     conjurou       = bool (false também se não tinha Sonhos pro custo total),
--     sem_sonhos     = bool (recusou por falta de Sonhos, nem chegou a rolar),
--     passou         = bool (resultado do teste, só existe se sem_sonhos == false),
--     falha_feia     = bool,
--     quebras_ganhas = número (0 se passou ou falha leve),
--     sonhos_extra   = número pago a mais (0 se não usou a opção),
--     base, face, bonus, total, dif = detalhes do teste (dif já é a EFETIVA),
--   }
function magia.conjurar(conjurador, feitico, rng, sonhos_extra)
  sonhos_extra = sonhos_extra or 0
  local custo_total = feitico.custo + sonhos_extra
  if not conjurador:gastar_sonhos(custo_total) then
    return { conjurou = false, sem_sonhos = true, quebras_ganhas = 0 }
  end

  local dif_efetiva = feitico.dif - sonhos_extra * magia.REDUCAO_DIF_POR_SONHO_EXTRA

  local base = conjurador:sonhos_atual() + conjurador:attr("vontade")
  local bonus, face = dado.rolar(rng)
  local total = base + bonus
  local passou = total >= dif_efetiva

  local resultado = {
    conjurou = passou,
    sem_sonhos = false,
    passou = passou,
    base = base,
    face = face,
    bonus = bonus,
    total = total,
    dif = dif_efetiva,
    sonhos_extra = sonhos_extra,
    falha_feia = false,
    quebras_ganhas = 0,
  }

  if not passou then
    local margem_falha = dif_efetiva - total
    local limiar = math.floor(dif_efetiva / 2)
    if margem_falha > limiar then
      resultado.falha_feia = true
      -- Usa feitico.dif (a ambição ORIGINAL da fusão), não a dif_efetiva já
      -- reduzida por sonhos_extra — pagar mais Sonhos melhora a chance de
      -- acertar, mas não compra desconto no tamanho da queda se ainda assim
      -- falhar feio.
      resultado.quebras_ganhas = magia.quebras_por_falha(feitico.dif)
      conjurador:ganhar_quebras(resultado.quebras_ganhas)
    end
  end

  return resultado
end

return magia
