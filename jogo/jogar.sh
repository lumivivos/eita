#!/bin/sh
# Launcher do jogo em Linux/Mac. Terminais desses sistemas já usam UTF-8,
# então só precisamos entrar na pasta certa e chamar o Lua.
#
# Uso:  sh jogar.sh   (ou  chmod +x jogar.sh  &&  ./jogar.sh)
cd "$(dirname "$0")" || exit 1
exec lua main.lua
