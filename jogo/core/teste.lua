-- core/teste.lua
-- A fórmula de teste do jogo (ver sistemas.md > Fórmula do teste).
--
--   Teste de ATRIBUTO:   resultado = atributo + 1d3
--   Teste de HABILIDADE: resultado = atributo + nível_habilidade + 1d3
--   Passa se  resultado >= dificuldade
--
-- Este módulo NÃO conhece a ficha nem o personagem — só recebe números.
-- Isso o torna trivial de testar e reaproveitar (combate vai usar o mesmo).

local dado = require("core.dado")

local teste = {}

-- Executa um teste.
--   base       = soma dos valores fixos do personagem (atributo, ou
--                atributo+habilidade). Quem monta essa soma é o chamador.
--   dificuldade = número-alvo (ancorado em feito concreto).
--   rng        = gerador opcional (pra testes determinísticos).
--
-- Devolve uma tabela com o resultado detalhado, pra a narrativa/UI decidir
-- o que mostrar (e pra a Força de Vontade saber se vale rerrolar):
--   {
--     passou   = bool,
--     base     = número (o que o personagem trouxe),
--     face     = 1/2/3 (o que saiu no d3),
--     bonus    = 0/1/2 (o que o dado somou),
--     total    = base + bonus,
--     dif      = dificuldade,
--     vacilou  = bool (a face foi 1),
--   }
function teste.rolar(base, dificuldade, rng)
  local bonus, face = dado.rolar(rng)
  local total = base + bonus
  return {
    passou = total >= dificuldade,
    base = base,
    face = face,
    bonus = bonus,
    total = total,
    dif = dificuldade,
    vacilou = dado.eh_vacilo(face),
  }
end

-- Açúcar sintático: teste de atributo puro.
function teste.atributo(valor_atributo, dificuldade, rng)
  return teste.rolar(valor_atributo, dificuldade, rng)
end

-- Açúcar sintático: teste de habilidade (atributo + nível da habilidade).
function teste.habilidade(valor_atributo, nivel_habilidade, dificuldade, rng)
  return teste.rolar(valor_atributo + nivel_habilidade, dificuldade, rng)
end

return teste
