-- testes.lua
-- Valida o núcleo de regras contra o que foi projetado em sistemas.md.
-- Rode:  lua testes.lua   (de dentro da pasta jogo/)
--
-- Faz duas coisas:
--   1) Testes de correção (assert): a lógica faz o que deve? Falha = erro claro.
--   2) Tabelas de probabilidade: mostra as chances REAIS pra você conferir se o
--      design "sente" certo (ex.: Força 2 arromba porta "na maioria das vezes"?).

package.path = package.path .. ";./?.lua"

local dado = require("core.dado")
local teste = require("core.teste")
local ficha = require("core.ficha")
local tempo = require("core.tempo")
local combate = require("core.combate")

-- ---- mini-framework de asserção -------------------------------------------
local passou, falhou = 0, 0
local function ok(cond, msg)
  if cond then
    passou = passou + 1
  else
    falhou = falhou + 1
    print("  [FALHOU] " .. msg)
  end
end
local function titulo(t)
  print("\n== " .. t .. " ==")
end

-- Gera um rng determinístico que devolve as faces desta lista, em ordem,
-- repetindo. Útil pra forçar resultados específicos do d3.
-- face desejada F -> precisamos de r tal que floor(r*3)+1 == F, ou seja
-- r no intervalo [(F-1)/3, F/3). Usamos o meio do intervalo.
local function rng_de_faces(faces)
  local i = 0
  return function()
    i = i % #faces + 1
    local f = faces[i]
    return ((f - 1) + 0.5) / 3
  end
end

-- ---------------------------------------------------------------------------
titulo("dado: mapeamento face -> bônus (vacilo no 1)")
ok(dado.bonus_da_face(1) == 0, "face 1 deve dar bônus 0 (vacilo)")
ok(dado.bonus_da_face(2) == 1, "face 2 deve dar bônus 1")
ok(dado.bonus_da_face(3) == 2, "face 3 deve dar bônus 2")

titulo("dado: rng determinístico devolve a face pedida")
do
  local r = rng_de_faces({1, 2, 3})
  local _, f1 = dado.rolar(r)
  local _, f2 = dado.rolar(r)
  local _, f3 = dado.rolar(r)
  ok(f1 == 1 and f2 == 2 and f3 == 3,
     "faces forçadas deveriam sair 1,2,3 (saiu " .. f1 .. "," .. f2 .. "," .. f3 .. ")")
end

-- ---------------------------------------------------------------------------
titulo("teste de atributo: casos-limite forçando o dado")
do
  -- Porta difícil (dif 5), Força 4 (o exemplo do design):
  -- vacilo (face1): 4+0=4 -> FALHA ; face2: 4+1=5 -> passa ; face3: 4+2=6 -> passa
  local r_vacilo = rng_de_faces({1})
  local res = teste.atributo(4, 5, r_vacilo)
  ok(res.passou == false and res.vacilou, "Força 4 vs dif 5 no vacilo deve FALHAR")

  local r_dois = rng_de_faces({2})
  res = teste.atributo(4, 5, r_dois)
  ok(res.passou == true and res.total == 5, "Força 4 vs dif 5 na face 2 deve passar (total 5)")
end

-- ---------------------------------------------------------------------------
titulo("teste de habilidade: atributo + habilidade + dado")
do
  -- Carisma 2 + Intimidação 3 vs dif 6. face2 -> 2+3+1 = 6 (passa no limite).
  local r = rng_de_faces({2})
  local res = teste.habilidade(2, 3, 6, r)
  ok(res.total == 6 and res.passou, "Car2+Intim3 face2 deve dar total 6 e passar")
end

-- ---------------------------------------------------------------------------
titulo("Força de Vontade: base estável x pool gastável")
do
  local p = ficha.nova({ vontade = 6 })
  ok(p:defesa_mental() == 6, "defesa mental inicial deve ser 6 (a base)")
  ok(p:vontade_disponivel() == 6, "pool inicial deve começar cheio (6)")
  ok(p:gastar_vontade() == true, "deve conseguir gastar 1 de vontade")
  ok(p:vontade_disponivel() == 5, "pool deve cair pra 5 após gastar")
  ok(p:defesa_mental() == 6, "defesa mental deve CONTINUAR 6 (gasto é só do pool)")
  p:recarregar_vontade(10)
  ok(p:vontade_disponivel() == 6, "recarga não deve passar da base (teto 6)")
  -- esvaziar de vez
  local p2 = ficha.nova({ vontade = 1 })
  ok(p2:gastar_vontade() == true, "gasta o último ponto")
  ok(p2:gastar_vontade() == false, "não deve gastar com pool vazio")
end

titulo("ficha: valores padrão e atributos")
do
  local p = ficha.nova({ forca = 3 })  -- lobisomem começa Força 3
  ok(p:attr("forca") == 3, "força definida deve ser 3")
  ok(p:attr("carisma") == 2, "atributo não informado deve assumir 2 (humano comum)")
  ok(p:pericia("intimidacao") == 0, "perícia nunca usada deve ser 0")
end

titulo("tempo: relógio soma custos e é reiniciável")
do
  local relogio = tempo.novo()
  ok(relogio:agora() == 0, "relógio deve começar em 0")
  relogio:avancar(1)
  relogio:avancar(3)
  ok(relogio:agora() == 4, "relógio deve somar custos (1+3=4)")
  relogio:reiniciar()
  ok(relogio:agora() == 0, "reiniciar deve zerar")
end

titulo("tempo: dois relógios são independentes")
do
  local a, b = tempo.novo(), tempo.novo()
  a:avancar(5)
  ok(a:agora() == 5, "relógio A avança sozinho")
  ok(b:agora() == 0, "relógio B não é afetado pelo A")
end

-- ---------------------------------------------------------------------------
titulo("combate: as 3 faixas (exemplo do design: adaga diff 1, defesa 3)")
do
  local armas = require("data.armas")
  -- Alvo com defesa 3 => Vitalidade 1 (defesa = vit+2). Atacante Agilidade 0,
  -- sem habilidade, pra o ataque = 0 + 0 + bônus do dado. Adaga: diff 1.
  local alvo = ficha.nova({ vitalidade = 1 }, "humano")
  ok(alvo:defesa() == 3, "defesa do alvo deve ser 3 (vit1 +2)")
  local atk = ficha.nova({ agilidade = 0 }, "humano")
  local adaga = armas.adaga

  -- Forço o dado: face1->bônus0 (ataque 0), face2->1, face3->2.
  -- ataque 0  -> <= diff(1) -> ERRO
  local r = combate.atacar(atk, alvo, adaga, rng_de_faces({1}))
  ok(r.tipo == "erro" and r.dano == 0, "ataque 0 vs diff 1: ERRO, 0 dano")
  -- ataque 1 seria empate com diff... não alcançável aqui (bônus é 0/1/2 e attr 0
  -- dá 0/1/2). ataque 2 (face3) -> >diff, <=defesa(3) -> PARCIAL
  r = combate.atacar(atk, alvo, adaga, rng_de_faces({3}))
  ok(r.tipo == "parcial" and r.dano >= 1, "ataque 2 vs def 3: PARCIAL, dano>=1")

  -- Agora um atacante forte pra garantir TOTAL: Agilidade 5 -> ataque 5..7 > def 3.
  local atk2 = ficha.nova({ agilidade = 5 }, "humano")
  r = combate.atacar(atk2, alvo, adaga, rng_de_faces({3}))  -- 5+0+2 = 7
  ok(r.tipo == "total", "ataque 7 vs def 3: TOTAL")
  -- dano total = base(2) + margem(7-3=4) + atributo(5) = 11
  ok(r.dano == 2 + 4 + 5, "dano total = base+margem+atributo (2+4+5=11), veio " .. r.dano)
end

titulo("combate: regeneração por raça (modo)")
do
  local humano = ficha.nova({ vitalidade = 2 }, "humano")
  humano:sofrer(10)
  local hp_apos = humano:regenerar(5)
  ok(humano:modo_regen() == "nenhuma", "humano não regenera (modo nenhuma)")
  ok(hp_apos == humano:hp_max() - 10, "humano NÃO recupera HP ao 'regenerar'")

  local lobo = ficha.nova({ vitalidade = 2 }, "lobisomem")
  lobo:sofrer(10)
  local hp_lobo = lobo:regenerar(5)
  ok(lobo:modo_regen() == "passiva", "lobisomem regenera passiva")
  ok(hp_lobo == lobo:hp_max() - 10 + 5, "lobisomem recupera 5 de HP")

  local vamp = ficha.nova({}, "vampiro")
  ok(vamp:modo_regen() == "escolha", "vampiro regenera por escolha")
  local mago = ficha.nova({}, "mago")
  ok(mago:modo_regen() == "magia", "mago regenera via magia")
end

titulo("combate: bônus de forma (Crino/Bestial +2 acerto, +2 dano; Lupino/Humanóide 0)")
do
  local armas = require("data.armas")
  local alvo = ficha.nova({ vitalidade = 1 }, "humano")  -- defesa 3
  -- Lobisomem Força 4. Humanóide: ataque = 4 + 0(peri) + 0(dado forçado) + 0(forma) = 4.
  local lobo = ficha.nova({ forca = 4 }, "lobisomem")
  local r_vacilo = rng_de_faces({1})  -- dado 1 -> bônus 0

  -- Humanóide (sem bônus): ataque 4 vs def 3 -> total (margem 1)
  local r = combate.atacar(lobo, alvo, armas.punhos, r_vacilo)
  local dano_humanoide = r.dano

  -- Bestial (+2 acerto, +2 dano): ataque 4+2=6 vs def 3 -> margem maior + dano maior
  lobo:transformar("bestial")
  r = combate.atacar(lobo, alvo, armas.punhos, r_vacilo)
  ok(r.arma.nome == "Garras", "Bestial usa Garras (não punhos)")
  ok(r.dano > dano_humanoide, "Bestial causa mais dano que humanóide (acerto+dano)")

  -- Lupino: sem bônus de combate (igual humanóide em poder), mas usa garras.
  lobo:transformar("lupino")
  ok(lobo:bonus_acerto_forma() == 0 and lobo:bonus_dano_forma() == 0,
     "Lupino não tem bônus de combate")
end

titulo("combate: regeneração passiva por turno do lobisomem = teto(nível/2)")
do
  local function regen_nivel(n)
    return ficha.nova({ nivel = n }, "lobisomem"):regen_por_turno()
  end
  ok(regen_nivel(1) == 1, "nível 1 -> 1/turno")
  ok(regen_nivel(2) == 1, "nível 2 -> 1/turno")
  ok(regen_nivel(3) == 2, "nível 3 -> 2/turno (teto 1.5)")
  ok(regen_nivel(10) == 5, "nível 10 -> 5/turno")
  -- Só lobisomem cura passivo por turno:
  ok(ficha.nova({ nivel = 10 }, "humano"):regen_por_turno() == 0, "humano não regenera por turno")
  ok(ficha.nova({ nivel = 10 }, "vampiro"):regen_por_turno() == 0, "vampiro não regenera PASSIVO por turno")
  -- regenerar_turno respeita o teto de HP:
  local lobo = ficha.nova({ nivel = 4, vitalidade = 2 }, "lobisomem")  -- cura 2/turno
  lobo:sofrer(1)
  ok(lobo:regenerar_turno() == 1, "cura só até o teto de HP (curou 1, não 2)")
end

titulo("ficha: HP secreto = base_da_raça + Vitalidade*2")
do
  -- Humano: base 10. Vit2 -> 14; Vit10 -> 30.
  ok(ficha.nova({ vitalidade = 2 }, "humano"):hp_max() == 14, "humano Vit2 -> 14 HP")
  ok(ficha.nova({ vitalidade = 10 }, "humano"):hp_max() == 30, "humano Vit10 -> 30 HP")
  -- Lobisomem: base 15. Vit2 -> 19.
  ok(ficha.nova({ vitalidade = 2 }, "lobisomem"):hp_max() == 19, "lobisomem Vit2 -> 19 HP")
  -- Vampiro/mago: base 10 (padrão).
  ok(ficha.nova({ vitalidade = 2 }, "vampiro"):hp_max() == 14, "vampiro Vit2 -> 14 HP")
  ok(ficha.nova({ vitalidade = 5 }, "humano"):defesa() == 7, "Vit5 -> defesa 7")
end

-- ---------------------------------------------------------------------------
titulo("níveis: curva crescente de EXP")
do
  local niveis = require("core.niveis")
  ok(niveis.custo_degrau(1) == 100, "nível 1->2 custa 100")
  ok(niveis.custo_degrau(2) == 250, "nível 2->3 custa 250 (+150)")
  ok(niveis.custo_degrau(3) == 450, "nível 3->4 custa 450 (+200)")
  ok(niveis.custo_degrau(9) > niveis.custo_degrau(8), "custo sempre cresce")
  ok(niveis.no_teto(10), "nível 10 é o teto")
  ok(niveis.custo_degrau(10) == 0, "no teto não há próximo degrau")
end

titulo("progressão: ganhar EXP sinaliza nível, não sobe sozinho")
do
  local p = ficha.nova({}, "humano")
  ok(p:ganhar_exp(50) == 0, "50 EXP não sobe (custa 100)")
  ok(not p:tem_nivel_pendente(), "sem nível pendente ainda")
  ok(p:ganhar_exp(60) == 1, "chegou a 110 -> 1 nível pronto")
  ok(p:tem_nivel_pendente(), "agora há nível pendente")
  ok(p.nivel == 1, "nível NÃO sobe sozinho (espera o jogador distribuir)")
  ok(p.exp == 10, "sobra 10 EXP rumo ao próximo (110-100)")
end

titulo("progressão: subir nível aplica +1 em 2 atributos diferentes")
do
  local p = ficha.nova({ forca = 2, agilidade = 2 }, "humano")
  p:ganhar_exp(100)
  local ok1 = p:subir_nivel("forca", "agilidade")
  ok(ok1 == true, "subiu distribuindo em força e agilidade")
  ok(p.nivel == 2, "nível agora é 2")
  ok(p:attr("forca") == 3 and p:attr("agilidade") == 3, "cada um subiu +1")
  ok(not p:tem_nivel_pendente(), "pendente consumido")

  -- Regras de recusa:
  local p2 = ficha.nova({}, "humano")
  p2:ganhar_exp(100)
  local recusa = select(1, p2:subir_nivel("forca", "forca"))
  ok(recusa == false, "recusa 2 pontos no MESMO atributo")
  ok(p2.nivel == 1, "nível não subiu na recusa")
  ok(select(1, ficha.nova({}, "humano"):subir_nivel("forca", "agilidade")) == false,
     "sem EXP/pendente, não sobe")
end

titulo("progressão: EXP grande pode conquistar vários níveis de uma vez")
do
  local p = ficha.nova({}, "humano")
  -- 100 (nv2) + 250 (nv3) = 350 -> 2 níveis prontos
  ok(p:ganhar_exp(350) == 2, "350 EXP -> 2 níveis prontos")
  ok((p.niveis_pendentes or 0) == 2, "2 pendentes acumulados")
end

-- ---------------------------------------------------------------------------
-- Tabelas de PROBABILIDADE (não são assert; são pra VOCÊ conferir a sensação).
-- Como o d3 é uniforme (1/3 cada face), dá pra calcular exato sem simular:
-- bônus possíveis: 0, 1, 2 (cada 1/3).
local function chance(base, dif)
  local sucessos = 0
  for _, bonus in ipairs({ 0, 1, 2 }) do
    if base + bonus >= dif then sucessos = sucessos + 1 end
  end
  return sucessos / 3 * 100
end

titulo("PROBABILIDADES — teste de ATRIBUTO puro (confira a sensação)")
print("  (linha = atributo, coluna = dificuldade da tarefa)")
io.write("        ")
for dif = 2, 8 do io.write(string.format("dif%-2d ", dif)) end
io.write("\n")
for atr = 1, 6 do
  io.write(string.format("  attr%d ", atr))
  for dif = 2, 8 do
    io.write(string.format("%4.0f%% ", chance(atr, dif)))
  end
  io.write("\n")
end
print("\n  Referências do design:")
print("  - Porta (feito de Força ~2): olhe a coluna dif 3~4 na linha attr2.")
print("  - 1 tonelada (feito de Força 4): compare linhas attr3/4/5 numa dif alta (~6).")

-- ---------------------------------------------------------------------------
print(string.format("\nRESULTADO: %d passaram, %d falharam.", passou, falhou))
os.exit(falhou == 0 and 0 or 1)
