-- EUI_Logger.lua — sistema de log centralizado do PZ Evolution UI
--
-- Uso:
--   EUI.log.info("painel aberto", "HUD")    → [EUI] [INFO] [HUD] painel aberto
--   EUI.log.error("falha ao ler stats")     → [EUI] [ERROR] falha ao ler stats
--   EUI.log.setLevel("DEBUG")               → habilita mensagens de debug
--   EUI.log.setLevel("INFO")                → silencia debug (padrão)

EUI = EUI or {}

local PREFIX = "[EUI]"

local LEVELS = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }
local NAMES  = { [1] = "ERROR", [2] = "WARN", [3] = "INFO", [4] = "DEBUG" }

local currentLevel = LEVELS.INFO  -- producao: sem spam de debug

local function write(levelNum, ctx, msg)
    if levelNum > currentLevel then return end
    local tag = NAMES[levelNum] or "?"
    if ctx then
        print(string.format("%s [%s] [%s] %s", PREFIX, tag, ctx, tostring(msg)))
    else
        print(string.format("%s [%s] %s", PREFIX, tag, tostring(msg)))
    end
end

EUI.log = {
    -- Muda o nivel minimo: "ERROR" | "WARN" | "INFO" | "DEBUG"
    setLevel = function(name)
        currentLevel = LEVELS[name] or LEVELS.INFO
        print(string.format("%s [INFO] nivel de log: %s", PREFIX, name))
    end,

    error = function(msg, ctx) write(LEVELS.ERROR, ctx, msg) end,
    warn  = function(msg, ctx) write(LEVELS.WARN,  ctx, msg) end,
    info  = function(msg, ctx) write(LEVELS.INFO,  ctx, msg) end,
    debug = function(msg, ctx) write(LEVELS.DEBUG, ctx, msg) end,
}
