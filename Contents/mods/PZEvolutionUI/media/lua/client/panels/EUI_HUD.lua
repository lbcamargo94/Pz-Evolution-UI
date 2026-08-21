-- EUI_HUD.lua — HUD principal (vida, fome, cansaço, thirst, humor, bônus)

EUI = EUI or {}

EUI_HUD = ISPanel:derive("EUI_HUD")

local T = EUI.Theme
local U = EUI.Utils

local HUD_W    = 200
local HUD_PAD  = 8
local BAR_H    = 6
local ROW_H    = 18
local ICON_W   = 16

-- Stats exibidos no HUD com suas respectivas cores e fontes de dado
local STATS = {
    { key="health",    label="Vida",      icon="❤",  color=T.Red,    get=function(p) return p:getBodyDamage():getOverallBodyHealth() / 100 end },
    { key="hunger",    label="Fome",      icon="🍗",  color=T.Yellow, get=function(p) return 1 - (p:getStats():getHunger() or 0)           end },
    { key="thirst",    label="Sede",      icon="💧",  color=T.Blue,   get=function(p) return 1 - (p:getStats():getThirst() or 0)           end },
    { key="fatigue",   label="Cansaço",   icon="😴",  color=T.TextDim,get=function(p) return 1 - (p:getStats():getFatigue() or 0)          end },
    { key="stress",    label="Estresse",  icon="😰",  color=T.Yellow, get=function(p) return 1 - (p:getStats():getStress() or 0)           end },
    { key="boredom",   label="Tédio",     icon="😐",  color=T.TextOff,get=function(p) return 1 - (p:getStats():getBoredom() or 0)          end },
    { key="morale",    label="Humor",     icon="🙂",  color=T.Green,  get=function(p)
        local ok, v = pcall(function() return p:getStats():getMorale() end)
        return ok and v or 0.5
    end },
}

function EUI_HUD:new(playerNum)
    local rows = #STATS
    local h    = HUD_PAD * 2 + rows * (ROW_H + 4) - 4
    local o    = ISPanel.new(self, HUD_PAD, getCore():getScreenHeight() - h - 60, HUD_W, h)
    o.playerNum = playerNum or 0
    o.moveWithMouse = false
    return o
end

function EUI_HUD:initialise()
    ISPanel.initialise(self)
end

function EUI_HUD:prerender()
    local bg = T.BG
    self:drawRect(0, 0, self.width, self.height, bg.a * 0.92, bg.r, bg.g, bg.b)
    local brd = T.Border
    self:drawRectBorder(0, 0, self.width, self.height, brd.a, brd.r, brd.g, brd.b)
end

function EUI_HUD:render()
    local player = getSpecificPlayer(self.playerNum)
    if not player or player:isDead() then return end

    local font = T.FontSm
    local fh   = getTextManager():getFontHeight(font)
    local y    = HUD_PAD

    for _, stat in ipairs(STATS) do
        local ok, pct = pcall(stat.get, player)
        if not ok then pct = 0 end
        pct = U.clamp(pct, 0, 1)

        -- Ícone + label
        local col = (pct < 0.25) and T.Red or stat.color
        self:drawText(stat.icon .. " " .. stat.label, HUD_PAD, y + math.floor((ROW_H - fh) / 2), col.r, col.g, col.b, col.a, font)

        -- Porcentagem à direita
        local pctStr = math.floor(pct * 100) .. "%"
        local pw     = getTextManager():MeasureStringX(font, pctStr)
        local dimC   = T.TextDim
        self:drawText(pctStr, self.width - pw - HUD_PAD, y + math.floor((ROW_H - fh) / 2), dimC.r, dimC.g, dimC.b, dimC.a, font)

        -- Barra
        local barY  = y + ROW_H - BAR_H - 1
        local barW  = self.width - HUD_PAD * 2
        local bgCol = T.BG3
        U.drawBar(self, HUD_PAD, barY, barW, BAR_H, pct, col, bgCol)

        y = y + ROW_H + 4
    end
end

-- ── Registro ──────────────────────────────────────────────────────────────────

Events.OnGameStart.Add(function()
    local hud = EUI_HUD:new(0)
    hud:initialise()
    hud:instantiate()
    hud:addToUIManager()
    EUI._hud = hud
end)
