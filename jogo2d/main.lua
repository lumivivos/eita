-- jogo2d/main.lua
-- Versão 2D (LÖVE2D) do jogo. REAPROVEITA a lógica do protótipo de terminal
-- (../jogo/core/) — o "cérebro" é o mesmo; aqui muda só a APRESENTAÇÃO (janela,
-- desenho, input). Placeholders por enquanto (retângulos no lugar de sprites).
--
-- Rodar:  love jogo2d       (a partir da pasta bobagem/)

-- Deixa o require enxergar os módulos de lógica do protótipo de terminal.
-- (fonte única da verdade: a lógica vive em jogo/core, usada pelas duas versões)
package.path = package.path
  .. ";../jogo/?.lua"      -- quando rodado de dentro de jogo2d/
  .. ";./jogo/?.lua"       -- quando rodado da pasta bobagem/
  .. ";../?.lua;./?.lua"

local ficha = require("core.ficha")
local combate = require("core.combate")
local armas = require("data.armas")

-- ---- Estado do jogo (mínimo, só pra provar a tela de combate) --------------
local jogo = {}

-- Cores dos placeholders (trocar por sprites depois).
local COR = {
  fundo      = {0.08, 0.07, 0.10},
  jogador    = {0.35, 0.55, 0.75},
  inimigo    = {0.70, 0.30, 0.30},
  caixa      = {0.15, 0.14, 0.18},
  texto      = {0.90, 0.88, 0.85},
  destaque   = {0.95, 0.80, 0.35},
  sombra     = {0, 0, 0, 0.4},
}

local FONTE       -- fonte grande (texto)
local FONTE_PEQ   -- fonte pequena (dicas)

-- Ações do menu de combate.
local ACOES = { "Atacar", "Esquivar", "Fugir" }

function love.load()
  love.window.setTitle("ABERRAÇÃO")
  love.window.setMode(800, 500)
  love.graphics.setBackgroundColor(COR.fundo)

  FONTE = love.graphics.newFont(18)
  FONTE_PEQ = love.graphics.newFont(13)

  -- Monta um combate de teste com a MESMA lógica do terminal.
  jogo.jogador = ficha.nova({ forca = 3, vitalidade = 3, agilidade = 3 }, "lobisomem")
  jogo.inimigo = ficha.nova({}, "humano")
  jogo.inimigo.pericias.esgrima = 2
  jogo.arma_jogador = armas.punhos
  jogo.arma_inimigo = armas.adaga

  jogo.selecao = 1                  -- índice do menu de ações
  jogo.log = { "Um bandido se ergue diante de você." }  -- narração recente
  jogo.acabou = nil                 -- nil | "vitoria" | "morte" | "fuga"
end

-- Adiciona uma linha ao log (mantém as últimas 4).
local function logar(txt)
  table.insert(jogo.log, txt)
  while #jogo.log > 4 do table.remove(jogo.log, 1) end
end

-- Descreve a saúde sem número (HP é secreto).
local function saude(f)
  local frac = f.hp / f:hp_max()
  if frac <= 0 then return "caído"
  elseif frac < 0.25 then return "à beira da morte"
  elseif frac < 0.5 then return "gravemente ferido"
  elseif frac < 0.85 then return "ferido"
  else return "inteiro" end
end

-- Frase de um ataque (reusa os tipos do core/combate).
local function frase(atacante, alvo, r)
  local arma = r.arma and r.arma.nome or "o golpe"
  if r.tipo == "erro" then return atacante .. " ataca, mas erra " .. alvo .. "."
  elseif r.tipo == "parcial" then return atacante .. " arranha " .. alvo .. " — golpe raso."
  else return atacante .. " acerta " .. alvo .. " em cheio com " .. arma .. "!" end
end

-- Executa um turno completo (jogador age -> inimigo revida).
local function turno_jogador(acao)
  if jogo.acabou then return end

  if acao == "Atacar" then
    local r = combate.atacar(jogo.jogador, jogo.inimigo, jogo.arma_jogador)
    combate.aplicar(jogo.inimigo, r)
    logar(frase("Você", "o bandido", r))
    if not jogo.inimigo:vivo() then jogo.acabou = "vitoria"; logar("O bandido tomba."); return end
  elseif acao == "Fugir" then
    logar("Você tenta fugir...")
    jogo.acabou = "fuga"; return
  else
    logar("Você se prepara para desviar.")
  end

  -- Turno do inimigo.
  local ri = combate.atacar(jogo.inimigo, jogo.jogador, jogo.arma_inimigo)
  combate.aplicar(jogo.jogador, ri)
  logar(frase("O bandido", "você", ri))
  jogo.jogador:regenerar_turno()
  if not jogo.jogador:vivo() then jogo.acabou = "morte"; logar("Tudo escurece.") end
end

function love.keypressed(tecla)
  if jogo.acabou then
    if tecla == "escape" then love.event.quit() end
    return
  end
  if tecla == "up" then
    jogo.selecao = (jogo.selecao - 2) % #ACOES + 1
  elseif tecla == "down" then
    jogo.selecao = jogo.selecao % #ACOES + 1
  elseif tecla == "return" or tecla == "space" then
    turno_jogador(ACOES[jogo.selecao])
  elseif tecla == "escape" then
    love.event.quit()
  end
end

-- ---- Desenho (placeholders) ------------------------------------------------
function love.draw()
  local L, A = love.graphics.getDimensions()

  -- Personagens: retângulos placeholder.
  love.graphics.setColor(COR.inimigo)
  love.graphics.rectangle("fill", L - 220, 80, 120, 160, 8, 8)
  love.graphics.setColor(COR.jogador)
  love.graphics.rectangle("fill", 100, 80, 120, 160, 8, 8)

  -- Rótulos de estado (saúde secreta, sem número).
  love.graphics.setFont(FONTE_PEQ)
  love.graphics.setColor(COR.texto)
  love.graphics.printf("Você\n(" .. saude(jogo.jogador) .. ")", 100, 250, 120, "center")
  love.graphics.printf("Bandido\n(" .. saude(jogo.inimigo) .. ")", L - 220, 250, 120, "center")

  -- Caixa de narração (log).
  love.graphics.setColor(COR.caixa)
  love.graphics.rectangle("fill", 40, 310, L - 80, 110, 6, 6)
  love.graphics.setColor(COR.texto)
  love.graphics.setFont(FONTE_PEQ)
  for i, linha in ipairs(jogo.log) do
    love.graphics.print(linha, 56, 320 + (i - 1) * 22)
  end

  -- Menu de ações (ou desfecho).
  love.graphics.setFont(FONTE)
  if jogo.acabou then
    love.graphics.setColor(COR.destaque)
    local msg = ({ vitoria = "VITÓRIA", morte = "VOCÊ MORREU", fuga = "VOCÊ FUGIU" })[jogo.acabou]
    love.graphics.printf(msg .. "   (Esc para sair)", 0, 440, L, "center")
  else
    for i, a in ipairs(ACOES) do
      local x = 56 + (i - 1) * 160
      if i == jogo.selecao then
        love.graphics.setColor(COR.destaque)
        love.graphics.print("> " .. a, x, 440)
      else
        love.graphics.setColor(COR.texto)
        love.graphics.print("  " .. a, x, 440)
      end
    end
  end
end
