-- data/armas.lua
-- Catálogo de armas (data-driven — adicionar arma = adicionar entrada aqui).
-- Cada arma declara:
--   nome      = rótulo exibido
--   base      = dano base
--   diff      = dificuldade SECRETA do golpe (piso do ataque; ver combate em sistemas.md)
--   atributo  = qual atributo entra no ataque E no dano
--   pericia   = qual perícia (interna) o ataque exercita/usa
--
-- A `diff` é secreta: a UI nunca a mostra ao analisar a arma.

return {
  punhos = {
    nome = "Punhos",
    base = 1,
    diff = 2,   -- acertar um golpe é fácil; o difícil é o alvo reagir (ver design)
    atributo = "forca",
    pericia = "artes_marciais",
  },
  -- Armas NATURAIS das formas Lupino/Bestial. Fera não empunha aço, mas rasga e
  -- morde. Garras: mais fáceis, menos dano. Presas: mais dano, mais arriscadas
  -- (diff maior — morder exige aproximar/expor mais que arranhar).
  garras = {
    nome = "Garras",
    base = 3,
    diff = 2,
    atributo = "forca",
    pericia = "artes_marciais",
    natural = true,
  },
  presas = {
    nome = "Presas",
    base = 4,
    diff = 4,   -- morder é bem mais difícil de acertar que arranhar
    atributo = "forca",
    pericia = "artes_marciais",
    natural = true,
  },
  adaga = {
    nome = "Adaga",
    base = 2,
    diff = 1,
    atributo = "agilidade",
    pericia = "esgrima",
  },
  espada = {
    nome = "Espada",
    base = 3,
    diff = 2,
    atributo = "agilidade",
    pericia = "esgrima",
  },
  lanca = {
    nome = "Lança",
    base = 3,
    diff = 2,
    atributo = "agilidade",
    pericia = "armas_de_haste",
  },
}
