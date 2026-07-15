@echo off
REM Launcher da versao 2D (LOVE2D). Abre o jogo numa janela.
REM Uso: duplo-clique neste arquivo, ou rode:  .\jogar2d.cmd
REM (roda a partir da pasta bobagem/, onde ficam jogo2d/ e jogo/)
cd /d "%~dp0"
"C:\Program Files\LOVE\love.exe" jogo2d
