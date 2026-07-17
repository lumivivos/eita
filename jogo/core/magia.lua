-- core/magia.lua
-- Resolução de uma conjuração (ver sistemas.md > Sonhos & Quebras). Lógica
-- pura, sem UI — devolve um resultado detalhado pra a camada de tela narrar.
-- Espelha core/combate.lua na estrutura (mesmo espírito: motor separado da
-- apresentação).

local dado = require("core.dado")

local magia = {}

-- Quantas Quebras uma FALHA FEIA de uma magia de determinado custo gera.
-- Escala em degraus de 5: custo 1-5 -> 1 Quebra, 6-10 -> 2, 11-15 -> 3, e
-- sucessivamente (ver sistemas.md).
function magia.quebras_por_falha(custo_sonhos)
  return math.ceil(custo_sonhos / 5)
end

-- ---- Fusão de conceitos (spellmaking) --------------------------------------
-- O mago funde CONCEITOS aprendidos (tijolos de data/conceitos.lua) numa magia
-- sua (ver sistemas.md > Conceitos & Fusão). NÃO há escola de magia nem lista
-- de feitiços: o único limite é ter os conceitos aprendidos e ter Sonhos pra
-- pagar. Este é o único lugar que decide o custo/dif de uma magia — o resto do
-- motor (magia.conjurar) trata a magia fundida igual a qualquer outra entrada.

-- Penalidade por COMPLEXIDADE: fundir mais conceitos numa mesma magia é mais
-- instável. O 1º conceito não penaliza; cada conceito ADICIONAL soma isto ao
-- custo E à dif (provisório — afinar depois de jogar; ver sistemas.md).
magia.PENALIDADE_POR_CONCEITO_EXTRA = 1

-- Funde uma lista de conceitos (entradas de data/conceitos.lua, cada uma com
-- `peso` e `dif`) numa magia. `nome` é opcional (rótulo que o jogador dá à sua
-- criação). Devolve uma tabela no MESMO formato que magia.conjurar espera
-- (`custo` + `dif`), mais metadados da fusão:
--   {
--     nome        = string,
--     custo       = Σ pesos + penalidade de complexidade,
--     dif         = Σ difs  + penalidade de complexidade,
--     conceitos   = { ids... } (referência do que a compõe),
--     tags        = { tags únicas de todos os conceitos },
--   }
-- Devolve nil + motivo se a lista estiver vazia (não dá pra fundir nada).
function magia.fundir(conceitos, nome)
  if not conceitos or #conceitos == 0 then
    return nil, "nenhum conceito pra fundir"
  end

  local custo, dif = 0, 0
  local ids, tags, tags_vistas = {}, {}, {}
  for _, c in ipairs(conceitos) do
    custo = custo + (c.peso or 0)
    dif = dif + (c.dif or 0)
    ids[#ids + 1] = c.id or c.nome
    for _, t in ipairs(c.tags or {}) do
      if not tags_vistas[t] then
        tags_vistas[t] = true
        tags[#tags + 1] = t
      end
    end
  end

  -- Cada conceito ALÉM do primeiro adiciona instabilidade (custo e dif).
  local extras = (#conceitos - 1) * magia.PENALIDADE_POR_CONCEITO_EXTRA
  custo = custo + extras
  dif = dif + extras

  return {
    nome = nome or "Magia sem nome",
    custo = custo,
    dif = dif,
    conceitos = ids,
    tags = tags,
  }
end

-- Conjura uma `feitico` (entrada de data/magias.lua — precisa de `custo` e
-- `dif`) usando o `conjurador` (ficha de mago). `rng` opcional pra testes
-- determinísticos.
--
-- Fórmula do teste (ver sistemas.md):
--   resultado = sonhos_atual (DEPOIS de pagar o custo) + vontade + 1d3
--   passa se resultado >= dif da magia
-- Falha FEIA (gera Quebras) = errou por MAIS que metade da dif (arredondada
-- pra baixo). Falha leve ("quase passei") não gera Quebras.
--
-- Devolve tabela:
--   {
--     conjurou       = bool (false também se não tinha Sonhos pro custo),
--     sem_sonhos     = bool (recusou por falta de Sonhos, nem chegou a rolar),
--     passou         = bool (resultado do teste, só existe se sem_sonhos == false),
--     falha_feia     = bool,
--     quebras_ganhas = número (0 se passou ou falha leve),
--     base, face, bonus, total, dif = detalhes do teste,
--   }
function magia.conjurar(conjurador, feitico, rng)
  if not conjurador:gastar_sonhos(feitico.custo) then
    return { conjurou = false, sem_sonhos = true, quebras_ganhas = 0 }
  end

  local base = conjurador:sonhos_atual() + conjurador:attr("vontade")
  local bonus, face = dado.rolar(rng)
  local total = base + bonus
  local passou = total >= feitico.dif

  local resultado = {
    conjurou = passou,
    sem_sonhos = false,
    passou = passou,
    base = base,
    face = face,
    bonus = bonus,
    total = total,
    dif = feitico.dif,
    falha_feia = false,
    quebras_ganhas = 0,
  }

  if not passou then
    local margem_falha = feitico.dif - total
    local limiar = math.floor(feitico.dif / 2)
    if margem_falha > limiar then
      resultado.falha_feia = true
      resultado.quebras_ganhas = magia.quebras_por_falha(feitico.custo)
      conjurador:ganhar_quebras(resultado.quebras_ganhas)
    end
  end

  return resultado
end

return magia
