-- util/console.lua
-- Utilitários de entrada/saída no terminal.
-- Mantido separado do resto pra que trocar a "camada de tela" no futuro
-- (cores, uma UI mais rica, etc.) não mexa na lógica do jogo.

local console = {}

-- true quando estamos no Windows (separador de caminho é "\").
local eh_windows = package.config:sub(1, 1) == "\\"

-- Prepara o terminal pra exibir acentos corretamente.
--
-- Os arquivos do jogo estão em UTF-8. No Windows o console costuma vir numa
-- code page antiga (850/1252) que mostra "ç" e "ã" como lixo. O jeito
-- confiável de corrigir isso é rodar `chcp 65001` ANTES do Lua iniciar —
-- por isso o jogo é iniciado pelo launcher (jogar.cmd), que já faz isso.
--
-- Esta função é uma tentativa "best-effort" adicional; se o jogo foi aberto
-- pelo launcher, o console já está em UTF-8 e ela não faz diferença.
function console.preparar()
  if eh_windows then
    local _ = os.execute("chcp 65001 >nul 2>nul")
  end
end

-- Limpa a tela (funciona no Windows e em terminais POSIX).
function console.limpar()
  local _ = os.execute(eh_windows and "cls" or "clear")
end

-- Imprime uma linha.
function console.linha(texto)
  print(texto or "")
end

-- Imprime texto e espera o jogador apertar Enter.
function console.pausar(texto)
  io.write(texto or "\n(pressione Enter para continuar)")
  local _ = io.read("l")
end

-- Mostra um menu numerado e devolve o índice escolhido (1..#opcoes).
-- opcoes: lista de strings.
-- Repete até o jogador digitar algo válido — nada de crashar por input ruim.
-- `recuo` (opcional) = string de indentação aplicada a cada opção e ao prompt.
-- Padrão "  " (2 espaços), pra não mudar chamadas antigas.
function console.menu(opcoes, recuo)
  recuo = recuo or "  "
  for i, texto in ipairs(opcoes) do
    console.linha(string.format("%s%d) %s", recuo, i, texto))
  end
  while true do
    io.write("\n" .. recuo .. "> ")
    local entrada = io.read("l")
    if entrada == nil then           -- EOF (Ctrl+D / pipe fechado): sai limpo
      os.exit(0)
    end
    local n = tonumber(entrada)
    if n and n >= 1 and n <= #opcoes and n == math.floor(n) then
      return n
    end
    console.linha("Escolha inválida. Digite o número de uma das opções.")
  end
end

return console
