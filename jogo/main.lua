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
  else
    console.linha("  Assim termina — mais um nome que o mundo não vai lembrar.")
  end
  console.linha("")
  console.linha("  [ fim do protótipo ]")
  console.linha("")
  console.pausar("  (Enter para sair)")
end

-- Gancho da rota do vampirismo (desfecho "preso" da masmorra). Por ora só um
-- marcador; será construída na sequência (ver campanha/principal).
local function rota_vampirismo()
  console.limpar()
  console.linha("")
  console.linha("  A porta da cela range. Você não está mais sozinho.")
  console.linha("")
  console.linha("  [ A rota do vampirismo começa aqui — a construir ]")
  console.linha("")
  console.pausar("  (Enter para sair)")
end

local function main()
  tela_abertura()
  local raca = escolher_origem()
  local jogador = criar_personagem(raca)
  despertar(raca)

  -- Caminho HUMANO: começa preso na masmorra.
  --   fuga  -> segue livre (por ora, o primeiro encontro na estrada)
  --   preso -> rota do vampirismo (gancho)
  -- (O lobisomem, por ora, vai direto ao primeiro encontro — inalterado.)
  if raca == "humano" then
    local saida = masmorra.jogar()
    if saida == "preso" then
      rota_vampirismo()
      return
    end
    -- escapou: continua livre.
  end

  local resultado = primeiro_encontro(jogador)
  desfecho(resultado)
end

main()
