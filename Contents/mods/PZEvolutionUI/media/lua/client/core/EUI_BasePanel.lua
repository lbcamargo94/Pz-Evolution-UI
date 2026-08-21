-- EUI_BasePanel.lua — painel base estilizado que todos os painéis EUI estendem

EUI = EUI or {}

EUI_BasePanel = ISPanel:derive("EUI_BasePanel")

local T = EUI.Theme
local U = EUI.Utils

-- ── Constructor ────────────────────────────────────────────────────────────────

function EUI_BasePanel:new(x, y, w, h, title)
    local o = ISPanel.new(self, x, y, w, h)
    o.title        = title or ""
    o.draggable    = true
    o.resizable    = false
    o._dragOffX    = 0
    o._dragOffY    = 0
    o._dragging    = false
    o._closeBtn    = nil
    o.euiStyle     = true
    return o
end

function EUI_BasePanel:initialise()
    ISPanel.initialise(self)
    self:buildCloseButton()
end

-- ── Botão de fechar ────────────────────────────────────────────────────────────

function EUI_BasePanel:buildCloseButton()
    if not self.showCloseButton then return end
    local bw = 18
    local bh = 18
    local btn = ISButton:new(self.width - bw - T.PadSm, math.floor((T.TitleH - bh) / 2), bw, bh, "×", self, EUI_BasePanel.onClose)
    btn:initialise()
    btn:instantiate()
    btn.backgroundColor       = { r=0, g=0, b=0, a=0 }
    btn.backgroundColorMouseOver = T.BG_Hover
    btn.borderColor           = { r=0, g=0, b=0, a=0 }
    btn.textColor             = T.TextDim
    self:addChild(btn)
    self._closeBtn = btn
end

function EUI_BasePanel:onClose()
    self:setVisible(false)
    if self.onCloseCallback then self:onCloseCallback() end
end

-- ── Render ────────────────────────────────────────────────────────────────────

function EUI_BasePanel:prerender()
    -- Fundo principal
    local bg = T.BG
    self:drawRect(0, 0, self.width, self.height, bg.a, bg.r, bg.g, bg.b)

    -- Borda externa
    local brd = T.Border
    self:drawRectBorder(0, 0, self.width, self.height, brd.a, brd.r, brd.g, brd.b)

    -- Barra de título
    if self.title and self.title ~= "" then
        U.drawTitle(self, 0, 0, self.width, self.title)
    end
end

function EUI_BasePanel:render()
    -- subclasses sobreescrevem
end

-- ── Arrastar ──────────────────────────────────────────────────────────────────

function EUI_BasePanel:onMouseDown(x, y)
    if not self.draggable then return end
    if y <= T.TitleH then
        self._dragging = true
        self._dragOffX = x
        self._dragOffY = y
        self:bringToTop()
    end
end

function EUI_BasePanel:onMouseUp(x, y)
    self._dragging = false
end

function EUI_BasePanel:onMouseMove(dx, dy)
    if self._dragging then
        local nx = self:getX() + dx
        local ny = self:getY() + dy
        -- mantém dentro da tela
        nx = math.max(0, math.min(getCore():getScreenWidth()  - self.width,  nx))
        ny = math.max(0, math.min(getCore():getScreenHeight() - self.height, ny))
        self:setX(nx)
        self:setY(ny)
    end
end

-- ── Helpers para subclasses ────────────────────────────────────────────────────

-- Área útil abaixo do título
function EUI_BasePanel:contentY()    return T.TitleH + T.Pad end
function EUI_BasePanel:contentH()    return self.height - self:contentY() - T.Pad end
function EUI_BasePanel:contentX()    return T.Pad end
function EUI_BasePanel:contentW()    return self.width - T.Pad * 2 end
