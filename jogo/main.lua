-- main.lua
-- Ponto de entrada do jogo. Fluxo do protótipo jogável:
--   abertura -> escolha de origem -> cria ficha -> cena -> primeiro combate -> desfecho
--
-- Abra pelo launcher jogar.cmd (Windows) pra ter acentos corretos.

package.path = package.path .. ";./?.lua"

local console = require("util.console")
local ficha = require("core.ficha")
local racas = require("data.racas")
local armas = require("data.armas")
local combate_ui = require("core.combate_ui")
local masmorra = require("core.masmorra")
local dado = require("core.dado")

console.preparar()

local TITULO = "ABERRAÇÃO"

local function tela_abertura()
  console.limpar()
  console.linha("")
  console.linha("        " .. TITULO)
  console.linha("        " .. string.rep("-", #TITULO))
  console.linha("")
  console.linha("  Um mundo que já pertenceu a um deus, e não pertence mais.")
  console.linha("  Você não é um herói. Você é apenas mais um.")
  console.linha("")
  console.pausar("  (pressione Enter)")
end

-- Primeira decisão. Define só o PONTO DE PARTIDA (a raça de nascimento),
-- sem revelar ao jogador o que cada opção implica.
-- Devolve a chave de raça: "humano" ou "lobisomem".
local function escolher_origem()
  console.limpar()
  console.linha("")
  console.linha("  Antes de tudo, uma pergunta.")
  console.linha("")
  console.linha("  Deseja ser um monstro ou um homem?")
  console.linha("")
  local escolha = console.menu({ "Um homem.", "Um monstro." })
  return escolha == 1 and "humano" or "lobisomem"
end

-- Cria a ficha do jogador a partir da raça escolhida (atributos iniciais
-- vêm de data/racas.lua; perícias começam em 0).
local function criar_personagem(raca)
  local def = racas[raca]
  return ficha.nova(def.atributos, raca)
end

-- Cena de "despertar" no mundo — tom conforme a raça, sem entregar mecânica.
local function despertar(raca)
  console.limpar()
  console.linha("")
  if raca == "humano" then
    console.linha("  Você abre os olhos como um homem. Frágil. Comum. Livre.")
    console.linha("")
    console.linha("  A estrada de terra corta a floresta. Você não lembra o")
    console.linha("  próprio nome, nem que idade tem. Só a fome, e o frio.")
  else
    console.linha("  Você abre os olhos como um monstro. O sangue de Gaia")
    console.linha("  e de Caos disputa dentro de você desde o primeiro fôlego.")
    console.linha("")
    console.linha("  A floresta cheira a tudo ao mesmo tempo. Você não lembra")
    console.linha("  o próprio nome — mas seus dentes lembram para que servem.")
  end
  console.linha("")
  console.pausar("  (Enter)")
end

-- Prepara e roda o primeiro encontro (um bandido na estrada).
local function primeiro_encontro(jogador)
  console.limpar()
  console.linha("")
  console.linha("  Passos na estrada. Um homem sai de trás das árvores, faca")
  console.linha("  em punho. Não é a primeira vez que ele faz isso.")
  console.linha("")
  console.pausar("  (Enter)")

  -- Bandido: humano comum de atributos, mas com prática de briga.
  local bandido = ficha.nova({}, "humano")
  bandido.pericias.esgrima = 2

  -- Arma do jogador conforme a raça: humano começa de punhos; lobisomem idem
  -- (a fera usa garras/formas pelo menu Habilidades).
  local arma_jogador = armas.punhos

  return combate_ui.lutar(
    jogador, bandido,
    { jogador = "Você", inimigo = "O bandido" },
    { jogador = arma_jogador, inimigo = armas.adaga }
  )
end

local function desfecho(resultado)
  console.limpar()
  console.linha("")
  if resultado == "vitoria" then
    console.linha("  O corpo esfria a seus pés. Você continua vivo — por ora.")
    console.linha("  A estrada segue. E ela é longa.")
  elseif resultado == "fuga" then
    console.linha("  Você corre até os pulmões arderem. Escapou. Dessa vez.")
  elseif resultado == "morte" then
    console.linha("  Assim termina — mais um nome que o mundo não vai lembrar.")
  else
    -- Fallback defensivo: combate_ui.lutar só devolve vitoria/fuga/morte hoje.
    -- Se algum dia devolver outra coisa, isto evita uma tela muda.
    console.linha("  [ desfecho desconhecido: " .. tostring(resultado) .. " ]")
  end
  console.linha("")
  console.linha("  [ fim do protótipo ]")
  console.linha("")
  console.pausar("  (Enter para sair)")
end

-- Rota do vampirismo (desfecho "preso" da masmorra). Um vampiro te encontra
-- na cela e te transforma — sem escolha, como a fuga já não é mais possível.
-- Transforma a MESMA ficha (ficha:transformar_raca), preservando tudo que o
-- jogador já era; só a raça (e os recursos que vêm com ela) muda.
local function rota_vampirismo(jogador)
  console.limpar()
  console.linha("")
  console.linha("  A porta da cela range. Você não está mais sozinho.")
  console.linha("")
  console.linha("  Uma figura pálida entra, sem pressa nenhuma. Fome nos")
  console.linha("  olhos — mas também cálculo, como quem já decidiu algo.")
  console.linha("")
  console.pausar("  (Enter)")

  console.linha("")
  console.linha("  Não há negociação. Presas encontram sua garganta antes")
  console.linha("  que você consiga reagir.")
  console.linha("")
  console.pausar("  (Enter)")

  jogador:transformar_raca("vampiro")

  console.linha("")
  console.linha("  Quando a dor passa, o mundo parece diferente. Mais")
  console.linha("  nítido. Mais frio. Você já não é mais só um homem")
  console.linha("  preso numa cela.")
  console.linha("")
  console.pausar("  (Enter)")
end

-- Chance de os Sonhos te notarem logo após escapar (só caminho humano — ver
-- lore.md > Magos: "buscam pessoas aptas... seja um animal ou humano, não
-- importa"). Rola 1d3; só a face 3 (1/3 de chance) acerta. Se acertar,
-- transforma a ficha em mago; senão, o jogador simplesmente segue humano.
local function tentar_sonhos(jogador)
  local _, face = dado.rolar()
  if face ~= 3 then
    return
  end

  console.limpar()
  console.linha("")
  console.linha("  Livre, correndo ainda ofegante, algo te nota. Não é um")
  console.linha("  deus, nem um monstro — um sussurro sem voz, atrás dos")
  console.linha("  seus olhos, dentro do seu peito. Procurando alguém apto.")
  console.linha("")
  console.pausar("  (Enter)")

  jogador:transformar_raca("mago")

  console.linha("")
  console.linha("  Encontrou. A partir de agora, a realidade tem uma nova")
  console.linha("  fresta — e ela passa por você.")
  console.linha("")
  console.pausar("  (Enter)")
end

local function main()
  tela_abertura()
  local raca = escolher_origem()
  local jogador = criar_personagem(raca)
  despertar(raca)

  -- Caminho HUMANO: começa preso na masmorra.
  --   fuga  -> segue livre; chance de os Sonhos te notarem (vira mago)
  --   preso -> um vampiro te encontra e te transforma (rota_vampirismo)
  -- Os dois casos seguem pro mesmo primeiro encontro depois — a ficha (agora
  -- vampiro/mago/humano) já carrega os recursos certos pro combate.
  -- (O lobisomem, por ora, vai direto ao primeiro encontro — inalterado.)
  if raca == "humano" then
    local saida = masmorra.jogar()
    if saida == "preso" then
      rota_vampirismo(jogador)
    else
      tentar_sonhos(jogador)
    end
  end

  local resultado = primeiro_encontro(jogador)
  desfecho(resultado)
end

main()
