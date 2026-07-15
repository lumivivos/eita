-- core/tempo.lua
-- O relógio global do mundo (ver sistemas.md > Tempo).
-- Linear e infinito: só cresce, somando o custo das ações. É INVISÍVEL ao
-- jogador — existe só pra gerar consequências (NPCs reagem a ele).

local tempo = {}

local relogio = 0  -- estado interno; ninguém lê direto, usa agora()

-- Quanto tempo já passou (número interno). Usado por NPCs/eventos, não pela UI.
function tempo.agora()
  return relogio
end

-- Avança o relógio pelo custo de uma ação (inteiro pequeno; a maioria = 1).
-- Devolve o novo valor.
function tempo.avancar(custo)
  custo = custo or 1
  relogio = relogio + custo
  return relogio
end

-- Zera o relógio (pra iniciar um jogo novo / testes).
function tempo.reiniciar()
  relogio = 0
end

return tempo
