-- core/tempo.lua
-- Um relógio de mundo (ver sistemas.md > Tempo).
-- Linear e infinito: só cresce, somando o custo das ações. É INVISÍVEL ao
-- jogador — existe só pra gerar consequências (NPCs reagem a ele).
--
-- É um OBJETO instanciável (`tempo.novo()`), não um módulo-singleton: assim
-- cada "mundo"/sessão de jogo tem o seu próprio relógio, independente dos
-- outros. Importante se um dia várias partidas precisarem rodar ao mesmo
-- tempo no mesmo processo (ex.: coop, ou testes isolados uns dos outros).

local tempo = {}
tempo.__index = tempo

-- Cria um relógio novo, zerado.
function tempo.novo()
  return setmetatable({ relogio = 0 }, tempo)
end

-- Quanto tempo já passou (número interno). Usado por NPCs/eventos, não pela UI.
function tempo:agora()
  return self.relogio
end

-- Avança o relógio pelo custo de uma ação (inteiro pequeno; a maioria = 1).
-- Devolve o novo valor.
function tempo:avancar(custo)
  custo = custo or 1
  self.relogio = self.relogio + custo
  return self.relogio
end

-- Zera o relógio (pra iniciar um jogo novo / testes).
function tempo:reiniciar()
  self.relogio = 0
  return self.relogio
end

return tempo
