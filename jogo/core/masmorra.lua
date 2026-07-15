-- core/masmorra.lua
-- Cena de abertura (tutorial): o random desperta preso e precisa fugir.
-- Usa a gramática primário -> secundário (ver sistemas.md 6.7):
--   PRIMÁRIO (grátis): olhar um objeto — descreve e revela ações possíveis nele.
--   SECUNDÁRIO (gasta 1 ação): agir sobre o objeto — avança o tempo.
-- Há só 5 ações (secundárias) antes de a janela de fuga fechar.
--
-- Puzzle: revirar a CAMA -> martelo; bater na PAREDE com o martelo 2x -> fuga.
-- Bater sem martelo (ou nas grades) só desperdiça ação.
--
-- Desfecho: "fuga" | "preso" (-> rota do vampirismo).
--
-- >>> OS TEXTOS/DIÁLOGOS ESTÃO TODOS EM data/textos_masmorra.lua <<<
--     Aqui há apenas a LÓGICA; edite as falas lá.

local console = require("util.console")
local T = require("data.textos_masmorra")

local masmorra = {}

local MAX_ACOES = 5

local function intro()
  console.limpar()
  console.linha("")
  for _, l in ipairs(T.intro) do console.linha("  " .. l) end
  console.linha("")
  console.pausar("  (Enter)")
end

function masmorra.jogar()
  intro()

  -- Estado da cena.
  local st = {
    acoes = 0,
    tem_martelo = false,
    cama_revirada = false,
    batidas = 0,
    escapou = false,
  }

  -- Mostra um texto (lista de linhas de data/textos_masmorra) e pausa.
  local function fala(linhas)
    console.linha("")
    for _, l in ipairs(linhas) do console.linha("      " .. l) end
    console.linha("")
    console.pausar("      (Enter)")
  end

  local function gastar_acao()
    st.acoes = st.acoes + 1
  end

  -- ---- OBJETOS DA CENA ----
  -- Cada objeto: nome, texto ao olhar (primário, grátis), e uma função que
  -- devolve a lista de ações secundárias disponíveis DADO o estado atual.
  local objetos = {
    {
      nome = "As grades",
      olhar = function() fala(T.grades_olhar) end,
      acoes = function()
        return {
          { nome = "Bater nas grades", efeito = function()
              gastar_acao()
              fala(st.tem_martelo and T.grades_bater_martelo or T.grades_bater)
          end },
        }
      end,
    },
    {
      nome = "A rachadura na parede",
      olhar = function() fala(T.rachadura_olhar) end,
      acoes = function()
        local nome = st.tem_martelo and "Bater com o martelo" or "Bater na parede"
        return {
          { nome = nome, efeito = function()
              gastar_acao()
              if not st.tem_martelo then
                fala(T.parede_esmurrar)
              else
                st.batidas = st.batidas + 1
                if st.batidas == 1 then
                  fala(T.parede_martelo_1)
                else
                  st.escapou = true
                end
              end
          end },
        }
      end,
    },
    {
      nome = "A mesa",
      olhar = function() fala(T.mesa_olhar) end,
      acoes = function()
        return {
          { nome = "Revirar a mesa", efeito = function()
              gastar_acao()
              fala(T.mesa_revirar)
          end },
        }
      end,
    },
    {
      nome = "A cama",
      olhar = function() fala(T.cama_olhar) end,
      acoes = function()
        return {
          { nome = "Revirar a cama", efeito = function()
              gastar_acao()
              if not st.cama_revirada then
                st.cama_revirada = true
                st.tem_martelo = true
                fala(T.cama_martelo)
              else
                fala(T.cama_vazia)
              end
          end },
        }
      end,
    },
  }

  -- ---- LOOP: escolher objeto -> olhar (grátis) -> agir (custa) ----
  while st.acoes < MAX_ACOES and not st.escapou do
    console.limpar()
    console.linha("")
    console.linha("    A cela. O que você observa?")
    if MAX_ACOES - st.acoes <= 2 then
      console.linha("    " .. T.tempo_apertando)
    end
    console.linha("")

    -- Menu primário: os objetos (olhar é grátis).
    local nomes = {}
    for _, o in ipairs(objetos) do table.insert(nomes, o.nome) end
    local i = console.menu(nomes, "      ")
    local obj = objetos[i]

    obj.olhar()

    -- Fica NESTE objeto até escolher Voltar (QOL: repetir ações sem
    -- re-selecionar). Sai também se escapou ou o tempo acabou.
    while not st.escapou and st.acoes < MAX_ACOES do
      local acoes_obj = obj.acoes()  -- remontado: rótulos evoluem com o estado
      console.limpar()
      console.linha("")
      console.linha("    " .. obj.nome .. ". O que você faz?")
      console.linha("")
      local rotulos = {}
      for _, a in ipairs(acoes_obj) do table.insert(rotulos, a.nome) end
      table.insert(rotulos, "Voltar")
      local j = console.menu(rotulos, "      ")

      if j > #acoes_obj then
        break  -- "Voltar" -> volta à lista de objetos (sem gastar tempo)
      end
      acoes_obj[j].efeito()
    end
  end

  -- Desfecho.
  console.limpar()
  console.linha("")
  local texto = st.escapou and T.fuga or T.preso
  for _, l in ipairs(texto) do console.linha("    " .. l) end
  console.linha("")
  console.pausar("    (Enter)")
  return st.escapou and "fuga" or "preso"
end

return masmorra
