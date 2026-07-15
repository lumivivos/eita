-- core/dado.lua
-- O dado do jogo. Regra central (ver sistemas.md > Fórmula do teste):
--   Rola-se 1d3 sempre. O BÔNUS que ele soma ao teste é:
--     face 1 -> +0  (o "vacilo")
--     face 2 -> +1
--     face 3 -> +2
-- O bônus real é 0/1/2 — contido de propósito, pra que o atributo domine.
--
-- Isolado num módulo próprio: se um dia a regra do dado mudar, muda-se só aqui.

local dado = {}

-- Converte a FACE crua do d3 (1..3) no BÔNUS que entra no teste (0/1/2).
-- Deixado exposto pra que os testes possam verificar o mapeamento diretamente.
function dado.bonus_da_face(face)
  return face - 1  -- 1->0, 2->1, 3->2 (o vacilo é a face 1)
end

-- Rola uma face de d3 (1..3). Aceita um gerador opcional `rng` (função que
-- devolve um float em [0,1), como math.random) — assim os testes podem
-- injetar valores determinísticos em vez da aleatoriedade real.
function dado.rolar_face(rng)
  rng = rng or math.random
  -- math.random() em [0,1) -> 1..3
  return math.floor(rng() * 3) + 1
end

-- Rola o d3 e já devolve o BÔNUS (0/1/2) e a FACE (1/2/3) que saiu.
-- Devolve dois valores: bonus, face.
function dado.rolar(rng)
  local face = dado.rolar_face(rng)
  return dado.bonus_da_face(face), face
end

-- Verdadeiro se a face rolada é um vacilo (não somou nada).
function dado.eh_vacilo(face)
  return face == 1
end

return dado
