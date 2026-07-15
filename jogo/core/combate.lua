-- core/combate.lua
-- Resolução de um ataque (ver sistemas.md > Combate). Lógica pura, sem UI —
-- devolve um resultado detalhado pra a camada de tela narrar.

local dado = require("core.dado")

local combate = {}

-- Fração do dano cheio aplicada num acerto PARCIAL (bloqueio).
-- Bem reduzido, mas não-zero (anti-frustração). Arredonda pra baixo, mínimo 1.
combate.FRACAO_PARCIAL = 0.25

-- Resolve um ataque de `atacante` (ficha) contra `alvo` (ficha) com `arma`
-- (entrada de data/armas.lua). `rng` opcional pra testes determinísticos.
--
-- Devolve tabela:
--   {
--     tipo    = "erro" | "parcial" | "total",
--     ataque  = número rolado (atributo + habilidade + bônus do dado),
--     face,bonus,vacilou = detalhes do d3,
--     defesa  = defesa do alvo,
--     dano    = dano aplicado (0 no erro),
--   }
function combate.atacar(atacante, alvo, arma, rng)
  -- Arma efetiva: se a forma atual não empunha armas (Lupino/Bestial), usa a
  -- arma natural (garras). Só o atacante-ficha sabe disso.
  arma = combate.arma_efetiva(atacante, arma)

  local atributo = atacante:attr(arma.atributo)
  local pericia = atacante:pericia(arma.pericia)
  local bonus, face = dado.rolar(rng)
  -- Bônus de forma (0 pra quem não transforma). Acerto soma no teste; dano no dano.
  local acerto_forma = atacante.bonus_acerto_forma and atacante:bonus_acerto_forma() or 0
  local bonus_forma = atacante.bonus_dano_forma and atacante:bonus_dano_forma() or 0
  local ataque = atributo + pericia + bonus + acerto_forma
  local defesa = alvo:defesa()

  local resultado = {
    ataque = ataque,
    face = face,
    bonus = bonus,
    vacilou = dado.eh_vacilo(face),
    defesa = defesa,
    arma = arma,
    dano = 0,
  }

  if ataque <= arma.diff then
    -- Não superou nem a dificuldade da arma: errou o golpe.
    resultado.tipo = "erro"
  elseif ataque <= defesa then
    -- Passou da arma mas não da defesa: bloqueio, dano muito reduzido.
    resultado.tipo = "parcial"
    local cheio = arma.base + atributo + bonus_forma   -- (sem margem)
    resultado.dano = math.max(1, math.floor(cheio * combate.FRACAO_PARCIAL))
  else
    -- Superou a defesa: acerto total, dano escala com a margem.
    resultado.tipo = "total"
    local margem = ataque - defesa
    resultado.dano = arma.base + margem + atributo + bonus_forma
  end

  return resultado
end

-- Resolve a arma que o atacante realmente usa neste golpe. Se a ficha estiver
-- numa forma que não empunha armas, devolve a arma natural dela (garras).
function combate.arma_efetiva(atacante, arma_empunhada)
  if atacante.usa_armas and not atacante:usa_armas() then
    local f = atacante:forma_atual()
    if f and f.arma_natural then
      return require("data.armas")[f.arma_natural]
    end
  end
  return arma_empunhada
end

-- Aplica o resultado de um ataque no alvo (causa o dano). Devolve o HP restante.
function combate.aplicar(alvo, resultado)
  return alvo:sofrer(resultado.dano)
end

return combate
