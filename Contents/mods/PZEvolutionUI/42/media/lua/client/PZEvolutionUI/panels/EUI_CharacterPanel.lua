-- EUI_CharacterPanel.lua — painel de personagem (stats, habilidades, traços)

EUI = EUI or {}

EUI_CharacterPanel = EUI_BasePanel:derive("EUI_CharacterPanel")

local T = EUI.Theme
local U = EUI.Utils

local PANEL_W = 460
local PANEL_H = 580
local TAB_H   = 30

local TABS = { "Stats", "Habilidades", "Traços", "Conquistas" }

function EUI_CharacterPanel:new(x, y, playerNum)
    local o = EUI_BasePanel.new(self, x, y, PANEL_W, PANEL_H, "Personagem")
    o.playerNum       = playerNum or 0
    o.showCloseButton = true
    o._activeTab      = 1
    return o
end

function EUI_CharacterPanel:initialise()
    EUI_BasePanel.initialise(self)
    self:buildTabs()
end

function EUI_CharacterPanel:buildTabs()
    local tabW = math.floor(self:contentW() / #TABS)
    local ty   = self:contentY()

    self._tabBtns = {}
    for i, name in ipairs(TABS) do
        local tx  = self:contentX() + (i - 1) * tabW
        local btn = EUI_BaseButton:new(tx, ty, tabW - 2, TAB_H, name, self, function() self:setTab(i) end, "ghost")
        btn:initialise()
        btn:instantiate()
        self:addChild(btn)
        self._tabBtns[i] = btn
    end
end

function EUI_CharacterPanel:setTab(idx)
    self._activeTab = idx
end

function EUI_CharacterPanel:render()
    EUI_BasePanel.render(self)
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end

    local tab = self._activeTab

    if tab == 1 then     self:renderStats(player)
    elseif tab == 2 then self:renderSkills(player)
    elseif tab == 3 then self:renderTraits(player)
    elseif tab == 4 then self:renderAchievements(player)
    end

    -- Linha separadora abaixo das abas
    local ly = self:contentY() + TAB_H
    U.drawDivider(self, self:contentX(), ly, self:contentW())

    -- Indicador de aba ativa
    local tabW  = math.floor(self:contentW() / #TABS)
    local tabX  = self:contentX() + (self._activeTab - 1) * tabW
    local green = T.Green
    self:drawRect(tabX, ly - 2, tabW - 2, 2, green.a, green.r, green.g, green.b)
end

-- ── Tab: Stats ────────────────────────────────────────────────────────────────

local STATS_DISPLAY = {
    { label="Saúde",       get=function(p) return p:getBodyDamage():getOverallBodyHealth() / 100 end,    color=nil },
    { label="Fome",        get=function(p) return 1-(p:getStats():getHunger() or 0)          end,    color=nil },
    { label="Sede",        get=function(p) return 1-(p:getStats():getThirst() or 0)          end,    color=nil },
    { label="Fadiga",      get=function(p) return 1-(p:getStats():getFatigue() or 0)         end,    color=nil },
    { label="Pânico",      get=function(p) return p:getStats():getPanic() or 0               end,    color=nil, invert=true },
    { label="Estresse",    get=function(p) return p:getStats():getStress() or 0              end,    color=nil, invert=true },
    { label="Tédio",       get=function(p) return p:getStats():getBoredom() or 0             end,    color=nil, invert=true },
}

function EUI_CharacterPanel:renderStats(player)
    local cy   = self:contentY() + TAB_H + T.Gap * 2
    local cx   = self:contentX()
    local cw   = self:contentW()
    local font = T.FontSm
    local fh   = getTextManager():getFontHeight(font)
    local barW = cw - 80

    for _, s in ipairs(STATS_DISPLAY) do
        local ok, pct = pcall(s.get, player)
        if not ok then pct = 0 end
        if s.invert then pct = 1 - pct end
        pct = U.clamp(pct, 0, 1)

        local col = pct > 0.5 and T.Green or (pct > 0.25 and T.Yellow or T.Red)
        local tc  = T.TextDim

        -- Label
        self:drawText(s.label, cx, cy, tc.r, tc.g, tc.b, tc.a, font)

        -- Barra
        U.drawBar(self, cx + 80, cy + math.floor((fh - 8) / 2), barW, 8, pct, col)

        -- Valor
        local vs = math.floor(pct * 100) .. "%"
        local vw = getTextManager():MeasureStringX(font, vs)
        self:drawText(vs, cx + cw - vw, cy, col.r, col.g, col.b, col.a, font)

        cy = cy + fh + T.Gap
    end
end

-- ── Tab: Habilidades ──────────────────────────────────────────────────────────

function EUI_CharacterPanel:renderSkills(player)
    local cy   = self:contentY() + TAB_H + T.Gap * 2
    local cx   = self:contentX()
    local cw   = self:contentW()
    local font = T.FontSm
    local fh   = getTextManager():getFontHeight(font)

    local perks = PerkFactory.getPerkList()
    if not perks then return end

    for i = 0, perks:size() - 1 do
        local perk = perks:get(i)
        if perk then
            local lvl    = player:getPerkLevel(perk)
            local maxLvl = 10
            local pct    = lvl / maxLvl
            local name   = perk:getName() or "?"
            local col    = lvl >= 10 and T.Green or (lvl >= 5 and T.Blue or T.TextDim)

            self:drawText(U.truncate(name, 100, font), cx, cy, col.r, col.g, col.b, col.a, font)
            U.drawBar(self, cx + 110, cy + math.floor((fh - 6) / 2), cw - 150, 6, pct, col)

            local lvlStr = tostring(lvl) .. "/10"
            local lw     = getTextManager():MeasureStringX(font, lvlStr)
            local tc     = T.TextDim
            self:drawText(lvlStr, cx + cw - lw, cy, tc.r, tc.g, tc.b, tc.a, font)

            cy = cy + fh + T.Gap
            if cy > self.height - T.Pad * 2 then break end
        end
    end
end

-- ── Tab: Traços ───────────────────────────────────────────────────────────────

function EUI_CharacterPanel:renderTraits(player)
    local cy   = self:contentY() + TAB_H + T.Gap * 2
    local cx   = self:contentX()
    local font = T.FontSm
    local fh   = getTextManager():getFontHeight(font)

    local traits = player:getTraits()
    if not traits then return end

    for i = 0, traits:size() - 1 do
        local traitName = traits:get(i)
        local trait     = TraitFactory.getTrait(traitName)
        if trait then
            local cost    = trait:getCost() or 0
            local isPos   = cost < 0  -- custo negativo = traço positivo
            local col     = isPos and T.TextGreen or T.TextRed
            local tc      = T.TextDim
            local label   = trait:getName() or traitName
            self:drawText(label, cx + 10, cy, col.r, col.g, col.b, col.a, font)
            local pts     = (isPos and "+" or "") .. tostring(math.abs(cost)) .. "p"
            local pw      = getTextManager():MeasureStringX(font, pts)
            self:drawText(pts, cx + self:contentW() - pw, cy, tc.r, tc.g, tc.b, tc.a, font)
            cy = cy + fh + T.Gap
        end
    end
end

-- ── Tab: Conquistas (placeholder) ─────────────────────────────────────────────

function EUI_CharacterPanel:renderAchievements(player)
    local cx   = self:contentX()
    local cy   = self:contentY() + TAB_H + T.Gap * 4
    local font = T.Font
    local tc   = T.TextDim
    self:drawText("Em breve…", cx + math.floor(self:contentW() / 2) - 30, cy, tc.r, tc.g, tc.b, tc.a, font)
end

-- ── Registro ──────────────────────────────────────────────────────────────────

Events.OnKeyPressed.Add(function(key)
    if key == EUI.getKey("Health") then
        if EUI._characterPanel and EUI._characterPanel:isVisible() then
            EUI._characterPanel:setVisible(false)
            return
        end
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local p  = EUI_CharacterPanel:new(math.floor((sw - PANEL_W) / 2), math.floor((sh - PANEL_H) / 2), 0)
        p:initialise()
        p:instantiate()
        p:addToUIManager()
        p:setVisible(true)
        EUI._characterPanel = p
    end
end)
