-- EUI_GeneratorPanel.lua — painel de geradores

EUI = EUI or {}

EUI_GeneratorPanel = EUI_BasePanel:derive("EUI_GeneratorPanel")

local T = EUI.Theme
local U = EUI.Utils

local PANEL_W  = 340
local PANEL_H  = 380
local ROW_H    = 28
local BAR_H    = 8

-- ── Constructor ───────────────────────────────────────────────────────────────

function EUI_GeneratorPanel:new(x, y, playerNum)
    local o = EUI_BasePanel.new(self, x, y, PANEL_W, PANEL_H, "Gerador")
    o.playerNum       = playerNum or 0
    o.showCloseButton = true
    o._generator      = nil  -- IsoGenerator atual
    return o
end

function EUI_GeneratorPanel:initialise()
    EUI_BasePanel.initialise(self)
    self:buildButtons()
end

function EUI_GeneratorPanel:buildButtons()
    local bw  = math.floor((self:contentW() - T.Gap) / 2)
    local bh  = T.BtnH
    local by  = self.height - T.Pad * 2 - bh
    local cx  = self:contentX()

    self._btnToggle = EUI_BaseButton:new(cx, by, bw, bh, "Ligar / Desligar", self,
        EUI_GeneratorPanel.onToggle, "primary")
    self._btnToggle:initialise(); self._btnToggle:instantiate(); self:addChild(self._btnToggle)

    self._btnFuel = EUI_BaseButton:new(cx + bw + T.Gap, by, bw, bh, "Abastecer", self,
        EUI_GeneratorPanel.onRefuel, "ghost")
    self._btnFuel:initialise(); self._btnFuel:instantiate(); self:addChild(self._btnFuel)
end

-- ── Update ────────────────────────────────────────────────────────────────────

function EUI_GeneratorPanel:update()
    EUI_BasePanel.update(self)
    -- Atualiza referência ao gerador mais próximo do jogador
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    local sq = player:getSquare()
    if not sq then return end
    -- Procura gerador num raio de 2 tiles
    for dx = -2, 2 do
        for dy = -2, 2 do
            local s = getCell():getGridSquare(sq:getX() + dx, sq:getY() + dy, sq:getZ())
            if s then
                local objs = s:getObjects()
                for i = 0, objs:size() - 1 do
                    local obj = objs:get(i)
                    if obj and obj.getType and obj:getType() == IsoObjectType.generator then
                        self._generator = obj
                        return
                    end
                end
            end
        end
    end
end

-- ── Ações ─────────────────────────────────────────────────────────────────────

function EUI_GeneratorPanel:onToggle()
    local player = getSpecificPlayer(self.playerNum)
    local gen    = self._generator
    if not player or not gen then return end
    pcall(function()
        if gen:isActivated() then
            ISTimedActionQueue.add(ISToggleGenerator:new(player, gen, false))
        else
            ISTimedActionQueue.add(ISToggleGenerator:new(player, gen, true))
        end
    end)
end

function EUI_GeneratorPanel:onRefuel()
    local player = getSpecificPlayer(self.playerNum)
    local gen    = self._generator
    if not player or not gen then return end
    pcall(function()
        ISTimedActionQueue.add(ISRefuelGenerator:new(player, gen,
            player:getInventory():getItemFromType("Base.Gasoline")))
    end)
end

-- ── Render ────────────────────────────────────────────────────────────────────

function EUI_GeneratorPanel:render()
    local cx   = self:contentX()
    local cy   = self:contentY()
    local cw   = self:contentW()
    local font = T.Font
    local sm   = T.FontSm
    local fh   = getTextManager():getFontHeight(font)
    local fhSm = getTextManager():getFontHeight(sm)

    local gen = self._generator
    if not gen then
        local tc  = T.TextOff
        local msg = "Nenhum gerador próximo"
        local mw  = getTextManager():MeasureStringX(font, msg)
        self:drawText(msg, cx + math.floor((cw - mw) / 2), cy + 40, tc.r, tc.g, tc.b, tc.a, font)
        return
    end

    -- Status: Ligado / Desligado
    local running = false
    pcall(function() running = gen:isActivated() end)
    local statusTxt = running and "● LIGADO" or "○ DESLIGADO"
    local statusCol = running and T.Green or T.TextOff
    self:drawText(statusTxt, cx, cy, statusCol.r, statusCol.g, statusCol.b, statusCol.a, font)
    cy = cy + fh + T.Gap

    U.drawDivider(self, cx, cy, cw)
    cy = cy + T.Gap + 4

    -- Combustível
    local fuel, fuelMax = 0, 1
    pcall(function() fuel    = gen:getFuel()    end)
    pcall(function() fuelMax = gen:getFuelMax() end)
    local fuelPct = fuelMax > 0 and U.clamp(fuel / fuelMax, 0, 1) or 0
    local fuelCol = fuelPct > 0.4 and T.Green or (fuelPct > 0.15 and T.Yellow or T.Red)

    local dim = T.TextDim
    self:drawText("Combustível", cx, cy + math.floor((ROW_H - fhSm) / 2), dim.r, dim.g, dim.b, dim.a, sm)
    U.drawBar(self, cx + 110, cy + math.floor((ROW_H - BAR_H) / 2), cw - 170, BAR_H, fuelPct, fuelCol)
    local fuelStr = string.format("%.1f / %.1f L", fuel, fuelMax)
    local fw = getTextManager():MeasureStringX(sm, fuelStr)
    self:drawText(fuelStr, cx + cw - fw, cy + math.floor((ROW_H - fhSm) / 2), fuelCol.r, fuelCol.g, fuelCol.b, fuelCol.a, sm)
    cy = cy + ROW_H + T.Gap

    -- Consumo por hora
    local consume = 0
    pcall(function() consume = gen:getFuelConsumption() or 0 end)
    self:drawText("Consumo/h", cx, cy + math.floor((ROW_H - fhSm) / 2), dim.r, dim.g, dim.b, dim.a, sm)
    local cStr = string.format("%.2f L/h", consume)
    local cw2  = getTextManager():MeasureStringX(sm, cStr)
    self:drawText(cStr, cx + cw - cw2, cy + math.floor((ROW_H - fhSm) / 2), dim.r, dim.g, dim.b, dim.a, sm)
    cy = cy + ROW_H + T.Gap

    -- Autonomia estimada
    if running and consume > 0 then
        local hours = fuel / consume
        local hoursStr = string.format("Autonomia: %.1f h", hours)
        local hCol = hours > 4 and T.TextGreen or (hours > 1 and T.TextYellow or T.TextRed)
        self:drawText(hoursStr, cx, cy + math.floor((ROW_H - fhSm) / 2), hCol.r, hCol.g, hCol.b, hCol.a, sm)
        cy = cy + ROW_H + T.Gap
    end

    U.drawDivider(self, cx, cy, cw)
    cy = cy + T.Gap + 4

    -- Zonas conectadas
    local connCount = 0
    pcall(function() connCount = gen:getConnectedCount() or 0 end)
    local connStr = string.format("Zonas conectadas: %d", connCount)
    local cc = connCount > 0 and T.TextGreen or T.TextDim
    self:drawText(connStr, cx, cy + math.floor((ROW_H - fhSm) / 2), cc.r, cc.g, cc.b, cc.a, sm)
    cy = cy + ROW_H + T.Gap

    -- Condição do gerador
    local cond, condMax = 100, 100
    pcall(function() cond    = gen:getCondition()    end)
    pcall(function() condMax = gen:getConditionMax() end)
    local condPct = condMax > 0 and U.clamp(cond / condMax, 0, 1) or 1
    local condCol = condPct > 0.5 and T.Green or (condPct > 0.25 and T.Yellow or T.Red)

    self:drawText("Condição", cx, cy + math.floor((ROW_H - fhSm) / 2), dim.r, dim.g, dim.b, dim.a, sm)
    U.drawBar(self, cx + 110, cy + math.floor((ROW_H - BAR_H) / 2), cw - 170, BAR_H, condPct, condCol)
    local condStr = string.format("%d%%", math.floor(condPct * 100))
    local cdw = getTextManager():MeasureStringX(sm, condStr)
    self:drawText(condStr, cx + cw - cdw, cy + math.floor((ROW_H - fhSm) / 2), condCol.r, condCol.g, condCol.b, condCol.a, sm)
end

-- ── Registro ──────────────────────────────────────────────────────────────────

Events.OnKeyPressed.Add(function(key)
    if key == EUI.getKey("Generator") then
        if EUI._generatorPanel then
            EUI._generatorPanel:setVisible(not EUI._generatorPanel:isVisible())
            return
        end
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local p  = EUI_GeneratorPanel:new(
            math.floor((sw - PANEL_W) / 2),
            math.floor((sh - PANEL_H) / 2), 0)
        p:initialise(); p:instantiate(); p:addToUIManager(); p:setVisible(true)
        EUI._generatorPanel = p
    end
end)
