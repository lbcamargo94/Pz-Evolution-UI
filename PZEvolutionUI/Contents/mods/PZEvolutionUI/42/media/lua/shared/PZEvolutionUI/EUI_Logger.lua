-- EUI_Logger.lua — sistema de log centralizado do PZ Evolution UI
--
-- Uso:
--   EUI.log.info("painel aberto", "HUD")    → [EUI] [INFO] [HUD] painel aberto
--   EUI.log.error("falha ao ler stats")     → [EUI] [ERROR] falha ao ler stats
--   EUI.log.setLevel("DEBUG")               → habilita mensagens de debug
--   EUI.log.setLevel("INFO")                → silencia debug (padrão)
--   EUI.log.togglePanel()                   → abre/fecha o painel in-game

EUI = EUI or {}

local PREFIX     = "[EUI]"
local BUFFER_MAX = 80   -- máximo de entradas no buffer circular

local LEVELS = { ERROR = 1, WARN = 2, INFO = 3, DEBUG = 4 }
local NAMES  = { [1] = "ERROR", [2] = "WARN", [3] = "INFO", [4] = "DEBUG" }

local currentLevel = LEVELS.INFO

-- Buffer circular acessado pelo EUI_LogPanel (client/)
local _buffer = {}   -- { text, levelNum, time }

local function push(levelNum, line)
    if #_buffer >= BUFFER_MAX then table.remove(_buffer, 1) end
    table.insert(_buffer, { text = line, level = levelNum, time = getTimestamp and getTimestamp() or 0 })
end

local function write(levelNum, ctx, msg)
    if levelNum > currentLevel then return end
    local tag  = NAMES[levelNum] or "?"
    local line
    if ctx then
        line = string.format("%s [%s] [%s] %s", PREFIX, tag, ctx, tostring(msg))
    else
        line = string.format("%s [%s] %s", PREFIX, tag, tostring(msg))
    end
    -- console.txt
    print(line)
    -- in-game debug console (disponível em modo debug do PZ)
    if DebugLog and DebugLog.log and DebugType then
        pcall(function() DebugLog.log(DebugType.Lua, line) end)
    end
    -- buffer para o painel visual
    push(levelNum, line)
end

EUI.log = {
    -- Muda o nivel minimo: "ERROR" | "WARN" | "INFO" | "DEBUG"
    setLevel = function(name)
        currentLevel = LEVELS[name] or LEVELS.INFO
        print(string.format("%s [INFO] nivel de log: %s", PREFIX, name))
    end,

    -- Expõe o buffer para o EUI_LogPanel (leitura)
    _buffer = _buffer,
    _levels = LEVELS,

    -- Abre/fecha o painel in-game (implementado em EUI_LogPanel.lua)
    togglePanel = function()
        if EUI._logPanel then EUI._logPanel:toggleVisible() end
    end,

    error = function(msg, ctx) write(LEVELS.ERROR, ctx, msg) end,
    warn  = function(msg, ctx) write(LEVELS.WARN,  ctx, msg) end,
    info  = function(msg, ctx) write(LEVELS.INFO,  ctx, msg) end,
    debug = function(msg, ctx) write(LEVELS.DEBUG, ctx, msg) end,
}
