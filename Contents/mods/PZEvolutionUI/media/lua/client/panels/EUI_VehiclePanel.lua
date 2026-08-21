-- EUI_VehiclePanel.lua — mecânica de veículos

EUI = EUI or {}

EUI_VehiclePanel = EUI_BasePanel:derive("EUI_VehiclePanel")

local T = EUI.Theme
local U = EUI.Utils

local PANEL_W   = 480
local PANEL_H   = 560
local COL_L_W   = 200   -- coluna esquerda (resumo)
local GAP       = 8
local ROW_H     = 22
local BAR_H     = 6
local SECTION_H = 20

-- Partes do veículo que queremos exibir, em ordem, com label PT-BR
local PART_DEFS = {
    { id="Engine",         label="Motor"          },
    { id="Battery",        label="Bateria"        },
    { id="GasTank",        label="Tanque"         },
    { id="Muffler",        label="Escapamento"    },
    { id="Brake",          label="Freios"         },
    { id="TireFrontLeft",  label="Pneu DF"        },
    { id="TireFrontRight", label="Pneu DT"        },
    { id="TireRearLeft",   label="Pneu TE"        },
    { id="TireRearRight",  label="Pneu TD"        },
    { id="SuspensionFrontLeft",  label="Susp. DF" },
    { id="SuspensionFrontRight", label="Susp. DT" },
    { id="SuspensionRearLeft",   label="Susp. TE" },
    { id="SuspensionRearRight",  label="Susp. TD" },
    { id="WindshieldFront", label="Para-brisa F"  },
    { id="WindshieldRear",  label="Para-brisa T"  },
    { id="DoorFrontLeft",   label="Porta DF"      },
    { id="DoorFrontRight",  label="Porta DT"      },
    { id="DoorRearLeft",    label="Porta TE"      },
    { id="DoorRearRight",   label="Porta TD"      },
    { id="Trunk",           label="Porta-malas"   },
    { id="Hood",            label="Capô"          },
}

-- ── Constructor ───────────────────────────────────────────────────────────────

function EUI_VehiclePanel:new(x, y, playerNum)
    local o = EUI_BasePanel.new(self, x, y, PANEL_W, PANEL_H, "Mecânica do Veículo")
    o.playerNum       = playerNum or 0
    o.showCloseButton = true
    o._vehicle        = nil
    o._scroll         = 0
    o._maxScroll      = 0
    o._partCache      = {}
    return o
end

function EUI_VehiclePanel:initialise()
    EUI_BasePanel.initialise(self)
    self:buildSummarySection()
    self:buildScrollButtons()
end

-- ── Seção de resumo (coluna esquerda) ─────────────────────────────────────────

function EUI_VehiclePanel:buildSummarySection()
    -- Os dados de resumo são desenhados no render() diretamente
    -- (dependem do veículo atual e mudam a cada frame)
end

function EUI_VehiclePanel:buildScrollButtons()
    local bw = 24
    local bh = 24
    local rx = PANEL_W - T.Pad - bw
    local by = PANEL_H - T.Pad * 2 - bh * 2 - T.Gap

    self._btnUp = EUI_BaseButton:new(rx, by, bw, bh, "▲", self, function() self:scroll(-3) end, "icon")
    self._btnUp:initialise(); self._btnUp:instantiate(); self:addChild(self._btnUp)

    self._btnDn = EUI_BaseButton:new(rx, by + bh + T.Gap, bw, bh, "▼", self, function() self:scroll(3) end, "icon")
    self._btnDn:initialise(); self._btnDn:instantiate(); self:addChild(self._btnDn)
end

function EUI_VehiclePanel:scroll(delta)
    self._scroll = U.clamp(self._scroll + delta * ROW_H, 0, math.max(0, self._maxScroll))
end

-- ── Update ────────────────────────────────────────────────────────────────────

function EUI_VehiclePanel:update()
    EUI_BasePanel.update(self)
    local player = getSpecificPlayer(self.playerNum)
    if player then
        local veh = player:getVehicle()
        if veh ~= self._vehicle then
            self._vehicle   = veh
            self._scroll    = 0
            self._partCache = {}
        end
        if veh then self:cacheParts(veh) end
    end
end

function EUI_VehiclePanel:cacheParts(veh)
    self._partCache = {}
    for _, def in ipairs(PART_DEFS) do
        local ok, part = pcall(function() return veh:getPartById(def.id) end)
        if ok and part then
            local cond    = 100
            local condMax = 100
            pcall(function() cond    = part:getCondition()    end)
            pcall(function() condMax = part:getConditionMax() end)
            table.insert(self._partCache, {
                label   = def.label,
                id      = def.id,
                cond    = cond,
                condMax = condMax,
                pct     = condMax > 0 and U.clamp(cond / condMax, 0, 1) or 0,
            })
        end
    end
    local listH    = self:contentH() - SECTION_H - T.Gap * 2
    local totalH   = #self._partCache * (ROW_H + T.Gap)
    self._maxScroll = math.max(0, totalH - listH)
end

-- ── Render ────────────────────────────────────────────────────────────────────

function EUI_VehiclePanel:render()
    local cy = self:contentY()
    local cx = self:contentX()
    local cw = self:contentW()

    local veh = self._vehicle
    if not veh then
        self:drawNoVehicle(cx, cy, cw)
        return
    end

    -- ── Linha de nome do veículo ──────────────────────────────────────────────
    local vname = ""
    pcall(function() vname = veh:getType():getName() or "" end)
    local font  = T.Font
    local fh    = getTextManager():getFontHeight(font)
    local tc    = T.Text
    self:drawText(vname, cx, cy, tc.r, tc.g, tc.b, tc.a, font)
    cy = cy + fh + T.Gap

    U.drawDivider(self, cx, cy, cw)
    cy = cy + T.Gap + 2

    -- ── Resumo rápido (combustível, motor, bateria) ───────────────────────────
    cy = self:drawQuickStats(cx, cy, cw, veh)

    U.drawDivider(self, cx, cy, cw)
    cy = cy + T.Gap + 2

    -- ── Lista de peças (scrollável) ────────────────────────────────────────────
    local listH = self.height - cy - T.Pad * 3 - 24  -- 24 = botões scroll
    self:drawPartsList(cx, cy, cw - 30, listH)
end

function EUI_VehiclePanel:drawNoVehicle(cx, cy, cw)
    local font = T.Font
    local msg  = "Nenhum veículo acessado"
    local mw   = getTextManager():MeasureStringX(font, msg)
    local tc   = T.TextOff
    self:drawText(msg, cx + math.floor((cw - mw) / 2), cy + 40, tc.r, tc.g, tc.b, tc.a, font)
end

function EUI_VehiclePanel:drawQuickStats(cx, cy, cw, veh)
    local fontSm = T.FontSm
    local fh     = getTextManager():getFontHeight(fontSm)
    local barW   = cw - 90
    local labelW = 80

    local stats = {}

    -- Combustível
    local fuelCur, fuelMax = 0, 1
    pcall(function() fuelCur = veh:getCurrentFuel()  end)
    pcall(function() fuelMax = veh:getFuelMax() or 1 end)
    table.insert(stats, {
        label = "Combustível",
        pct   = fuelMax > 0 and U.clamp(fuelCur / fuelMax, 0, 1) or 0,
        val   = string.format("%.1f / %.1f L", fuelCur, fuelMax),
        color = nil,
    })

    -- Motor
    local engCond = 100
    pcall(function()
        local ep = veh:getPartById("Engine")
        if ep then engCond = ep:getCondition() end
    end)
    table.insert(stats, {
        label = "Motor",
        pct   = U.clamp(engCond / 100, 0, 1),
        val   = string.format("%d%%", math.floor(engCond)),
        color = nil,
    })

    -- Bateria
    local batPct = 1
    pcall(function()
        local bp = veh:getPartById("Battery")
        if bp then
            local bc  = bp:getCondition()
            local bcm = bp:getConditionMax()
            batPct = bcm > 0 and bc / bcm or 0
        end
    end)
    table.insert(stats, {
        label = "Bateria",
        pct   = U.clamp(batPct, 0, 1),
        val   = string.format("%d%%", math.floor(batPct * 100)),
        color = T.Blue,
    })

    -- Temperatura do motor
    local temp = 0
    pcall(function() temp = veh:getEngineTemperature() or 0 end)
    local tempCol = temp > 100 and T.Red or (temp > 80 and T.Yellow or T.TextDim)
    table.insert(stats, {
        label = "Temperatura",
        pct   = U.clamp(temp / 120, 0, 1),
        val   = string.format("%.0f°C", temp),
        color = tempCol,
    })

    for _, s in ipairs(stats) do
        local col = s.color or (s.pct > 0.5 and T.Green or (s.pct > 0.25 and T.Yellow or T.Red))
        local tc  = T.TextDim

        self:drawText(s.label, cx, cy + math.floor((ROW_H - fh) / 2), tc.r, tc.g, tc.b, tc.a, fontSm)
        U.drawBar(self, cx + labelW, cy + math.floor((ROW_H - BAR_H) / 2), barW - 50, BAR_H, s.pct, col)

        local vw = getTextManager():MeasureStringX(fontSm, s.val)
        self:drawText(s.val, cx + cw - vw, cy + math.floor((ROW_H - fh) / 2), col.r, col.g, col.b, col.a, fontSm)

        cy = cy + ROW_H + T.PadSm
    end

    return cy + T.Gap
end

function EUI_VehiclePanel:drawPartsList(cx, cy, cw, listH)
    -- Clip region: fundo da lista
    local bg = T.BG2
    self:drawRect(cx, cy, cw, listH, bg.a, bg.r, bg.g, bg.b)

    local fontSm = T.FontSm
    local fh     = getTextManager():getFontHeight(fontSm)
    local labelW = 100
    local barW   = cw - labelW - 50

    local yOff   = cy - self._scroll
    local yEnd   = cy + listH

    for _, part in ipairs(self._partCache) do
        local rowY = yOff
        yOff = yOff + ROW_H + T.Gap

        -- Só desenha se visível na janela de clip
        if rowY + ROW_H >= cy and rowY <= yEnd then
            local col = part.pct > 0.6 and T.Green or (part.pct > 0.3 and T.Yellow or T.Red)
            local tc  = T.TextDim

            -- Fundo alternado
            if math.floor((rowY - cy + self._scroll) / (ROW_H + T.Gap)) % 2 == 0 then
                local rbg = T.BG3
                self:drawRect(cx, rowY, cw, ROW_H, rbg.a, rbg.r, rbg.g, rbg.b)
            end

            -- Label da peça
            self:drawText(part.label, cx + T.PadSm, rowY + math.floor((ROW_H - fh) / 2),
                tc.r, tc.g, tc.b, tc.a, fontSm)

            -- Barra de condição
            U.drawBar(self, cx + labelW, rowY + math.floor((ROW_H - BAR_H) / 2),
                barW, BAR_H, part.pct, col)

            -- Valor %
            local vs = string.format("%d%%", math.floor(part.pct * 100))
            local vw = getTextManager():MeasureStringX(fontSm, vs)
            self:drawText(vs, cx + cw - vw, rowY + math.floor((ROW_H - fh) / 2),
                col.r, col.g, col.b, col.a, fontSm)
        end
    end

    -- Scrollbar lateral
    if self._maxScroll > 0 then
        local totalH = #self._partCache * (ROW_H + T.Gap)
        local ratio  = listH / totalH
        local barH   = math.max(20, math.floor(listH * ratio))
        local barY   = cy + math.floor(self._scroll / self._maxScroll * (listH - barH))
        local sbg    = T.BG3
        local sfg    = T.Border
        self:drawRect(cx + cw + 2, cy, T.ScrollW, listH, sbg.a, sbg.r, sbg.g, sbg.b)
        self:drawRect(cx + cw + 3, barY, T.ScrollW - 2, barH, sfg.a, sfg.r, sfg.g, sfg.b)
    end
end

function EUI_VehiclePanel:onMouseWheel(del)
    self:scroll(-del * 2)
    return true
end

-- ── Registro ──────────────────────────────────────────────────────────────────

local function openVehiclePanel(playerNum)
    if EUI._vehiclePanel then
        EUI._vehiclePanel:setVisible(not EUI._vehiclePanel:isVisible())
        return
    end
    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local p  = EUI_VehiclePanel:new(
        math.floor((sw - PANEL_W) / 2),
        math.floor((sh - PANEL_H) / 2),
        playerNum or 0
    )
    p:initialise(); p:instantiate(); p:addToUIManager(); p:setVisible(true)
    EUI._vehiclePanel = p
end

-- Abre ao entrar/sair de veículo (abre automaticamente ao sentar no carro)
Events.OnEnterVehicle.Add(function(player)
    if player:getPlayerNum() ~= 0 then return end
    openVehiclePanel(0)
end)

Events.OnExitVehicle.Add(function(player)
    if player:getPlayerNum() ~= 0 then return end
    if EUI._vehiclePanel then EUI._vehiclePanel:setVisible(false) end
end)
