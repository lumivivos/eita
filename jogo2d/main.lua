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
local teste = require("core.teste")
local armas = require("data.armas")
local formas = require("data.formas")

-- As feras que um lobisomem pode assumir a partir da forma humana (mesma
-- lista de core/combate_ui.lua, pra não haver duas fontes da verdade).
local FORMAS_FERA = { "crino", "lupino", "bestial" }

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
local ACOES = { "Atacar", "Esquivar", "Fugir", "Habilidades" }

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
  jogo.submenu = nil                -- não-nil = dentro do submenu de Habilidades
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

-- Fecha um turno: o inimigo revida (a menos que o jogador tenha esquivado)
-- e depois os dois regeneram (passiva de fim de turno, como no console).
local function turno_do_inimigo(esquivou)
  if not esquivou then
    local ri = combate.atacar(jogo.inimigo, jogo.jogador, jogo.arma_inimigo)
    combate.aplicar(jogo.jogador, ri)
    logar(frase("O bandido", "você", ri))
    if not jogo.jogador:vivo() then jogo.acabou = "morte"; logar("Tudo escurece."); return end
  end
  jogo.inimigo:regenerar_turno()
  jogo.jogador:regenerar_turno()
  -- Duração do buff de Fúria (3 turnos; ver ficha:passar_turno_furia).
  -- No-op pra quem não tem Fúria ativa (a maioria).
  jogo.inimigo:passar_turno_furia()
  jogo.jogador:passar_turno_furia()
end

-- Executa um turno completo (jogador age -> inimigo revida).
-- Esquivar/Fugir usam a mesma fórmula de teste do console (core/teste.lua),
-- pra não haver dois comportamentos diferentes pra mesma ação.
local function turno_jogador(acao)
  if jogo.acabou then return end

  local esquivou = false

  if acao == "Atacar" then
    local r = combate.atacar(jogo.jogador, jogo.inimigo, jogo.arma_jogador)
    combate.aplicar(jogo.inimigo, r)
    logar(frase("Você", "o bandido", r))
    if not jogo.inimigo:vivo() then jogo.acabou = "vitoria"; logar("O bandido tomba."); return end
  elseif acao == "Fugir" then
    local res = teste.atributo(jogo.jogador:attr("agilidade"), 5)
    if res.passou then
      logar("Você rompe o cerco e desaparece.")
      jogo.acabou = "fuga"; return
    else
      logar("Você tenta fugir, mas ele corta seu caminho.")
    end
  else -- Esquivar
    local res = teste.atributo(jogo.jogador:attr("agilidade"), 4)
    if res.passou then
      esquivou = true
      logar("Você escorrega para as sombras.")
    else
      logar("Você tenta se esquivar, mas trava. Exposto.")
    end
  end

  turno_do_inimigo(esquivou)
end

-- Monta as opções do submenu "Habilidades" pro estado atual (mesma regra de
-- core/combate_ui.lua: só o lobisomem tem conteúdo aqui, por ora).
local function abrir_habilidades()
  local opcoes, acoes = {}, {}
  if jogo.jogador.raca == "lobisomem" then
    if jogo.jogador:eh_humanoide() then
      for _, id in ipairs(FORMAS_FERA) do
        table.insert(opcoes, formas[id].nome)
        table.insert(acoes, id)
      end
    else
      table.insert(opcoes, formas.humanoide.nome)
      table.insert(acoes, "humanoide")
    end
    -- Fúria: uma opção por nível possível (1..FURIA_GASTO_MAX, limitado pelo
    -- quanto o jogador realmente tem). Dura FURIA_DURACAO_TURNOS turnos.
    -- Gastar tudo de uma vez é sempre 100% de risco de Frenesi (ver
    -- ficha:risco_frenesi).
    local teto_gasto = math.min(ficha.FURIA_GASTO_MAX, jogo.jogador:furia_atual() or 0)
    for q = 1, teto_gasto do
      local reducao = ficha.FURIA_TABELA_REDUCAO[q]
      local extra = reducao and string.format(", -%d dano tomado", reducao) or ""
      table.insert(opcoes, string.format("Fúria: gastar %d (%d turnos, +%d dano, -1 acerto%s)",
        q, ficha.FURIA_DURACAO_TURNOS, ficha.FURIA_TABELA_DANO[q], extra))
      table.insert(acoes, { furia = q })
    end
  end

  if #opcoes == 0 then
    logar("Você não tem nenhuma habilidade a usar agora.")
    return
  end

  table.insert(opcoes, "Voltar")
  jogo.submenu = { opcoes = opcoes, acoes = acoes, selecao = 1 }
end

-- Assumir uma forma consome o turno (o inimigo revida em seguida), igual à
-- versão console.
local function transformar_jogador(id_forma)
  jogo.jogador:transformar(id_forma)
  logar(formas[id_forma].descricao)
  turno_do_inimigo(false)
end

-- Ativa o buff de Fúria (também consome o turno, igual transformar). A lista
-- do submenu já garante saldo suficiente (só oferece 1..furia_atual).
-- Rola o risco de Frenesi ANTES de gastar (fórmula usa a Fúria atual).
local function usar_furia_jogador(quanto)
  local surtou = jogo.jogador:rolar_frenesi(quanto)
  jogo.jogador:ativar_furia(quanto)
  logar("O Caos ferve sob sua pele. O próximo golpe será cru.")
  if surtou then
    jogo.jogador:entrar_frenesi()
    logar("Mas algo se rompe. Você não comanda mais as próprias mãos.")
  end
  turno_do_inimigo(false)
end

-- FRENESI (versão mínima): sem controle. Um ataque automático por turno, sem
-- menu/esquiva/fuga, até a fúria passar. Ver sistemas.md > Fúria.
local function atacar_em_frenesi()
  logar("A fúria toma seus músculos. Você avança sem querer avançar.")
  local r = combate.atacar(jogo.jogador, jogo.inimigo, jogo.arma_jogador)
  combate.aplicar(jogo.inimigo, r)
  logar(frase("Você", "o bandido", r))
  if not jogo.inimigo:vivo() then
    jogo.acabou = "vitoria"; logar("O bandido tomba."); return
  end
  jogo.jogador:passar_turno_frenesi()
  turno_do_inimigo(false)
end

local function navegar_submenu(tecla)
  local n = #jogo.submenu.opcoes
  if tecla == "up" then
    jogo.submenu.selecao = (jogo.submenu.selecao - 2) % n + 1
  elseif tecla == "down" then
    jogo.submenu.selecao = jogo.submenu.selecao % n + 1
  elseif tecla == "escape" then
    jogo.submenu = nil  -- cancela, não consome o turno
  elseif tecla == "return" or tecla == "space" then
    local i = jogo.submenu.selecao
    local id = jogo.submenu.acoes[i]
    jogo.submenu = nil
    if type(id) == "table" and id.furia then
      usar_furia_jogador(id.furia)
    elseif id then
      transformar_jogador(id)  -- nil = "Voltar", não consome o turno
    end
  end
end

function love.keypressed(tecla)
  if jogo.acabou then
    if tecla == "escape" then love.event.quit() end
    return
  end

  if jogo.submenu then
    navegar_submenu(tecla)
    return
  end

  -- FRENESI: sem menu. Enter/Espaço só avança o ataque automático.
  if jogo.jogador:em_frenesi() then
    if tecla == "return" or tecla == "space" then
      atacar_em_frenesi()
    elseif tecla == "escape" then
      love.event.quit()
    end
    return
  end

  if tecla == "up" then
    jogo.selecao = (jogo.selecao - 2) % #ACOES + 1
  elseif tecla == "down" then
    jogo.selecao = jogo.selecao % #ACOES + 1
  elseif tecla == "return" or tecla == "space" then
    local acao = ACOES[jogo.selecao]
    if acao == "Habilidades" then
      abrir_habilidades()
    else
      turno_jogador(acao)
    end
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

  -- Menu de ações (ou submenu de Habilidades, ou desfecho).
  love.graphics.setFont(FONTE)
  if jogo.acabou then
    love.graphics.setColor(COR.destaque)
    local msg = ({ vitoria = "VITÓRIA", morte = "VOCÊ MORREU", fuga = "VOCÊ FUGIU" })[jogo.acabou]
    love.graphics.printf(msg .. "   (Esc para sair)", 0, 440, L, "center")
  elseif jogo.jogador:em_frenesi() then
    love.graphics.setColor(COR.inimigo)
    love.graphics.printf("FRENESI — você não se controla. (Enter)", 0, 440, L, "center")
  elseif jogo.submenu then
    for i, nome in ipairs(jogo.submenu.opcoes) do
      local x = 56 + (i - 1) * 160
      if i == jogo.submenu.selecao then
        love.graphics.setColor(COR.destaque)
        love.graphics.print("> " .. nome, x, 440)
      else
        love.graphics.setColor(COR.texto)
        love.graphics.print("  " .. nome, x, 440)
      end
    end
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
