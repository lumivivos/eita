-- data/racas.lua
-- Atributos iniciais por raça jogável de nascimento (ver sistemas.md).
-- Só as raças de NASCIMENTO entram aqui (humano, lobisomem). Vampiro/mago/
-- abominação são transformações posteriores, não pontos de partida.
--
-- Atributos não listados assumem o padrão da ficha (2; e Vontade = 5).
-- Perícias começam todas em 0 (aprendidas pelo uso).

return {
  humano = {
    nome = "Humano",
    -- tudo 2 (o padrão da ficha já cobre; explicitado pra clareza)
    atributos = {
      forca = 2, vitalidade = 2, agilidade = 2, carisma = 2, inteligencia = 2,
    },
  },
  lobisomem = {
    nome = "Lobisomem",
    atributos = {
      forca = 3, vitalidade = 3, agilidade = 2, carisma = 2, inteligencia = 2,
    },
    -- TODO: 3 sub-raças (lupino/humanoide/impuro) — a sortear no nascimento.
  },
}
