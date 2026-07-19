-- data/conceitos.lua
-- Catálogo de CONCEITOS mágicos — os "tijolos" que o mago aprende e depois
-- funde em magias (ver sistemas.md > Sonhos & Quebras > Conceitos & Fusão).
--
-- O mago NÃO aprende feitiços prontos: ele aprende CONCEITOS (verdades
-- fundamentais do universo — "manipular o atrito", "endurecer a matéria"...)
-- e, meditando, FUNDE conceitos aprendidos numa magia sua. Feitiço = fusão.
-- Aprender conceito é raro e permanente (1 escolha a cada 2 níveis; ver
-- ficha.CONCEITO_A_CADA_N_NIVEIS) — cada escolha molda quem você é como mago.
--
-- Cada conceito é um TIJOLO com parâmetros. Quem funde soma esses parâmetros
-- pra derivar a dificuldade da magia resultante — ver magia.fundir() em
-- core/magia.lua. O CUSTO em Sonhos é sempre fixo (magia.CUSTO_FUSAO = 1),
-- não importa o que for fundido: peso e dif NÃO pagam mais custo, os dois
-- só somam na DIFICULDADE. Formato de um conceito:
--
--   id_do_conceito = {
--     nome      = "Manipular Atrito",   -- rótulo exibido
--     peso      = 2,   -- contribuição à DIFICULDADE (quanto mais pesada/bruta
--                      --   a força, mais difícil controlar — não mais caro)
--     dif       = 3,   -- contribuição à DIFICULDADE do teste de conjuração
--     tags      = { "cinetico" },  -- (opcional) categorias pra sinergias/
--                      --   restrições futuras; não afetam a dif por ora
--     descricao = "…",  -- (opcional) texto de sabor pra a UI
--   }
--
-- (peso e dif são dois números separados só por clareza de autoria — um
-- descreve "quão bruta é a força", o outro "quão difícil é controlá-la" —
-- mas mecanicamente os dois somam no mesmo lugar.)
--
-- (Vazio de propósito — QUAIS são os ~10 conceitos é trabalho criativo, fica
-- por conta de quem escreve. O motor de fusão já está pronto em core/magia.lua
-- e funciona com qualquer conceito que siga o formato acima.)

-- 10 conceitos (planejados)
-- Gravidade      -- implementado abaixo
-- Átomo          -- pendente (será "energia nuclear" — alto risco/escala, não simples)
-- Espaço
-- Magnetismo     -- implementado abaixo
-- Temperatura    -- implementado abaixo
-- Vida
-- Probabilidades
-- Tempo          -- pendente de propósito: mexe no relógio global (core/tempo.lua),
--                --   merece cautela extra antes de virar conteúdo
-- Vácuo
-- Fótons

-- Os 3 primeiros (Temperatura, Magnetismo, Gravidade) são MOLDES ABERTOS: o
-- `peso`/`dif` aqui é o BASE de um uso simples e pequeno (esquentar uma
-- xícara, atrair um prego, fazer uma pena cair mais devagar). O efeito exato
-- de uma magia específica (bola de fogo vs. incendiar um campo inteiro;
-- atrair um prego vs. arrancar uma espada da mão de alguém à distância) é
-- decidido por quem FUNDE a magia (`ficha:fundir_magia` / `magia.fundir`) —
-- e quanto mais ambicioso o efeito desejado (mais alcance, mais dano, mais
-- alvos), maior deve ser a `dif` daquela magia específica (o CUSTO nunca
-- muda — é sempre 1, ver magia.CUSTO_FUSAO), ajustada à mão pelo autor por
-- cima do que `magia.fundir` calcula (o motor soma os pesos/difs do
-- catálogo; nada impede o autor de subir o número na magia final pra
-- refletir uma versão mais poderosa/perigosa do mesmo conceito).

return {
  temperatura = {
    nome = "Temperatura",
    peso = 1,
    dif = 3,
    tags = { "termico" },
    descricao = "Manipular calor e frio — de esquentar algo a criar fogo/gelo.",
  },
  magnetismo = {
    nome = "Magnetismo",
    peso = 1,
    dif = 3,
    tags = { "cinetico" },
    descricao = "Manipular forças magnéticas — atrair, repelir, desarmar metal.",
  },
  gravidade = {
    nome = "Gravidade",
    peso = 1,
    dif = 3,
    tags = { "cinetico" },
    descricao = "Manipular peso e atração — mais leve, mais pesado, puxar, empurrar.",
  },
}
