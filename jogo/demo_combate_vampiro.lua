-- demo_combate_vampiro.lua
-- Demonstração jogável do combate como VAMPIRO (isolada do jogo principal).
-- Rode pelo launcher pra ter acentos, ou:  lua demo_combate_vampiro.lua
--
-- Pensada pra exercitar os 3 estigmas gerais no menu Habilidades:
--   Elevação  — buff físico temporário (custa Sangue)
--   Dominatio — tenta atordoar o inimigo (custa Sangue)
--   Besta     — acalmar, dá folga contra o Frenesi (custa Sangue)
-- Geração 5 (multiplicador x2 na Elevação) e Sangue/Vontade padrão de
-- propósito: gastar Sangue à toa pode te jogar em Frenesi de verdade — a
-- tensão é sentir quando vale a pena arriscar.

package.path = package.path .. ";./?.lua"

local console = require("util.console")
local ficha = require("core.ficha")
local armas = require("data.armas")
local combate_ui = require("core.combate_ui")

console.preparar()

-- Você: um vampiro de geração 5 (Elevação x2), atributos de camponês comum.
local jogador = ficha.nova({ geracao = 5 }, "vampiro")

-- O caçador: humano treinado, arma branca — mesma lógica do outro demo.
local inimigo = ficha.nova({}, "humano")
inimigo.pericias.esgrima = 3

local resultado = combate_ui.lutar(
  jogador, inimigo,
  { jogador = "Você", inimigo = "O caçador" },
  { jogador = armas.adaga, inimigo = armas.espada }
)

console.limpar()
console.linha("")
console.linha("  [ demo encerrada — desfecho: " .. resultado .. " ]")
console.linha("")
