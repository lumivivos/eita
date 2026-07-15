# ABERRAÇÃO

RPG old-school de dark fantasy — uma "adaptação jogável" de uma web-novel própria.
O jogador é um **random** (não um herói): nasce homem ou monstro e decide quem será.

## Como rodar

Requer **Lua 5.5** (console) e **LÖVE 11.5** (versão visual).

- **Versão console** (laboratório de mecânicas): `jogar.cmd` — ou `cd jogo && lua main.lua`
- **Versão 2D / LÖVE** (produto): `jogar2d.cmd` — ou `love jogo2d` a partir desta pasta
- **Rodar os testes** da lógica: `cd jogo && lua testes.lua`

> No Windows, use os `.cmd` (eles configuram UTF-8 pros acentos aparecerem certos).

## Estrutura

```
lore.md        — o universo (cosmologia, raças, protagonistas, linhagens)
sistemas.md    — as regras / design (fonte da verdade das mecânicas)
campanha/      — o conteúdo jogável (cenas, quests, NPCs, regiões)
jogo/          — versão console
  core/        — a LÓGICA (compartilhada): dado, teste, combate, ficha, níveis...
  data/        — dados (armas, formas, raças, textos...)
  testes.lua   — testes automatizados da lógica
jogo2d/        — versão LÖVE2D (reaproveita jogo/core)
```

A lógica vive em `jogo/core/` e serve às duas versões (console e LÖVE). Toda mecânica
nova nasce e é testada no console; depois a camada visual do LÖVE a utiliza.
