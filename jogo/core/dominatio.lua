-- core/dominatio.lua
-- Resolução do estigma Dominatio (ver sistemas.md > Estigmas gerais).
-- Ataque mental: comandar/dominar a mente de outrem pelo olhar. Versão
-- MÍNIMA — só um stun básico; profundidade (comandos de verdade, resistência
-- graduada) fica pra depois. Lógica pura, sem UI — espelha core/combate.lua
-- e core/magia.lua na estrutura.

local dado = require("core.dado")

local dominatio = {}

dominatio.CUSTO_SANGUE = 1
dominatio.DURACAO_ATORDOADO_TURNOS = 2

-- Tenta dominar `alvo` com `atacante` (fichas de vampiro). `rng` opcional
-- pra testes determinísticos.
--
-- Teste: NÍVEL do atacante + 1d3, comparado com a DEFESA MENTAL do alvo (a
-- base de Vontade dele, estável — ver ficha:defesa_mental). Passa se
-- resultado >= dif.
--
-- BLOQUEIO AUTOMÁTICO (nem chega a rolar o dado, mas AINDA gasta o Sangue —
-- você tentou): se o alvo for vampiro de geração MENOR (mais forte, mais
-- perto de Caim) que o atacante. Ver lore.md: "você tem Dominatio, mas é
-- fraca demais pra dominar minha mente".
--
-- Sucesso = ATORDOA o alvo por DURACAO_ATORDOADO_TURNOS turnos (ver
-- ficha:atordoar) — perde a vez por completo.
--
-- Devolve tabela:
--   {
--     tentou      = bool (false só se nem tinha Sangue pro custo),
--     sem_sangue  = bool,
--     bloqueado   = bool (geração do alvo protegeu automaticamente),
--     passou      = bool,
--     base, face, bonus, total, dif = detalhes do teste (nil se bloqueado),
--   }
function dominatio.tentar(atacante, alvo, rng)
  if not atacante.sangue then
    return { tentou = false, sem_sangue = true }
  end

  -- Bloqueio automático por geração (só se ambos forem vampiro).
  local bloqueado = alvo.geracao and atacante.geracao and alvo.geracao < atacante.geracao

  if not atacante:gastar_sangue(dominatio.CUSTO_SANGUE) then
    return { tentou = false, sem_sangue = true }
  end

  if bloqueado then
    return { tentou = true, sem_sangue = false, bloqueado = true, passou = false }
  end

  local base = atacante.nivel
  local bonus, face = dado.rolar(rng)
  local total = base + bonus
  local dif = alvo:defesa_mental()
  local passou = total >= dif

  if passou then
    alvo:atordoar(dominatio.DURACAO_ATORDOADO_TURNOS)
  end

  return {
    tentou = true,
    sem_sangue = false,
    bloqueado = false,
    passou = passou,
    base = base,
    face = face,
    bonus = bonus,
    total = total,
    dif = dif,
  }
end

return dominatio
