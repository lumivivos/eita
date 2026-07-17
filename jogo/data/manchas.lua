-- data/manchas.lua
-- Catálogo de MANCHAS — atos que "marcam" a Humanidade (ver sistemas.md >
-- Humanidade & Marcações). Data-driven, igual conceitos/magias: adicionar um
-- ato que corrói a alma = adicionar uma entrada aqui, sem tocar no motor.
--
-- Como funciona (motor em core/ficha.lua): cada ato dá UMA marcação. Ao juntar
-- MARCACOES_POR_HUMANIDADE (3), cai 1 de Humanidade e a contagem ZERA. A
-- corrupção é gradual: um ato solto não pune; a reincidência é que desce a
-- Humanidade. (Diablerie é a ÚNICA exceção — tira 1 Humanidade direto, sem
-- passar por marcação; ver ficha:diablerizar.)
--
-- Cada mancha é só um id -> rótulo (todo ato vale 1; a gravidade vem de
-- QUANTAS vezes se faz, não de peso por ato):
--
--   id_do_ato = { nome = "Rótulo exibido" }
--
-- (Propositalmente enxuto — QUAIS atos mancham é conteúdo criativo. O motor
-- aceita qualquer id; passe-o pra ficha:marcar_humanidade(id). Exemplos de
-- atos que devem entrar aqui conforme o jogo cresce: sugar até a morte,
-- roubar, mentir sob juramento, quebrar hospitalidade, etc.)

return {
  -- sugar_ate_a_morte = { nome = "Sugar até a morte" },
  -- roubar            = { nome = "Roubar" },
  -- mentir_juramento  = { nome = "Mentir sob juramento" },
}
