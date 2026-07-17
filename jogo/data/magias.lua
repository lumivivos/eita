-- data/magias.lua
-- Catálogo de magias (data-driven — adicionar magia = adicionar entrada
-- aqui). Resolvidas por core/magia.lua (ver sistemas.md > Sonhos & Quebras).
--
-- Cada magia declara:
--   nome  = rótulo exibido
--   custo = quanto de Sonhos a conjuração gasta (define também quantas
--           Quebras uma falha feia gera — ver magia.quebras_por_falha)
--   dif   = dificuldade do teste de conjuração (comparada com
--           sonhos_atual + vontade + 1d3, DEPOIS de pagar o custo)
--
-- (Vazio de propósito — o conteúdo das magias é criativo, fica por conta de
-- quem escreve. O motor já está pronto em core/magia.lua.)

return {}
