@echo off
REM Launcher do jogo no Windows.
REM Seta o console pra UTF-8 (65001) ANTES de iniciar o Lua, para que os
REM acentos (ç, ã, é) e o travessão (—) apareçam corretos no terminal.
REM
REM Uso: dê um duplo-clique neste arquivo, ou rode no terminal:
REM     .\jogar.cmd
chcp 65001 >nul
lua "%~dp0main.lua"
