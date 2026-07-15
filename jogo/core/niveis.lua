-- core/niveis.lua
-- Curva de níveis de personagem (ver sistemas.md > Progressão).
-- Nível vai de 1 a 10 (teto mortal). Subir é BEM difícil: curva CRESCENTE —
-- cada nível custa mais que o anterior, e o incremento também cresce.
--
-- Faixas de EXP das fontes (referência de design; o valor real é dado de cada
-- fonte, data-driven): combate comum 5-10; combate difícil até 100; exploração
-- 20-100; quests 10..sem teto (a fonte principal, definida a dedo).

local niveis = {}

niveis.MAX = 10

-- EXP necessário pra ir do nível N ao N+1 (custo do DEGRAU).
-- Começa em 100 e o incremento sobe +50 a cada degrau:
--   2:100, 3:250(+150), 4:450(+200), 5:700(+250), ... 10:2700.
-- (custo do degrau d = 100 + 50*(d-1)*(d)/2 ... mas montamos por soma simples)
local CUSTO_DEGRAU = {}  -- CUSTO_DEGRAU[n] = exp pra sair do nível n rumo a n+1
do
  local custo = 100
  local incremento = 150
  for n = 1, niveis.MAX - 1 do
    CUSTO_DEGRAU[n] = custo
    custo = custo + incremento
    incremento = incremento + 50
  end
end

-- Custo pra sair do nível `n` (rumo a n+1). 0 se já está no teto.
function niveis.custo_degrau(n)
  return CUSTO_DEGRAU[n] or 0
end

-- true se o nível `n` é o teto (não sobe mais).
function niveis.no_teto(n)
  return n >= niveis.MAX
end

-- Exponibilizado pra inspeção/testes: a tabela inteira de custos.
function niveis.tabela()
  return CUSTO_DEGRAU
end

return niveis
