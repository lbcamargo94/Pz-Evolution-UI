-- EUI_CookingPanel.lua — painel de culinária (B42)

EUI = EUI or {}

EUI_CookingPanel = EUI_BasePanel:derive("EUI_CookingPanel")

local T = EUI.Theme
local U = EUI.Utils

local PANEL_W  = 580
local PANEL_H  = 540
local CAT_W    = 130
local LIST_W   = 190
local DETAIL_W = PANEL_W - CAT_W - LIST_W - T.Pad * 4 - T.Gap * 2
local CAT_ROW  = 28
local REC_ROW  = 30
local SEARCH_H = 26

local CATEGORIES = {
    { id="Carne",    icon="🥩", label="Carnes"      },
    { id="Vegetal",  icon="🥦", label="Vegetais"    },
    { id="Pão",      icon="🍞", label="Pães"        },
    { id="Sopa",     icon="🍲", label="Sopas"       },
    { id="Bebidas",  icon="🍵", label="Bebidas"     },
    { id="Doces",    icon="🍰", label="Doces"       },
    { id="Outros",   icon="🍴", label="Outros"      },
}

-- Receitas fallback (B42 ainda pode ter API própria)
local FALLBACK_RECIPES = {
    { cat="Carne",   name="Churrasco",         time=30, hunger=-35 },
    { cat="Carne",   name="Ensopado de Carne", time=45, hunger=-50 },
    { cat="Vegetal", name="Salada",            time=10, hunger=-20 },
    { cat="Vegetal", name="Sopa de Legumes",   time=40, hunger=-45 },
    { cat="Pão",     name="Pão Simples",       time=60, hunger=-30 },
    { cat="Pão",     name="Sanduíche",         time=5,  hunger=-25 },
    { cat="Sopa",    name="Sopa de Batata",    time=35, hunger=-40 },
    { cat="Sopa",    name="Caldo de Osso",     time=60, hunger=-55 },
    { cat="Bebidas", name="Chá de Ervas",      time=10, hunger=-5  },
    { cat="Bebidas", name="Caldo Quente",      time=15, hunger=-10 },
    { cat="Doces",   name="Torta de Frutas",   time=50, hunger=-45 },
    { cat="Outros",  name="Omelete",           time=15, hunger=-30 },
    { cat="Outros",  name="Ovos Cozidos",      time=10, hunger=-20 },
}

-- ── Constructor ───────────────────────────────────────────────────────────────

function EUI_CookingPanel:new(x, y, playerNum)
    local o = EUI_BasePanel.new(self, x, y, PANEL_W, PANEL_H, "Culinária")
    o.playerNum       = playerNum or 0
    o.showCloseButton = true
    o._recipes        = {}
    o._filtered       = {}
    o._selCat         = nil
    o._selRec         = nil
    o._searchText     = ""
    o._scrollCat      = 0
    o._scrollRec      = 0
    o._maxScrollCat   = 0
    o._maxScrollRec   = 0
    return o
end

function EUI_CookingPanel:initialise()
    EUI_BasePanel.initialise(self)
    self:buildSearch()
    self:buildCookBtn()
    self:loadRecipes()
end

function EUI_CookingPanel:buildSearch()
    local cx = self:contentX() + CAT_W + T.Gap
    local cy = self:contentY()
    self._searchBox = ISTextEntryBox:new("", cx, cy, LIST_W, SEARCH_H)
    self._searchBox:initialise(); self._searchBox:instantiate()
    self._searchBox.placeholder     = "Buscar receita…"
    self._searchBox.backgroundColor = T.BG3
    self._searchBox.borderColor     = T.Border
    self._searchBox.textColor       = T.Text
    self._searchBox.onTextChange    = function() self:onSearch() end
    self:addChild(self._searchBox)
end

function EUI_CookingPanel:buildCookBtn()
    local bw = DETAIL_W - T.Pad
    local bh = T.BtnH
    local bx = self:contentX() + CAT_W + T.Gap + LIST_W + T.Gap
    local by = self.height - T.Pad * 2 - bh
    self._btnCook = EUI_BaseButton:new(bx, by, bw, bh, "Cozinhar", self,
        EUI_CookingPanel.onCook, "primary")
    self._btnCook:initialise(); self._btnCook:instantiate(); self:addChild(self._btnCook)
end

-- ── Dados ─────────────────────────────────────────────────────────────────────

function EUI_CookingPanel:loadRecipes()
    self._recipes = {}
    local loaded = false

    -- Tenta carregar do CraftRecipeManager (B42)
    local ok, mgr = pcall(function() return CraftRecipeManager end)
    if ok and mgr then
        local allRec = nil
        pcall(function() allRec = mgr:getRecipes() end)
        if allRec then
            for i = 0, allRec:size() - 1 do
                local rec = allRec:get(i)
                if rec then
                    local isFood = false
                    pcall(function() isFood = rec:getCategory() == "Cooking" end)
                    if isFood then
                        local name = "?"; local cat = "Outros"
                        pcall(function() name = rec:getName() or "?" end)
                        pcall(function() cat  = rec:getSubCategory() or "Outros" end)
                        table.insert(self._recipes, { name=name, cat=cat, rec=rec })
                        loaded = true
                    end
                end
            end
        end
    end

    if not loaded then
        for _, r in ipairs(FALLBACK_RECIPES) do
            table.insert(self._recipes, { name=r.name, cat=r.cat, rec=nil,
                time=r.time, hunger=r.hunger })
        end
    end

    if #CATEGORIES > 0 then self:selectCat(CATEGORIES[1].id) end
end

function EUI_CookingPanel:selectCat(catId)
    self._selCat = catId; self._selRec = nil; self._scrollRec = 0
    self:applyFilter()
end

function EUI_CookingPanel:onSearch()
    self._searchText = self._searchBox:getText() or ""
    self._selRec     = nil; self._scrollRec = 0
    self:applyFilter()
end

function EUI_CookingPanel:applyFilter()
    local q   = self._searchText:lower()
    local cat = self._selCat
    self._filtered = {}
    for _, r in ipairs(self._recipes) do
        local mCat = not cat or r.cat == cat
        local mQ   = q == "" or r.name:lower():find(q, 1, true)
        if mCat and mQ then table.insert(self._filtered, r) end
    end
    local ch           = self:contentH() - SEARCH_H - T.Gap
    self._maxScrollRec = math.max(0, #self._filtered * (REC_ROW + T.PadSm) - ch)
    self._maxScrollCat = math.max(0, #CATEGORIES * (CAT_ROW + T.PadSm) - self:contentH())
end

-- ── Ação ──────────────────────────────────────────────────────────────────────

function EUI_CookingPanel:onCook()
    if not self._selRec then return end
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    if self._selRec.rec then
        pcall(function()
            ISTimedActionQueue.add(ISCraftAction:new(player, self._selRec.rec, 1))
        end)
    end
end

-- ── Render ────────────────────────────────────────────────────────────────────

function EUI_CookingPanel:render()
    local cy     = self:contentY()
    local cx     = self:contentX()
    local fontSm = T.FontSm
    local fh     = getTextManager():getFontHeight(fontSm)
    local dim    = T.TextDim

    self:drawText("Categorias", cx, cy, dim.r, dim.g, dim.b, dim.a, fontSm)
    local rx = cx + CAT_W + T.Gap + LIST_W + T.Gap
    self:drawText("Detalhe", rx, cy, dim.r, dim.g, dim.b, dim.a, fontSm)
    cy = cy + fh + T.Gap

    local dh = self.height - cy - T.Pad
    self:drawRect(cx + CAT_W + math.floor(T.Gap/2), cy, 1, dh, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    self:drawRect(rx - math.floor(T.Gap/2),         cy, 1, dh, T.Border.a, T.Border.r, T.Border.g, T.Border.b)

    local listTop = cy + SEARCH_H + T.Gap
    local listH   = self.height - listTop - T.Pad * 2 - T.BtnH - T.Gap

    self:drawCategories(cx, cy, CAT_W, self.height - cy - T.Pad)
    self:drawRecipes(cx + CAT_W + T.Gap, listTop, LIST_W, listH)
    self:drawDetail(rx, cy, DETAIL_W, listH + SEARCH_H + T.Gap)
end

function EUI_CookingPanel:drawCategories(cx, cy, cw, ch)
    local font = T.FontSm
    local fh   = getTextManager():getFontHeight(font)
    local bg   = T.BG2
    self:drawRect(cx, cy, cw, ch, bg.a, bg.r, bg.g, bg.b)

    local yOff = cy - self._scrollCat
    for _, cat in ipairs(CATEGORIES) do
        if yOff + CAT_ROW >= cy and yOff <= cy + ch then
            local sel = cat.id == self._selCat
            local rbg = sel and T.BG_Select or T.BG2
            self:drawRect(cx, yOff, cw, CAT_ROW, rbg.a, rbg.r, rbg.g, rbg.b)
            if sel then
                self:drawRect(cx, yOff, 2, CAT_ROW, T.Green.a, T.Green.r, T.Green.g, T.Green.b)
            end
            local tc    = sel and T.TextGreen or T.Text
            local label = cat.icon .. " " .. U.truncate(cat.label, cw - T.Pad * 2 - 16, font)
            self:drawText(label, cx + T.PadSm + (sel and 4 or 0),
                yOff + math.floor((CAT_ROW - fh) / 2), tc.r, tc.g, tc.b, tc.a, font)
        end
        yOff = yOff + CAT_ROW + T.PadSm
    end
end

function EUI_CookingPanel:drawRecipes(cx, cy, cw, ch)
    local font = T.FontSm
    local fh   = getTextManager():getFontHeight(font)
    local bg   = T.BG2
    self:drawRect(cx, cy, cw, ch, bg.a, bg.r, bg.g, bg.b)

    if #self._filtered == 0 then
        local tc  = T.TextOff
        local msg = "Sem receitas"
        local mw  = getTextManager():MeasureStringX(font, msg)
        self:drawText(msg, cx + math.floor((cw - mw) / 2), cy + 20, tc.r, tc.g, tc.b, tc.a, font)
        return
    end

    local player = getSpecificPlayer(self.playerNum)
    local yOff   = cy - self._scrollRec

    for i, r in ipairs(self._filtered) do
        if yOff + REC_ROW >= cy and yOff <= cy + ch then
            local sel  = r == self._selRec
            local rbg  = sel and T.BG_Select or (i % 2 == 0 and T.BG3 or T.BG2)
            self:drawRect(cx, yOff, cw, REC_ROW, rbg.a, rbg.r, rbg.g, rbg.b)
            if sel then
                self:drawRect(cx, yOff, 2, REC_ROW, T.Green.a, T.Green.r, T.Green.g, T.Green.b)
            end

            local avail = false
            if player and r.rec then
                pcall(function() avail = r.rec:isAvailable(player) end)
            elseif r.hunger then
                avail = true  -- receita fallback sempre "disponível"
            end

            local tc   = sel and T.TextGreen or (avail and T.Text or T.TextOff)
            local name = U.truncate(r.name, cw - T.PadSm * 2 - 18, font)
            self:drawText(name, cx + T.PadSm + (sel and 4 or 0),
                yOff + math.floor((REC_ROW - fh) / 2), tc.r, tc.g, tc.b, tc.a, font)

            if avail then
                local gc = T.Green
                self:drawText("✓", cx + cw - 14, yOff + math.floor((REC_ROW - fh) / 2),
                    gc.r, gc.g, gc.b, gc.a, font)
            end
        end
        yOff = yOff + REC_ROW + T.PadSm
    end

    if self._maxScrollRec > 0 then
        local totalH = #self._filtered * (REC_ROW + T.PadSm)
        local ratio  = ch / totalH
        local barH   = math.max(16, math.floor(ch * ratio))
        local barY   = cy + math.floor(self._scrollRec / self._maxScrollRec * (ch - barH))
        self:drawRect(cx + cw, cy, T.ScrollW, ch, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
        self:drawRect(cx + cw + 1, barY, T.ScrollW - 2, barH, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    end
end

function EUI_CookingPanel:drawDetail(cx, cy, cw, ch)
    local bg = T.BG2
    self:drawRect(cx, cy, cw, ch, bg.a, bg.r, bg.g, bg.b)

    local r = self._selRec
    if not r then
        local tc  = T.TextOff; local font = T.FontSm
        local msg = "Selecione uma receita"
        local mw  = getTextManager():MeasureStringX(font, msg)
        self:drawText(msg, cx + math.floor((cw - mw) / 2), cy + 40, tc.r, tc.g, tc.b, tc.a, font)
        return
    end

    local font = T.Font; local sm = T.FontSm
    local fhM  = getTextManager():getFontHeight(font)
    local fh   = getTextManager():getFontHeight(sm)
    local y    = cy + T.Pad; local tc = T.Text; local dim = T.TextDim

    -- Nome
    self:drawText(U.truncate(r.name, cw - T.Pad * 2, font), cx + T.Pad, y, tc.r, tc.g, tc.b, tc.a, font)
    y = y + fhM + T.Gap

    -- Categoria
    local catIcon = ""
    for _, c in ipairs(CATEGORIES) do if c.id == r.cat then catIcon = c.icon; break end end
    self:drawText(catIcon .. " " .. (r.cat or "?"), cx + T.Pad, y, dim.r, dim.g, dim.b, dim.a, sm)
    y = y + fh + T.Gap

    U.drawDivider(self, cx + T.Pad, y, cw - T.Pad * 2); y = y + T.Gap + 2

    -- Stats rápidos
    local hdr = T.TextGreen
    self:drawText("Informações:", cx + T.Pad, y, hdr.r, hdr.g, hdr.b, hdr.a, sm)
    y = y + fh + T.PadSm

    local timeVal = r.time or "?"
    local hungerVal = r.hunger
    if r.rec then
        pcall(function() timeVal   = r.rec:getCraftTime() or timeVal end)
        pcall(function() hungerVal = r.rec:getHungerChange() or hungerVal end)
    end
    if timeVal ~= "?" then
        self:drawText(string.format("  Tempo: %s min", tostring(timeVal)), cx + T.Pad, y,
            dim.r, dim.g, dim.b, dim.a, sm)
        y = y + fh + T.PadSm
    end
    if hungerVal then
        local hCol = T.TextGreen
        self:drawText(string.format("  Saciedade: %+d", hungerVal), cx + T.Pad, y,
            hCol.r, hCol.g, hCol.b, hCol.a, sm)
        y = y + fh + T.PadSm
    end
    y = y + T.Gap

    U.drawDivider(self, cx + T.Pad, y, cw - T.Pad * 2); y = y + T.Gap + 2

    -- Ingredientes
    self:drawText("Ingredientes:", cx + T.Pad, y, hdr.r, hdr.g, hdr.b, hdr.a, sm)
    y = y + fh + T.PadSm

    local player = getSpecificPlayer(self.playerNum)
    local ings   = {}
    if r.rec then
        pcall(function()
            local il = r.rec:getIngredients and r.rec:getIngredients()
            if il then
                for i = 0, il:size() - 1 do
                    local ing = il:get(i)
                    if ing then
                        local iname = "?"; local qty = 1; local have = 0
                        pcall(function() iname = ing:getName() or "?" end)
                        pcall(function() qty   = ing:getCount()  or 1  end)
                        if player then
                            pcall(function()
                                have = player:getInventory():getCountType(iname)
                            end)
                        end
                        table.insert(ings, { name=iname, qty=qty, have=have })
                    end
                end
            end
        end)
    end

    if #ings == 0 then
        self:drawText("  (verifique no jogo)", cx + T.Pad, y, dim.r, dim.g, dim.b, dim.a, sm)
    else
        for _, ing in ipairs(ings) do
            local ok  = ing.have >= ing.qty
            local col = ok and T.TextGreen or T.TextRed
            self:drawText(string.format("  %s  %d/%d",
                U.truncate(ing.name, cw - 80, sm), ing.have, ing.qty),
                cx + T.Pad, y, col.r, col.g, col.b, col.a, sm)
            self:drawText(ok and "✓" or "✗", cx + cw - 20, y,
                col.r, col.g, col.b, col.a, sm)
            y = y + fh + T.PadSm
            if y > cy + ch - fh - T.Pad then break end
        end
    end
end

-- ── Mouse ─────────────────────────────────────────────────────────────────────

function EUI_CookingPanel:onMouseDown(mx, my)
    EUI_BasePanel.onMouseDown(self, mx, my)
    if my <= T.TitleH then return end
    local cx  = self:contentX()
    local cy  = self:contentY()
    local fh  = getTextManager():getFontHeight(T.FontSm)
    local top = cy + fh + T.Gap

    if U.inRect(mx, my, cx, top, CAT_W, self.height - top - T.Pad) then
        local rel = my - top + self._scrollCat
        local idx = math.floor(rel / (CAT_ROW + T.PadSm)) + 1
        if CATEGORIES[idx] then self:selectCat(CATEGORIES[idx].id) end
        return
    end

    local lx   = cx + CAT_W + T.Gap
    local lTop = top + SEARCH_H + T.Gap
    local lH   = self.height - lTop - T.Pad * 2 - T.BtnH - T.Gap
    if U.inRect(mx, my, lx, lTop, LIST_W, lH) then
        local rel = my - lTop + self._scrollRec
        local idx = math.floor(rel / (REC_ROW + T.PadSm)) + 1
        if self._filtered[idx] then self._selRec = self._filtered[idx] end
    end
end

function EUI_CookingPanel:onMouseWheel(del)
    local mx = self:getMouseX()
    local cx = self:contentX()
    if mx < cx + CAT_W then
        self._scrollCat = U.clamp(self._scrollCat - del * CAT_ROW, 0, self._maxScrollCat)
    else
        self._scrollRec = U.clamp(self._scrollRec - del * REC_ROW, 0, self._maxScrollRec)
    end
    return true
end

-- ── Registro ──────────────────────────────────────────────────────────────────

Events.OnKeyPressed.Add(function(key)
    if key == getCore():getKey("Cooking") then
        if EUI._cookingPanel then
            EUI._cookingPanel:setVisible(not EUI._cookingPanel:isVisible())
            if EUI._cookingPanel:isVisible() then EUI._cookingPanel:loadRecipes() end
            return
        end
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local p  = EUI_CookingPanel:new(math.floor((sw - PANEL_W) / 2), math.floor((sh - PANEL_H) / 2), 0)
        p:initialise(); p:instantiate(); p:addToUIManager(); p:setVisible(true)
        EUI._cookingPanel = p
    end
end)
