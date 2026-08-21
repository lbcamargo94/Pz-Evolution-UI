-- EUI_AnimalPanel.lua — painel de animais e pecuária (B42)

EUI = EUI or {}

EUI_AnimalPanel = EUI_BasePanel:derive("EUI_AnimalPanel")

local T = EUI.Theme
local U = EUI.Utils

local PANEL_W  = 520
local PANEL_H  = 500
local LIST_W   = 180
local ROW_H    = 32
local BAR_H    = 7
local INFO_W   = PANEL_W - LIST_W - T.Pad * 3 - T.Gap

-- Tipos de animais B42
local ANIMAL_TYPES = {
    { id="Chicken",  label="Galinha",   icon="🐔" },
    { id="Rabbit",   label="Coelho",    icon="🐰" },
    { id="Pig",      label="Porco",     icon="🐷" },
    { id="Sheep",    label="Ovelha",    icon="🐑" },
    { id="Cow",      label="Vaca",      icon="🐄" },
    { id="Horse",    label="Cavalo",    icon="🐴" },
    { id="Cat",      label="Gato",      icon="🐱" },
    { id="Dog",      label="Cão",       icon="🐶" },
}

-- Ações disponíveis
local ACTIONS = { "Alimentar", "Ordenhar", "Tosquiar", "Montar", "Acariciar" }

-- ── Constructor ───────────────────────────────────────────────────────────────

function EUI_AnimalPanel:new(x, y, playerNum)
    local o = EUI_BasePanel.new(self, x, y, PANEL_W, PANEL_H, "Animais & Pecuária")
    o.playerNum       = playerNum or 0
    o.showCloseButton = true
    o._animals        = {}   -- lista de IsoAnimal próximos
    o._selAnimal      = nil
    o._scroll         = 0
    o._maxScroll      = 0
    o._tab            = "animais"  -- "animais" | "pecuaria"
    o._timer          = 0
    return o
end

function EUI_AnimalPanel:initialise()
    EUI_BasePanel.initialise(self)
    self:buildTabs()
    self:buildActionButtons()
    self:scanAnimals()
end

function EUI_AnimalPanel:buildTabs()
    local bw = 100
    local bh = 26
    local cx = self:contentX()
    local cy = self:contentY()

    self._tabAnimal = EUI_BaseButton:new(cx, cy, bw, bh, "Animais", self,
        function() self:setTab("animais") end, "ghost")
    self._tabAnimal:initialise(); self._tabAnimal:instantiate(); self:addChild(self._tabAnimal)

    self._tabFarm = EUI_BaseButton:new(cx + bw + T.Gap, cy, bw, bh, "Pecuária", self,
        function() self:setTab("pecuaria") end, "ghost")
    self._tabFarm:initialise(); self._tabFarm:instantiate(); self:addChild(self._tabFarm)

    self._tabH = bh + T.Gap
end

function EUI_AnimalPanel:buildActionButtons()
    local bw = math.floor((INFO_W - T.Gap) / 2)
    local bh = T.BtnH
    local bx = self:contentX() + LIST_W + T.Gap
    local by = self.height - T.Pad * 2 - bh

    self._btnAct1 = EUI_BaseButton:new(bx, by, bw, bh, "Alimentar", self,
        function() self:doAction("feed")  end, "primary")
    self._btnAct1:initialise(); self._btnAct1:instantiate(); self:addChild(self._btnAct1)

    self._btnAct2 = EUI_BaseButton:new(bx + bw + T.Gap, by, bw, bh, "Ordenhar", self,
        function() self:doAction("milk")  end, "ghost")
    self._btnAct2:initialise(); self._btnAct2:instantiate(); self:addChild(self._btnAct2)
end

function EUI_AnimalPanel:setTab(tab)
    self._tab = tab; self._selAnimal = nil; self._scroll = 0
    if tab == "animais" then self:scanAnimals() end
end

-- ── Dados ─────────────────────────────────────────────────────────────────────

function EUI_AnimalPanel:scanAnimals()
    self._animals = {}
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    local sq = player:getSquare()
    if not sq then return end

    local radius = (EUI.Settings and EUI.Settings.animalRadius) or 12
    for dx = -radius, radius do
        for dy = -radius, radius do
            local s = getCell():getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
            if s then
                local objs = s:getObjects()
                if objs then
                    for i = 0, objs:size() - 1 do
                        local obj = objs:get(i)
                        if obj then
                            local isAnimal = false
                            pcall(function()
                                isAnimal = obj.isAnimal and obj:isAnimal()
                            end)
                            if isAnimal then
                                table.insert(self._animals, obj)
                            end
                        end
                    end
                end
            end
        end
    end

    local listH = self:contentH() - self._tabH - T.Gap
    self._maxScroll = math.max(0, #self._animals * (ROW_H + T.PadSm) - listH)
end

function EUI_AnimalPanel:update()
    EUI_BasePanel.update(self)
    self._timer = (self._timer or 0) + 1
    if self._timer >= 60 then   -- re-escaneia a cada ~1s (60 frames)
        self._timer = 0
        if self._tab == "animais" then self:scanAnimals() end
    end
end

-- ── Ações ─────────────────────────────────────────────────────────────────────

function EUI_AnimalPanel:doAction(action)
    local a   = self._selAnimal
    local player = getSpecificPlayer(self.playerNum)
    if not a or not player then return end
    pcall(function()
        if action == "feed" then
            local food = player:getInventory():getFirstTypeRecurse("Base.Berries")
            if food and a.feed then
                a:feed(player, food)
            end
        elseif action == "milk" then
            if a.milkAnimal then a:milkAnimal(player) end
        end
    end)
end

-- ── Render ────────────────────────────────────────────────────────────────────

function EUI_AnimalPanel:render()
    local cy  = self:contentY() + self._tabH
    local cx  = self:contentX()
    local cw  = self:contentW()

    -- Indicador de aba ativa
    local tabACol = self._tab == "animais"  and T.Green or T.Border
    local tabFCol = self._tab == "pecuaria" and T.Green or T.Border
    self:drawRect(cx,              self:contentY() + (self._tabH - T.Gap), 100, 2, tabACol.a, tabACol.r, tabACol.g, tabACol.b)
    self:drawRect(cx + 100 + T.Gap, self:contentY() + (self._tabH - T.Gap), 100, 2, tabFCol.a, tabFCol.r, tabFCol.g, tabFCol.b)

    -- Divisor vertical
    local dh = self.height - cy - T.Pad
    self:drawRect(cx + LIST_W + math.floor(T.Gap/2), cy, 1, dh, T.Border.a, T.Border.r, T.Border.g, T.Border.b)

    local listH = self.height - cy - T.Pad * 2 - T.BtnH - T.Gap
    local infoX = cx + LIST_W + T.Gap
    local infoH = listH + T.Gap

    if self._tab == "animais" then
        self:drawAnimalList(cx, cy, LIST_W, listH)
        self:drawAnimalInfo(infoX, cy, INFO_W, infoH)
    else
        self:drawFarmView(cx, cy, cw, listH + T.BtnH + T.Gap)
    end
end

-- ── Lista de animais ──────────────────────────────────────────────────────────

function EUI_AnimalPanel:drawAnimalList(cx, cy, cw, ch)
    local font = T.FontSm
    local fh   = getTextManager():getFontHeight(font)
    local bg   = T.BG2
    self:drawRect(cx, cy, cw, ch, bg.a, bg.r, bg.g, bg.b)

    if #self._animals == 0 then
        local tc  = T.TextOff
        local msg = "Sem animais próximos"
        local mw  = getTextManager():MeasureStringX(font, msg)
        self:drawText(msg, cx + math.floor((cw - mw) / 2), cy + 20,
            tc.r, tc.g, tc.b, tc.a, font)
        return
    end

    local yOff = cy - self._scroll
    for i, a in ipairs(self._animals) do
        if yOff + ROW_H >= cy and yOff <= cy + ch then
            local sel = a == self._selAnimal
            local rbg = sel and T.BG_Select or (i % 2 == 0 and T.BG3 or T.BG2)
            self:drawRect(cx, yOff, cw, ROW_H, rbg.a, rbg.r, rbg.g, rbg.b)
            if sel then
                self:drawRect(cx, yOff, 2, ROW_H, T.Green.a, T.Green.r, T.Green.g, T.Green.b)
            end

            local name = "?"; local icon = "🐾"
            pcall(function() name = a:getAnimalType() or a:getName() or "?" end)
            -- Busca icon correspondente
            for _, at in ipairs(ANIMAL_TYPES) do
                if name:find(at.id) then icon = at.icon; name = at.label; break end
            end

            local tc  = sel and T.TextGreen or T.Text
            local label = icon .. " " .. U.truncate(name, cw - T.PadSm * 2 - 20, font)
            self:drawText(label, cx + T.PadSm + (sel and 4 or 0),
                yOff + math.floor((ROW_H - fh) / 2), tc.r, tc.g, tc.b, tc.a, font)

            -- Barra de saúde pequena
            local hp, hpMax = 100, 100
            pcall(function() hp    = a:getHealth()    end)
            pcall(function() hpMax = a:getMaxHealth() end)
            local pct = hpMax > 0 and U.clamp(hp / hpMax, 0, 1) or 1
            local hCol = pct > 0.6 and T.Green or (pct > 0.3 and T.Yellow or T.Red)
            U.drawBar(self, cx + T.PadSm, yOff + ROW_H - 6, cw - T.PadSm * 2, 3, pct, hCol)
        end
        yOff = yOff + ROW_H + T.PadSm
    end

    -- Scrollbar
    if self._maxScroll > 0 then
        local totalH = #self._animals * (ROW_H + T.PadSm)
        local ratio  = ch / totalH
        local barH   = math.max(16, math.floor(ch * ratio))
        local barY   = cy + math.floor(self._scroll / self._maxScroll * (ch - barH))
        self:drawRect(cx + cw, cy, T.ScrollW, ch, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
        self:drawRect(cx + cw + 1, barY, T.ScrollW - 2, barH, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    end
end

-- ── Detalhe do animal ─────────────────────────────────────────────────────────

function EUI_AnimalPanel:drawAnimalInfo(cx, cy, cw, ch)
    local bg = T.BG2
    self:drawRect(cx, cy, cw, ch, bg.a, bg.r, bg.g, bg.b)

    local a = self._selAnimal
    if not a then
        local tc  = T.TextOff; local font = T.FontSm
        local msg = "Selecione um animal"
        local mw  = getTextManager():MeasureStringX(font, msg)
        self:drawText(msg, cx + math.floor((cw - mw) / 2), cy + 40,
            tc.r, tc.g, tc.b, tc.a, font)
        return
    end

    local font  = T.Font; local sm = T.FontSm
    local fhM   = getTextManager():getFontHeight(font)
    local fh    = getTextManager():getFontHeight(sm)
    local y     = cy + T.Pad; local tc = T.Text; local dim = T.TextDim

    -- Nome / tipo
    local name = "?"; local icon = "🐾"
    pcall(function() name = a:getAnimalType() or a:getName() or "?" end)
    for _, at in ipairs(ANIMAL_TYPES) do
        if name:find(at.id) then icon = at.icon; name = at.label; break end
    end
    self:drawText(icon .. "  " .. name, cx + T.Pad, y, tc.r, tc.g, tc.b, tc.a, font)
    y = y + fhM + T.Gap

    -- ID / sexo
    local sex = "?"; local age = "?"
    pcall(function() sex = a:isMale() and "Macho" or "Fêmea" end)
    pcall(function() age = tostring(a:getAge() or "?") end)
    self:drawText("Sexo: " .. sex .. "  Idade: " .. age, cx + T.Pad, y,
        dim.r, dim.g, dim.b, dim.a, sm)
    y = y + fh + T.Gap

    U.drawDivider(self, cx + T.Pad, y, cw - T.Pad * 2); y = y + T.Gap + 2

    -- Saúde
    local stats = {}
    local function addStat(label, cur, max, color)
        local pct = max > 0 and U.clamp(cur / max, 0, 1) or 0
        local col = color or (pct > 0.6 and T.Green or (pct > 0.3 and T.Yellow or T.Red))
        table.insert(stats, { label=label, pct=pct, val=string.format("%d / %d", cur, max), col=col })
    end

    local hp, hpM = 100, 100; pcall(function() hp = a:getHealth() end); pcall(function() hpM = a:getMaxHealth() end)
    addStat("Saúde", hp, hpM)

    local stress = 0
    pcall(function() stress = a:getStress() or 0 end)
    addStat("Stress", math.floor(stress * 100), 100, stress < 0.4 and T.Green or (stress < 0.7 and T.Yellow or T.Red))

    local hunger = 0
    pcall(function() hunger = a:getHunger() or 0 end)
    addStat("Fome", math.floor(hunger * 100), 100, hunger < 0.4 and T.Green or (hunger < 0.7 and T.Yellow or T.Red))

    local thirst = 0
    pcall(function() thirst = a:getThirst() or 0 end)
    addStat("Sede", math.floor(thirst * 100), 100, thirst < 0.4 and T.Green or (thirst < 0.7 and T.Yellow or T.Red))

    local barW = cw - T.Pad * 2 - 80 - 50
    for _, s in ipairs(stats) do
        self:drawText(s.label, cx + T.Pad, y + math.floor((20 - fh) / 2),
            dim.r, dim.g, dim.b, dim.a, sm)
        U.drawBar(self, cx + T.Pad + 80, y + math.floor((20 - BAR_H) / 2), barW, BAR_H, s.pct, s.col)
        local vw = getTextManager():MeasureStringX(sm, s.val)
        self:drawText(s.val, cx + cw - T.Pad - vw, y + math.floor((20 - fh) / 2),
            s.col.r, s.col.g, s.col.b, s.col.a, sm)
        y = y + 22 + T.PadSm
        if y > cy + ch - fh - T.Pad then break end
    end

    U.drawDivider(self, cx + T.Pad, y + T.PadSm, cw - T.Pad * 2); y = y + T.PadSm + T.Gap + 2

    -- Status textual
    local status = "Normal"
    pcall(function()
        if a.isPregnant and a:isPregnant() then status = "Prenha" end
        if a:isSick     and a:isSick()     then status = "Doente" end
        if a:isDead     and a:isDead()     then status = "Morto"  end
    end)
    local sc = status == "Normal" and T.TextGreen or (status == "Morto" and T.TextRed or T.TextYellow)
    self:drawText("Estado: " .. status, cx + T.Pad, y, sc.r, sc.g, sc.b, sc.a, sm)
end

-- ── Aba Pecuária ──────────────────────────────────────────────────────────────

function EUI_AnimalPanel:drawFarmView(cx, cy, cw, ch)
    local font = T.Font; local sm = T.FontSm
    local fhM  = getTextManager():getFontHeight(font)
    local fh   = getTextManager():getFontHeight(sm)
    local y    = cy + T.Pad
    local tc   = T.Text; local dim = T.TextDim; local hdr = T.TextGreen

    -- Contagem por tipo
    local counts = {}
    for _, at in ipairs(ANIMAL_TYPES) do counts[at.id] = 0 end

    for _, a in ipairs(self._animals) do
        local atype = "?"
        pcall(function() atype = a:getAnimalType() or "?" end)
        for _, at in ipairs(ANIMAL_TYPES) do
            if atype:find(at.id) then
                counts[at.id] = (counts[at.id] or 0) + 1
                break
            end
        end
    end

    self:drawText("Resumo do rebanho", cx + T.Pad, y, hdr.r, hdr.g, hdr.b, hdr.a, font)
    y = y + fhM + T.Gap

    U.drawDivider(self, cx + T.Pad, y, cw - T.Pad * 2); y = y + T.Gap + 2

    local totalAnimals = #self._animals
    local cStr = string.format("Total: %d animais no raio de 12 tiles", totalAnimals)
    self:drawText(cStr, cx + T.Pad, y, dim.r, dim.g, dim.b, dim.a, sm)
    y = y + fh + T.Gap * 2

    -- Grid 2 colunas
    local col1X = cx + T.Pad
    local col2X = cx + math.floor(cw / 2)
    local colY  = y; local colI = 0

    for _, at in ipairs(ANIMAL_TYPES) do
        local n = counts[at.id] or 0
        if n > 0 then
            local xPos = colI % 2 == 0 and col1X or col2X
            local lCol = n > 0 and T.Text or dim
            local line = string.format("%s %s: %d", at.icon, at.label, n)
            self:drawText(line, xPos, colY, lCol.r, lCol.g, lCol.b, lCol.a, sm)
            if colI % 2 == 1 then colY = colY + fh + T.PadSm end
            colI = colI + 1
        end
    end
    if colI % 2 == 1 then colY = colY + fh + T.PadSm end

    colY = colY + T.Gap
    U.drawDivider(self, cx + T.Pad, colY, cw - T.Pad * 2)
    colY = colY + T.Gap + 2

    -- Dica de ação em massa
    self:drawText("Use a aba Animais para interagir individualmente.", cx + T.Pad, colY,
        dim.r, dim.g, dim.b, dim.a, sm)
    colY = colY + fh + T.PadSm
    self:drawText("Alimente, ordunhe ou tosuqie cada animal selecionado.", cx + T.Pad, colY,
        dim.r, dim.g, dim.b, dim.a, sm)
end

-- ── Mouse ─────────────────────────────────────────────────────────────────────

function EUI_AnimalPanel:onMouseDown(mx, my)
    EUI_BasePanel.onMouseDown(self, mx, my)
    if my <= T.TitleH then return end
    local cy   = self:contentY() + self._tabH
    local cx   = self:contentX()
    local listH = self.height - cy - T.Pad * 2 - T.BtnH - T.Gap

    if self._tab == "animais" and U.inRect(mx, my, cx, cy, LIST_W, listH) then
        local rel = my - cy + self._scroll
        local idx = math.floor(rel / (ROW_H + T.PadSm)) + 1
        if self._animals[idx] then self._selAnimal = self._animals[idx] end
    end
end

function EUI_AnimalPanel:onMouseWheel(del)
    local mx = self:getMouseX()
    if mx < self:contentX() + LIST_W then
        self._scroll = U.clamp(self._scroll - del * ROW_H, 0, self._maxScroll)
    end
    return true
end

-- ── Registro ──────────────────────────────────────────────────────────────────

Events.OnKeyPressed.Add(function(key)
    if key == EUI.getKey("Animals") then
        if EUI._animalPanel then
            EUI._animalPanel:setVisible(not EUI._animalPanel:isVisible())
            if EUI._animalPanel:isVisible() then EUI._animalPanel:scanAnimals() end
            return
        end
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local p  = EUI_AnimalPanel:new(
            math.floor((sw - PANEL_W) / 2),
            math.floor((sh - PANEL_H) / 2), 0)
        p:initialise(); p:instantiate(); p:addToUIManager(); p:setVisible(true)
        EUI._animalPanel = p
    end
end)
