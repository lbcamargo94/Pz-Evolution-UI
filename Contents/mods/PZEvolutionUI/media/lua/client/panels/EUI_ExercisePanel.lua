-- EUI_ExercisePanel.lua — painel de exercícios (B42)

EUI = EUI or {}

EUI_ExercisePanel = EUI_BasePanel:derive("EUI_ExercisePanel")

local T = EUI.Theme
local U = EUI.Utils

local PANEL_W  = 420
local PANEL_H  = 500
local ROW_H    = 36
local BAR_H    = 8

-- Exercícios disponíveis no B42
local EXERCISES = {
    { id="StrengthExercise",   label="Flexão",          perk="Strength",   icon="💪", sets=3, reps=10 },
    { id="FitnessExercise",    label="Polichinelo",     perk="Fitness",    icon="🤸", sets=3, reps=20 },
    { id="SprinterExercise",   label="Corrida",         perk="Sprinting",  icon="🏃", sets=1, reps=60 },
    { id="LightFootExercise",  label="Agachamento",     perk="Lightfooted",icon="🦵", sets=3, reps=15 },
    { id="NimbleExercise",     label="Prancha",         perk="Nimble",     icon="🧘", sets=1, reps=30 },
    { id="AimingExercise",     label="Mira (treino)",   perk="Aiming",     icon="🎯", sets=2, reps=10 },
    { id="ReloadExercise",     label="Recarga (treino)",perk="Reloading",  icon="🔫", sets=2, reps=10 },
}

-- ── Constructor ───────────────────────────────────────────────────────────────

function EUI_ExercisePanel:new(x, y, playerNum)
    local o = EUI_BasePanel.new(self, x, y, PANEL_W, PANEL_H, "Exercício")
    o.playerNum       = playerNum or 0
    o.showCloseButton = true
    o._selExercise    = nil
    o._scroll         = 0
    o._maxScroll      = 0
    o._doing          = false
    return o
end

function EUI_ExercisePanel:initialise()
    EUI_BasePanel.initialise(self)
    self:buildButtons()
    local listH = self:contentH() - T.Gap
    self._maxScroll = math.max(0, #EXERCISES * (ROW_H + T.PadSm) - listH)
end

function EUI_ExercisePanel:buildButtons()
    local bw = math.floor((self:contentW() - T.Gap) / 2)
    local bh = T.BtnH
    local cx = self:contentX()
    local by = self.height - T.Pad * 2 - bh

    self._btnStart = EUI_BaseButton:new(cx, by, bw, bh, "Iniciar", self,
        EUI_ExercisePanel.onStart, "primary")
    self._btnStart:initialise(); self._btnStart:instantiate(); self:addChild(self._btnStart)

    self._btnStop = EUI_BaseButton:new(cx + bw + T.Gap, by, bw, bh, "Parar", self,
        EUI_ExercisePanel.onStop, "danger")
    self._btnStop:initialise(); self._btnStop:instantiate(); self:addChild(self._btnStop)
end

-- ── Ações ─────────────────────────────────────────────────────────────────────

function EUI_ExercisePanel:onStart()
    local ex     = self._selExercise
    local player = getSpecificPlayer(self.playerNum)
    if not ex or not player then return end
    pcall(function()
        -- B42: ISTimedActionQueue com ISExerciseAction (ou nome equivalente)
        if ISExerciseAction then
            ISTimedActionQueue.add(ISExerciseAction:new(player, ex.id, ex.sets, ex.reps))
        end
        self._doing = true
    end)
end

function EUI_ExercisePanel:onStop()
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    pcall(function() ISTimedActionQueue.clear(player) end)
    self._doing = false
end

function EUI_ExercisePanel:update()
    EUI_BasePanel.update(self)
    if self._doing then
        local player = getSpecificPlayer(self.playerNum)
        if player then
            local queue = nil
            pcall(function() queue = ISTimedActionQueue.getTimedActionQueue(player) end)
            if not queue or queue:isEmpty() then self._doing = false end
        end
    end
end

-- ── Render ────────────────────────────────────────────────────────────────────

function EUI_ExercisePanel:render()
    local cx   = self:contentX()
    local cy   = self:contentY()
    local cw   = self:contentW()
    local sm   = T.FontSm
    local font = T.Font
    local fhSm = getTextManager():getFontHeight(sm)
    local dim  = T.TextDim

    -- Status de exercício em andamento
    if self._doing then
        local gc = T.Green
        local msg = "● Exercitando…"
        self:drawText(msg, cx, cy, gc.r, gc.g, gc.b, gc.a, sm)
    else
        local tc = dim
        self:drawText("Selecione e inicie um exercício", cx, cy, tc.r, tc.g, tc.b, tc.a, sm)
    end
    cy = cy + fhSm + T.Gap

    U.drawDivider(self, cx, cy, cw); cy = cy + T.Gap + 2

    -- Atributos físicos do jogador
    local player = getSpecificPlayer(self.playerNum)
    local fh     = getTextManager():getFontHeight(font)
    cy = self:drawCharStats(cx, cy, cw, player, sm, fhSm)

    U.drawDivider(self, cx, cy, cw); cy = cy + T.Gap + 2

    -- Header lista
    self:drawText("Exercícios disponíveis:", cx, cy, dim.r, dim.g, dim.b, dim.a, sm)
    cy = cy + fhSm + T.PadSm

    -- Lista
    local listH = self.height - cy - T.Pad * 2 - T.BtnH - T.Gap
    self:drawExerciseList(cx, cy, cw, listH, player)
end

function EUI_ExercisePanel:drawCharStats(cx, cy, cw, player, sm, fh)
    -- Mostra fitness + strength atuais
    local stats = {
        { perk="Fitness",  label="Resistência" },
        { perk="Strength", label="Força"       },
        { perk="Sprinting",label="Corrida"     },
    }
    local barW = cw - 100 - 50
    for _, s in ipairs(stats) do
        local lvl = 0; local xp = 0; local xpMax = 1
        if player then
            pcall(function()
                local pk = PerkFactory.getPerkFromString(s.perk)
                if pk then
                    lvl    = player:getPerkLevel(pk)
                    xp     = player:getXp():getXP(pk)
                    xpMax  = player:getXp():getPerkXpNeeded(pk, lvl + 1) or 1
                end
            end)
        end
        local pct = xpMax > 0 and U.clamp(xp / xpMax, 0, 1) or 0
        local dim = T.TextDim; local gc = T.Green
        self:drawText(s.label, cx, cy + math.floor((20 - fh) / 2), dim.r, dim.g, dim.b, dim.a, sm)
        self:drawText(tostring(lvl), cx + 100, cy + math.floor((20 - fh) / 2),
            gc.r, gc.g, gc.b, gc.a, sm)
        U.drawBar(self, cx + 120, cy + math.floor((20 - 6) / 2), barW, 6, pct, T.Blue)
        local xpStr = string.format("%d / %d xp", xp, xpMax)
        local xw    = getTextManager():MeasureStringX(sm, xpStr)
        self:drawText(xpStr, cx + cw - xw, cy + math.floor((20 - fh) / 2),
            dim.r, dim.g, dim.b, dim.a, sm)
        cy = cy + 22 + T.PadSm
    end
    return cy + T.Gap
end

function EUI_ExercisePanel:drawExerciseList(cx, cy, cw, listH, player)
    local sm  = T.FontSm
    local fh  = getTextManager():getFontHeight(sm)
    local bg  = T.BG2
    self:drawRect(cx, cy, cw, listH, bg.a, bg.r, bg.g, bg.b)

    local yOff = cy - self._scroll
    for i, ex in ipairs(EXERCISES) do
        if yOff + ROW_H >= cy and yOff <= cy + listH then
            local sel = ex == self._selExercise
            local rbg = sel and T.BG_Select or (i % 2 == 0 and T.BG3 or T.BG2)
            self:drawRect(cx, yOff, cw, ROW_H, rbg.a, rbg.r, rbg.g, rbg.b)
            if sel then
                self:drawRect(cx, yOff, 2, ROW_H, T.Green.a, T.Green.r, T.Green.g, T.Green.b)
            end

            -- Nível da perícia relacionada
            local perkLvl = 0
            if player then
                pcall(function()
                    local pk = PerkFactory.getPerkFromString(ex.perk)
                    if pk then perkLvl = player:getPerkLevel(pk) end
                end)
            end

            local tc = sel and T.TextGreen or T.Text
            local iconLabel = ex.icon .. " " .. ex.label
            self:drawText(iconLabel, cx + T.PadSm + (sel and 4 or 0),
                yOff + math.floor((ROW_H - fh * 2 - T.PadSm) / 2),
                tc.r, tc.g, tc.b, tc.a, sm)

            local sub = string.format("%d séries × %d reps", ex.sets, ex.reps)
            local dim = T.TextDim
            self:drawText(sub, cx + T.PadSm + (sel and 4 or 0),
                yOff + math.floor((ROW_H - fh * 2 - T.PadSm) / 2) + fh + T.PadSm,
                dim.r, dim.g, dim.b, dim.a, sm)

            -- Nível da perk à direita
            local lvlStr = string.format("Nív.%d", perkLvl)
            local lw     = getTextManager():MeasureStringX(sm, lvlStr)
            local lCol   = perkLvl >= 5 and T.TextGreen or T.TextDim
            self:drawText(lvlStr, cx + cw - lw - T.PadSm, yOff + math.floor((ROW_H - fh) / 2),
                lCol.r, lCol.g, lCol.b, lCol.a, sm)
        end
        yOff = yOff + ROW_H + T.PadSm
    end

    if self._maxScroll > 0 then
        local totalH = #EXERCISES * (ROW_H + T.PadSm)
        local ratio  = listH / totalH
        local barH   = math.max(16, math.floor(listH * ratio))
        local barY   = cy + math.floor(self._scroll / self._maxScroll * (listH - barH))
        self:drawRect(cx + cw, cy, T.ScrollW, listH, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
        self:drawRect(cx + cw + 1, barY, T.ScrollW - 2, barH, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    end
end

-- ── Mouse ─────────────────────────────────────────────────────────────────────

function EUI_ExercisePanel:onMouseDown(mx, my)
    EUI_BasePanel.onMouseDown(self, mx, my)
    if my <= T.TitleH then return end
    local cx     = self:contentX()
    local cy     = self:contentY()
    local sm     = T.FontSm
    local fhSm   = getTextManager():getFontHeight(sm)
    -- estimativa do topo da lista (2 linhas de header + stats + divs)
    local listTop = cy + fhSm + T.Gap + 2 + (22 + T.PadSm) * 3 + T.Gap * 3 + fhSm + T.PadSm
    local listH   = self.height - listTop - T.Pad * 2 - T.BtnH - T.Gap

    if U.inRect(mx, my, cx, listTop, self:contentW(), listH) then
        local rel = my - listTop + self._scroll
        local idx = math.floor(rel / (ROW_H + T.PadSm)) + 1
        if EXERCISES[idx] then self._selExercise = EXERCISES[idx] end
    end
end

function EUI_ExercisePanel:onMouseWheel(del)
    self._scroll = U.clamp(self._scroll - del * ROW_H, 0, self._maxScroll)
    return true
end

-- ── Registro ──────────────────────────────────────────────────────────────────

Events.OnKeyPressed.Add(function(key)
    if key == getCore():getKey("Exercise") then
        if EUI._exercisePanel then
            EUI._exercisePanel:setVisible(not EUI._exercisePanel:isVisible())
            return
        end
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local p  = EUI_ExercisePanel:new(
            math.floor((sw - PANEL_W) / 2),
            math.floor((sh - PANEL_H) / 2), 0)
        p:initialise(); p:instantiate(); p:addToUIManager(); p:setVisible(true)
        EUI._exercisePanel = p
    end
end)
