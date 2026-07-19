-- data/pericias.lua
-- Catálogo de GRIND por perícia — quantos usos pra subir 1 nível (ver
-- sistemas.md > Perícias > "cada perícia tem seu grind próprio, definido
-- manualmente"). Perícia que não está aqui usa o padrão
-- (ficha.PERICIA_USOS_PADRAO, ver core/ficha.lua).
--
--   id_da_pericia = { grind = N }
--
-- Provisório: só as perícias já exercitadas pelo combate atual (armas em
-- data/armas.lua) e a Intimidação (já citada em sistemas.md como referência
-- de "sobe rápido") estão preenchidas. O resto do catálogo (Furtividade,
-- Persuasão, Ocultismo, etc.) é conteúdo — fica pra quando for escrito.

return {
  esgrima = { grind = 12 },         -- arma branca é técnica/timing; "não sobe a cada 2 espadadas"
  artes_marciais = { grind = 8 },   -- briga desarmada, um pouco mais rápida que esgrima
  armas_de_haste = { grind = 10 },  -- lança/haste: perto da esgrima em ritmo
  intimidacao = { grind = 2 },      -- referência de sistemas.md: "~2 usos já sobem"
}
