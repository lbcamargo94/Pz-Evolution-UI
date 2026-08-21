-- EUI_LogPanel.lua — painel de log in-game do PZ Evolution UI
--
-- Exibe o buffer de EUI.log em tempo real, cor-codificado por nível.
-- Abrir/fechar: EUI.log.togglePanel()  ou tecla F8 (configurável).
--
-- Cores:
--   ERROR → vermelho    WARN → amarelo
--   INFO  → branco      DEBUG → cinza

EUI = EUI or {}

EUI_LogPanel = ISPanel:derive("EUI_LogPanel")

local PANEL_W   = 520
local PANEL_H   = 260
local PAD       = 6
local ROW_H     = 15
local MAX_ROWS  = 14   -- linhas visíveis (sem scroll por ora)

-- Cores por nível (r, g, b, a)
local LEVEL_COLOR = {
    [1] = { r=0.95, g=0.25, b=0.25, a=1 },   -- ERROR  vermelho
    [2] = { r=0.95, g=0.85, b=0.20, a=1 },   -- WARN   amarelo
    [3] = { r=0.90, g=0.90, b=0.90, a=1 },   -- INFO   branco
    [4] = { r=0.55, g=0.55, b=0.55, a=1 },   -- DEBUG  cinza
}
local DEFAULT_COLOR = { r=0.80, g=0.80, b=0.80, a=1 }

function EUI_LogPanel:new()
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local x  = sw - PANEL_W - 10
    local y  = sh - PANEL_H - 40
    local o  = ISPanel.new(self, x, y, PANEL_W, PANEL_H)
    o.moveWithMouse  = true
    o._lastCount     = 0
    return o
end

function EUI_LogPanel:initialise()
    ISPanel.initialise(self)
end

function EUI_LogPanel:prerender()
    -- fundo semitransparente
    self:drawRect(0, 0, self.width, self.height, 0.82, 0.06, 0.06, 0.08)
    -- borda
    self:drawRectBorder(0, 0, self.width, self.height, 1, 0.20, 0.55, 0.20)
    -- título
    local font = UIFont.Small
    self:drawText("[EUI] Log  (arraste para mover)", PAD, PAD, 0.20, 0.85, 0.20, 1, font)
    self:drawRect(0, ROW_H + PAD + 2, self.width, 1, 0.6, 0.20, 0.55, 0.20)
end

function EUI_LogPanel:render()
    local buf  = EUI.log._buffer
    local font = UIFont.Small
    local fh   = getTextManager():getFontHeight(font)
    local startY = ROW_H + PAD + 6

    -- mostra as últimas MAX_ROWS entradas
    local total = #buf
    local from  = math.max(1, total - MAX_ROWS + 1)

    for i = from, total do
        local entry = buf[i]
        if entry then
            local c = LEVEL_COLOR[entry.level] or DEFAULT_COLOR
            local row = (i - from)
            self:drawText(entry.text, PAD, startY + row * (fh + 2), c.r, c.g, c.b, c.a, font)
        end
    end
end

function EUI_LogPanel:toggleVisible()
    if self:isVisible() then
        self:setVisible(false)
    else
        self:setVisible(true)
        self:bringToTop()
    end
end

-- ── Registro ──────────────────────────────────────────────────────────────────

Events.OnGameStart.Add(function()
    local panel = EUI_LogPanel:new()
    panel:initialise()
    panel:instantiate()
    panel:addToUIManager()
    panel:setVisible(false)   -- oculto por padrão
    EUI._logPanel = panel
    EUI.log.info("EUI_LogPanel pronto — use EUI.log.togglePanel() para abrir", "LogPanel")
end)

-- Tecla F8 abre/fecha o painel (sem conflito com atalhos padrão do PZ)
Events.OnKeyPressed.Add(function(key)
    if key == Keyboard.KEY_F8 then
        EUI.log.togglePanel()
    end
end)
