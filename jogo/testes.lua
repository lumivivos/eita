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
local magia = require("core.magia")
local dominatio = require("core.dominatio")
local sagrado = require("core.sagrado")

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

titulo("Fúria: só lobisomem tem, gasta reduz o próprio valor")
do
  local lobo = ficha.nova({}, "lobisomem")
  ok(lobo:furia_atual() == 5, "Fúria deve começar em 5")
  ok(lobo:gastar_furia(2) == true, "deve conseguir gastar 2 de Fúria")
  ok(lobo:furia_atual() == 3, "Fúria deve cair pra 3 após gastar 2")
  ok(lobo:gastar_furia(10) == false, "não deve gastar mais do que tem")
  ok(lobo:furia_atual() == 3, "Fúria não deve mudar num gasto recusado")
  lobo:recarregar_furia(20)
  ok(lobo:furia_atual() == 10, "recarga não deve passar do teto (10)")

  local humano = ficha.nova({}, "humano")
  ok(humano:furia_atual() == nil, "humano não tem Fúria")
  ok(humano:gastar_furia(1) == false, "humano não deve conseguir gastar Fúria")
end

titulo("Umbra: só lobisomem tem, começa em 1, só sobe (nunca é gasta)")
do
  local lobo = ficha.nova({}, "lobisomem")
  ok(lobo:umbra_atual() == 1, "Umbra deve começar em 1")
  ok(lobo:ganhar_umbra(3) == 4, "ganhar deve somar (1+3=4)")
  lobo:ganhar_umbra(20)
  ok(lobo:umbra_atual() == 10, "não deve passar do teto (10)")

  local vampiro = ficha.nova({}, "vampiro")
  ok(vampiro:umbra_atual() == nil, "vampiro não tem Umbra (só lobisomem)")
  ok(vampiro:ganhar_umbra(1) == nil, "ganhar_umbra não deve fazer nada em quem não tem Umbra")
end

titulo("Sangue: só vampiro tem, teto SEMPRE 10 (geração não reduz)")
do
  local vamp = ficha.nova({}, "vampiro")
  ok(vamp:sangue_atual() == 5, "Sangue deve começar em 5")
  ok(vamp:gastar_sangue(2) == true, "deve conseguir gastar 2 de Sangue")
  ok(vamp:sangue_atual() == 3, "Sangue deve cair pra 3 após gastar 2")
  ok(vamp:gastar_sangue(10) == false, "não deve gastar mais do que tem")
  vamp:recarregar_sangue(20)
  ok(vamp:sangue_atual() == 10, "recarga não deve passar do teto (10), mesmo geração alta (fraca)")

  local humano = ficha.nova({}, "humano")
  ok(humano:sangue_atual() == nil, "humano não tem Sangue")
end

titulo("Geração & diablerie: baixa a geração e custa 1 de Humanidade fixo")
do
  local vamp = ficha.nova({ geracao = 7 }, "vampiro")
  ok(vamp:geracao_atual() == 7, "geração deve começar no valor passado (7)")
  ok(vamp:humanidade_atual() == 7, "Humanidade deve começar em 7")

  ok(vamp:diablerizar(4) == true, "diablerizar deve funcionar")
  ok(vamp:geracao_atual() == 4, "geração deve baixar pra da vítima (4)")
  ok(vamp:humanidade_atual() == 6, "diablerizar deve custar 1 de Humanidade fixo (7->6)")

  -- Diablerizar alguém de geração PIOR (número maior) não deve piorar a sua.
  vamp:diablerizar(9)
  ok(vamp:geracao_atual() == 4, "diablerizar vítima mais fraca não deve piorar a própria geração")
  ok(vamp:humanidade_atual() == 5, "mas ainda custa 1 de Humanidade, mesmo sem melhorar geração")

  local humano = ficha.nova({}, "humano")
  ok(select(1, humano:diablerizar(1)) == false, "humano não pode diablerizar (não tem geração)")
end

titulo("Humanidade: 0-10, Sagrado é elegível pra QUALQUER raça em 10")
do
  local vamp = ficha.nova({}, "vampiro")
  ok(vamp:elegivel_sagrado() == false, "7 de Humanidade não é elegível ainda")
  vamp:ganhar_humanidade(20)
  ok(vamp:humanidade_atual() == 10, "não deve passar do teto (10)")
  ok(vamp:elegivel_sagrado() == true, "10 de Humanidade -> elegível ao Sagrado")
  vamp:perder_humanidade(100)
  ok(vamp:humanidade_atual() == 0, "não deve passar do chão (0)")

  -- Humanidade é UNIVERSAL: todo ser tem (todos começam em 7). O Sagrado
  -- (elegível em 10) vale pra qualquer raça — um humano também pode alcançá-lo.
  local humano = ficha.nova({}, "humano")
  ok(humano:humanidade_atual() == 7, "humano também tem Humanidade, começa em 7")
  ok(humano:elegivel_sagrado() == false, "humano em 7 ainda não é elegível")
  humano:ganhar_humanidade(3)
  ok(humano:elegivel_sagrado() == true, "humano que chega a 10 TAMBÉM fica elegível ao Sagrado")
end

titulo("Sagrado: ganha ao bater 10, histerese (só perde abaixo de 9)")
do
  local p = ficha.nova({}, "humano")  -- Humanidade 7
  ok(p:tem_sagrado() == false, "não deve ter Sagrado com Humanidade 7")

  p:ganhar_humanidade(3)  -- 10
  ok(p:tem_sagrado() == true, "deve ganhar Sagrado ao bater 10")

  p:perder_humanidade(1)  -- 9
  ok(p:tem_sagrado() == true, "cair pra 9 NÃO deve tirar o Sagrado (histerese)")

  p:perder_humanidade(1)  -- 8
  ok(p:tem_sagrado() == false, "cair abaixo de 9 (8) deve tirar o Sagrado")

  p:ganhar_humanidade(1)  -- volta pra 9
  ok(p:tem_sagrado() == false, "voltar a 9 não recupera sozinho — precisa bater 10 de novo")

  p:ganhar_humanidade(1)  -- 10
  ok(p:tem_sagrado() == true, "bater 10 de novo recupera o Sagrado")

  -- Vale pra qualquer raça (universal).
  local vamp = ficha.nova({}, "vampiro")
  ok(vamp:tem_sagrado() == false, "vampiro começa sem Sagrado (Humanidade 7)")
  vamp:ganhar_humanidade(3)
  ok(vamp:tem_sagrado() == true, "vampiro também pode ganhar Sagrado")

  -- Fix B: ficha.nova sincroniza o Sagrado no ponto de partida. Antes,
  -- sagrado_obtido ficava nil até a 1ª mudança de Humanidade; agora tem_sagrado
  -- devolve um bool já na criação (false em 7, sem esperar nada).
  local recem = ficha.nova({}, "humano")
  ok(recem:tem_sagrado() == false, "recém-criado (Humanidade 7) já responde false, não nil")
  ok(recem.sagrado_obtido ~= nil, "estado do Sagrado é sincronizado na criação (não fica nil)")
end

titulo("Sagrado: nível começa em 1 na primeira concessão, sobe até 5, não reseta")
do
  local p = ficha.nova({}, "humano")
  ok(p:sagrado_nivel_atual() == nil, "sem Sagrado ainda, nível é nil")

  p:ganhar_humanidade(3)  -- bate 10, ganha Sagrado
  ok(p:sagrado_nivel_atual() == 1, "primeira concessão começa no nível 1")

  ok(p:ganhar_sagrado(2) == 3, "ganhar sobe o nível (1+2=3)")
  p:ganhar_sagrado(20)
  ok(p:sagrado_nivel_atual() == 5, "não deve passar do teto (5)")

  -- Perder e reconquistar o Sagrado não reseta o nível já treinado.
  p:perder_humanidade(3)  -- Humanidade 7, perde o Sagrado
  ok(p:tem_sagrado() == false, "perdeu o Sagrado (Humanidade caiu bem abaixo)")
  ok(p:sagrado_nivel_atual() == 5, "nível continua guardado mesmo sem o Sagrado ativo")
  p:ganhar_humanidade(3)  -- bate 10 de novo
  ok(p:tem_sagrado() == true, "reconquistou o Sagrado")
  ok(p:sagrado_nivel_atual() == 5, "nível NÃO reseta pra 1 — continua o de antes")

  local vamp = ficha.nova({}, "vampiro")
  ok(vamp:ganhar_sagrado(1) == nil, "sem o Sagrado concedido ainda, ganhar_sagrado não faz nada")
end

titulo("core/sagrado: teste sem custo, dano escala com nível + margem")
do
  local atacante = ficha.nova({ vontade = 6 }, "humano")  -- vontade/2 = 3
  atacante:ganhar_humanidade(3)  -- ganha Sagrado nível 1
  local alvo = ficha.nova({ vontade = 4 }, "humano")  -- defesa mental 4

  -- base = nivel(1) + floor(vontade/2)(3) = 4. face 3 -> bônus 2. total = 6.
  -- dif 4 -> passa. margem = 6-4 = 2. dano = 1*5 + 2 = 7.
  local r = sagrado.tentar(atacante, alvo, rng_de_faces({3}))
  ok(r.tentou == true, "deve tentar (tem Sagrado)")
  ok(r.passou == true, "total 6 >= dif 4 deve passar")
  ok(r.dano == 7, "dano deve ser nivel*5 + margem (1*5+2=7)")
  ok(alvo.hp == alvo:hp_max() - 7, "dano deve ser aplicado no alvo")

  -- Sem Sagrado: recusa, sem rolar nem causar dano.
  local sem_fe = ficha.nova({}, "humano")
  local alvo2 = ficha.nova({}, "humano")
  local r2 = sagrado.tentar(sem_fe, alvo2)
  ok(r2.tentou == false, "sem Sagrado não deve tentar")
  ok(r2.sem_sagrado == true, "deve sinalizar a falta de Sagrado")
  ok(alvo2.hp == alvo2:hp_max(), "alvo não deve sofrer nada numa recusa")

  -- Falha: dado ruim, dif alta -> sem dano, mas SEM CUSTO (nada é gasto).
  local fraco = ficha.nova({ vontade = 2 }, "humano")
  fraco:ganhar_humanidade(3)
  local tanque = ficha.nova({ vontade = 10 }, "humano")  -- defesa mental 10
  local r3 = sagrado.tentar(fraco, tanque, rng_de_faces({1}))
  ok(r3.passou == false, "teste fraco vs defesa alta deve falhar")
  ok(r3.dano == 0, "falha não causa dano")
  ok(tanque.hp == tanque:hp_max(), "alvo intacto numa falha")
end

titulo("Ferida sagrada: trava o teto de cura SOBRENATURAL (lobisomem/vampiro)")
do
  -- Lobisomem, regen passiva. Nível alto pra regenerar rápido.
  local lobo = ficha.nova({ vitalidade = 2, nivel = 10 }, "lobisomem")  -- hp_max 15+4=19
  ok(lobo:dano_sagrado_atual() == 0, "começa sem ferida sagrada")
  ok(lobo:teto_cura_sobrenatural() == 19, "teto de cura = hp_max sem ferida")

  lobo:sofrer_sagrado(10)  -- hp 19->9, dano_sagrado 10, teto 19-10=9
  ok(lobo.hp == 9, "sofrer_sagrado aplica o dano normalmente")
  ok(lobo:dano_sagrado_atual() == 10, "marca a ferida sagrada")
  ok(lobo:teto_cura_sobrenatural() == 9, "teto de cura sobrenatural cai (19-10=9)")

  -- Regen passiva (lobisomem nível 10 -> teto(10/2)=5/turno) NÃO deve passar
  -- do teto travado (9), mesmo tendo "espaço" até o hp_max real (19).
  lobo:regenerar_turno()
  lobo:regenerar_turno()
  lobo:regenerar_turno()
  ok(lobo.hp == 9, "regen passiva não passa do teto travado pela ferida sagrada")

  -- Cura mundana (⚪, só o mecanismo) reduz a ferida em si, liberando o teto.
  lobo:reduzir_dano_sagrado(10)
  ok(lobo:dano_sagrado_atual() == 0, "cura mundana reduz a ferida sagrada")
  ok(lobo:teto_cura_sobrenatural() == 19, "teto de cura volta ao hp_max normal")
  lobo:regenerar_turno()
  ok(lobo.hp > 9, "com a ferida resolvida, regen passiva volta a curar de verdade")

  -- Vampiro: mesma trava vale pra curar_com_sangue.
  local vamp = ficha.nova({ vitalidade = 2, geracao = 0 }, "vampiro")  -- hp_max 14, cura_por_geracao(0)=10
  vamp:recarregar_sangue(5)
  vamp:sofrer_sagrado(12)  -- hp 14->2, dano_sagrado 12, teto 14-12=2
  local ok_curou, quanto = vamp:curar_com_sangue()
  ok(ok_curou == true, "curar_com_sangue ainda funciona (só o VALOR é limitado)")
  ok(quanto == 0, "não cura nada — já está no teto travado (2)")
  ok(vamp.hp == 2, "HP não passa do teto travado pela ferida sagrada")
end

titulo("Ferida sagrada: teto nunca fica negativo se o hp_max CAIR depois da ferida")
do
  -- Vitalidade 8 via Elevação eleva o hp_max; sofre ferida sagrada grande
  -- (capada no hp_max ALTO); depois a Elevação reverte e o hp_max CAI —
  -- dano_sagrado fica maior que o hp_max atual.
  local vamp = ficha.nova({ vitalidade = 2, geracao = 1 }, "vampiro")  -- hp_max 14, x4 na Elevação
  vamp:recarregar_sangue(5)
  vamp:ativar_elevacao()  -- Vitalidade 2->6, hp_max 14->22
  ok(vamp:hp_max() == 22, "hp_max sobe com a Elevação")

  vamp:sofrer_sagrado(22)  -- hp 22->0, dano_sagrado capado no hp_max atual (22)
  ok(vamp:dano_sagrado_atual() == 22, "ferida sagrada capada no hp_max de quando aconteceu (22)")

  vamp:passar_turno_elevacao()
  vamp:passar_turno_elevacao()  -- reverte: Vitalidade volta a 2, hp_max volta a 14
  ok(vamp:hp_max() == 14, "hp_max cai de volta ao reverter a Elevação")

  -- Sem o clamp, teto seria 14-22 = -8, e uma "cura" reduziria o HP.
  ok(vamp:teto_cura_sobrenatural() == 0, "teto nunca fica negativo (clampado em 0)")
  vamp.hp = 0
  local antes = vamp.hp
  vamp:recarregar_sangue(5)
  vamp:curar_com_sangue()
  ok(vamp.hp >= antes, "curar não deve REDUZIR o HP mesmo com dano_sagrado > hp_max")
  ok(vamp.hp == 0, "efetivamente não cura nada enquanto a ferida sagrada não for tratada")
end

titulo("Marcações: 3 atos sombrios = -1 Humanidade e zera (não vaza)")
do
  local vamp = ficha.nova({}, "vampiro")  -- Humanidade 7, marcações 0
  ok(vamp:marcacoes_atual() == 0, "começa sem marcações")
  ok(vamp:marcar_humanidade("roubar") == false, "1ª marcação só acumula")
  ok(vamp:marcar_humanidade("mentir") == false, "2ª marcação só acumula")
  ok(vamp:humanidade_atual() == 7, "Humanidade intacta até a 3ª (atos soltos não punem)")
  ok(vamp:marcar_humanidade("roubar") == true, "3ª marcação converte em queda")
  ok(vamp:humanidade_atual() == 6, "Humanidade cai 1 ao completar 3 marcações")
  ok(vamp:marcacoes_atual() == 0, "contagem ZERA ao converter (não vaza o excedente)")
  ok(vamp.ultima_mancha == "roubar", "registra o último ato que marcou")

  -- Diablerie é a EXCEÇÃO: tira 1 direto, sem passar pela contagem.
  local anciao = ficha.nova({ geracao = 6 }, "vampiro")  -- Humanidade 7
  anciao:marcar_humanidade("roubar")  -- 1 marcação
  anciao:diablerizar(3)
  ok(anciao:humanidade_atual() == 6, "diablerie tira 1 Humanidade DIRETO")
  ok(anciao:marcacoes_atual() == 1, "diablerie NÃO mexe nas marcações (é a exceção)")

  -- Humanidade é universal: o humano TAMBÉM marca (só não sofre debuffs por
  -- Humanidade baixa — isso é só do vampiro, ainda ⚪).
  local humano = ficha.nova({}, "humano")
  ok(humano:marcar_humanidade("roubar") == false, "humano também acumula marcações (universal)")
  ok(humano:marcacoes_atual() == 1, "marcação registrada no humano")
end

titulo("Alimentar: beber +2 Sangue; sugar até a morte +3 e deixa 1 marca")
do
  local vamp = ficha.nova({}, "vampiro")  -- Sangue 5
  vamp:gastar_sangue(3)  -- Sangue 2, pra ter espaço
  ok(vamp:alimentar(false) == 4, "beber sem matar dá +2 (2->4)")
  ok(vamp:marcacoes_atual() == 0, "beber sem matar não mancha")

  vamp:gastar_sangue(3)  -- Sangue 1
  ok(vamp:alimentar(true) == 4, "sugar até a morte dá +3 (1->4)")
  ok(vamp:marcacoes_atual() == 1, "sugar até a morte deixa 1 marcação")

  -- Não passa do teto ao alimentar.
  local cheio = ficha.nova({}, "vampiro")  -- Sangue 5
  cheio:recarregar_sangue(4)  -- Sangue 9
  ok(cheio:alimentar(false) == 10, "alimentar respeita o teto 10 (9+2 capa em 10)")
end

titulo("Cura com Sangue: escolha (1 Sangue) cura HP conforme a geração")
do
  ok(ficha.cura_por_geracao(7) == 2, "geração 7 (fraca) -> cura 2")
  ok(ficha.cura_por_geracao(3) == 6, "geração 3 -> cura 6")
  ok(ficha.cura_por_geracao(0) == 10, "geração 0 (Caim) -> cura 10")

  local vamp = ficha.nova({ geracao = 3, vitalidade = 5 }, "vampiro")  -- cura 6/gota
  vamp:sofrer(8)
  local ok_curou, curou = vamp:curar_com_sangue()
  ok(ok_curou == true, "deve curar com Sangue de sobra")
  ok(curou == 6, "geração 3 cura 6 de HP")
  ok(vamp:sangue_atual() == 4, "cura gasta 1 de Sangue (5->4)")

  -- Sem Sangue não cura.
  local seco = ficha.nova({}, "vampiro")
  seco.sangue = 0
  ok(select(1, seco:curar_com_sangue()) == false, "sem Sangue não cura")

  -- Humano não cura com Sangue (não tem).
  ok(select(1, ficha.nova({}, "humano"):curar_com_sangue()) == false, "humano não cura com Sangue")
end

titulo("Metabolismo: -1 Sangue por dia; chegar a 0 dispara Frenesi de fome")
do
  local vamp = ficha.nova({}, "vampiro")  -- Sangue 5
  ok(vamp:passar_dia() == 4, "perde 1 de Sangue por dia (5->4)")
  ok(vamp:em_frenesi() == false, "com Sangue de sobra, sem Frenesi")

  -- Deixa em 1 e passa o dia -> chega a 0 -> Frenesi de fome.
  vamp.sangue = 1
  ok(vamp:passar_dia() == 0, "chega a 0 de Sangue")
  ok(vamp:em_frenesi() == true, "Sangue 0 dispara Frenesi sem controle (a fome vence)")

  -- Não fica negativo.
  vamp.sangue = 0
  ok(vamp:passar_dia() == 0, "Sangue não fica negativo")

  ok(ficha.nova({}, "humano"):passar_dia() == nil, "humano não tem metabolismo de Sangue")
end

titulo("Elevação: buffa Força+Vitalidade+Agilidade JUNTAS, escala com geração, PODE passar do teto 10")
do
  local vamp = ficha.nova({ forca = 8, geracao = 7 }, "vampiro")  -- geração 7 -> x1
  ok(ficha.multiplicador_elevacao(7) == 1, "geração 7 -> multiplicador x1")
  ok(ficha.multiplicador_elevacao(5) == 2, "geração 5 -> multiplicador x2")
  ok(ficha.multiplicador_elevacao(3) == 3, "geração 3 -> multiplicador x3")
  ok(ficha.multiplicador_elevacao(1) == 4, "geração 1 -> multiplicador x4")
  ok(ficha.multiplicador_elevacao(0) == 5, "geração 0 (Caim) -> multiplicador x5")

  local ok_ativou, bonus = vamp:ativar_elevacao()
  ok(ok_ativou == true, "deve ativar com Sangue de sobra")
  ok(bonus == 1, "geração 7 dá bônus x1")
  ok(vamp:attr("forca") == 9, "força deve subir (8+1=9)")
  ok(vamp:attr("vitalidade") == 3, "vitalidade também sobe junto (2+1=3)")
  ok(vamp:attr("agilidade") == 3, "agilidade também sobe junto (2+1=3)")
  ok(vamp:sangue_atual() == 4, "deve gastar exatamente 1 de Sangue (custo fixo)")

  ok(vamp:ativar_elevacao() == false, "não deve ativar de novo enquanto já tem uma ativa")

  vamp:passar_turno_elevacao()
  ok(vamp:attr("forca") == 9, "força ainda buffada após 1 turno (dura 2)")
  vamp:passar_turno_elevacao()
  ok(vamp:attr("forca") == 8, "força deve reverter sozinha após 2 turnos (volta a 8)")
  ok(vamp:attr("vitalidade") == 2, "vitalidade reverte junto")
  ok(vamp:attr("agilidade") == 2, "agilidade reverte junto")
  ok(vamp:elevacao_ativa() == false, "Elevação não deve estar mais ativa")

  -- PODE passar do teto 10 (só enquanto ativo).
  local vamp_forte = ficha.nova({ forca = 10, geracao = 1 }, "vampiro")  -- x4
  vamp_forte:recarregar_sangue(5)
  vamp_forte:ativar_elevacao()
  ok(vamp_forte:attr("forca") == 14, "10+4=14, PASSA do teto normal de 10")

  -- Sem Sangue deve recusar (nada de atributo pra escolher agora).
  local vamp2 = ficha.nova({}, "vampiro")
  vamp2.sangue = 0
  ok(select(1, vamp2:ativar_elevacao()) == false, "sem Sangue deve recusar")
end

titulo("Elevação: dá HP na hora (Vitalidade sobe junto) e não deixa HP fantasma ao reverter")
do
  -- Geração 3 -> x3. Vit 2 -> hp_max = 10(base) + 2*2 = 14. HP começa cheio.
  local vamp = ficha.nova({ vitalidade = 2, geracao = 3 }, "vampiro")
  ok(vamp:hp_max() == 14 and vamp.hp == 14, "começa com 14/14")

  vamp:ativar_elevacao()  -- Vit 2->5, hp_max 14->20 (+3*2=6)
  ok(vamp:hp_max() == 20, "elevar Vit (junto com o resto) sobe o teto de HP (14 -> 20)")
  ok(vamp.hp == 20, "HP atual sobe JUNTO na hora (senão elevar Vit seria inútil)")

  -- Toma dano enquanto elevado, depois deixa reverter: HP não pode ficar
  -- acima do teto que volta a cair.
  vamp:sofrer(3)  -- 20 -> 17
  vamp:passar_turno_elevacao()
  vamp:passar_turno_elevacao()  -- reverte: Vit volta a 2, hp_max volta a 14
  ok(vamp:hp_max() == 14, "teto de HP volta ao normal ao reverter")
  ok(vamp.hp == 14, "HP é clampado ao novo teto (17 viraria fantasma sem o clamp)")
  ok(vamp.hp <= vamp:hp_max(), "nunca sobra HP acima do máximo")
end

titulo("Frenesi do vampiro: dispara quando Sangue chega a 0 (a fome vence)")
do
  local vamp = ficha.nova({}, "vampiro")  -- Sangue 5
  ok(vamp:em_risco_frenesi_vampiro() == false, "Sangue 5 -> sem risco")

  vamp.sangue = 1
  ok(vamp:em_risco_frenesi_vampiro() == false, "Sangue 1 -> ainda sem risco (só dispara em 0)")

  vamp.sangue = 0
  ok(vamp:em_risco_frenesi_vampiro() == true, "Sangue 0 -> em risco (a fome vence)")

  -- Reaproveita o MESMO estado de Frenesi do lobisomem.
  vamp:entrar_frenesi()
  ok(vamp:em_frenesi() == true, "entrar_frenesi deve funcionar igual pro vampiro (estado compartilhado)")
  vamp:passar_turno_frenesi()
  ok(vamp:em_frenesi() == true, "ainda em frenesi após 1 turno (dura 2)")
  vamp:passar_turno_frenesi()
  ok(vamp:em_frenesi() == false, "recupera o controle após 2 turnos")

  local humano = ficha.nova({}, "humano")
  ok(humano:em_risco_frenesi_vampiro() == false, "humano não entra em Frenesi de vampiro (não tem Sangue)")
end

titulo("Besta: todo ser tem 10 (força animadora igual em todos)")
do
  ok(ficha.nova({}, "humano"):besta_atual() == 10, "humano tem Besta 10")
  ok(ficha.nova({}, "lobisomem"):besta_atual() == 10, "lobisomem tem Besta 10")
  ok(ficha.nova({}, "vampiro"):besta_atual() == 10, "vampiro tem Besta 10")
  ok(ficha.nova({}, "mago"):besta_atual() == 10, "mago tem Besta 10 (igual em todos)")
  local p = ficha.nova({}, "humano")
  ok(p:so_carne() == false, "Besta 10 não é 'só carne'")
  p.besta = 0
  ok(p:so_carne() == true, "Besta 0 = só carne")
end

titulo("Besta: acalmar gasta Sangue e dá IMUNIDADE ao Frenesi por N turnos")
do
  local vamp = ficha.nova({}, "vampiro")
  vamp.sangue = 0
  ok(vamp:em_risco_frenesi_vampiro() == true, "Sangue 0 -> em risco")

  vamp:recarregar_sangue(1)  -- só pra ter Sangue pra pagar o acalmar
  ok(vamp:acalmar_besta() == true, "deve acalmar com Sangue de sobra")
  ok(vamp:besta_acalmada() == true, "a Besta está acalmada")
  vamp.sangue = 0
  ok(vamp:em_risco_frenesi_vampiro() == false, "acalmada -> imune ao Frenesi mesmo com Sangue 0")

  ok(select(1, vamp:acalmar_besta()) == false, "não deve empilhar enquanto já acalmado")

  -- Dura 3 turnos e some.
  vamp:passar_turno_besta()
  vamp:passar_turno_besta()
  ok(vamp:besta_acalmada() == true, "ainda acalmada após 2 turnos (dura 3)")
  vamp:passar_turno_besta()
  ok(vamp:besta_acalmada() == false, "acaba após o 3º turno")
  ok(vamp:em_risco_frenesi_vampiro() == true, "sem a imunidade, Sangue 0 volta a arriscar")

  -- Só vampiro acalma (precisa de Sangue).
  ok(select(1, ficha.nova({}, "humano"):acalmar_besta()) == false, "humano não domina a Besta")
  ok(ficha.nova({}, "humano"):passar_turno_besta() == 0, "passar_turno_besta é inofensivo em quem não acalmou")
end

titulo("Atordoado: efeito de status genérico, perde a vez por N turnos")
do
  local p = ficha.nova({}, "humano")
  ok(p:atordoado() == false, "não deve começar atordoado")
  p:atordoar(2)
  ok(p:atordoado() == true, "deve estar atordoado após atordoar(2)")
  p:passar_turno_atordoado()
  ok(p:atordoado() == true, "ainda atordoado após 1 turno (durava 2)")
  p:passar_turno_atordoado()
  ok(p:atordoado() == false, "recupera após 2 turnos")
end

titulo("Dominatio: teste NÍVEL vs defesa mental, sucesso atordoa o alvo")
do
  local vamp = ficha.nova({}, "vampiro")  -- nível 1, Sangue 5
  local alvo = ficha.nova({ vontade = 3 }, "humano")  -- defesa mental 3
  -- base = nível(1). face 3 -> bônus 2. total = 3. dif 3 -> passa (empate).
  local r = dominatio.tentar(vamp, alvo, rng_de_faces({3}))
  ok(r.tentou == true, "deve tentar (tinha Sangue)")
  ok(r.bloqueado == false, "alvo não é vampiro, sem bloqueio por geração")
  ok(r.passou == true, "total 3 >= dif 3 deve passar")
  ok(vamp:sangue_atual() == 4, "deve gastar 1 de Sangue (custo fixo)")
  ok(alvo:atordoado() == true, "sucesso deve atordoar o alvo")

  -- Falha: face 1 -> bônus 0. total = 1. dif 3 -> falha.
  local vamp2 = ficha.nova({}, "vampiro")
  local alvo2 = ficha.nova({ vontade = 3 }, "humano")
  local r2 = dominatio.tentar(vamp2, alvo2, rng_de_faces({1}))
  ok(r2.passou == false, "total 1 < dif 3 deve falhar")
  ok(alvo2:atordoado() == false, "falha não deve atordoar")
  ok(vamp2:sangue_atual() == 4, "gasta o Sangue mesmo na falha (você tentou)")
end

titulo("Dominatio: bloqueio automático contra vampiro de geração mais forte")
do
  local fraco = ficha.nova({ geracao = 7 }, "vampiro")
  local forte = ficha.nova({ geracao = 3 }, "vampiro")  -- geração MENOR = mais forte
  local r = dominatio.tentar(fraco, forte, rng_de_faces({3}))  -- dado bom, não importa
  ok(r.tentou == true, "deve tentar (gasta Sangue mesmo bloqueado)")
  ok(r.bloqueado == true, "geração mais forte do alvo deve bloquear automaticamente")
  ok(r.passou == false, "bloqueio nunca passa, nem com dado bom")
  ok(fraco:sangue_atual() == 4, "ainda gasta 1 de Sangue mesmo bloqueado (você tentou)")
  ok(forte:atordoado() == false, "alvo bloqueado não deve atordoar")

  -- O inverso (atacar alguém de geração IGUAL ou PIOR) não deve bloquear.
  local igual = ficha.nova({ geracao = 7 }, "vampiro")
  local r2 = dominatio.tentar(fraco, igual, rng_de_faces({3}))
  ok(r2.bloqueado == false, "geração igual não deve bloquear")
end

titulo("Dominatio: recusa sem Sangue, sem gastar nem rolar")
do
  local vamp = ficha.nova({}, "vampiro")
  vamp.sangue = 0
  local alvo = ficha.nova({}, "humano")
  local r = dominatio.tentar(vamp, alvo)
  ok(r.tentou == false, "não deve tentar sem Sangue")
  ok(r.sem_sangue == true, "deve sinalizar falta de Sangue")
  ok(alvo:atordoado() == false, "alvo não deve ser afetado numa recusa")
end

titulo("Sonhos: só mago tem, sem teto, nunca abaixo do mínimo (1)")
do
  local mago = ficha.nova({}, "mago")
  ok(mago:sonhos_atual() == 1, "Sonhos deve começar em 1")
  ok(mago:gastar_sonhos(1) == false, "não deve gastar se derrubaria abaixo do mínimo (1-1=0)")
  mago:recarregar_sonhos(9)
  ok(mago:sonhos_atual() == 10, "recarga deve somar (1+9=10)")
  ok(mago:gastar_sonhos(9) == true, "deve gastar até deixar exatamente no mínimo (10-9=1)")
  ok(mago:sonhos_atual() == 1, "sonhos deve cair pro mínimo (1)")
  mago:recarregar_sonhos(1000)
  ok(mago:sonhos_atual() == 1001, "não existe teto pra Sonhos")

  local humano = ficha.nova({}, "humano")
  ok(humano:sonhos_atual() == nil, "humano não tem Sonhos")
end

titulo("Conquistas: contador UNIVERSAL (toda raça acumula, mesmo quem não é mago)")
do
  local humano = ficha.nova({}, "humano")
  ok(humano:conquistas_atual() == 0, "começa em 0")
  humano:ganhar_conquista()
  humano:ganhar_conquista()
  ok(humano:conquistas_atual() == 2, "cada chamada soma 1 por padrão")
  ok(humano:sonhos_atual() == nil, "humano não tem Sonhos pra conquista virar (sem raça pra receber)")

  local lobo = ficha.nova({}, "lobisomem")
  lobo:ganhar_conquista()
  ok(lobo:conquistas_atual() == 1, "lobisomem também acumula, mesmo não usando pra nada ainda")
end

titulo("Sonhos iniciais do mago vêm do que já foi CONQUISTADO antes de virar mago")
do
  -- Sem conquistas -> preso no piso (SONHOS_INICIAL), como já era.
  local mago_zero = ficha.nova({}, "mago")
  ok(mago_zero:sonhos_atual() == 1, "sem conquistas, começa no piso (1)")

  -- ficha.nova aceita attrs.conquistas (ex.: um humano que virou mago
  -- carregando o que já tinha conquistado).
  local mago_com_historico = ficha.nova({ conquistas = 5 }, "mago")
  ok(mago_com_historico:sonhos_atual() == 5, "Sonhos inicial = conquistas acumuladas (5), acima do piso")

  -- transformar_raca preserva o self.conquistas já existente na ficha (não é
  -- um attrs novo) — simula o humano lutando/explorando ANTES de virar mago.
  local personagem = ficha.nova({}, "humano")
  personagem:ganhar_conquista()  -- matou o bandido, digamos
  personagem:ganhar_conquista()  -- explorou algo
  personagem:ganhar_conquista()  -- concluiu uma quest
  ok(personagem:conquistas_atual() == 3, "3 conquistas acumuladas como humano")
  personagem:transformar_raca("mago")
  ok(personagem:sonhos_atual() == 3, "virou mago já com 3 Sonhos, herdados das conquistas de quando era humano")

  -- Já sendo mago, uma conquista nova vira Sonhos NA HORA (não só no futuro).
  personagem:ganhar_conquista()
  ok(personagem:sonhos_atual() == 4, "conquista de mago já ativo soma direto no Sonhos atual")
  ok(personagem:conquistas_atual() == 4, "contador universal segue subindo junto")
end

titulo("transformar_raca: vampiro e lobisomem NUNCA viram mago (ver lore.md)")
do
  local vampiro = ficha.nova({}, "vampiro")
  local ok1, motivo1 = vampiro:transformar_raca("mago")
  ok(ok1 == false, "vampiro não pode virar mago")
  ok(motivo1 ~= nil, "recusa vem com motivo")
  ok(vampiro.raca == "vampiro", "raça não muda numa recusa")

  local lobo = ficha.nova({}, "lobisomem")
  local ok2 = lobo:transformar_raca("mago")
  ok(ok2 == false, "lobisomem não pode virar mago")
  ok(lobo.raca == "lobisomem", "raça não muda numa recusa")

  -- Humano continua podendo (o único caminho jogável hoje pra virar mago).
  local humano = ficha.nova({}, "humano")
  local ok3 = humano:transformar_raca("mago")
  ok(ok3 == true, "humano pode virar mago")
  ok(humano.raca == "mago", "raça muda numa transformação aceita")

  -- Lobisomem -> vampiro (Abominação futura) continua permitido; não é essa
  -- a regra restringida aqui.
  local lobo2 = ficha.nova({}, "lobisomem")
  ok(lobo2:transformar_raca("vampiro") == true, "lobisomem -> vampiro continua permitido")
end

titulo("Quebras: acumula, tem teto 10, pode reduzir (diferente de Corrupção)")
do
  local mago = ficha.nova({}, "mago")
  ok(mago:quebras_atual() == 0, "Quebras deve começar em 0")
  ok(mago:ganhar_quebras(3) == 3, "ganhar deve somar")
  ok(mago:no_cemiterio_dos_sonhos() == false, "3 de 10 não é o teto ainda")
  mago:ganhar_quebras(20)
  ok(mago:quebras_atual() == 10, "não deve passar do teto (10)")
  ok(mago:no_cemiterio_dos_sonhos() == true, "10 de Quebras = Cemitério dos Sonhos")
  ok(mago:reduzir_quebras(4) == 6, "reduzir deve subtrair (10-4=6, diferente de Corrupção)")
  mago:reduzir_quebras(100)
  ok(mago:quebras_atual() == 0, "não deve passar do chão (0)")
end

titulo("magia: quebras_por_falha escala em degraus de 5 pelo custo")
do
  ok(magia.quebras_por_falha(1) == 1, "custo 1 -> 1 Quebra")
  ok(magia.quebras_por_falha(5) == 1, "custo 5 -> 1 Quebra (teto do primeiro degrau)")
  ok(magia.quebras_por_falha(6) == 2, "custo 6 -> 2 Quebras (novo degrau)")
  ok(magia.quebras_por_falha(10) == 2, "custo 10 -> 2 Quebras")
  ok(magia.quebras_por_falha(11) == 3, "custo 11 -> 3 Quebras")
end

titulo("magia: conjurar recusa sem Sonhos suficiente, sem rolar nada")
do
  local mago = ficha.nova({}, "mago")  -- Sonhos 1, mínimo 1 -> não pode gastar nada
  local feitico = { nome = "Teste", custo = 1, dif = 3 }
  local r = magia.conjurar(mago, feitico)
  ok(r.conjurou == false, "não deve conjurar sem Sonhos")
  ok(r.sem_sonhos == true, "deve sinalizar falta de Sonhos")
  ok(mago:sonhos_atual() == 1, "Sonhos não deve mudar numa recusa")
end

titulo("magia: sucesso não gera Quebras")
do
  local mago = ficha.nova({}, "mago")
  mago:recarregar_sonhos(9)  -- Sonhos 10
  -- Depois de gastar 1 (custo), sonhos=9. base = 9 + vontade(5) = 14.
  -- dado forçado pra face 3 (bônus 2) -> total = 16. dif 3 -> passa fácil.
  local feitico = { nome = "Teste", custo = 1, dif = 3 }
  local r = magia.conjurar(mago, feitico, rng_de_faces({3}))
  ok(r.conjurou == true, "deve conjurar (teste alto vs dif baixa)")
  ok(r.quebras_ganhas == 0, "sucesso não gera Quebras")
  ok(mago:quebras_atual() == 0, "Quebras deve continuar em 0")
end

titulo("magia: falha LEVE (quase passou) não gera Quebras")
do
  local mago = ficha.nova({}, "mago")
  mago.sonhos = 2  -- após gastar o custo (1), sobra 1 -> base baixo de propósito
  -- base = sonhos APÓS pagar (2-1=1) + vontade(5) = 6. face 1 -> bônus 0.
  -- total = 6. dif 8: margem_falha = 8-6 = 2. limiar = floor(8/2) = 4.
  -- 2 <= 4 -> falha LEVE.
  local feitico = { nome = "Teste", custo = 1, dif = 8 }
  local r = magia.conjurar(mago, feitico, rng_de_faces({1}))
  ok(r.conjurou == false, "deve falhar (total 6 < dif 8)")
  ok(r.falha_feia == false, "margem 2 <= limiar 4 -> falha LEVE, não feia")
  ok(r.quebras_ganhas == 0, "falha leve não gera Quebras")
end

titulo("magia: falha FEIA (errou por mais que metade) gera Quebras")
do
  local mago = ficha.nova({}, "mago")
  mago.sonhos = 2
  -- base = sonhos APÓS pagar (2-1=1) + vontade(5) = 6. face 1 -> bônus 0.
  -- total = 6. dif 15: margem_falha = 15-6 = 9. limiar = floor(15/2) = 7.
  -- 9 > 7 -> falha FEIA.
  local feitico = { nome = "Teste", custo = 1, dif = 15 }
  local r = magia.conjurar(mago, feitico, rng_de_faces({1}))
  ok(r.conjurou == false, "deve falhar (total 6 < dif 15)")
  ok(r.falha_feia == true, "margem 9 > limiar 7 -> falha FEIA")
  ok(r.quebras_ganhas == magia.quebras_por_falha(15), "quebras geradas devem bater com a fórmula (dif 15 -> 3)")
  ok(mago:quebras_atual() == r.quebras_ganhas, "ficha deve refletir as Quebras ganhas")
end

titulo("magia: sonhos_extra reduz a dificuldade, mas custa mais e reduz a própria base")
do
  local mago = ficha.nova({}, "mago")
  mago:recarregar_sonhos(9)  -- Sonhos 10
  -- custo 1 + sonhos_extra 2 = paga 3. Sonhos após pagar = 10-3 = 7.
  -- base = 7 + vontade(5) = 12. dif efetiva = 20 - 2*2 = 16. face 1 -> bônus 0.
  -- total = 12. 12 < 16 -> ainda falha (a dif começou alta de propósito).
  local feitico = { nome = "Teste", custo = 1, dif = 20 }
  local r = magia.conjurar(mago, feitico, rng_de_faces({1}), 2)
  ok(r.sonhos_extra == 2, "resultado registra quanto foi pago a mais")
  ok(r.dif == 16, "dif efetiva = 20 - (2 sonhos_extra * 2) = 16")
  ok(mago:sonhos_atual() == 7, "pagou custo(1) + sonhos_extra(2) = 3 no total (10-3=7)")

  -- Pagando sonhos_extra o suficiente, a dif efetiva pode até zerar/negativar
  -- (garante sucesso) — sem teto, como confirmado.
  local mago2 = ficha.nova({}, "mago")
  mago2:recarregar_sonhos(99)
  local feitico2 = { nome = "Teste2", custo = 1, dif = 10 }
  local r2 = magia.conjurar(mago2, feitico2, rng_de_faces({1}), 10)
  ok(r2.dif == 10 - 10 * 2, "dif efetiva pode ficar bem negativa (10 - 20 = -10)")
  ok(r2.conjurou == true, "dif efetiva negativa garante sucesso mesmo com dado vacilando")
end

titulo("conceitos: mago aprende 1 a cada 2 níveis, gasta o crédito ao escolher")
do
  local mago = ficha.nova({}, "mago")
  ok(mago:tem_conceito_pendente() == false, "mago nível 1 não tem crédito ainda")
  ok(mago:conhece_conceito("atrito") == false, "nasce sem conceito nenhum")

  -- Sobe pro nível 2 (múltiplo de 2 -> ganha 1 crédito).
  mago:ganhar_exp(100)
  mago:subir_nivel("inteligencia", "vontade")
  ok(mago.nivel == 2, "subiu pro nível 2")
  ok(mago:tem_conceito_pendente() == true, "nível 2 concede 1 crédito de conceito")

  ok(mago:aprender_conceito("atrito") == true, "aprende gastando o crédito")
  ok(mago:conhece_conceito("atrito") == true, "agora conhece o conceito")
  ok(mago:tem_conceito_pendente() == false, "crédito consumido")
  ok(select(1, mago:aprender_conceito("fogo")) == false, "sem crédito, não aprende outro")
  ok(select(1, mago:aprender_conceito("atrito")) == false, "nem com crédito aprenderia repetido")

  -- Nível 3 é ímpar -> NÃO concede crédito; nível 4 (par) -> concede.
  mago:ganhar_exp(1000)
  mago:subir_nivel("forca", "agilidade")  -- nv3
  ok(mago:tem_conceito_pendente() == false, "nível 3 (ímpar) não concede crédito")
  mago:subir_nivel("forca", "agilidade")  -- nv4
  ok(mago:tem_conceito_pendente() == true, "nível 4 (par) concede outro crédito")

  -- Só mago aprende conceitos.
  local humano = ficha.nova({}, "humano")
  ok(select(1, humano:aprender_conceito("atrito")) == false, "humano não aprende conceitos")
end

titulo("fusão: custo é SEMPRE 1; peso+dif somam na dificuldade, com penalidade por conceito extra")
do
  -- Dois conceitos-tijolo de teste (formato de data/conceitos.lua).
  local atrito = { id = "atrito", nome = "Atrito", peso = 2, dif = 3, tags = { "cinetico" } }
  local acelerar = { id = "acelerar", nome = "Acelerar", peso = 3, dif = 4, tags = { "tempo", "cinetico" } }

  -- Fusão de 1 conceito: custo fixo, dif = peso+dif do próprio, sem penalidade.
  local m1 = magia.fundir({ atrito }, "Fricção")
  ok(m1.custo == magia.CUSTO_FUSAO and m1.dif == 2 + 3, "1 conceito: custo sempre fixo, dif=peso+dif, sem penalidade")

  -- Fusão de 2 conceitos: custo continua fixo; dif soma tudo + 1 de penalidade.
  local m2 = magia.fundir({ atrito, acelerar }, "Ignição por Fricção")
  ok(m2.custo == magia.CUSTO_FUSAO, "2 conceitos: custo continua fixo, não escala")
  ok(m2.dif == (2 + 3) + (3 + 4) + 1, "2 conceitos: dif = Σ(peso+dif)(12) + penalidade(1) = 13")
  ok(#m2.conceitos == 2, "registra os 2 conceitos que a compõem")
  ok(#m2.tags == 2, "tags únicas: cinetico, tempo (cinetico não duplica)")

  -- Fundir nada é recusado.
  ok(select(1, magia.fundir({})) == nil, "fundir lista vazia devolve nil")
end

titulo("fusão na ficha: só funde conceitos conhecidos e guarda a magia criada")
do
  local catalogo = {
    atrito = { nome = "Manipular Atrito", peso = 2, dif = 3, tags = { "cinetico" } },
    fogo = { nome = "Invocar Fogo", peso = 4, dif = 5, tags = { "elemental" } },
  }
  local mago = ficha.nova({}, "mago")
  mago.conceitos_pendentes = 2
  mago:aprender_conceito("atrito")
  mago:aprender_conceito("fogo")

  -- Tenta fundir um conceito que NÃO conhece -> recusa.
  ok(select(1, mago:fundir_magia({ "gelo" }, "X", catalogo)) == nil,
     "não funde conceito desconhecido")
  ok(#mago.magias_fundidas == 0, "nada foi guardado na recusa")

  -- Funde dois conhecidos -> guarda a magia.
  local nova = mago:fundir_magia({ "atrito", "fogo" }, "Chama Cinética", catalogo)
  ok(nova ~= nil, "funde conceitos conhecidos")
  ok(nova.nome == "Chama Cinética", "guarda o nome que o jogador deu")
  ok(nova.custo == magia.CUSTO_FUSAO, "custo sempre fixo, não importa o catálogo")
  ok(nova.dif == (2 + 3) + (4 + 5) + 1, "dif derivada do catálogo (Σpeso+dif dos 2 + penalidade 1 = 14)")
  ok(#mago.magias_fundidas == 1, "a magia criada foi guardada na ficha")

  -- A magia fundida é conjurável pelo motor existente (mesmo formato).
  mago:recarregar_sonhos(100)  -- Sonhos altos pra pagar o custo e passar
  local r = magia.conjurar(mago, nova, rng_de_faces({3}))
  ok(r.conjurou == true, "magia fundida entra em magia.conjurar como qualquer feitiço")

  -- Humano não funde.
  ok(select(1, ficha.nova({}, "humano"):fundir_magia({ "atrito" }, "X", catalogo)) == nil,
     "humano não funde magias")
end

titulo("Fúria: risco de Frenesi sobe com o gasto, desce com a Fúria restante")
do
  local lobo = ficha.nova({}, "lobisomem")  -- Fúria 5
  ok(lobo:risco_frenesi(1) < lobo:risco_frenesi(4), "gastar mais de uma vez deve arriscar mais")
  ok(lobo:risco_frenesi(5) == 1, "gastar TUDO de uma vez deve ser 100% de risco")
  local lobo_forte = ficha.nova({}, "lobisomem")
  lobo_forte:recarregar_furia(5)  -- Fúria 10 (teto)
  ok(lobo_forte:risco_frenesi(2) < lobo:risco_frenesi(2),
    "com mais Fúria total, o mesmo gasto deve arriscar menos")
end

titulo("ficha: valores padrão e atributos")
do
  local p = ficha.nova({ forca = 3 })  -- lobisomem começa Força 3
  ok(p:attr("forca") == 3, "força definida deve ser 3")
  ok(p:attr("carisma") == 2, "atributo não informado deve assumir 2 (humano comum)")
  ok(p:pericia("intimidacao") == 0, "perícia nunca usada deve ser 0")
end

titulo("Perícia: sobe por uso, com grind próprio por perícia (data/pericias.lua)")
do
  local p = ficha.nova({}, "humano")
  -- intimidacao tem grind=2 no catálogo (data/pericias.lua).
  ok(p:usar_pericia("intimidacao") == false, "1º uso não sobe ainda (grind 2)")
  ok(p:pericia("intimidacao") == 0, "nível continua 0 no meio do grind")
  ok(p:usar_pericia("intimidacao") == true, "2º uso bate o grind -> sobe")
  ok(p:pericia("intimidacao") == 1, "nível sobe pra 1")
  ok(p:usar_pericia("intimidacao") == false, "contador zerou, precisa de outro ciclo completo")
  ok(p:usar_pericia("intimidacao") == true, "mais 1 uso completa o 2º ciclo")
  ok(p:pericia("intimidacao") == 2, "nível sobe pra 2")

  -- Perícia fora do catálogo usa o padrão (ficha.PERICIA_USOS_PADRAO = 5).
  local q = ficha.nova({}, "humano")
  for i = 1, ficha.PERICIA_USOS_PADRAO - 1 do
    q:usar_pericia("furtividade")
  end
  ok(q:pericia("furtividade") == 0, "ainda não bateu o padrão")
  q:usar_pericia("furtividade")
  ok(q:pericia("furtividade") == 1, "bateu o padrão (5 usos) -> sobe 1")

  ok(ficha.nova({}, "humano"):usar_pericia(nil) == false, "usar_pericia(nil) não quebra, só recusa")
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

titulo("combate: todo ataque exercita a perícia da arma (mesmo num erro)")
do
  local armas = require("data.armas")
  local atk = ficha.nova({ agilidade = 0 }, "humano")
  ok(atk:pericia("esgrima") == 0, "começa sem nível em esgrima")
  -- esgrima tem grind=12 (data/pericias.lua) — 1 ataque não sobe ainda.
  combate.atacar(atk, ficha.nova({}, "humano"), armas.adaga, rng_de_faces({1}))  -- ERRO garantido
  ok(atk:pericia("esgrima") == 0, "1 uso não bate o grind (12), mas já contou")
  ok(atk.pericias_uso.esgrima == 1, "contador de uso registrou mesmo com ataque ERRO")
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

titulo("Fúria: tabela por nível (não é linear) e teto de gasto por ativação")
do
  local lobo = ficha.nova({}, "lobisomem")  -- Fúria 5

  ok(lobo:ativar_furia(1) == true, "nível 1 deve ativar com Fúria de sobra")
  ok(lobo:furia_atual() == 4, "ativar deve gastar exatamente o nível (1)")
  ok(lobo:bonus_dano_furia() == 3, "nível 1 -> +3 dano")
  ok(lobo:bonus_acerto_furia() == -1, "acerto é sempre -1, não escala por nível")
  ok(lobo:bonus_reducao_dano_furia() == 0, "nível 1 não reduz dano tomado")

  local lobo2 = ficha.nova({}, "lobisomem")
  lobo2:ativar_furia(3)
  ok(lobo2:bonus_dano_furia() == 5, "nível 3 -> +5 dano (não é 3x3=9, a tabela não é linear)")
  ok(lobo2:bonus_reducao_dano_furia() == 0, "nível 3 ainda não reduz dano tomado")

  local lobo3 = ficha.nova({}, "lobisomem")
  lobo3:recarregar_furia(5)  -- Fúria 10, pra poder testar níveis 4 e 5
  lobo3:ativar_furia(4)
  ok(lobo3:bonus_dano_furia() == 5, "nível 4 trava no dano do nível 3 (+5), não soma mais")
  ok(lobo3:bonus_reducao_dano_furia() == 3, "nível 4 -> -3 de dano tomado")

  local lobo4 = ficha.nova({}, "lobisomem")
  lobo4:recarregar_furia(5)  -- Fúria 10
  lobo4:ativar_furia(5)
  ok(lobo4:bonus_dano_furia() == 5, "nível 5 também trava em +5 dano")
  ok(lobo4:bonus_reducao_dano_furia() == 5, "nível 5 -> -5 de dano tomado (mais que o 4)")

  local lobo5 = ficha.nova({}, "lobisomem")
  lobo5:recarregar_furia(5)  -- Fúria 10
  ok(lobo5:ativar_furia(6) == false, "não deve ativar acima do teto de gasto (5), mesmo tendo Fúria de sobra")

  local lobo_vazio = ficha.nova({}, "lobisomem")
  lobo_vazio.furia = 0
  ok(lobo_vazio:ativar_furia(1) == false, "não deve ativar sem Fúria suficiente")
end

titulo("Fúria: buff dura 3 turnos e depois desliga sozinho")
do
  local lobo = ficha.nova({}, "lobisomem")
  lobo:ativar_furia(2)
  ok(lobo:furia_buff_ativo() == true, "buff deve começar ativo")
  ok(lobo:bonus_dano_furia() == 4, "nível 2 -> +4 dano enquanto ativo")

  lobo:passar_turno_furia()
  ok(lobo:furia_buff_ativo() == true, "ainda ativo depois de 1 turno (dura 3)")
  lobo:passar_turno_furia()
  ok(lobo:furia_buff_ativo() == true, "ainda ativo depois de 2 turnos")
  lobo:passar_turno_furia()
  ok(lobo:furia_buff_ativo() == false, "desativa sozinho depois do 3º turno")
  ok(lobo:bonus_dano_furia() == 0, "sem bônus depois de desativar")

  -- passar_turno_furia em quem não tem Fúria (ex.: humano) deve ser inofensivo.
  local humano = ficha.nova({}, "humano")
  ok(humano:passar_turno_furia() == 0, "não deve dar erro em quem não tem Fúria")
end

titulo("Frenesi: disparo pelo risco e perda de controle por 2 turnos")
do
  local lobo = ficha.nova({}, "lobisomem")  -- Fúria 5
  -- risco de gastar 1 = 1/5 = 0.2. rng que devolve 0.1 (<0.2) -> DISPARA.
  ok(lobo:rolar_frenesi(1, function() return 0.1 end) == true, "rng 0.1 < risco 0.2 -> frenesi dispara")
  -- rng 0.5 (>0.2) -> NÃO dispara.
  ok(lobo:rolar_frenesi(1, function() return 0.5 end) == false, "rng 0.5 > risco 0.2 -> não dispara")
  -- gastar tudo (5 de 5) = risco 100%: qualquer rng dispara.
  ok(lobo:rolar_frenesi(5, function() return 0.99 end) == true, "gastar tudo -> risco 100%, sempre dispara")

  -- Entrar em Frenesi: perde o controle por 2 turnos.
  ok(not lobo:em_frenesi(), "não está em frenesi ainda")
  lobo:entrar_frenesi()
  ok(lobo:em_frenesi(), "entrou em frenesi")
  ok(lobo:passar_turno_frenesi() == 1, "após 1 turno, resta 1")
  ok(lobo:em_frenesi(), "ainda sem controle no 2º turno")
  lobo:passar_turno_frenesi()
  ok(not lobo:em_frenesi(), "recupera o controle após 2 turnos")

  -- Quem não tem Fúria não entra em frenesi por gasto (risco 0).
  ok(ficha.nova({}, "humano"):rolar_frenesi(1) == false, "humano nunca frenesi por Fúria")
end

titulo("combate: buff de Fúria do ATACANTE afeta dano/acerto; do ALVO reduz dano tomado")
do
  local armas = require("data.armas")
  -- defesa 2 (vitalidade 0), de propósito bem baixa: mesmo com o -1 de acerto
  -- do buff, o ataque continua na faixa TOTAL, senão a comparação de dano
  -- fica inválida (parcial usa outra fórmula).
  local alvo = ficha.nova({ vitalidade = 0 }, "humano")
  local lobo = ficha.nova({ forca = 4 }, "lobisomem")
  local r_vacilo = rng_de_faces({1})  -- dado 1 -> bônus 0

  lobo:ativar_furia(1)  -- +3 dano, -1 acerto
  local r1 = combate.atacar(lobo, alvo, armas.punhos, r_vacilo)
  ok(r1.tipo == "total", "teste pressupõe faixa TOTAL (ajuste os atributos se isso falhar)")
  ok(lobo:furia_buff_ativo() == true, "atacar NÃO consome mais o buff (agora dura por turnos)")

  -- Comparação: um lobo IGUAL mas SEM Fúria (o buff dura por turnos, então não
  -- dá pra reusar o mesmo lobo — ele continuaria buffado).
  local lobo_sem = ficha.nova({ forca = 4 }, "lobisomem")
  local alvo2 = ficha.nova({ vitalidade = 0 }, "humano")
  local r2 = combate.atacar(lobo_sem, alvo2, armas.punhos, r_vacilo)
  -- +3 direto no dano, mas o -1 de acerto também reduz a MARGEM em 1 — o
  -- efeito líquido é +2, não +3 (comportamento correto da fórmula).
  ok(r1.dano == r2.dano + 2,
     "efeito líquido do buff no atacante deve ser +2 (dano +3, margem -1)")

  -- Agora o buff no ALVO (defesa): nível 4 reduz -3 do dano tomado.
  local tanque = ficha.nova({ vitalidade = 0 }, "lobisomem")
  tanque:recarregar_furia(5)  -- Fúria 10
  tanque:ativar_furia(4)
  local atacante_fraco = ficha.nova({ forca = 4 }, "lobisomem")
  local r_sem_defesa = combate.atacar(atacante_fraco, ficha.nova({ vitalidade = 0 }, "humano"), armas.punhos, r_vacilo)
  local r_com_defesa = combate.atacar(atacante_fraco, tanque, armas.punhos, r_vacilo)
  ok(r_com_defesa.dano == math.max(0, r_sem_defesa.dano - 3),
     "alvo com Fúria nível 4 deve tomar 3 a menos de dano")
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

titulo("PROBABILIDADES — risco de Frenesi (confira a sensação; fórmula PROVISÓRIA)")
print("  (linha = Fúria atual, coluna = quanto está sendo gasto agora)")
io.write("          ")
for gasto = 1, 5 do io.write(string.format("gasta%d ", gasto)) end
io.write("\n")
for furia = 2, 10, 2 do
  io.write(string.format("  fúria%2d ", furia))
  for gasto = 1, 5 do
    local lobo = ficha.nova({}, "lobisomem")
    lobo:recarregar_furia(furia - ficha.FURIA_INICIAL)
    if gasto > furia then
      io.write("   -  ")
    else
      io.write(string.format("%4.0f%% ", lobo:risco_frenesi(gasto) * 100))
    end
  end
  io.write("\n")
end

titulo("PROBABILIDADES — Sagrado (confira a sensação; DANO_POR_NIVEL PROVISÓRIO)")
print("  Atacante com Vontade 5 (base = nível + floor(5/2) = nível + 2).")
print("  (linha = nível de Sagrado, coluna = defesa mental do alvo)")
io.write("        ")
for dif = 3, 12, 3 do io.write(string.format("  dif%-2d      ", dif)) end
io.write("\n")
for nivel = 1, 5 do
  io.write(string.format("  nv%d  ", nivel))
  local base = nivel + math.floor(5 / 2)
  for dif = 3, 12, 3 do
    local acertos, dano_min, dano_max = 0, nil, nil
    for _, bonus in ipairs({ 0, 1, 2 }) do
      local total = base + bonus
      if total >= dif then
        acertos = acertos + 1
        local dano = nivel * sagrado.DANO_POR_NIVEL + (total - dif)
        dano_min = dano_min and math.min(dano_min, dano) or dano
        dano_max = dano_max and math.max(dano_max, dano) or dano
      end
    end
    local chance = acertos / 3 * 100
    if acertos == 0 then
      io.write(string.format("%3.0f%% (0)   ", chance))
    else
      io.write(string.format("%3.0f%% (%d-%d) ", chance, dano_min, dano_max))
    end
  end
  io.write("\n")
end
print("\n  Referência: HP típico gira entre ~10 (humano/vampiro/mago base) e")
print("  ~35 (lobisomem nível alto com Vitalidade alta).")

-- ---------------------------------------------------------------------------
print(string.format("\nRESULTADO: %d passaram, %d falharam.", passou, falhou))
os.exit(falhou == 0 and 0 or 1)
