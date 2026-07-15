-- demo_masmorra.lua
-- Demonstração isolada da cena da masmorra (tutorial de fuga).
-- Rode pelo launcher, ou:  lua demo_masmorra.lua

package.path = package.path .. ";./?.lua"

local console = require("util.console")
local masmorra = require("core.masmorra")

console.preparar()

local resultado = masmorra.jogar()

console.limpar()
console.linha("")
if resultado == "fuga" then
  console.linha("  [ você ESCAPOU — seguiria livre (humano/mago) ]")
else
  console.linha("  [ você ficou PRESO — começaria a rota do vampirismo ]")
end
console.linha("")
