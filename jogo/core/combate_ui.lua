-- core/combate_ui.lua
-- Camada de APRESENTAÇÃO do combate: roda uma luta por turnos no terminal,
-- narrando na voz do mundo. Não expõe números (HP/diff são secretos).
-- Estilo: texto sóbrio, sem símbolos/emojis; blocos separados por espaço.
-- A lógica de resolução vive em core/combate.lua; aqui é só tela + fluxo.

local console = require("util.console")
local combate = require("core.combate")
local teste = require("core.teste")
local formas = require("data.formas")
local ficha = require("core.ficha")
local dominatio = require("core.dominatio")
local niveis = require("core.niveis")

local ui = {}

-- As feras que um lobisomem pode assumir a partir da forma humana.
local FORMAS_FERA = { "crino", "lupino", "bestial" }

-- Submenu "Habilidades" do combate. Lobisomem: formas + Fúria. Vampiro:
-- Elevação + Dominatio + Besta (acalmar). Retorna true se consumiu o turno,
-- false se cancelou. Precisa do `inimigo`/`nomes` porque Dominatio mira o
-- adversário (os outros estigmas de raça, até agora, eram só auto-buff).
local function menu_habilidades(jogador, inimigo, nomes)
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
    -- Fúria: uma opção por nível possível (1..FURIA_GASTO_MAX, limitado pelo
    -- quanto o jogador realmente tem). Dura FURIA_DURACAO_TURNOS turnos.
    -- Gastar tudo de uma vez é sempre 100% de risco de Frenesi (ver
    -- ficha:risco_frenesi).
    local teto_gasto = math.min(ficha.FURIA_GASTO_MAX, jogador:furia_atual() or 0)
    for q = 1, teto_gasto do
      local reducao = ficha.FURIA_TABELA_REDUCAO[q]
      local extra = reducao and string.format(", -%d dano tomado", reducao) or ""
      table.insert(opcoes, string.format("Fúria: gastar %d (%d turnos, +%d dano, -1 acerto%s)",
        q, ficha.FURIA_DURACAO_TURNOS, ficha.FURIA_TABELA_DANO[q], extra))
      table.insert(acoes, { furia = q })
    end
  end

  local eh_vampiro = (jogador.raca == "vampiro")
  if eh_vampiro then
    -- Elevação: UMA opção só — buffa Força+Vitalidade+Agilidade JUNTAS
    -- (custo fixo 1 Sangue; não pode ter mais de uma ativa ao mesmo tempo).
    if not jogador:elevacao_ativa() and (jogador:sangue_atual() or 0) >= ficha.ELEVACAO_CUSTO then
      local bonus = ficha.multiplicador_elevacao(jogador:geracao_atual())
      table.insert(opcoes, string.format("Elevação: Força+Vitalidade+Agilidade (+%d por %d turnos, %d Sangue)",
        bonus, ficha.ELEVACAO_DURACAO_TURNOS, ficha.ELEVACAO_CUSTO))
      table.insert(acoes, { elevacao = true })
    end

    -- Dominatio: mira o inimigo (custo fixo 1 Sangue, gasta mesmo se falhar
    -- ou for bloqueada — "você tentou"; ver core/dominatio.lua).
    if (jogador:sangue_atual() or 0) >= dominatio.CUSTO_SANGUE then
      table.insert(opcoes, string.format("Dominatio: dominar %s (%d Sangue)",
        nomes.inimigo, dominatio.CUSTO_SANGUE))
      table.insert(acoes, { dominatio = true })
    end

    -- Besta: acalma a própria (imunidade ao Frenesi por uns turnos).
    if not jogador:besta_acalmada() and (jogador:sangue_atual() or 0) >= ficha.ACALMAR_CUSTO_SANGUE then
      table.insert(opcoes, string.format("Besta: acalmar (imune ao Frenesi por %d turnos, %d Sangue)",
        ficha.ACALMAR_DURACAO_TURNOS, ficha.ACALMAR_CUSTO_SANGUE))
      table.insert(acoes, { acalmar = true })
    end

    -- Curar: cura escolhida (ver ficha:curar_com_sangue) — gasta Sangue,
    -- cura HP conforme a geração. PROVISÓRIO: não gasta o turno (ver
    -- sistemas.md > Cura). Sempre disponível (mesmo cheio de vida — HP é
    -- secreto, o jogador não sabe ao certo quanto falta).
    if (jogador:sangue_atual() or 0) >= ficha.CURA_SANGUE_CUSTO then
      table.insert(opcoes, string.format("Curar (fecha feridas com o próprio Sangue, %d Sangue, não gasta o turno)",
        ficha.CURA_SANGUE_CUSTO))
      table.insert(acoes, { curar = true })
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

  if type(id) == "table" and id.furia then
    -- Rola o risco de Frenesi ANTES de gastar (a fórmula usa a Fúria atual).
    local surtou = jogador:rolar_frenesi(id.furia)
    jogador:ativar_furia(id.furia)  -- lista já garante saldo suficiente
    console.linha("    O Caos ferve sob sua pele. O próximo golpe será cru.")
    if surtou then
      jogador:entrar_frenesi()
      console.linha("")
      console.linha("    Mas algo se rompe. Você não comanda mais as próprias mãos.")
    end
    console.linha("")
    return true
  end

  if type(id) == "table" and id.elevacao then
    local _, bonus = jogador:ativar_elevacao()
    console.linha(("    Seu corpo inteiro se retorce além do humano — +%d por uns turnos.")
      :format(bonus))
    console.linha("")
    return true
  end

  if type(id) == "table" and id.dominatio then
    local r = dominatio.tentar(jogador, inimigo)
    if r.bloqueado then
      console.linha(("    Você tenta prender o olhar de %s, mas a vontade dele é forte demais.")
        :format(nomes.inimigo))
    elseif r.passou then
      console.linha(("    Seus olhos prendem os de %s. A mente dele cede — ele trava, atordoado.")
        :format(nomes.inimigo))
    else
      console.linha(("    Você tenta dominar %s, mas a mente dele resiste."):format(nomes.inimigo))
    end
    console.linha("")
    return true
  end

  if type(id) == "table" and id.acalmar then
    jogador:acalmar_besta()
    console.linha("    Você respira fundo, prendendo a fera por dentro. Um pouco mais de controle.")
    console.linha("")
    return true
  end

  if type(id) == "table" and id.curar then
    -- PROVISÓRIO: não consome o turno (ver sistemas.md > Cura). No futuro
    -- isso vai exigir um teste ou gastar 1 de Vontade pra curar "de graça"
    -- assim; por ora está simplificado — cura sempre sem custo de turno.
    local _, quanto = jogador:curar_com_sangue()
    if quanto and quanto > 0 then
      console.linha("    O Sangue se retrai, costurando a carne por dentro.")
    else
      console.linha("    O Sangue se gasta, mas não havia ferida pra fechar.")
    end
    console.linha("")
    return false
  end

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

-- Concede as recompensas de vencer um combate: EXP (rumo a nível) e 1
-- conquista (rumo a Sonhos, se um dia virar mago — ver sistemas.md > Sonhos).
-- Só o jogador ganha — o inimigo é uma ficha descartada ao fim da luta.
local function conceder_vitoria(jogador)
  jogador:ganhar_exp(niveis.EXP_COMBATE_COMUM)
  jogador:ganhar_conquista()
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

    -- FRENESI DE VAMPIRO: gatilho PASSIVO, checado toda rodada pros dois
    -- lados (diferente do de lobisomem, que dispara ao gastar Fúria). Ver
    -- ficha:em_risco_frenesi_vampiro.
    if jogador:em_risco_frenesi_vampiro() and not jogador:em_frenesi() then
      jogador:entrar_frenesi()
      paragrafo("A fome aperta mais que a vontade. As rédeas escapam.")
    end
    if inimigo:em_risco_frenesi_vampiro() and not inimigo:em_frenesi() then
      inimigo:entrar_frenesi()
    end

    local jogador_esquivou = false
    local turno_gasto = true   -- Habilidades pode não gastar o turno (se cancelar)

    -- ATORDOADO (Dominatio): perde a vez por completo, nem no automático.
    if jogador:atordoado() then
      paragrafo("Você está atordoado. Não consegue reagir.")
    -- FRENESI: sem controle. O jogo ataca por você (não há menu, nem esquiva,
    -- nem fuga). Ver sistemas.md > Fúria (versão mínima).
    elseif jogador:em_frenesi() then
      paragrafo("A fúria toma seus músculos. Você avança sem querer avançar.")
      local r = combate.atacar(jogador, inimigo, armas.jogador)
      combate.aplicar(inimigo, r)
      paragrafo(frase_ataque(nomes.jogador, nomes.inimigo, r))
      if not inimigo:vivo() then
        console.linha(DIV)
        console.linha("")
        paragrafo(("%s tomba. Silêncio."):format(nomes.inimigo))
        conceder_vitoria(jogador)
        console.pausar("    (Enter)")
        return "vitoria"
      end
      -- turno_gasto segue true; sem esquiva. Cai no turno do inimigo abaixo.
    else
      console.linha("    O que você faz?")
      console.linha("")
      local escolha = console.menu({ "Atacar", "Esquivar", "Fugir", "Habilidades" }, "      ")
      console.linha("")

      if escolha == 4 then
        -- Submenu. Se cancelar (não consumir o turno), o inimigo NÃO age e o loop
        -- reinicia — o jogador volta a escolher.
        turno_gasto = menu_habilidades(jogador, inimigo, nomes)
      elseif escolha == 1 then
        local r = combate.atacar(jogador, inimigo, armas.jogador)
        combate.aplicar(inimigo, r)
        paragrafo(frase_ataque(nomes.jogador, nomes.inimigo, r))
        if not inimigo:vivo() then
          console.linha(DIV)
          console.linha("")
          paragrafo(("%s tomba. Silêncio."):format(nomes.inimigo))
          conceder_vitoria(jogador)
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
    end

    -- Turno do inimigo — só ocorre se o jogador consumiu o próprio turno.
    -- (Cancelar o submenu Habilidades não gasta o turno: o inimigo não age.)
    if turno_gasto then
      if jogador_esquivou then
        -- esquivou, inimigo não acerta nada
      elseif inimigo:atordoado() then
        paragrafo(("%s está atordoado, incapaz de reagir."):format(nomes.inimigo))
      else
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

      -- Duração de todos os buffs/status temporários (3 turnos de Fúria, 2 de
      -- Elevação, 3 do acalmar da Besta, 2 de Frenesi, 2 de Atordoado — cada
      -- passar_turno_* é no-op pra quem não tem aquele estado ativo).
      for _, f in ipairs({ jogador, inimigo }) do
        f:passar_turno_furia()
        f:passar_turno_elevacao()
        f:passar_turno_besta()
        f:passar_turno_frenesi()
        f:passar_turno_atordoado()
      end

      console.linha(DIV)
      console.pausar("    (Enter para continuar)")
    end

    console.limpar()
    console.linha("")
  end
end

return ui
