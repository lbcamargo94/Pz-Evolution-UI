-- EUI_CollectPanel.lua — painel de coleta / recursos do mapa (B42)

EUI = EUI or {}

EUI_CollectPanel = EUI_BasePanel:derive("EUI_CollectPanel")

local T = EUI.Theme
local U = EUI.Utils

local PANEL_W  = 480
local PANEL_H  = 520
local CAT_W    = 130
local ROW_H    = 30
local CAT_ROW  = 28

-- Categorias de coleta com itens tipo PZ
local CATEGORIES = {
    {
        id   = "Plantas",
        icon = "🌿",
        items = {
            { name="Foraging.WildGarlic",    label="Alho Selvagem"     },
            { name="Foraging.Mushroom",      label="Cogumelo"          },
            { name="Foraging.Blackberries",  label="Amoras"            },
            { name="Foraging.WildOnion",     label="Cebola Selvagem"   },
            { name="Foraging.Nettles",       label="Urtiga"            },
            { name="Foraging.DogWood",       label="Corniso"           },
            { name="Foraging.Dandelion",     label="Dente-de-leão"     },
            { name="Foraging.Plantain",      label="Tanchagem"         },
        },
    },
    {
        id   = "Insetos",
        icon = "🪲",
        items = {
            { name="Foraging.Worm",          label="Minhoca"           },
            { name="Foraging.Moth",          label="Mariposa"          },
            { name="Foraging.Cricket",       label="Grilo"             },
            { name="Foraging.GrassHopper",   label="Gafanhoto"         },
        },
    },
    {
        id   = "Pedras",
        icon = "🪨",
        items = {
            { name="Foraging.Flint",         label="Sílex"             },
            { name="Foraging.SmallStone",    label="Pedra Pequena"     },
            { name="Foraging.TwigBundle",    label="Galhos"            },
        },
    },
    {
        id   = "Animais",
        icon = "🐇",
        items = {
            { name="Foraging.DeadBird",      label="Pássaro Morto"     },
            { name="Foraging.DeadRabbit",    label="Coelho Morto"      },
            { name="Foraging.DeadSquirrel",  label="Esquilo Morto"     },
            { name="Foraging.DeadFrog",      label="Rã Morta"          },
        },
    },
    {
        id   = "Cogumelos",
        icon = "🍄",
        items = {
            { name="Foraging.YellowMushroom",label="Cogumelo Amarelo"  },
            { name="Foraging.GlowCap",       label="Cogumelo Glow"     },
            { name="Foraging.PuffBall",      label="Puffball"          },
        },
    },
}

-- ── Constructor ───────────────────────────────────────────────────────────────

function EUI_CollectPanel:new(x, y, playerNum)
    local o = EUI_BasePanel.new(self, x, y, PANEL_W, PANEL_H, "Coleta")
    o.playerNum       = playerNum or 0
    o.showCloseButton = true
    o._selCat         = CATEGORIES[1].id
    o._foragingLvl    = 0
    o._inventory      = {}  -- contagem de itens no inventário
    o._scrollCat      = 0
    o._scrollList     = 0
    o._maxScrollList  = 0
    return o
end

function EUI_CollectPanel:initialise()
    EUI_BasePanel.initialise(self)
    self:buildForageBtn()
    self:refreshInventory()
end

function EUI_CollectPanel:buildForageBtn()
    local bw = self:contentW()
    local bh = T.BtnH
    local cx = self:contentX()
    local by = self.height - T.Pad * 2 - bh
    self._btnForage = EUI_BaseButton:new(cx, by, bw, bh, "Coletar na Área", self,
        EUI_CollectPanel.onForage, "primary")
    self._btnForage:initialise(); self._btnForage:instantiate(); self:addChild(self._btnForage)
end

-- ── Dados ─────────────────────────────────────────────────────────────────────

function EUI_CollectPanel:refreshInventory()
    self._inventory = {}
    local player    = getSpecificPlayer(self.playerNum)
    if not player then return end

    -- Nível de forrageamento
    pcall(function()
        -- B42: "Foraging" foi renomeado para "PlantScavenging"
        local pk = PerkFactory.getPerkFromString("PlantScavenging")
                or PerkFactory.getPerkFromString("Foraging")
        if pk then self._foragingLvl = player:getPerkLevel(pk) end
    end)

    local inv = player:getInventory()
    if not inv then return end

    for _, cat in ipairs(CATEGORIES) do
        for _, it in ipairs(cat.items) do
            local count = 0
            pcall(function() count = inv:getCountType(it.name) end)
            self._inventory[it.name] = count
        end
    end

    -- Calcula scroll
    local cat = self:getCurCat()
    if cat then
        local listH = self:contentH() - 80 - T.Gap
        local items = cat.items
        self._maxScrollList = math.max(0, #items * (ROW_H + T.PadSm) - listH)
    end
end

function EUI_CollectPanel:getCurCat()
    for _, c in ipairs(CATEGORIES) do
        if c.id == self._selCat then return c end
    end
    return CATEGORIES[1]
end

-- ── Ação ──────────────────────────────────────────────────────────────────────

function EUI_CollectPanel:onForage()
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    pcall(function()
        if ISForageAction then
            ISTimedActionQueue.add(ISForageAction:new(player, player:getSquare()))
        end
    end)
end

-- ── Render ────────────────────────────────────────────────────────────────────

function EUI_CollectPanel:render()
    local cx  = self:contentX()
    local cy  = self:contentY()
    local cw  = self:contentW()
    local sm  = T.FontSm
    local fh  = getTextManager():getFontHeight(sm)
    local dim = T.TextDim
    local hdr = T.TextGreen

    -- Nível de forrageamento
    local fgStr = string.format("Forrageamento Nível %d", self._foragingLvl)
    self:drawText(fgStr, cx, cy, hdr.r, hdr.g, hdr.b, hdr.a, sm)
    cy = cy + fh + T.Gap

    U.drawDivider(self, cx, cy, cw); cy = cy + T.Gap + 2

    -- Divisor vertical
    local dh = self.height - cy - T.Pad
    self:drawRect(cx + CAT_W + math.floor(T.Gap / 2), cy, 1, dh,
        T.Border.a, T.Border.r, T.Border.g, T.Border.b)

    local listW = cw - CAT_W - T.Gap
    local listH = self.height - cy - T.Pad * 2 - T.BtnH - T.Gap

    self:drawCategories(cx, cy, CAT_W, listH)
    self:drawItemList(cx + CAT_W + T.Gap, cy, listW, listH)
end

function EUI_CollectPanel:drawCategories(cx, cy, cw, ch)
    local sm  = T.FontSm
    local fh  = getTextManager():getFontHeight(sm)
    local bg  = T.BG2
    self:drawRect(cx, cy, cw, ch, bg.a, bg.r, bg.g, bg.b)

    local yOff = cy - self._scrollCat
    for _, cat in ipairs(CATEGORIES) do
        if yOff + CAT_ROW >= cy and yOff <= cy + ch then
            local sel  = cat.id == self._selCat
            local rbg  = sel and T.BG_Select or T.BG2
            self:drawRect(cx, yOff, cw, CAT_ROW, rbg.a, rbg.r, rbg.g, rbg.b)
            if sel then
                self:drawRect(cx, yOff, 2, CAT_ROW, T.Green.a, T.Green.r, T.Green.g, T.Green.b)
            end
            local tc    = sel and T.TextGreen or T.Text
            local label = cat.icon .. " " .. U.truncate(cat.id, cw - T.Pad * 2 - 16, sm)
            self:drawText(label, cx + T.PadSm + (sel and 4 or 0),
                yOff + math.floor((CAT_ROW - fh) / 2), tc.r, tc.g, tc.b, tc.a, sm)
        end
        yOff = yOff + CAT_ROW + T.PadSm
    end
end

function EUI_CollectPanel:drawItemList(cx, cy, cw, ch)
    local sm  = T.FontSm
    local fh  = getTextManager():getFontHeight(sm)
    local bg  = T.BG2
    self:drawRect(cx, cy, cw, ch, bg.a, bg.r, bg.g, bg.b)

    local cat  = self:getCurCat()
    if not cat then return end

    local yOff = cy - self._scrollList
    for i, it in ipairs(cat.items) do
        if yOff + ROW_H >= cy and yOff <= cy + ch then
            local rbg = i % 2 == 0 and T.BG3 or T.BG2
            self:drawRect(cx, yOff, cw, ROW_H, rbg.a, rbg.r, rbg.g, rbg.b)

            local count = self._inventory[it.name] or 0
            local tc    = count > 0 and T.TextGreen or T.Text
            local dim   = T.TextDim
            self:drawText(it.label, cx + T.PadSm,
                yOff + math.floor((ROW_H - fh) / 2), tc.r, tc.g, tc.b, tc.a, sm)

            -- Contagem no inventário
            local cStr = count > 0 and string.format("x%d", count) or "–"
            local cCol = count > 0 and T.TextGreen or dim
            local cw2  = getTextManager():MeasureStringX(sm, cStr)
            self:drawText(cStr, cx + cw - cw2 - T.PadSm,
                yOff + math.floor((ROW_H - fh) / 2), cCol.r, cCol.g, cCol.b, cCol.a, sm)

            -- Item ID (pequeno, escurecido)
            local idStr = it.name
            local idW   = getTextManager():MeasureStringX(sm, idStr)
            if idW < cw - 80 then
                local dco = T.TextDim
                -- não exibe o full type ID para não poluir; mostra só o label
            end
        end
        yOff = yOff + ROW_H + T.PadSm
    end

    if self._maxScrollList > 0 then
        local cat2    = self:getCurCat()
        local total   = cat2 and #cat2.items or 0
        local totalH  = total * (ROW_H + T.PadSm)
        local ratio   = ch / totalH
        local barH    = math.max(16, math.floor(ch * ratio))
        local barY    = cy + math.floor(self._scrollList / self._maxScrollList * (ch - barH))
        self:drawRect(cx + cw, cy, T.ScrollW, ch, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
        self:drawRect(cx + cw + 1, barY, T.ScrollW - 2, barH, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    end
end

-- ── Mouse ─────────────────────────────────────────────────────────────────────

function EUI_CollectPanel:onMouseDown(mx, my)
    EUI_BasePanel.onMouseDown(self, mx, my)
    if my <= T.TitleH then return end
    local cx  = self:contentX()
    local cy  = self:contentY()
    local sm  = T.FontSm
    local fh  = getTextManager():getFontHeight(sm)
    local top = cy + fh + T.Gap + T.Gap + 4

    -- Categoria
    if U.inRect(mx, my, cx, top, CAT_W, self.height - top - T.Pad) then
        local rel = my - top + self._scrollCat
        local idx = math.floor(rel / (CAT_ROW + T.PadSm)) + 1
        if CATEGORIES[idx] then
            self._selCat     = CATEGORIES[idx].id
            self._scrollList = 0
            self:refreshInventory()
        end
    end
end

function EUI_CollectPanel:onMouseWheel(del)
    local mx = self:getMouseX()
    local cx = self:contentX()
    if mx < cx + CAT_W then
        self._scrollCat = U.clamp(self._scrollCat - del * CAT_ROW, 0, 0)
    else
        self._scrollList = U.clamp(self._scrollList - del * ROW_H, 0, self._maxScrollList)
    end
    return true
end

-- ── Registro ──────────────────────────────────────────────────────────────────

Events.OnKeyPressed.Add(function(key)
    if key == EUI.getKey("Collect") then
        if EUI._collectPanel then
            EUI._collectPanel:setVisible(not EUI._collectPanel:isVisible())
            if EUI._collectPanel:isVisible() then EUI._collectPanel:refreshInventory() end
            return
        end
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local p  = EUI_CollectPanel:new(
            math.floor((sw - PANEL_W) / 2),
            math.floor((sh - PANEL_H) / 2), 0)
        p:initialise(); p:instantiate(); p:addToUIManager(); p:setVisible(true)
        EUI._collectPanel = p
    end
end)
