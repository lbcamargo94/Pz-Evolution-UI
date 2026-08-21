-- EUI_ChickenPanel.lua — painel de galinheiro (B42)

EUI = EUI or {}

EUI_ChickenPanel = EUI_BasePanel:derive("EUI_ChickenPanel")

local T = EUI.Theme
local U = EUI.Utils

local PANEL_W  = 460
local PANEL_H  = 480
local ROW_H    = 38
local BAR_H    = 7

-- ── Constructor ───────────────────────────────────────────────────────────────

function EUI_ChickenPanel:new(x, y, playerNum)
    local o = EUI_BasePanel.new(self, x, y, PANEL_W, PANEL_H, "Galinheiro")
    o.playerNum       = playerNum or 0
    o.showCloseButton = true
    o._chickens       = {}
    o._eggs           = 0
    o._selChicken     = nil
    o._scroll         = 0
    o._maxScroll      = 0
    o._timer          = 0
    return o
end

function EUI_ChickenPanel:initialise()
    EUI_BasePanel.initialise(self)
    self:buildButtons()
    self:scanChickens()
end

function EUI_ChickenPanel:buildButtons()
    local half = math.floor((self:contentW() - T.Gap) / 2)
    local bh   = T.BtnH
    local cx   = self:contentX()
    local by   = self.height - T.Pad * 2 - bh

    self._btnCollect = EUI_BaseButton:new(cx, by, half, bh, "Coletar Ovos", self,
        EUI_ChickenPanel.onCollectEggs, "primary")
    self._btnCollect:initialise(); self._btnCollect:instantiate(); self:addChild(self._btnCollect)

    self._btnFeed = EUI_BaseButton:new(cx + half + T.Gap, by, half, bh, "Alimentar", self,
        EUI_ChickenPanel.onFeedAll, "ghost")
    self._btnFeed:initialise(); self._btnFeed:instantiate(); self:addChild(self._btnFeed)
end

-- ── Dados ─────────────────────────────────────────────────────────────────────

function EUI_ChickenPanel:scanChickens()
    self._chickens = {}
    self._eggs     = 0
    local player   = getSpecificPlayer(self.playerNum)
    if not player then return end
    local sq = player:getSquare()
    if not sq then return end

    local radius = (EUI.Settings and EUI.Settings.chickenRadius) or 16
    for dx = -radius, radius do
        for dy = -radius, radius do
            local s = getCell():getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
            if s then
                local objs = s:getObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if obj then
                            local isChicken = false
                            pcall(function()
                                local t = obj:getAnimalType and obj:getAnimalType() or ""
                                isChicken = t:find("Chicken") ~= nil or t:find("Hen") ~= nil
                            end)
                            if isChicken then
                                local name   = "Galinha"; local hp = 100; local hpMax = 100
                                local hunger = 0; local stress = 0; local eggReady = false
                                pcall(function() name     = obj:getName()        or "Galinha" end)
                                pcall(function() hp       = obj:getHealth()      or 100       end)
                                pcall(function() hpMax    = obj:getMaxHealth()   or 100       end)
                                pcall(function() hunger   = obj:getHunger()      or 0         end)
                                pcall(function() stress   = obj:getStress()      or 0         end)
                                pcall(function() eggReady = obj:hasEgg and obj:hasEgg()       end)
                                if eggReady then self._eggs = self._eggs + 1 end
                                table.insert(self._chickens, {
                                    obj      = obj,
                                    name     = name,
                                    hp       = hp,
                                    hpMax    = hpMax,
                                    hunger   = hunger,
                                    stress   = stress,
                                    eggReady = eggReady,
                                    hpPct    = hpMax > 0 and U.clamp(hp / hpMax, 0, 1) or 1,
                                })
                            end
                        end
                    end
                end
            end
        end
    end

    local listH = self:contentH() - 80 - T.Gap
    self._maxScroll = math.max(0, #self._chickens * (ROW_H + T.PadSm) - listH)
end

function EUI_ChickenPanel:update()
    EUI_BasePanel.update(self)
    self._timer = (self._timer or 0) + 1
    if self._timer >= 120 then self._timer = 0; self:scanChickens() end
end

-- ── Ações ─────────────────────────────────────────────────────────────────────

function EUI_ChickenPanel:onCollectEggs()
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    for _, c in ipairs(self._chickens) do
        if c.eggReady then
            pcall(function()
                if ISCollectEggAction then
                    ISTimedActionQueue.add(ISCollectEggAction:new(player, c.obj))
                end
            end)
        end
    end
end

function EUI_ChickenPanel:onFeedAll()
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    local food = nil
    pcall(function() food = player:getInventory():getFirstTypeRecurse("Base.Corn") end)
    if not food then
        pcall(function() food = player:getInventory():getFirstTypeRecurse("Base.Berries") end)
    end
    if not food then return end
    for _, c in ipairs(self._chickens) do
        if c.hunger > 0.3 then
            pcall(function()
                if c.obj.feed then c.obj:feed(player, food) end
            end)
        end
    end
end

-- ── Render ────────────────────────────────────────────────────────────────────

function EUI_ChickenPanel:render()
    local cx  = self:contentX()
    local cy  = self:contentY()
    local cw  = self:contentW()
    local sm  = T.FontSm
    local fh  = getTextManager():getFontHeight(sm)
    local dim = T.TextDim
    local hdr = T.TextGreen

    -- Resumo
    local total = #self._chickens
    self:drawText(string.format("🐔 %d galinha(s)  |  🥚 %d ovo(s) prontos", total, self._eggs),
        cx, cy, hdr.r, hdr.g, hdr.b, hdr.a, sm)
    cy = cy + fh + T.Gap

    -- Aviso se nenhuma
    if total == 0 then
        local tc  = T.TextOff
        local msg = "Nenhuma galinha encontrada no raio de 16 tiles"
        local mw  = getTextManager():MeasureStringX(sm, msg)
        self:drawText(msg, cx + math.floor((cw - mw) / 2), cy + 40,
            tc.r, tc.g, tc.b, tc.a, sm)
        return
    end

    U.drawDivider(self, cx, cy, cw); cy = cy + T.Gap + 2

    -- Saúde média do plantel
    local avgHp = 0
    for _, c in ipairs(self._chickens) do avgHp = avgHp + c.hpPct end
    avgHp = total > 0 and avgHp / total or 0
    local hpCol = avgHp > 0.6 and T.Green or (avgHp > 0.3 and T.Yellow or T.Red)
    self:drawText("Saúde média:", cx, cy + math.floor((20 - fh) / 2), dim.r, dim.g, dim.b, dim.a, sm)
    U.drawBar(self, cx + 100, cy + math.floor((20 - BAR_H) / 2), cw - 160, BAR_H, avgHp, hpCol)
    local hpStr = string.format("%d%%", math.floor(avgHp * 100))
    local hpW   = getTextManager():MeasureStringX(sm, hpStr)
    self:drawText(hpStr, cx + cw - hpW, cy + math.floor((20 - fh) / 2),
        hpCol.r, hpCol.g, hpCol.b, hpCol.a, sm)
    cy = cy + 22 + T.Gap

    U.drawDivider(self, cx, cy, cw); cy = cy + T.Gap + 2

    -- Lista individual
    local listH = self.height - cy - T.Pad * 2 - T.BtnH - T.Gap
    self:drawChickenList(cx, cy, cw, listH)
end

function EUI_ChickenPanel:drawChickenList(cx, cy, cw, listH)
    local sm  = T.FontSm
    local fh  = getTextManager():getFontHeight(sm)
    local bg  = T.BG2
    self:drawRect(cx, cy, cw, listH, bg.a, bg.r, bg.g, bg.b)

    local yOff = cy - self._scroll
    for i, c in ipairs(self._chickens) do
        if yOff + ROW_H >= cy and yOff <= cy + listH then
            local sel  = c == self._selChicken
            local rbg  = sel and T.BG_Select or (i % 2 == 0 and T.BG3 or T.BG2)
            self:drawRect(cx, yOff, cw, ROW_H, rbg.a, rbg.r, rbg.g, rbg.b)
            if sel then
                self:drawRect(cx, yOff, 2, ROW_H, T.Green.a, T.Green.r, T.Green.g, T.Green.b)
            end

            local tc   = sel and T.TextGreen or T.Text
            local dim  = T.TextDim
            local egg  = c.eggReady and " 🥚" or ""
            local name = U.truncate(c.name, 130, sm) .. egg
            self:drawText(name, cx + T.PadSm + (sel and 4 or 0),
                yOff + math.floor((ROW_H - fh * 2 - T.PadSm) / 2),
                tc.r, tc.g, tc.b, tc.a, sm)

            -- Sub: fome e stress
            local sub = string.format("Fome %.0f%%  Stress %.0f%%",
                c.hunger * 100, c.stress * 100)
            local sCol = (c.hunger > 0.6 or c.stress > 0.6) and T.TextRed or T.TextDim
            self:drawText(sub, cx + T.PadSm + (sel and 4 or 0),
                yOff + math.floor((ROW_H - fh * 2 - T.PadSm) / 2) + fh + T.PadSm,
                sCol.r, sCol.g, sCol.b, sCol.a, sm)

            -- Mini barra HP
            local hpCol = c.hpPct > 0.6 and T.Green or (c.hpPct > 0.3 and T.Yellow or T.Red)
            U.drawBar(self, cx + 200, yOff + math.floor((ROW_H - BAR_H) / 2),
                cw - 210, BAR_H, c.hpPct, hpCol)
        end
        yOff = yOff + ROW_H + T.PadSm
    end

    -- Scrollbar
    if self._maxScroll > 0 then
        local totalH = #self._chickens * (ROW_H + T.PadSm)
        local ratio  = listH / totalH
        local barH   = math.max(16, math.floor(listH * ratio))
        local barY   = cy + math.floor(self._scroll / self._maxScroll * (listH - barH))
        self:drawRect(cx + cw, cy, T.ScrollW, listH, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
        self:drawRect(cx + cw + 1, barY, T.ScrollW - 2, barH, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    end
end

-- ── Mouse ─────────────────────────────────────────────────────────────────────

function EUI_ChickenPanel:onMouseDown(mx, my)
    EUI_BasePanel.onMouseDown(self, mx, my)
    if my <= T.TitleH then return end
    local cx  = self:contentX(); local cy = self:contentY()
    local sm  = T.FontSm; local fh = getTextManager():getFontHeight(sm)
    local top = cy + fh + T.Gap + 2 + 22 + T.Gap * 3 + 4
    local lH  = self.height - top - T.Pad * 2 - T.BtnH - T.Gap
    if U.inRect(mx, my, cx, top, self:contentW(), lH) then
        local rel = my - top + self._scroll
        local idx = math.floor(rel / (ROW_H + T.PadSm)) + 1
        if self._chickens[idx] then self._selChicken = self._chickens[idx] end
    end
end

function EUI_ChickenPanel:onMouseWheel(del)
    self._scroll = U.clamp(self._scroll - del * ROW_H, 0, self._maxScroll)
    return true
end

-- ── Registro ──────────────────────────────────────────────────────────────────

Events.OnKeyPressed.Add(function(key)
    if key == EUI.getKey("Chicken") then
        if EUI._chickenPanel then
            EUI._chickenPanel:setVisible(not EUI._chickenPanel:isVisible())
            if EUI._chickenPanel:isVisible() then EUI._chickenPanel:scanChickens() end
            return
        end
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local p  = EUI_ChickenPanel:new(
            math.floor((sw - PANEL_W) / 2),
            math.floor((sh - PANEL_H) / 2), 0)
        p:initialise(); p:instantiate(); p:addToUIManager(); p:setVisible(true)
        EUI._chickenPanel = p
    end
end)
