-- EUI_SettingsPanel.lua — painel de configurações do mod (B42)

EUI = EUI or {}

EUI_SettingsPanel = EUI_BasePanel:derive("EUI_SettingsPanel")

local T = EUI.Theme
local U = EUI.Utils

local PANEL_W  = 520
local PANEL_H  = 580
local TAB_W    = 130
local ROW_H    = 30
local INDENT   = 12

-- Definição declarativa das configurações por aba
local TABS = {
    {
        id    = "hud",
        label = "HUD",
        icon  = "📊",
        rows  = {
            { type="toggle", key="hudEnabled",    label="HUD ativo"              },
            { type="select", key="hudPosition",   label="Posição",
              opts={ "bottomLeft","bottomRight","topLeft","topRight" },
              labels={ "Inferior-Esq","Inferior-Dir","Superior-Esq","Superior-Dir" } },
            { type="slider", key="hudOpacity",    label="Opacidade",  min=0.3, max=1.0, step=0.05 },
        },
    },
    {
        id    = "paineis",
        label = "Painéis",
        icon  = "🗂",
        rows  = {
            { type="toggle", key="panelInventory", label="Inventário"    },
            { type="toggle", key="panelCharacter", label="Personagem"    },
            { type="toggle", key="panelVehicle",   label="Veículo"       },
            { type="toggle", key="panelCrafting",  label="Crafting"      },
            { type="toggle", key="panelGenerator", label="Gerador"       },
            { type="toggle", key="panelBuilding",  label="Construção"    },
            { type="toggle", key="panelAnimal",    label="Animais"       },
            { type="toggle", key="panelCooking",   label="Culinária"     },
            { type="toggle", key="panelExercise",  label="Exercício"     },
            { type="toggle", key="panelLiquid",    label="Líquidos"      },
            { type="toggle", key="panelChicken",   label="Galinheiro"    },
            { type="toggle", key="panelCollect",   label="Coleta"        },
            { type="toggle", key="panelBottle",    label="Recipientes"   },
        },
    },
    {
        id    = "gameplay",
        label = "Gameplay",
        icon  = "⚙",
        rows  = {
            { type="toggle", key="autoOpenVehicle", label="Abrir veículo automaticamente" },
            { type="select", key="animalRadius",    label="Raio de animais (tiles)",
              opts={6,12,20}, labels={"6 tiles","12 tiles","20 tiles"} },
            { type="select", key="chickenRadius",   label="Raio do galinheiro (tiles)",
              opts={8,16,24}, labels={"8 tiles","16 tiles","24 tiles"} },
        },
    },
    {
        id    = "visual",
        label = "Visual",
        icon  = "🎨",
        rows  = {
            { type="select", key="theme", label="Tema de cor",
              opts={"dark","darker","green"},
              labels={"Escuro (padrão)","Escuro+","Verde"} },
        },
    },
}

-- ── Constructor ───────────────────────────────────────────────────────────────

function EUI_SettingsPanel:new(x, y)
    local o = EUI_BasePanel.new(self, x, y, PANEL_W, PANEL_H, "Configurações — PZ Evolution UI")
    o.showCloseButton = true
    o._selTab   = TABS[1].id
    o._scroll   = 0
    o._maxScroll = 0
    o._pending  = {}  -- cópia de trabalho das settings
    return o
end

function EUI_SettingsPanel:initialise()
    EUI_BasePanel.initialise(self)
    self:buildTabButtons()
    self:buildFooterButtons()
    self:copySettings()
end

function EUI_SettingsPanel:buildTabButtons()
    local bh = 26
    local bw = TAB_W
    local cx = self:contentX()
    local cy = self:contentY()
    self._tabBtns = {}
    for i, tab in ipairs(TABS) do
        local btn = EUI_BaseButton:new(cx, cy + (bh + T.PadSm) * (i - 1),
            bw, bh, tab.icon .. " " .. tab.label, self,
            function() self:setTab(tab.id) end, "ghost")
        btn:initialise(); btn:instantiate(); self:addChild(btn)
        self._tabBtns[tab.id] = btn
    end
    self._tabBlockH = (#TABS) * (bh + T.PadSm)
end

function EUI_SettingsPanel:buildFooterButtons()
    local bw = math.floor((self:contentW() - T.Gap) / 2)
    local bh = T.BtnH
    local cx = self:contentX()
    local by = self.height - T.Pad * 2 - bh

    self._btnSave = EUI_BaseButton:new(cx, by, bw, bh, "Salvar", self,
        EUI_SettingsPanel.onSave, "primary")
    self._btnSave:initialise(); self._btnSave:instantiate(); self:addChild(self._btnSave)

    self._btnCancel = EUI_BaseButton:new(cx + bw + T.Gap, by, bw, bh, "Cancelar", self,
        EUI_SettingsPanel.onCancel, "ghost")
    self._btnCancel:initialise(); self._btnCancel:instantiate(); self:addChild(self._btnCancel)
end

function EUI_SettingsPanel:copySettings()
    self._pending = {}
    for k, v in pairs(EUI.Settings) do self._pending[k] = v end
end

function EUI_SettingsPanel:setTab(tabId)
    self._selTab = tabId; self._scroll = 0
    self:recalcScroll()
end

function EUI_SettingsPanel:recalcScroll()
    local tab = self:getCurTab()
    if not tab then return end
    local contentH = self:contentH() - T.Pad
    local rowsH    = #tab.rows * (ROW_H + T.PadSm)
    self._maxScroll = math.max(0, rowsH - contentH)
end

function EUI_SettingsPanel:getCurTab()
    for _, t in ipairs(TABS) do if t.id == self._selTab then return t end end
    return TABS[1]
end

-- ── Ações ─────────────────────────────────────────────────────────────────────

function EUI_SettingsPanel:onSave()
    for k, v in pairs(self._pending) do EUI.Settings[k] = v end
    EUI.saveSettings()
    EUI.applyTheme()
    self:setVisible(false)
end

function EUI_SettingsPanel:onCancel()
    self:copySettings()  -- descarta pending
    self:setVisible(false)
end

function EUI_SettingsPanel:toggleValue(key)
    self._pending[key] = not self._pending[key]
end

function EUI_SettingsPanel:cycleSelect(row, forward)
    local cur = self._pending[row.key]
    local idx = 1
    for i, v in ipairs(row.opts) do
        if v == cur then idx = i; break end
    end
    idx = idx + (forward and 1 or -1)
    if idx < 1 then idx = #row.opts end
    if idx > #row.opts then idx = 1 end
    self._pending[row.key] = row.opts[idx]
end

function EUI_SettingsPanel:adjustSlider(row, delta)
    local v   = (self._pending[row.key] or row.min) + delta * row.step
    self._pending[row.key] = U.clamp(v, row.min, row.max)
    -- Arredonda para 2 casas (evita float drift)
    self._pending[row.key] = math.floor(self._pending[row.key] * 100 + 0.5) / 100
end

-- ── Render ────────────────────────────────────────────────────────────────────

function EUI_SettingsPanel:render()
    local cx  = self:contentX()
    local cy  = self:contentY()
    local cw  = self:contentW()

    -- Divisor vertical (tabs | conteúdo)
    local dh = self.height - cy - T.Pad * 2 - T.BtnH - T.Gap
    self:drawRect(cx + TAB_W + math.floor(T.Gap / 2), cy, 1, dh,
        T.Border.a, T.Border.r, T.Border.g, T.Border.b)

    -- Indicadores de aba ativa
    for _, tab in ipairs(TABS) do
        if tab.id == self._selTab then
            local bh  = 26
            local idx = 0
            for i, t in ipairs(TABS) do if t.id == tab.id then idx = i - 1; break end end
            local ay  = cy + idx * (bh + T.PadSm)
            self:drawRect(cx + TAB_W - 2, ay, 2, bh,
                T.Green.a, T.Green.r, T.Green.g, T.Green.b)
        end
    end

    local rx = cx + TAB_W + T.Gap
    local rw = cw - TAB_W - T.Gap
    self:drawRows(rx, cy, rw, dh)
end

function EUI_SettingsPanel:drawRows(cx, cy, cw, ch)
    local tab = self:getCurTab()
    if not tab then return end

    local sm   = T.FontSm
    local font = T.Font
    local fhSm = getTextManager():getFontHeight(sm)
    local bg   = T.BG2
    self:drawRect(cx, cy, cw, ch, bg.a, bg.r, bg.g, bg.b)

    local yOff = cy - self._scroll

    for i, row in ipairs(tab.rows) do
        if yOff + ROW_H >= cy and yOff <= cy + ch then
            -- Fundo alternado
            local rbg = i % 2 == 0 and T.BG3 or T.BG2
            self:drawRect(cx, yOff, cw, ROW_H, rbg.a, rbg.r, rbg.g, rbg.b)

            -- Label
            local tc  = T.Text
            local dim = T.TextDim
            self:drawText(row.label, cx + INDENT,
                yOff + math.floor((ROW_H - fhSm) / 2),
                tc.r, tc.g, tc.b, tc.a, sm)

            if row.type == "toggle" then
                self:drawToggle(cx, yOff, cw, ROW_H, self._pending[row.key])

            elseif row.type == "select" then
                self:drawSelect(cx, yOff, cw, ROW_H, row)

            elseif row.type == "slider" then
                self:drawSlider(cx, yOff, cw, ROW_H, row)
            end
        end
        yOff = yOff + ROW_H + T.PadSm
    end

    -- Scrollbar
    if self._maxScroll > 0 then
        local totalH = #tab.rows * (ROW_H + T.PadSm)
        local ratio  = ch / totalH
        local barH   = math.max(16, math.floor(ch * ratio))
        local barY   = cy + math.floor(self._scroll / self._maxScroll * (ch - barH))
        self:drawRect(cx + cw, cy, T.ScrollW, ch, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
        self:drawRect(cx + cw + 1, barY, T.ScrollW - 2, barH, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    end
end

function EUI_SettingsPanel:drawToggle(cx, cy, cw, rh, value)
    local tw   = 40
    local th   = 16
    local tx   = cx + cw - tw - INDENT
    local ty   = cy + math.floor((rh - th) / 2)
    local onC  = T.Green; local offC = T.TextOff
    local col  = value and onC or offC
    -- trilho
    self:drawRect(tx, ty, tw, th, col.a * 0.5, col.r, col.g, col.b)
    self:drawRectBorder(tx, ty, tw, th, 1, col.a, col.r, col.g, col.b)
    -- bolinha
    local bx = value and (tx + tw - th) or tx
    self:drawRect(bx, ty, th, th, col.a, col.r, col.g, col.b)
    -- texto estado
    local sm  = T.FontSm
    local fh  = getTextManager():getFontHeight(sm)
    local lbl = value and "ON" or "OFF"
    local lw  = getTextManager():MeasureStringX(sm, lbl)
    self:drawText(lbl, tx - lw - T.PadSm, cy + math.floor((rh - fh) / 2),
        col.r, col.g, col.b, col.a, sm)
end

function EUI_SettingsPanel:drawSelect(cx, cy, cw, rh, row)
    local sm   = T.FontSm
    local fh   = getTextManager():getFontHeight(sm)
    local cur  = self._pending[row.key]
    local lbl  = "?"
    for i, v in ipairs(row.opts) do
        if v == cur then lbl = row.labels[i]; break end
    end

    local bw   = 120
    local bh   = rh - T.PadSm * 2
    local by   = cy + T.PadSm
    local bx   = cx + cw - bw - INDENT

    -- Botão ◀
    local arrW = 18
    self:drawRect(bx, by, arrW, bh, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
    self:drawRectBorder(bx, by, arrW, bh, 1, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    self:drawText("◀", bx + 3, by + math.floor((bh - fh) / 2),
        T.Text.r, T.Text.g, T.Text.b, T.Text.a, sm)

    -- Valor central
    local vw   = bw - arrW * 2
    self:drawRect(bx + arrW, by, vw, bh, T.BG2.a, T.BG2.r, T.BG2.g, T.BG2.b)
    local lw   = getTextManager():MeasureStringX(sm, lbl)
    local tc   = T.TextGreen
    self:drawText(U.truncate(lbl, vw - 4, sm),
        bx + arrW + math.floor((vw - math.min(lw, vw - 4)) / 2),
        by + math.floor((bh - fh) / 2),
        tc.r, tc.g, tc.b, tc.a, sm)

    -- Botão ▶
    self:drawRect(bx + arrW + vw, by, arrW, bh, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
    self:drawRectBorder(bx + arrW + vw, by, arrW, bh, 1, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    self:drawText("▶", bx + arrW + vw + 3, by + math.floor((bh) / 2 - fh / 2),
        T.Text.r, T.Text.g, T.Text.b, T.Text.a, sm)
end

function EUI_SettingsPanel:drawSlider(cx, cy, cw, rh, row)
    local sm   = T.FontSm
    local fh   = getTextManager():getFontHeight(sm)
    local val  = self._pending[row.key] or row.min
    local pct  = U.clamp((val - row.min) / (row.max - row.min), 0, 1)

    local sw   = 130
    local sh   = 6
    local sx   = cx + cw - sw - INDENT - 50
    local sy   = cy + math.floor((rh - sh) / 2)

    -- Trilho
    self:drawRect(sx, sy, sw, sh, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
    U.drawBar(self, sx, sy, sw, sh, pct, T.Green)

    -- Thumb
    local tx = sx + math.floor(pct * (sw - 8))
    self:drawRect(tx, cy + math.floor((rh - 14) / 2), 8, 14, T.Green.a, T.Green.r, T.Green.g, T.Green.b)

    -- Botões -/+
    local btnW = 20; local btnH = rh - T.PadSm * 2; local by = cy + T.PadSm
    local bxL  = sx + sw + T.PadSm
    self:drawRect(bxL, by, btnW, btnH, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
    self:drawRectBorder(bxL, by, btnW, btnH, 1, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    self:drawText("-", bxL + 6, by + math.floor((btnH - fh) / 2),
        T.Text.r, T.Text.g, T.Text.b, T.Text.a, sm)

    local bxR = bxL + btnW + T.PadSm
    self:drawRect(bxR, by, btnW, btnH, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
    self:drawRectBorder(bxR, by, btnW, btnH, 1, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    self:drawText("+", bxR + 5, by + math.floor((btnH - fh) / 2),
        T.Text.r, T.Text.g, T.Text.b, T.Text.a, sm)

    -- Valor
    local valStr = string.format("%.2f", val)
    local vw     = getTextManager():MeasureStringX(sm, valStr)
    self:drawText(valStr, cx + cw - INDENT - vw, cy + math.floor((rh - fh) / 2),
        T.TextGreen.r, T.TextGreen.g, T.TextGreen.b, T.TextGreen.a, sm)

    -- Guarda posições dos botões para click detection
    row._btnMinus = { x=bxL, y=by, w=btnW, h=btnH }
    row._btnPlus  = { x=bxR, y=by, w=btnW, h=btnH }
    row._sliderX  = sx; row._sliderW = sw; row._sliderY = cy; row._sliderH = rh
end

-- ── Mouse ─────────────────────────────────────────────────────────────────────

function EUI_SettingsPanel:onMouseDown(mx, my)
    EUI_BasePanel.onMouseDown(self, mx, my)
    if my <= T.TitleH then return end

    local cx   = self:contentX()
    local cy   = self:contentY()
    local rx   = cx + TAB_W + T.Gap
    local tab  = self:getCurTab()
    if not tab then return end

    local yBase = cy - self._scroll
    for i, row in ipairs(tab.rows) do
        local ry = yBase + (i - 1) * (ROW_H + T.PadSm)
        if U.inRect(mx, my, rx, ry, self:contentW() - TAB_W - T.Gap, ROW_H) then
            if row.type == "toggle" then
                -- Qualquer clique na linha faz toggle
                self:toggleValue(row.key)

            elseif row.type == "select" then
                local bw  = 120; local arrW = 18
                local bx  = rx + (self:contentW() - TAB_W - T.Gap) - bw - INDENT
                if U.inRect(mx, my, bx, ry, arrW, ROW_H) then
                    self:cycleSelect(row, false)
                elseif U.inRect(mx, my, bx + arrW + (bw - arrW * 2), ry, arrW, ROW_H) then
                    self:cycleSelect(row, true)
                end

            elseif row.type == "slider" then
                if row._btnMinus and U.inRect(mx, my,
                    row._btnMinus.x, row._btnMinus.y,
                    row._btnMinus.w, row._btnMinus.h) then
                    self:adjustSlider(row, -1)
                elseif row._btnPlus and U.inRect(mx, my,
                    row._btnPlus.x, row._btnPlus.y,
                    row._btnPlus.w, row._btnPlus.h) then
                    self:adjustSlider(row, 1)
                elseif row._sliderX and U.inRect(mx, my,
                    row._sliderX, row._sliderY,
                    row._sliderW, row._sliderH) then
                    -- Clique direto no trilho
                    local pct = U.clamp((mx - row._sliderX) / row._sliderW, 0, 1)
                    local v   = row.min + pct * (row.max - row.min)
                    self._pending[row.key] = math.floor(v / row.step + 0.5) * row.step
                    self._pending[row.key] = math.floor(self._pending[row.key] * 100 + 0.5) / 100
                end
            end
            return
        end
        yBase = yBase  -- ry já inclui o incremento
    end
end

function EUI_SettingsPanel:onMouseWheel(del)
    local mx = self:getMouseX()
    local cx = self:contentX()
    if mx > cx + TAB_W then
        self._scroll = U.clamp(self._scroll - del * ROW_H, 0, self._maxScroll)
    end
    return true
end

-- ── Registro ──────────────────────────────────────────────────────────────────

Events.OnKeyPressed.Add(function(key)
    if key == getCore():getKey("EUI_Settings") then
        if EUI._settingsPanel then
            EUI._settingsPanel:setVisible(not EUI._settingsPanel:isVisible())
            if EUI._settingsPanel:isVisible() then
                EUI._settingsPanel:copySettings()
            end
            return
        end
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local p  = EUI_SettingsPanel:new(
            math.floor((sw - PANEL_W) / 2),
            math.floor((sh - PANEL_H) / 2))
        p:initialise(); p:instantiate(); p:addToUIManager(); p:setVisible(true)
        EUI._settingsPanel = p
    end
end)

-- Hook no menu principal também
Events.OnMainMenuEnter.Add(function()
    -- Garante que settings estão carregadas mesmo sem entrar em jogo
    EUI.loadSettings()
end)
