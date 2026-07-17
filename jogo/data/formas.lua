-- data/formas.lua
-- Formas do lobisomem. Efeito mecânico PROVISÓRIO e simples (ver sistemas.md 6.5)
-- só pra testar — a versão final terá buffs E debuffs multi-atributo por forma:
--   - Bestial: +Agilidade, +acerto, -Inteligência
--   - Crino:   +dano, -controle/Força de Vontade
--   - Humanóide/Lupino: formas "base" (fracas; diferem só no formato social:
--     humanóide entre humanos, lupino entre lobos)
--
-- Por ora, só dois bônus fixos: bonus_acerto (soma no teste de ataque) e
-- bonus_dano (soma no dano). As formas fortes (Crino/Bestial) levam +2/+2.
--
-- Cada forma:
--   id           = chave interna
--   nome         = rótulo exibido no menu
--   descricao    = frase narrada ao assumir a forma
--   usa_armas    = pode empunhar arma? (false => usa a arma natural)
--   bonus_acerto = soma no ataque (facilita superar a defesa; provisório)
--   bonus_dano   = dano extra enquanto nesta forma (provisório)
--   arma_natural = id da arma usada quando usa_armas=false (ver data/armas.lua)

return {
  -- Forma base — pra onde se volta ao reverter. Sem bônus.
  humanoide = {
    id = "humanoide",
    nome = "Humanóide",
    descricao = "Os ossos recuam, a pele se acalma. Você volta a parecer gente.",
    eh_base = true,
    usa_armas = true,
    bonus_acerto = 0,
    bonus_dano = 0,
  },
  crino = {
    id = "crino",
    nome = "Crino",
    descricao = "Você se ergue maior, bípede e coberto de pelo — o homem-lobo.",
    usa_armas = true,       -- tem mãos hábeis
    bonus_acerto = 2,
    bonus_dano = 2,
  },
  -- Forma base "selvagem" — equivale à humanóide em poder (só muda o formato).
  lupino = {
    id = "lupino",
    nome = "Lupino",
    descricao = "Você desce sobre quatro patas. Um lobo grande, silencioso.",
    usa_armas = false,      -- quadrúpede: ataca com o corpo
    arma_natural = "garras",
    bonus_acerto = 0,
    bonus_dano = 0,
  },
  bestial = {
    id = "bestial",
    nome = "Bestial",
    descricao = "Algo maior que um lobo se desdobra de você — magro, torto, faminto.",
    usa_armas = false,
    arma_natural = "garras",
    bonus_acerto = 3,
    bonus_dano = 2,
  },
}
