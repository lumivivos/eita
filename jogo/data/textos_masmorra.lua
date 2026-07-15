-- data/textos_masmorra.lua
-- ============================================================================
--  TEXTOS DA CENA DA MASMORRA
--
--  Tudo aqui é SÓ TEXTO — pode editar à vontade, não há lógica.
--  Cada entrada é uma lista de linhas (cada string vira uma linha na tela).
--  A lógica em core/masmorra.lua só chama estes textos pelo nome (T.xxxx).
-- ============================================================================

-- Frase reaproveitada em várias batidas inúteis/arriscadas.
local ARREPENDIMENTO = "Talvez eu não devesse ter feito isso."

return {
  ARREPENDIMENTO = ARREPENDIMENTO,

  -- Abertura da cena.
  intro = {
    "Você desperta.",
    "",
    "Uma masmorra suja, úmida, horrível. As grades estão enferrujadas",
    "— mas ainda firmes o bastante para segurar um homem. Não há",
    "guardas. Não há comida. Só você e o próprio",
    "pensamento.",
    "",
    "Algo lhe diz que não há muito tempo.",
  },

  -- Dica ambiente quando o tempo aperta (aparece com poucas ações restando).
  tempo_apertando = "(O ar parece mais pesado. O tempo está contra você.)",

  -- GRADES ------------------------------------------------------------------
  grades_olhar = {
    "As grades estão tomadas de ferrugem, mas não cedem ao olhar.",
    "Firmes. Frias.",
  },
  grades_bater = {           -- bater sem martelo
    "Você sacode as grades enferrujadas. Firmes. Inúteis.",
    ARREPENDIMENTO,
  },
  grades_bater_martelo = {   -- bater com martelo (também inútil)
    "Você martela as grades. Faíscas, barulho — e nada mais.",
    ARREPENDIMENTO,
  },

  -- RACHADURA / PAREDE -------------------------------------------------------
  rachadura_olhar = {
    "Uma rachadura corta a parede de pedra, fina como um fio.",
    "Talvez, com a força certa, ela ceda.",
  },
  parede_esmurrar = {        -- bater sem martelo
    "Você esmurra a rachadura. A pele racha antes da pedra.",
    ARREPENDIMENTO,
  },
  parede_martelo_1 = {       -- 1ª martelada (ainda não abre)
    "Você crava o martelo na rachadura. A parede geme, solta",
    "poeira — mas resiste. Mais uma vez.",
    ARREPENDIMENTO,
  },

  -- MESA ---------------------------------------------------------------------
  mesa_olhar = {
    "Uma mesa de madeira, gasta e torta, encostada na parede.",
  },
  mesa_revirar = {
    "A mesa range, oca. Poeira e mais nada.",
  },

  -- CAMA ---------------------------------------------------------------------
  cama_olhar = {
    "Um catre com um colchão de palha apodrecida. Cheira a mofo.",
  },
  cama_martelo = {           -- primeira vez: acha o martelo
    "Sob o colchão, seus dedos encontram metal: um pequeno",
    "martelo, esquecido. Você o segura com força.",
  },
  cama_vazia = {             -- revirar de novo
    "Só palha podre e o martelo que você já pegou.",
  },

  -- DESFECHOS ----------------------------------------------------------------
  fuga = {
    "O segundo golpe estoura a parede. Ar frio invade a cela.",
    "Um buraco. Uma saída.",
  },
  preso = {
    "Passos no corredor. Você perdeu tempo demais.",
    "Algo se aproxima da cela — e não é um guarda.",
  },
}
