-- core/sagrado.lua
-- Resolução do ataque de Sagrado (ver sistemas.md > Sagrado e lore.md >
-- Eden). Poder por fé verdadeira e intensa, UNIVERSAL (qualquer raça pode
-- ter, não só a Eden) — sem custo de recurso pra usar (diferente de
-- Sangue/Sonhos/Fúria). O dano é uma FERIDA SAGRADA (`ficha:sofrer_sagrado`):
-- trava um pedaço do teto de cura sobrenatural do alvo (regen passiva,
-- Sangue, magia...) — só cura mundana resolve. Lógica pura, sem UI — espelha
-- core/dominatio.lua.

local dado = require("core.dado")

local sagrado = {}

-- Dano por nível de Sagrado (1-5). PROVISÓRIO — número escolhido pra já
-- sair forte (pedido explícito: precisa ser DPS considerável mesmo pra
-- lobisomem/mago de nível alto), ajustar depois de jogar. O dano final soma
-- a MARGEM do teste (quanto passou da defesa), igual ao combate normal.
sagrado.DANO_POR_NIVEL = 5

-- Tenta atingir `alvo` com o poder de `atacante` (fichas). `rng` opcional
-- pra testes determinísticos.
--
-- Teste: `nível de Sagrado + 1d3 + floor(Vontade/2)`, comparado com a
-- FORÇA DE VONTADE MÁXIMA do alvo (`ficha:defesa_mental` — a base, não a
-- pool gastável). SEM CUSTO: não gasta Sangue/Sonhos/Fúria/nada, só precisa
-- ter o Sagrado.
--
-- Devolve tabela:
--   {
--     tentou = bool (false só se nem tem o Sagrado),
--     passou = bool,
--     dano   = número (0 se falhou),
--     base, face, bonus, total, dif = detalhes do teste,
--   }
function sagrado.tentar(atacante, alvo, rng)
  if not atacante:tem_sagrado() then
    return { tentou = false, sem_sagrado = true, dano = 0 }
  end

  local nivel = atacante:sagrado_nivel_atual() or 1
  local base = nivel + math.floor(atacante:attr("vontade") / 2)
  local bonus, face = dado.rolar(rng)
  local total = base + bonus
  local dif = alvo:defesa_mental()
  local passou = total >= dif

  local resultado = {
    tentou = true,
    sem_sagrado = false,
    passou = passou,
    base = base,
    face = face,
    bonus = bonus,
    total = total,
    dif = dif,
    dano = 0,
  }

  if passou then
    local margem = total - dif
    resultado.dano = nivel * sagrado.DANO_POR_NIVEL + margem
    -- sofrer_sagrado (não sofrer comum): a ferida trava um pedaço do teto de
    -- cura SOBRENATURAL do alvo — só cura mundana a resolve (ver ficha.lua).
    alvo:sofrer_sagrado(resultado.dano)
  end

  return resultado
end

return sagrado
