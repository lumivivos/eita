@echo off
REM Launcher da versao console, a partir da raiz de bobagem/ (simetria com
REM jogar2d.cmd). So delega para jogo\jogar.cmd, que faz o trabalho de
REM verdade (chcp UTF-8 + lua main.lua).
REM Uso: duplo-clique neste arquivo, ou rode:  .\jogar.cmd
cd /d "%~dp0jogo"
call jogar.cmd
