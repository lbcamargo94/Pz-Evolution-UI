-- EUI_BaseButton.lua — botão estilizado padrão EUI

EUI = EUI or {}

EUI_BaseButton = ISButton:derive("EUI_BaseButton")

local T = EUI.Theme

-- variant: "primary" | "danger" | "ghost" | "icon"
function EUI_BaseButton:new(x, y, w, h, text, target, onclick, variant)
    local o = ISButton.new(self, x, y, w, h, text, target, onclick)
    o.variant  = variant or "primary"
    o._hovered = false
    o._pressed = false
    return o
end

function EUI_BaseButton:initialise()
    ISButton.initialise(self)
    self:applyStyle()
end

function EUI_BaseButton:applyStyle()
    local v = self.variant
    -- Desativa o render padrão do ISButton (vamos fazer o nosso)
    self.backgroundColor          = { r=0, g=0, b=0, a=0 }
    self.backgroundColorMouseOver = { r=0, g=0, b=0, a=0 }
    self.borderColor              = { r=0, g=0, b=0, a=0 }

    if v == "primary" then
        self._bgColor    = T.Green
        self._bgHover    = T.GreenHover
        self._textColor  = { r=0.05, g=0.05, b=0.05, a=1 }
    elseif v == "danger" then
        self._bgColor    = T.Red
        self._bgHover    = T.RedHover
        self._textColor  = { r=1, g=1, b=1, a=1 }
    elseif v == "ghost" then
        self._bgColor    = T.BG3
        self._bgHover    = T.BG_Hover
        self._textColor  = T.Text
    else -- "icon" ou default
        self._bgColor    = T.BG2
        self._bgHover    = T.BG3
        self._textColor  = T.TextDim
    end
end

function EUI_BaseButton:prerender()
    local bg = self._hovered and self._bgHover or self._bgColor
    if self._pressed then
        bg = { r=bg.r*0.8, g=bg.g*0.8, b=bg.b*0.8, a=bg.a }
    end
    self:drawRect(0, 0, self.width, self.height, bg.a, bg.r, bg.g, bg.b)

    -- borda sutil
    local brd = T.Border
    self:drawRectBorder(0, 0, self.width, self.height, brd.a, brd.r, brd.g, brd.b)

    -- texto centralizado
    local tc   = self._textColor
    local font = T.Font
    local tw   = getTextManager():MeasureStringX(font, self.title)
    local fh   = getTextManager():getFontHeight(font)
    local tx   = math.floor((self.width  - tw) / 2)
    local ty   = math.floor((self.height - fh) / 2)
    self:drawText(self.title, tx, ty, tc.r, tc.g, tc.b, tc.a, font)
end

function EUI_BaseButton:render() end

function EUI_BaseButton:onMouseMove(dx, dy)
    self._hovered = true
end
function EUI_BaseButton:onMouseMoveOutside(dx, dy)
    self._hovered = false
    self._pressed = false
end
function EUI_BaseButton:onMouseDown(x, y)
    self._pressed = true
end
function EUI_BaseButton:onMouseUp(x, y)
    self._pressed = false
    ISButton.onMouseUp(self, x, y)
end
