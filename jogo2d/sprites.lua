-- jogo2d/sprites.lua
-- Carrega uma folha de sprites (sprite sheet) em tiras horizontais de
-- quadros do mesmo tamanho e fatia em Quads prontos pra desenhar.
-- Genérico: não sabe nada de personagem/raça — só corta a imagem.
--
-- Uso:
--   local folha = sprites.folha("assets/sprites/bandido_idle.png", 100, 100)
--   love.graphics.draw(folha.imagem, folha.quads[1], x, y, 0, escala, escala)

local sprites = {}

-- Carrega `caminho` e fatia em quadros de `largura` x `altura` (a imagem
-- inteira deve ser uma tira horizontal: largura_total = largura * N).
-- Devolve { imagem, quads = {quad1, quad2, ...}, n, largura, altura }.
function sprites.folha(caminho, largura, altura)
  local imagem = love.graphics.newImage(caminho)
  local lw, lh = imagem:getDimensions()
  local n = math.floor(lw / largura)
  local quads = {}
  for i = 0, n - 1 do
    quads[i + 1] = love.graphics.newQuad(i * largura, 0, largura, altura, lw, lh)
  end
  return { imagem = imagem, quads = quads, n = n, largura = largura, altura = altura }
end

-- Estado de reprodução de uma animação em loop (independente da folha, pra
-- poder ter vários personagens usando a MESMA folha com timers diferentes).
-- `fps` = quadros por segundo. Devolve um objeto com :atualizar(dt) e
-- :quad_atual().
function sprites.animacao(folha, fps)
  local self = { folha = folha, fps = fps or 6, tempo = 0, quadro = 1 }

  function self:atualizar(dt)
    self.tempo = self.tempo + dt
    local duracao_quadro = 1 / self.fps
    while self.tempo >= duracao_quadro do
      self.tempo = self.tempo - duracao_quadro
      self.quadro = (self.quadro % self.folha.n) + 1
    end
  end

  function self:quad_atual()
    return self.folha.quads[self.quadro]
  end

  return self
end

return sprites
