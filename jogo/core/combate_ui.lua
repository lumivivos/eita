-- core/combate_ui.lua
-- Camada de APRESENTAÇÃO do combate: roda uma luta por turnos no terminal,
-- narrando na voz do mundo. Não expõe números (HP/diff são secretos).
-- Estilo: texto sóbrio, sem símbolos/emojis; blocos separados por espaço.
-- A lógica de resolução vive em core/combate.lua; aqui é só tela + fluxo.

local console = require("util.console")
local combate = require("core.combate")
local teste = require("core.teste")
local formas = require("data.formas")

local ui = {}

-- As feras que um lobisomem pode assumir a partir da forma humana.
local FORMAS_FERA = { "crino", "lupino", "bestial" }

-- Submenu "Habilidades" do combate. Por ora só o lobisomem tem conteúdo
-- (transformação). Retorna true se consumiu o turno, false se cancelou.
-- (Esqueleto: transformar só troca o estado; sem efeito mecânico ainda.)
local function menu_habilidades(jogador)
  -- Monta as opções conforme o estado atual.
  local opcoes, acoes = {}, {}

  local eh_lobisomem = (jogador.raca == "lobisomem")
  if eh_lobisomem then
    if jogador:eh_humanoide() then
      for _, id in ipairs(FORMAS_FERA) do
        table.insert(opcoes, formas[id].nome)
        table.insert(acoes, id)
      end
    else
      -- Já transformado: única opção é voltar a humano.
      table.insert(opcoes, formas.humanoide.nome)
      table.insert(acoes, "humanoide")
    end
  end

  if #opcoes == 0 then
    console.linha("    Você não tem nenhuma habilidade a usar agora.")
    console.linha("")
    return false
  end

  table.insert(opcoes, "Voltar")
  console.linha("    Habilidades:")
  console.linha("")
  local escolha = console.menu(opcoes, "      ")
  console.linha("")

  if escolha == #opcoes then
    return false  -- "Voltar" — não consome o turno
  end

  local id = acoes[escolha]
  jogador:transformar(id)
  console.linha("    " .. formas[id].descricao)
  console.linha("")
  return true  -- transformar consome o turno
end

local DIV = "  " .. string.rep("-", 44)

-- Descreve o estado de saúde do alvo SEM número (HP é secreto).
local function descrever_saude(f)
  local frac = f.hp / f:hp_max()
  if frac <= 0 then return "caído, imóvel"
  elseif frac < 0.25 then return "à beira da morte"
  elseif frac < 0.5 then return "gravemente ferido"
  elseif frac < 0.85 then return "ferido"
  else return "de pé, inteiro"
  end
end

-- Uma frase única que resume o golpe. Usa r.arma (a arma EFETIVA — ex.: garras,
-- se a forma trocou a arma empunhada). O tipo do resultado já conta a história;
-- não narramos o "vacilo do dado" separadamente (evita poluição/contradição).
local function frase_ataque(nome_atacante, nome_alvo, r)
  local arma_nome = r.arma and r.arma.nome or "o golpe"
  if r.tipo == "erro" then
    return ("%s ataca com %s, mas não encontra %s."):format(nome_atacante, arma_nome, nome_alvo)
  elseif r.tipo == "parcial" then
    return ("%s golpeia %s, que apara a maior parte. Um talho raso."):format(nome_atacante, nome_alvo)
  else
    return ("%s acerta %s em cheio com %s."):format(nome_atacante, nome_alvo, arma_nome)
  end
end

-- Imprime um parágrafo indentado (uma linha em branco depois).
local function paragrafo(texto)
  console.linha("    " .. texto)
  console.linha("")
end

-- Cabeçalho do turno: estado do inimigo entre divisores.
local function cabecalho(nomes, inimigo)
  console.linha(DIV)
  console.linha(("    %s — %s."):format(nomes.inimigo, descrever_saude(inimigo)))
  console.linha(DIV)
  console.linha("")
end

-- Roda um combate até alguém cair ou o jogador fugir.
--   jogador, inimigo = fichas
--   nomes = {jogador="Você", inimigo="O bandido"}
--   armas = {jogador=<arma>, inimigo=<arma>}
-- Devolve "vitoria" | "morte" | "fuga".
function ui.lutar(jogador, inimigo, nomes, armas)
  console.limpar()
  console.linha("")
  paragrafo(("%s se ergue diante de você. Não há palavras."):format(nomes.inimigo))

  while true do
    cabecalho(nomes, inimigo)

    console.linha("    O que você faz?")
    console.linha("")
    local escolha = console.menu({ "Atacar", "Esquivar", "Fugir", "Habilidades" }, "      ")
    console.linha("")

    local jogador_esquivou = false
    local turno_gasto = true   -- Habilidades pode não gastar o turno (se cancelar)

    if escolha == 4 then
      -- Submenu. Se cancelar (não consumir o turno), o inimigo NÃO age e o loop
      -- reinicia — o jogador volta a escolher.
      turno_gasto = menu_habilidades(jogador)
    elseif escolha == 1 then
      local r = combate.atacar(jogador, inimigo, armas.jogador)
      combate.aplicar(inimigo, r)
      paragrafo(frase_ataque(nomes.jogador, nomes.inimigo, r))
      if not inimigo:vivo() then
        console.linha(DIV)
        console.linha("")
        paragrafo(("%s tomba. Silêncio."):format(nomes.inimigo))
        console.pausar("    (Enter)")
        return "vitoria"
      end
    elseif escolha == 2 then
      local res = teste.atributo(jogador:attr("agilidade"), 4)
      if res.passou then
        jogador_esquivou = true
        paragrafo("Você escorrega para as sombras. O próximo golpe cortará o vazio.")
      else
        paragrafo("Você tenta se esquivar, mas trava. Exposto.")
      end
    else
      local res = teste.atributo(jogador:attr("agilidade"), 5)
      if res.passou then
        paragrafo("Você rompe o cerco e desaparece na escuridão.")
        console.pausar("    (Enter)")
        return "fuga"
      else
        paragrafo("Você tenta fugir, mas ele corta seu caminho.")
      end
    end

    -- Turno do inimigo — só ocorre se o jogador consumiu o próprio turno.
    -- (Cancelar o submenu Habilidades não gasta o turno: o inimigo não age.)
    if turno_gasto then
      if not jogador_esquivou then
        local ri = combate.atacar(inimigo, jogador, armas.inimigo)
        combate.aplicar(jogador, ri)
        paragrafo(frase_ataque(nomes.inimigo, nomes.jogador, ri))
        if not jogador:vivo() then
          console.linha(DIV)
          console.linha("")
          paragrafo("O mundo escurece. Seus joelhos cedem. Fim.")
          console.pausar("    (Enter)")
          return "morte"
        end
      end

      -- Regeneração passiva de fim de turno (só quem tem — o lobisomem).
      inimigo:regenerar_turno()
      local curou = jogador:regenerar_turno()
      if curou > 0 then
        paragrafo("Suas feridas se fecham sozinhas — a carne costura a carne.")
      end

      console.linha(DIV)
      console.pausar("    (Enter para continuar)")
    end

    console.limpar()
    console.linha("")
  end
end

return ui
