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
