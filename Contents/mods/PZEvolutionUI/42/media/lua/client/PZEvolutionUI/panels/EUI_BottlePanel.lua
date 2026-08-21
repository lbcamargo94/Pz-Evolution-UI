-- EUI_BottlePanel.lua — painel de garrafa plástica / recipientes de água (B42)

EUI = EUI or {}

EUI_BottlePanel = EUI_BasePanel:derive("EUI_BottlePanel")

local T = EUI.Theme
local U = EUI.Utils

local PANEL_W  = 440
local PANEL_H  = 460
local ROW_H    = 42
local BAR_H    = 8

-- Tipos de recipiente suportados
local BOTTLE_TYPES = {
    "Base.WaterBottleFull",
    "Base.WaterBottleEmpty",
    "Base.PlasticBottle",
    "Base.Bottle",
    "Base.Pop",
    "Base.MilkCarton",
    "Base.CanteenFull",
    "Base.Canteen",
    "Base.YogurtEmpty",
    "Base.GardenSprayCan",
}

-- ── Constructor ───────────────────────────────────────────────────────────────

function EUI_BottlePanel:new(x, y, playerNum)
    local o = EUI_BasePanel.new(self, x, y, PANEL_W, PANEL_H, "Recipientes de Água")
    o.playerNum       = playerNum or 0
    o.showCloseButton = true
    o._bottles        = {}
    o._selBottle      = nil
    o._scroll         = 0
    o._maxScroll      = 0
    o._nearbyWater    = false
    o._timer          = 0
    return o
end

function EUI_BottlePanel:initialise()
    EUI_BasePanel.initialise(self)
    self:buildButtons()
    self:scanBottles()
end

function EUI_BottlePanel:buildButtons()
    local third = math.floor((self:contentW() - T.Gap * 2) / 3)
    local bh    = T.BtnH
    local cx    = self:contentX()
    local by    = self.height - T.Pad * 2 - bh

    self._btnFill = EUI_BaseButton:new(cx, by, third, bh, "Encher", self,
        EUI_BottlePanel.onFill, "primary")
    self._btnFill:initialise(); self._btnFill:instantiate(); self:addChild(self._btnFill)

    self._btnEmpty = EUI_BaseButton:new(cx + third + T.Gap, by, third, bh, "Despejar", self,
        EUI_BottlePanel.onEmpty, "danger")
    self._btnEmpty:initialise(); self._btnEmpty:instantiate(); self:addChild(self._btnEmpty)

    self._btnBoil = EUI_BaseButton:new(cx + (third + T.Gap) * 2, by, third, bh, "Ferver", self,
        EUI_BottlePanel.onBoil, "ghost")
    self._btnBoil:initialise(); self._btnBoil:instantiate(); self:addChild(self._btnBoil)
end

-- ── Dados ─────────────────────────────────────────────────────────────────────

function EUI_BottlePanel:scanBottles()
    self._bottles     = {}
    self._nearbyWater = false
    local player      = getSpecificPlayer(self.playerNum)
    if not player then return end

    local inv  = player:getInventory()
    local items = nil
    pcall(function() items = inv:getItems() end)
    if not items then return end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            local isBottle = false
            local itype    = ""
            pcall(function() itype = item:getType() or "" end)
            for _, t in ipairs(BOTTLE_TYPES) do
                if itype == t or ("Base." .. itype) == t then isBottle = true; break end
            end
            -- Também aceita qualquer item com FluidContainer (B42) ou drainable (B41)
            if not isBottle then isBottle = U.isFluidItem(item) end
            if isBottle then
                local name    = "?"; local cur = 0; local cap = 1
                local liq     = "Vazio"; local boiled = false; local tainted = false
                pcall(function() name = item:getName() or "?" end)
                cur     = U.getFluidAmount(item)
                cap     = U.getFluidCapacity(item)
                liq     = U.getFluidName(item)
                boiled  = U.isBoiledWater(item)
                tainted = U.isTaintedWater(item)
                table.insert(self._bottles, {
                    item    = item,
                    name    = name,
                    cur     = cur,
                    cap     = cap,
                    liquid  = liq,
                    boiled  = boiled,
                    tainted = tainted,
                    pct     = cap > 0 and U.clamp(cur / cap, 0, 1) or 0,
                })
            end
        end
    end

    -- Verifica fonte de água próxima (pia, rio, etc.)
    local sq = player:getSquare()
    if sq then
        for dx = -3, 3 do
            for dy = -3, 3 do
                local s = getCell():getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
                if s then
                    local objs = s:getObjects()
                    if objs then
                        for i = 0, objs:size() - 1 do
                            local obj = objs:get(i)
                            if obj then
                                local isWater = false
                                pcall(function()
                                    isWater = obj:hasWater and obj:hasWater()
                                end)
                                if isWater then self._nearbyWater = true end
                            end
                        end
                    end
                end
            end
        end
    end

    local listH = self:contentH() - 70 - T.Gap
    self._maxScroll = math.max(0, #self._bottles * (ROW_H + T.PadSm) - listH)
end

function EUI_BottlePanel:update()
    EUI_BasePanel.update(self)
    self._timer = (self._timer or 0) + 1
    if self._timer >= 90 then self._timer = 0; self:scanBottles() end
end

-- ── Ações ─────────────────────────────────────────────────────────────────────

function EUI_BottlePanel:onFill()
    local b      = self._selBottle
    local player = getSpecificPlayer(self.playerNum)
    if not b or not player then return end
    if not self._nearbyWater then return end
    pcall(function()
        if ISFillWaterAction then
            ISTimedActionQueue.add(ISFillWaterAction:new(player, b.item, player:getSquare()))
        end
    end)
end

function EUI_BottlePanel:onEmpty()
    local b      = self._selBottle
    local player = getSpecificPlayer(self.playerNum)
    if not b or not player then return end
    pcall(function()
        if ISEmptyLiquidAction then
            ISTimedActionQueue.add(ISEmptyLiquidAction:new(player, b.item))
        end
    end)
end

function EUI_BottlePanel:onBoil()
    local b      = self._selBottle
    local player = getSpecificPlayer(self.playerNum)
    if not b or not player then return end
    pcall(function()
        if ISBoilWaterAction then
            ISTimedActionQueue.add(ISBoilWaterAction:new(player, b.item))
        end
    end)
end

-- ── Render ────────────────────────────────────────────────────────────────────

function EUI_BottlePanel:render()
    local cx  = self:contentX()
    local cy  = self:contentY()
    local cw  = self:contentW()
    local sm  = T.FontSm
    local fh  = getTextManager():getFontHeight(sm)
    local dim = T.TextDim

    -- Fonte de água próxima
    local srcCol = self._nearbyWater and T.TextGreen or T.TextRed
    local srcTxt = self._nearbyWater and "● Fonte d'água próxima" or "○ Sem fonte d'água próxima"
    self:drawText(srcTxt, cx, cy, srcCol.r, srcCol.g, srcCol.b, srcCol.a, sm)
    cy = cy + fh + T.Gap

    -- Totais
    local totalCur = 0; local totalCap = 0
    for _, b in ipairs(self._bottles) do totalCur = totalCur + b.cur; totalCap = totalCap + b.cap end
    local totalStr = string.format("Total: %.1f / %.1f  (%d recipiente(s))",
        totalCur, totalCap, #self._bottles)
    self:drawText(totalStr, cx, cy, dim.r, dim.g, dim.b, dim.a, sm)
    cy = cy + fh + T.Gap

    if totalCap > 0 then
        local pct    = U.clamp(totalCur / totalCap, 0, 1)
        local barCol = pct > 0.5 and T.Blue or (pct > 0.2 and T.Yellow or T.Red)
        U.drawBar(self, cx, cy, cw, 6, pct, barCol)
        cy = cy + 10 + T.Gap
    end

    U.drawDivider(self, cx, cy, cw); cy = cy + T.Gap + 2

    local listH = self.height - cy - T.Pad * 2 - T.BtnH - T.Gap
    self:drawBottleList(cx, cy, cw, listH)
end

function EUI_BottlePanel:drawBottleList(cx, cy, cw, listH)
    local sm  = T.FontSm
    local fh  = getTextManager():getFontHeight(sm)
    local bg  = T.BG2
    self:drawRect(cx, cy, cw, listH, bg.a, bg.r, bg.g, bg.b)

    if #self._bottles == 0 then
        local tc  = T.TextOff
        local msg = "Nenhum recipiente no inventário"
        local mw  = getTextManager():MeasureStringX(sm, msg)
        self:drawText(msg, cx + math.floor((cw - mw) / 2), cy + 30,
            tc.r, tc.g, tc.b, tc.a, sm)
        return
    end

    local barW = cw - 190
    local yOff = cy - self._scroll

    for i, b in ipairs(self._bottles) do
        if yOff + ROW_H >= cy and yOff <= cy + listH then
            local sel  = b == self._selBottle
            local rbg  = sel and T.BG_Select or (i % 2 == 0 and T.BG3 or T.BG2)
            self:drawRect(cx, yOff, cw, ROW_H, rbg.a, rbg.r, rbg.g, rbg.b)
            if sel then
                self:drawRect(cx, yOff, 2, ROW_H, T.Green.a, T.Green.r, T.Green.g, T.Green.b)
            end

            local tc  = sel and T.TextGreen or T.Text
            local dim = T.TextDim

            -- Nome + badges
            local badge = ""
            if b.boiled  then badge = badge .. " [Fervida]" end
            if b.tainted then badge = badge .. " [Contaminada]" end
            local nameStr = U.truncate(b.name, 150, sm) .. badge
            self:drawText(nameStr, cx + T.PadSm + (sel and 4 or 0),
                yOff + math.floor((ROW_H - fh * 2 - T.PadSm) / 2),
                tc.r, tc.g, tc.b, tc.a, sm)

            -- Tipo de líquido
            self:drawText(b.liquid, cx + T.PadSm + (sel and 4 or 0),
                yOff + math.floor((ROW_H - fh * 2 - T.PadSm) / 2) + fh + T.PadSm,
                dim.r, dim.g, dim.b, dim.a, sm)

            -- Barra de água
            local bCol = b.tainted and T.Red or (b.boiled and T.Green or T.Blue)
            U.drawBar(self, cx + 180, yOff + math.floor((ROW_H - BAR_H) / 2),
                barW, BAR_H, b.pct, bCol)

            -- Texto quantidade
            local qStr = string.format("%.1f/%.1f", b.cur, b.cap)
            local qw   = getTextManager():MeasureStringX(sm, qStr)
            self:drawText(qStr, cx + cw - qw - T.PadSm,
                yOff + math.floor((ROW_H - fh) / 2),
                dim.r, dim.g, dim.b, dim.a, sm)
        end
        yOff = yOff + ROW_H + T.PadSm
    end

    if self._maxScroll > 0 then
        local totalH = #self._bottles * (ROW_H + T.PadSm)
        local ratio  = listH / totalH
        local barH   = math.max(16, math.floor(listH * ratio))
        local barY   = cy + math.floor(self._scroll / self._maxScroll * (listH - barH))
        self:drawRect(cx + cw, cy, T.ScrollW, listH, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
        self:drawRect(cx + cw + 1, barY, T.ScrollW - 2, barH, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    end
end

-- ── Mouse ─────────────────────────────────────────────────────────────────────

function EUI_BottlePanel:onMouseDown(mx, my)
    EUI_BasePanel.onMouseDown(self, mx, my)
    if my <= T.TitleH then return end
    local cx   = self:contentX()
    local cy   = self:contentY()
    local sm   = T.FontSm
    local fh   = getTextManager():getFontHeight(sm)
    local barH = 6
    local top  = cy + fh * 2 + T.Gap * 5 + barH + 4 + 10
    local lH   = self.height - top - T.Pad * 2 - T.BtnH - T.Gap

    if U.inRect(mx, my, cx, top, self:contentW(), lH) then
        local rel = my - top + self._scroll
        local idx = math.floor(rel / (ROW_H + T.PadSm)) + 1
        if self._bottles[idx] then self._selBottle = self._bottles[idx] end
    end
end

function EUI_BottlePanel:onMouseWheel(del)
    self._scroll = U.clamp(self._scroll - del * ROW_H, 0, self._maxScroll)
    return true
end

-- ── Registro ──────────────────────────────────────────────────────────────────

Events.OnKeyPressed.Add(function(key)
    if key == EUI.getKey("Bottle") then
        if EUI._bottlePanel then
            EUI._bottlePanel:setVisible(not EUI._bottlePanel:isVisible())
            if EUI._bottlePanel:isVisible() then EUI._bottlePanel:scanBottles() end
            return
        end
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local p  = EUI_BottlePanel:new(
            math.floor((sw - PANEL_W) / 2),
            math.floor((sh - PANEL_H) / 2), 0)
        p:initialise(); p:instantiate(); p:addToUIManager(); p:setVisible(true)
        EUI._bottlePanel = p
    end
end)
