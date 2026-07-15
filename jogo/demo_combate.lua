-- demo_combate.lua
-- Demonstração jogável do combate (isolada do jogo principal).
-- Rode pelo launcher pra ter acentos, ou:  lua demo_combate.lua
--
-- Cenário HARDCORE e justo: você é um CAMPONÊS COMUM (atributos base, nenhuma
-- perícia) enfrentando um BANDIDO EXPERIENTE (mesmos atributos, mas treinado
-- em brigar). A diferença vem da HABILIDADE, não de superpoder. Deve ser tenso.

package.path = package.path .. ";./?.lua"

local console = require("util.console")
local ficha = require("core.ficha")
local armas = require("data.armas")
local combate_ui = require("core.combate_ui")

console.preparar()

-- Você: um lobisomem (pra testar formas + regeneração passiva por turno).
local jogador = ficha.nova({ agilidade = 3, vitalidade = 3, forca = 3, nivel = 4 }, "lobisomem")

-- O bandido: humano comum de atributos, mas EXPERIENTE — treinado em brigar.
local inimigo = ficha.nova({}, "humano")
inimigo.pericias.esgrima = 3   -- veterano de facadas

local resultado = combate_ui.lutar(
  jogador, inimigo,
  { jogador = "Você", inimigo = "O bandido" },
  { jogador = armas.adaga, inimigo = armas.adaga }  -- mesma arma; a perícia decide
)

console.limpar()
console.linha("")
console.linha("  [ demo encerrada — desfecho: " .. resultado .. " ]")
console.linha("")
