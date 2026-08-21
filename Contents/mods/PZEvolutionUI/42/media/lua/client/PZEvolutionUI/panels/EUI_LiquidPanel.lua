-- EUI_LiquidPanel.lua — painel de gestão de líquidos (B42)

EUI = EUI or {}

EUI_LiquidPanel = EUI_BasePanel:derive("EUI_LiquidPanel")

local T = EUI.Theme
local U = EUI.Utils

local PANEL_W  = 460
local PANEL_H  = 480
local ROW_H    = 40
local BAR_H    = 8

-- Cores por tipo de líquido
local LIQUID_COLORS = {
    Water      = { r=0.3,  g=0.7,  b=1.0, a=1 },
    GasCanFuel = { r=1.0,  g=0.6,  b=0.1, a=1 },
    Bleach     = { r=0.9,  g=0.9,  b=0.5, a=1 },
    Petrol     = { r=0.8,  g=0.4,  b=0.0, a=1 },
    Diesel     = { r=0.6,  g=0.5,  b=0.2, a=1 },
    Whiskey    = { r=0.8,  g=0.6,  b=0.2, a=1 },
    Beer       = { r=1.0,  g=0.8,  b=0.3, a=1 },
    Wine       = { r=0.7,  g=0.1,  b=0.3, a=1 },
    Milk       = { r=1.0,  g=1.0,  b=0.95,a=1 },
    Vinegar    = { r=0.9,  g=0.85, b=0.6, a=1 },
}
local DEFAULT_LIQUID_COLOR = { r=0.5, g=0.8, b=0.9, a=1 }

-- ── Constructor ───────────────────────────────────────────────────────────────

function EUI_LiquidPanel:new(x, y, playerNum)
    local o = EUI_BasePanel.new(self, x, y, PANEL_W, PANEL_H, "Gestão de Líquidos")
    o.playerNum       = playerNum or 0
    o.showCloseButton = true
    o._containers     = {}  -- itens com líquido no inventário
    o._selFrom        = nil
    o._selTo          = nil
    o._scroll         = 0
    o._maxScroll      = 0
    o._timer          = 0
    return o
end

function EUI_LiquidPanel:initialise()
    EUI_BasePanel.initialise(self)
    self:buildButtons()
    self:scanContainers()
end

function EUI_LiquidPanel:buildButtons()
    local third = math.floor((self:contentW() - T.Gap * 2) / 3)
    local bh    = T.BtnH
    local cx    = self:contentX()
    local by    = self.height - T.Pad * 2 - bh

    self._btnFill = EUI_BaseButton:new(cx, by, third, bh, "Transferir →", self,
        EUI_LiquidPanel.onTransfer, "primary")
    self._btnFill:initialise(); self._btnFill:instantiate(); self:addChild(self._btnFill)

    self._btnEmpty = EUI_BaseButton:new(cx + third + T.Gap, by, third, bh, "Despejar", self,
        EUI_LiquidPanel.onEmpty, "danger")
    self._btnEmpty:initialise(); self._btnEmpty:instantiate(); self:addChild(self._btnEmpty)

    self._btnRefresh = EUI_BaseButton:new(cx + (third + T.Gap) * 2, by, third, bh, "Atualizar", self,
        EUI_LiquidPanel.onRefresh, "ghost")
    self._btnRefresh:initialise(); self._btnRefresh:instantiate(); self:addChild(self._btnRefresh)
end

-- ── Dados ─────────────────────────────────────────────────────────────────────

function EUI_LiquidPanel:scanContainers()
    self._containers = {}
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end

    local inv = player:getInventory()
    if not inv then return end

    local items = nil
    pcall(function() items = inv:getItems() end)
    if not items then return end

    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item then
            if U.isFluidItem(item) then
                local name = "?"; local liqName = "Vazio"; local cur = 0; local cap = 1
                pcall(function() name = item:getName() or "?" end)
                liqName = U.getFluidName(item)
                cur     = U.getFluidAmount(item)
                cap     = U.getFluidCapacity(item)
                table.insert(self._containers, {
                    item    = item,
                    name    = name,
                    liquid  = liqName,
                    cur     = cur,
                    cap     = cap,
                    pct     = cap > 0 and U.clamp(cur / cap, 0, 1) or 0,
                })
            end
        end
    end

    local listH = self:contentH() - 60 - T.Gap -- 60 = header estimado
    self._maxScroll = math.max(0, #self._containers * (ROW_H + T.PadSm) - listH)
end

function EUI_LiquidPanel:update()
    EUI_BasePanel.update(self)
    self._timer = (self._timer or 0) + 1
    if self._timer >= 90 then self._timer = 0; self:scanContainers() end
end

-- ── Ações ─────────────────────────────────────────────────────────────────────

function EUI_LiquidPanel:onTransfer()
    local from = self._selFrom; local to = self._selTo
    local player = getSpecificPlayer(self.playerNum)
    if not from or not to or not player then return end
    if from == to then return end
    pcall(function()
        if ISTransferLiquidAction then
            ISTimedActionQueue.add(ISTransferLiquidAction:new(player, from.item, to.item))
        end
    end)
end

function EUI_LiquidPanel:onEmpty()
    local from = self._selFrom
    local player = getSpecificPlayer(self.playerNum)
    if not from or not player then return end
    pcall(function()
        if ISEmptyLiquidAction then
            ISTimedActionQueue.add(ISEmptyLiquidAction:new(player, from.item))
        end
    end)
end

function EUI_LiquidPanel:onRefresh()
    self._selFrom = nil; self._selTo = nil; self._scroll = 0
    self:scanContainers()
end

-- ── Render ────────────────────────────────────────────────────────────────────

function EUI_LiquidPanel:render()
    local cx   = self:contentX()
    local cy   = self:contentY()
    local cw   = self:contentW()
    local sm   = T.FontSm
    local fh   = getTextManager():getFontHeight(sm)
    local dim  = T.TextDim

    -- Header info
    local n = #self._containers
    local info = string.format("%d recipiente(s) no inventário", n)
    self:drawText(info, cx, cy, dim.r, dim.g, dim.b, dim.a, sm)
    cy = cy + fh + T.Gap

    -- Instrução de seleção
    local from = self._selFrom; local to = self._selTo
    local hint = ""
    if not from and not to then
        hint = "Clique = Origem   Shift+Click = Destino"
    elseif from and not to then
        hint = "Origem: " .. from.name .. "  |  Shift+Click = Destino"
    elseif from and to then
        hint = from.name .. "  →  " .. to.name
    end
    local hc = T.TextGreen
    self:drawText(hint, cx, cy, hc.r, hc.g, hc.b, hc.a, sm)
    cy = cy + fh + T.Gap

    U.drawDivider(self, cx, cy, cw); cy = cy + T.Gap + 2

    -- Lista de containers
    local listH = self.height - cy - T.Pad * 2 - T.BtnH - T.Gap
    self:drawContainerList(cx, cy, cw, listH)
end

function EUI_LiquidPanel:drawContainerList(cx, cy, cw, listH)
    local sm  = T.FontSm
    local fh  = getTextManager():getFontHeight(sm)
    local bg  = T.BG2
    self:drawRect(cx, cy, cw, listH, bg.a, bg.r, bg.g, bg.b)

    if #self._containers == 0 then
        local tc  = T.TextOff
        local msg = "Nenhum recipiente encontrado"
        local mw  = getTextManager():MeasureStringX(sm, msg)
        self:drawText(msg, cx + math.floor((cw - mw) / 2), cy + 30,
            tc.r, tc.g, tc.b, tc.a, sm)
        return
    end

    local barW  = cw - 200
    local yOff  = cy - self._scroll

    for i, c in ipairs(self._containers) do
        if yOff + ROW_H >= cy and yOff <= cy + listH then
            local isFrom = c == self._selFrom
            local isTo   = c == self._selTo

            -- Fundo com destaque de seleção
            local rbg = isFrom and T.BG_Select or (isTo and { r=0.1, g=0.15, b=0.3, a=0.8 }
                         or (i % 2 == 0 and T.BG3 or T.BG2))
            self:drawRect(cx, yOff, cw, ROW_H, rbg.a, rbg.r, rbg.g, rbg.b)

            -- Indicador lateral
            if isFrom then
                self:drawRect(cx, yOff, 3, ROW_H, T.Green.a, T.Green.r, T.Green.g, T.Green.b)
            elseif isTo then
                self:drawRect(cx, yOff, 3, ROW_H, T.Blue.a, T.Blue.r, T.Blue.g, T.Blue.b)
            end

            local tc   = (isFrom or isTo) and T.TextGreen or T.Text
            local dim  = T.TextDim
            -- Nome do item
            self:drawText(U.truncate(c.name, 140, sm), cx + T.PadSm + (isFrom and 4 or 0),
                yOff + math.floor((ROW_H - fh * 2 - T.PadSm) / 2),
                tc.r, tc.g, tc.b, tc.a, sm)
            -- Nome do líquido
            self:drawText(c.liquid, cx + T.PadSm + (isFrom and 4 or 0),
                yOff + math.floor((ROW_H - fh * 2 - T.PadSm) / 2) + fh + T.PadSm,
                dim.r, dim.g, dim.b, dim.a, sm)

            -- Barra de nível
            local lCol = LIQUID_COLORS[c.liquid] or DEFAULT_LIQUID_COLOR
            U.drawBar(self, cx + 160, yOff + math.floor((ROW_H - BAR_H) / 2),
                barW, BAR_H, c.pct, lCol)

            -- Texto capacidade
            local capStr = string.format("%.1f / %.1f", c.cur, c.cap)
            local cw2    = getTextManager():MeasureStringX(sm, capStr)
            self:drawText(capStr, cx + cw - cw2 - T.PadSm,
                yOff + math.floor((ROW_H - fh) / 2),
                dim.r, dim.g, dim.b, dim.a, sm)

            -- Tag Origem/Destino
            if isFrom then
                self:drawText("[O]", cx + cw - 30, yOff + 4, T.Green.r, T.Green.g, T.Green.b, T.Green.a, sm)
            elseif isTo then
                self:drawText("[D]", cx + cw - 30, yOff + 4, T.Blue.r, T.Blue.g, T.Blue.b, T.Blue.a, sm)
            end
        end
        yOff = yOff + ROW_H + T.PadSm
    end

    -- Scrollbar
    if self._maxScroll > 0 then
        local totalH = #self._containers * (ROW_H + T.PadSm)
        local ratio  = listH / totalH
        local barH   = math.max(16, math.floor(listH * ratio))
        local barY   = cy + math.floor(self._scroll / self._maxScroll * (listH - barH))
        self:drawRect(cx + cw, cy, T.ScrollW, listH, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
        self:drawRect(cx + cw + 1, barY, T.ScrollW - 2, barH, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    end
end

-- ── Mouse ─────────────────────────────────────────────────────────────────────

function EUI_LiquidPanel:onMouseDown(mx, my)
    EUI_BasePanel.onMouseDown(self, mx, my)
    if my <= T.TitleH then return end
    local cx     = self:contentX()
    local cy     = self:contentY()
    local sm     = T.FontSm
    local fh     = getTextManager():getFontHeight(sm)
    -- topo da lista = cy + 2 linhas header + 2 gaps + divider
    local listTop = cy + fh * 2 + T.Gap * 4 + 4
    local listH   = self.height - listTop - T.Pad * 2 - T.BtnH - T.Gap

    if U.inRect(mx, my, cx, listTop, self:contentW(), listH) then
        local rel = my - listTop + self._scroll
        local idx = math.floor(rel / (ROW_H + T.PadSm)) + 1
        local c   = self._containers[idx]
        if c then
            -- Shift = destino, click normal = origem
            if U.isShiftDown() then
                self._selTo = c
            else
                self._selFrom = c
                if self._selTo == c then self._selTo = nil end
            end
        end
    end
end

function EUI_LiquidPanel:onMouseWheel(del)
    self._scroll = U.clamp(self._scroll - del * ROW_H, 0, self._maxScroll)
    return true
end

-- ── Registro ──────────────────────────────────────────────────────────────────

Events.OnKeyPressed.Add(function(key)
    if key == EUI.getKey("Liquid") then
        if EUI._liquidPanel then
            EUI._liquidPanel:setVisible(not EUI._liquidPanel:isVisible())
            if EUI._liquidPanel:isVisible() then EUI._liquidPanel:scanContainers() end
            return
        end
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local p  = EUI_LiquidPanel:new(
            math.floor((sw - PANEL_W) / 2),
            math.floor((sh - PANEL_H) / 2), 0)
        p:initialise(); p:instantiate(); p:addToUIManager(); p:setVisible(true)
        EUI._liquidPanel = p
    end
end)
