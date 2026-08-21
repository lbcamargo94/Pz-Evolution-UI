-- EUI_LivestockPanel.lua — gestão de infraestrutura pecuária (B42)

EUI = EUI or {}

EUI_LivestockPanel = EUI_BasePanel:derive("EUI_LivestockPanel")

local T = EUI.Theme
local U = EUI.Utils

local PANEL_W  = 540
local PANEL_H  = 520
local ROW_H    = 38
local BAR_H    = 8
local SCAN_R   = 20   -- raio de busca de cochos / cercados

-- Nomes de objetos que são cochos/bebedouros no B42
local TROUGH_NAMES = {
    "FeedingTrough", "WaterTrough", "Trough", "Feeder",
    "AnimalFeeder", "AnimalWaterer", "LargeFeedingTrough",
}

-- Tipos conhecidos de animais (para resumo do rebanho)
local ANIMAL_TYPES = {
    { id="Chicken", label="Galinha", icon="🐔" },
    { id="Hen",     label="Galinha", icon="🐔" },
    { id="Rabbit",  label="Coelho",  icon="🐰" },
    { id="Pig",     label="Porco",   icon="🐷" },
    { id="Sheep",   label="Ovelha",  icon="🐑" },
    { id="Cow",     label="Vaca",    icon="🐄" },
    { id="Horse",   label="Cavalo",  icon="🐴" },
    { id="Cat",     label="Gato",    icon="🐱" },
    { id="Dog",     label="Cão",     icon="🐶" },
}

-- ── Constructor ───────────────────────────────────────────────────────────────

function EUI_LivestockPanel:new(x, y, playerNum)
    local o = EUI_BasePanel.new(self, x, y, PANEL_W, PANEL_H, "Manejo Pecuário")
    o.playerNum       = playerNum or 0
    o.showCloseButton = true
    o._troughs        = {}   -- cochos encontrados
    o._animals        = {}   -- animais próximos
    o._selTrough      = nil
    o._scroll         = 0
    o._maxScroll      = 0
    o._tab            = "troughs"  -- "troughs" | "herd"
    o._timer          = 0
    return o
end

function EUI_LivestockPanel:initialise()
    EUI_BasePanel.initialise(self)
    self:buildTabs()
    self:buildButtons()
    self:scan()
end

function EUI_LivestockPanel:buildTabs()
    local bw = 110
    local bh = 26
    local cx = self:contentX()
    local cy = self:contentY()

    self._tabTroughs = EUI_BaseButton:new(cx, cy, bw, bh, "Cochos", self,
        function() self:setTab("troughs") end, "ghost")
    self._tabTroughs:initialise(); self._tabTroughs:instantiate(); self:addChild(self._tabTroughs)

    self._tabHerd = EUI_BaseButton:new(cx + bw + T.Gap, cy, bw, bh, "Rebanho", self,
        function() self:setTab("herd") end, "ghost")
    self._tabHerd:initialise(); self._tabHerd:instantiate(); self:addChild(self._tabHerd)

    self._tabH = bh + T.Gap
end

function EUI_LivestockPanel:buildButtons()
    local third = math.floor((self:contentW() - T.Gap * 2) / 3)
    local bh    = T.BtnH
    local cx    = self:contentX()
    local by    = self.height - T.Pad * 2 - bh

    self._btnFill = EUI_BaseButton:new(cx, by, third, bh, "Encher Cocho", self,
        EUI_LivestockPanel.onFillTrough, "primary")
    self._btnFill:initialise(); self._btnFill:instantiate(); self:addChild(self._btnFill)

    self._btnFillAll = EUI_BaseButton:new(cx + third + T.Gap, by, third, bh, "Encher Todos", self,
        EUI_LivestockPanel.onFillAll, "ghost")
    self._btnFillAll:initialise(); self._btnFillAll:instantiate(); self:addChild(self._btnFillAll)

    self._btnRefresh = EUI_BaseButton:new(cx + (third + T.Gap) * 2, by, third, bh, "Atualizar", self,
        EUI_LivestockPanel.onRefresh, "ghost")
    self._btnRefresh:initialise(); self._btnRefresh:instantiate(); self:addChild(self._btnRefresh)
end

function EUI_LivestockPanel:setTab(tab)
    self._tab = tab; self._selTrough = nil; self._scroll = 0
end

-- ── Dados ─────────────────────────────────────────────────────────────────────

function EUI_LivestockPanel:scan()
    self:scanTroughs()
    self:scanAnimals()
end

function EUI_LivestockPanel:scanTroughs()
    self._troughs = {}
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    local sq = player:getSquare()
    if not sq then return end

    for dx = -SCAN_R, SCAN_R do
        for dy = -SCAN_R, SCAN_R do
            local s = getCell():getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
            if s then
                local objs = s:getObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if obj then
                            local objName = ""
                            pcall(function() objName = obj:getObjectName() or "" end)
                            for _, tn in ipairs(TROUGH_NAMES) do
                                if objName:find(tn) then
                                    local cur, cap, isWater = 0, 100, false
                                    pcall(function()
                                        -- B42: cochos usam FluidContainer ou campos próprios
                                        local fc = obj:getFluidContainer and obj:getFluidContainer()
                                        if fc then
                                            cur    = fc:getAmount()
                                            cap    = fc:getCapacity()
                                            local ft = fc:getFluidType()
                                            if ft then isWater = ft:getName():find("[Ww]ater") ~= nil end
                                        else
                                            cur = obj:getCurrentCapacity and obj:getCurrentCapacity() or 0
                                            cap = obj:getCapacity and obj:getCapacity() or 100
                                        end
                                    end)
                                    local isWaterTrough = objName:find("[Ww]ater") ~= nil or isWater
                                    table.insert(self._troughs, {
                                        obj      = obj,
                                        name     = objName,
                                        cur      = cur,
                                        cap      = cap,
                                        pct      = cap > 0 and U.clamp(cur / cap, 0, 1) or 0,
                                        isWater  = isWaterTrough,
                                        sq       = s,
                                    })
                                    break
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local listH = self:contentH() - self._tabH - T.BtnH - T.Gap * 2
    self._maxScroll = math.max(0, #self._troughs * (ROW_H + T.PadSm) - listH)
end

function EUI_LivestockPanel:scanAnimals()
    self._animals = {}
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    local sq = player:getSquare()
    if not sq then return end

    local radius = (EUI.Settings and EUI.Settings.animalRadius) or SCAN_R
    for dx = -radius, radius do
        for dy = -radius, radius do
            local s = getCell():getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
            if s then
                local objs = s:getObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if obj then
                            local ok = false
                            pcall(function() ok = obj:isAnimal and obj:isAnimal() end)
                            if ok then table.insert(self._animals, obj) end
                        end
                    end
                end
            end
        end
    end
end

function EUI_LivestockPanel:update()
    EUI_BasePanel.update(self)
    self._timer = (self._timer or 0) + 1
    if self._timer >= 90 then self._timer = 0; self:scan() end
end

-- ── Ações ─────────────────────────────────────────────────────────────────────

function EUI_LivestockPanel:onFillTrough()
    local t = self._selTrough
    local player = getSpecificPlayer(self.playerNum)
    if not t or not player then return end
    pcall(function()
        local inv = player:getInventory()
        if t.isWater then
            -- Tentar usar ISOFillWaterAction ou ação equivalente
            if ISFillWaterAction then
                ISTimedActionQueue.add(ISFillWaterAction:new(player, t.obj))
            end
        else
            -- Buscar comida animal no inventário
            local food = inv:getFirstTypeRecurse("Base.Hay")
                      or inv:getFirstTypeRecurse("Base.Corn")
                      or inv:getFirstTypeRecurse("Base.PileOfSeeds")
            if food and t.obj.fill then
                t.obj:fill(player, food)
            end
        end
    end)
end

function EUI_LivestockPanel:onFillAll()
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    for _, t in ipairs(self._troughs) do
        if t.pct < 0.9 then
            pcall(function()
                local inv = player:getInventory()
                if t.isWater then
                    if ISFillWaterAction then
                        ISTimedActionQueue.add(ISFillWaterAction:new(player, t.obj))
                    end
                else
                    local food = inv:getFirstTypeRecurse("Base.Hay")
                              or inv:getFirstTypeRecurse("Base.Corn")
                    if food and t.obj.fill then
                        t.obj:fill(player, food)
                    end
                end
            end)
        end
    end
end

function EUI_LivestockPanel:onRefresh()
    self._selTrough = nil; self._scroll = 0
    self:scan()
end

-- ── Render ────────────────────────────────────────────────────────────────────

function EUI_LivestockPanel:render()
    local cy = self:contentY() + self._tabH
    local cx = self:contentX()
    local cw = self:contentW()

    -- Indicadores de aba ativa
    local t1c = self._tab == "troughs" and T.Green or T.Border
    local t2c = self._tab == "herd"    and T.Green or T.Border
    local iY  = self:contentY() + self._tabH - T.Gap
    self:drawRect(cx, iY, 110, 2, t1c.a, t1c.r, t1c.g, t1c.b)
    self:drawRect(cx + 110 + T.Gap, iY, 110, 2, t2c.a, t2c.r, t2c.g, t2c.b)

    local listH = self.height - cy - T.Pad * 2 - T.BtnH - T.Gap

    if self._tab == "troughs" then
        self:drawTroughList(cx, cy, cw, listH)
    else
        self:drawHerdView(cx, cy, cw, listH + T.BtnH + T.Gap)
    end
end

-- ── Lista de cochos ───────────────────────────────────────────────────────────

function EUI_LivestockPanel:drawTroughList(cx, cy, cw, listH)
    local sm   = T.FontSm
    local fh   = getTextManager():getFontHeight(sm)
    local dim  = T.TextDim

    -- Resumo rápido
    local total = #self._troughs
    local low   = 0
    for _, t in ipairs(self._troughs) do if t.pct < 0.3 then low = low + 1 end end
    local sumStr = string.format("%d cocho(s) no raio de %d tiles", total, SCAN_R)
    self:drawText(sumStr, cx, cy, dim.r, dim.g, dim.b, dim.a, sm)
    cy = cy + fh + T.PadSm

    if low > 0 then
        local wc = T.TextYellow
        local warn = string.format("⚠ %d cocho(s) com nível baixo (< 30%%)", low)
        self:drawText(warn, cx, cy, wc.r, wc.g, wc.b, wc.a, sm)
    end
    cy = cy + fh + T.Gap

    U.drawDivider(self, cx, cy, cw); cy = cy + T.Gap + 2

    local bg = T.BG2
    local availH = self.height - cy - T.Pad * 2 - T.BtnH - T.Gap
    self:drawRect(cx, cy, cw, availH, bg.a, bg.r, bg.g, bg.b)

    if total == 0 then
        local tc  = T.TextOff
        local msg = "Nenhum cocho encontrado no raio de " .. SCAN_R .. " tiles"
        local mw  = getTextManager():MeasureStringX(sm, msg)
        self:drawText(msg, cx + math.floor((cw - mw) / 2), cy + 30,
            tc.r, tc.g, tc.b, tc.a, sm)
        return
    end

    local barW = cw - 200
    local yOff = cy - self._scroll

    for i, t in ipairs(self._troughs) do
        if yOff + ROW_H >= cy and yOff <= cy + availH then
            local sel = t == self._selTrough
            local rbg = sel and T.BG_Select or (i % 2 == 0 and T.BG3 or T.BG2)
            self:drawRect(cx, yOff, cw, ROW_H, rbg.a, rbg.r, rbg.g, rbg.b)

            -- Indicador lateral por tipo
            local sideCol = t.isWater and T.Blue or T.TextYellow
            self:drawRect(cx, yOff, 3, ROW_H, sideCol.a, sideCol.r, sideCol.g, sideCol.b)

            -- Nome e tipo
            local icon = t.isWater and "💧" or "🌾"
            local tc   = sel and T.TextGreen or T.Text
            local label = icon .. " " .. U.truncate(t.name, 140, sm)
            self:drawText(label, cx + T.PadSm + 4,
                yOff + math.floor((ROW_H - fh * 2 - T.PadSm) / 2),
                tc.r, tc.g, tc.b, tc.a, sm)

            local subType = t.isWater and "Bebedouro" or "Comedouro"
            self:drawText(subType, cx + T.PadSm + 4,
                yOff + math.floor((ROW_H - fh * 2 - T.PadSm) / 2) + fh + T.PadSm,
                dim.r, dim.g, dim.b, dim.a, sm)

            -- Barra de nível
            local lvlCol = t.pct > 0.6 and T.Green or (t.pct > 0.3 and T.Yellow or T.Red)
            if t.isWater then lvlCol = t.pct > 0.3 and T.Blue or T.Red end
            U.drawBar(self, cx + 160, yOff + math.floor((ROW_H - BAR_H) / 2),
                barW, BAR_H, t.pct, lvlCol)

            -- Percentagem
            local pctStr = string.format("%d%%", math.floor(t.pct * 100))
            local pw     = getTextManager():MeasureStringX(sm, pctStr)
            self:drawText(pctStr, cx + cw - pw - T.PadSm,
                yOff + math.floor((ROW_H - fh) / 2),
                lvlCol.r, lvlCol.g, lvlCol.b, lvlCol.a, sm)
        end
        yOff = yOff + ROW_H + T.PadSm
    end

    -- Scrollbar
    if self._maxScroll > 0 then
        local totalH = total * (ROW_H + T.PadSm)
        local ratio  = availH / totalH
        local barH   = math.max(16, math.floor(availH * ratio))
        local barY   = cy + math.floor(self._scroll / self._maxScroll * (availH - barH))
        self:drawRect(cx + cw, cy, T.ScrollW, availH, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
        self:drawRect(cx + cw + 1, barY, T.ScrollW - 2, barH, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    end
end

-- ── Aba Rebanho ───────────────────────────────────────────────────────────────

function EUI_LivestockPanel:drawHerdView(cx, cy, cw, ch)
    local font = T.Font; local sm = T.FontSm
    local fhM  = getTextManager():getFontHeight(font)
    local fh   = getTextManager():getFontHeight(sm)
    local dim  = T.TextDim; local hdr = T.TextGreen
    local y    = cy + T.Pad

    -- Contagem por tipo e saúde média
    local counts = {}; local healthSum = {}; local healthCount = {}
    for _, at in ipairs(ANIMAL_TYPES) do
        counts[at.id] = 0; healthSum[at.id] = 0; healthCount[at.id] = 0
    end

    for _, a in ipairs(self._animals) do
        local atype = "?"
        pcall(function() atype = a:getAnimalType() or a:getName() or "?" end)
        for _, at in ipairs(ANIMAL_TYPES) do
            if atype:find(at.id) then
                counts[at.id]      = (counts[at.id] or 0) + 1
                local hp, hpM = 100, 100
                pcall(function() hp  = a:getHealth()    end)
                pcall(function() hpM = a:getMaxHealth() end)
                healthSum[at.id]   = (healthSum[at.id] or 0) + (hpM > 0 and hp / hpM or 1)
                healthCount[at.id] = (healthCount[at.id] or 0) + 1
                break
            end
        end
    end

    -- Total geral
    local totalA = #self._animals
    self:drawText("Resumo do Rebanho", cx + T.Pad, y, hdr.r, hdr.g, hdr.b, hdr.a, font)
    y = y + fhM + T.PadSm
    local cStr = string.format("Total: %d animal(is) no raio de %d tiles", totalA, SCAN_R)
    self:drawText(cStr, cx + T.Pad, y, dim.r, dim.g, dim.b, dim.a, sm)
    y = y + fh + T.Gap
    U.drawDivider(self, cx + T.Pad, y, cw - T.Pad * 2); y = y + T.Gap + 2

    if totalA == 0 then
        local tc  = T.TextOff
        local msg = "Nenhum animal encontrado no raio de " .. SCAN_R .. " tiles"
        local mw  = getTextManager():MeasureStringX(sm, msg)
        self:drawText(msg, cx + math.floor((cw - mw) / 2), y + 20,
            tc.r, tc.g, tc.b, tc.a, sm)
        return
    end

    -- Uma linha por tipo com barra de saúde média
    local barW = cw - T.Pad * 2 - 160 - 60
    for _, at in ipairs(ANIMAL_TYPES) do
        local n = counts[at.id] or 0
        if n > 0 then
            local avgHp = healthCount[at.id] > 0
                and healthSum[at.id] / healthCount[at.id] or 1
            local hCol  = avgHp > 0.6 and T.Green or (avgHp > 0.3 and T.Yellow or T.Red)

            -- Ícone + nome + contagem
            local label = string.format("%s %s  ×%d", at.icon, at.label, n)
            self:drawText(label, cx + T.Pad, y + math.floor((22 - fh) / 2),
                T.Text.r, T.Text.g, T.Text.b, T.Text.a, sm)

            -- Barra de saúde média
            U.drawBar(self, cx + T.Pad + 160, y + math.floor((22 - BAR_H) / 2),
                barW, BAR_H, avgHp, hCol)

            -- Percentagem de saúde
            local pStr = string.format("%.0f%%", avgHp * 100)
            local pw   = getTextManager():MeasureStringX(sm, pStr)
            self:drawText(pStr, cx + cw - T.Pad - pw, y + math.floor((22 - fh) / 2),
                hCol.r, hCol.g, hCol.b, hCol.a, sm)

            y = y + 24 + T.PadSm
            if y > cy + ch - fh - T.Pad then break end
        end
    end

    y = y + T.Gap
    U.drawDivider(self, cx + T.Pad, y, cw - T.Pad * 2); y = y + T.Gap + 2

    -- Legenda de saúde
    local legend = "Saúde: "
    self:drawText(legend, cx + T.Pad, y, dim.r, dim.g, dim.b, dim.a, sm)
    local lw = getTextManager():MeasureStringX(sm, legend)
    self:drawText("Boa (>60%)", cx + T.Pad + lw, y, T.Green.r, T.Green.g, T.Green.b, T.Green.a, sm)
    local w2 = getTextManager():MeasureStringX(sm, "Boa (>60%)  ")
    self:drawText("Média", cx + T.Pad + lw + w2, y, T.Yellow.r, T.Yellow.g, T.Yellow.b, T.Yellow.a, sm)
    local w3 = getTextManager():MeasureStringX(sm, "Média  ")
    self:drawText("Crítica", cx + T.Pad + lw + w2 + w3, y, T.Red.r, T.Red.g, T.Red.b, T.Red.a, sm)
end

-- ── Mouse ─────────────────────────────────────────────────────────────────────

function EUI_LivestockPanel:onMouseDown(mx, my)
    EUI_BasePanel.onMouseDown(self, mx, my)
    if my <= T.TitleH then return end
    if self._tab ~= "troughs" then return end

    local cx   = self:contentX()
    local cy   = self:contentY() + self._tabH
    local sm   = T.FontSm
    local fh   = getTextManager():getFontHeight(sm)
    -- 2 linhas de summary + gaps + divider
    local listTop = cy + fh * 2 + T.PadSm + fh + T.Gap + T.Gap + 2
    local listH   = self.height - listTop - T.Pad * 2 - T.BtnH - T.Gap

    if U.inRect(mx, my, cx, listTop, self:contentW(), listH) then
        local rel = my - listTop + self._scroll
        local idx = math.floor(rel / (ROW_H + T.PadSm)) + 1
        if self._troughs[idx] then self._selTrough = self._troughs[idx] end
    end
end

function EUI_LivestockPanel:onMouseWheel(del)
    if self._tab == "troughs" then
        self._scroll = U.clamp(self._scroll - del * ROW_H, 0, self._maxScroll)
    end
    return true
end

-- ── Registro ──────────────────────────────────────────────────────────────────

Events.OnKeyPressed.Add(function(key)
    if key == EUI.getKey("Livestock") then
        if EUI._livestockPanel then
            EUI._livestockPanel:setVisible(not EUI._livestockPanel:isVisible())
            if EUI._livestockPanel:isVisible() then EUI._livestockPanel:scan() end
            return
        end
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local p  = EUI_LivestockPanel:new(
            math.floor((sw - PANEL_W) / 2),
            math.floor((sh - PANEL_H) / 2), 0)
        p:initialise(); p:instantiate(); p:addToUIManager(); p:setVisible(true)
        EUI._livestockPanel = p
    end
end)
