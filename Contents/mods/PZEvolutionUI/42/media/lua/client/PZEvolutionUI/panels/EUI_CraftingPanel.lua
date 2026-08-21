-- EUI_CraftingPanel.lua — painel de crafting (B42)

EUI = EUI or {}

EUI_CraftingPanel = EUI_BasePanel:derive("EUI_CraftingPanel")

local T = EUI.Theme
local U = EUI.Utils

local PANEL_W    = 640
local PANEL_H    = 560
local CAT_W      = 130   -- largura da coluna de categorias
local LIST_W     = 220   -- largura da lista de receitas
local DETAIL_W   = PANEL_W - CAT_W - LIST_W - T.Pad * 4 - T.Gap * 2
local SEARCH_H   = 26
local CAT_ROW_H  = 26
local REC_ROW_H  = 28

-- ── Constructor ───────────────────────────────────────────────────────────────

function EUI_CraftingPanel:new(x, y, playerNum)
    local o = EUI_BasePanel.new(self, x, y, PANEL_W, PANEL_H, "Crafting")
    o.playerNum         = playerNum or 0
    o.showCloseButton   = true
    o._categories       = {}
    o._recipes          = {}
    o._filteredRecipes  = {}
    o._selCategory      = nil
    o._selRecipe        = nil
    o._searchText       = ""
    o._scrollCat        = 0
    o._scrollRec        = 0
    o._maxScrollCat     = 0
    o._maxScrollRec     = 0
    o._dirty            = true
    return o
end

function EUI_CraftingPanel:initialise()
    EUI_BasePanel.initialise(self)
    self:buildSearchBar()
    self:buildCraftButton()
    self:loadRecipes()
end

-- ── UI estática ───────────────────────────────────────────────────────────────

function EUI_CraftingPanel:buildSearchBar()
    local cx = self:contentX() + CAT_W + T.Gap
    local cy = self:contentY()

    self._searchBox = ISTextEntryBox:new("", cx, cy, LIST_W, SEARCH_H)
    self._searchBox:initialise()
    self._searchBox:instantiate()
    self._searchBox.placeholder     = "Buscar receita…"
    self._searchBox.backgroundColor = T.BG3
    self._searchBox.borderColor     = T.Border
    self._searchBox.textColor       = T.Text
    self._searchBox.onTextChange    = function() self:onSearch() end
    self:addChild(self._searchBox)
end

function EUI_CraftingPanel:buildCraftButton()
    local bw  = DETAIL_W - T.Pad
    local bh  = T.BtnH
    local bx  = self:contentX() + CAT_W + T.Gap + LIST_W + T.Gap
    local by  = self.height - T.Pad * 2 - bh

    self._btnCraft = EUI_BaseButton:new(bx, by, bw, bh, "Fabricar", self, EUI_CraftingPanel.onCraft, "primary")
    self._btnCraft:initialise()
    self._btnCraft:instantiate()
    self:addChild(self._btnCraft)
end

-- ── Dados: receitas B42 ───────────────────────────────────────────────────────

function EUI_CraftingPanel:loadRecipes()
    self._categories = {}
    self._recipes    = {}

    local catSet = {}

    -- B42: CraftRecipeManager.getInstance() (não .instance())
    local ok, mgr = pcall(function() return CraftRecipeManager.getInstance() end)
    if not ok or not mgr then
        ok, mgr = pcall(function() return CraftRecipeManager.instance() end)  -- B41 fallback
    end
    if not ok or not mgr then
        pcall(function() mgr = getRecipes() end)
    end
    if not mgr then return end

    local recipeList
    pcall(function()
        recipeList = mgr.getRecipes and mgr:getRecipes() or mgr
    end)
    if not recipeList then return end

    local size = 0
    pcall(function() size = recipeList:size() end)

    for i = 0, size - 1 do
        local rec = nil
        pcall(function() rec = recipeList:get(i) end)
        if rec then
            local name, cat = "?", "Geral"
            pcall(function() name = rec:getName() or "?" end)
            pcall(function() cat  = rec:getCategory() or "Geral" end)

            if not catSet[cat] then
                catSet[cat] = true
                table.insert(self._categories, cat)
            end
            table.insert(self._recipes, { name=name, cat=cat, rec=rec })
        end
    end

    table.sort(self._categories)
    table.sort(self._recipes, function(a, b) return a.name < b.name end)

    -- Seleciona primeira categoria
    if #self._categories > 0 then
        self:selectCategory(self._categories[1])
    else
        self._filteredRecipes = self._recipes
    end
end

function EUI_CraftingPanel:selectCategory(cat)
    self._selCategory   = cat
    self._selRecipe     = nil
    self._scrollRec     = 0
    self:filterRecipes()
end

function EUI_CraftingPanel:onSearch()
    self._searchText  = self._searchBox:getText() or ""
    self._selRecipe   = nil
    self._scrollRec   = 0
    self:filterRecipes()
end

function EUI_CraftingPanel:filterRecipes()
    local q   = self._searchText:lower()
    local cat = self._selCategory
    self._filteredRecipes = {}
    for _, r in ipairs(self._recipes) do
        local matchCat  = not cat or r.cat == cat
        local matchQ    = q == "" or r.name:lower():find(q, 1, true)
        if matchCat and matchQ then
            table.insert(self._filteredRecipes, r)
        end
    end
    local contentH      = self:contentH() - SEARCH_H - T.Gap
    self._maxScrollRec  = math.max(0, #self._filteredRecipes * (REC_ROW_H + T.PadSm) - contentH)
    local catH          = self:contentH()
    self._maxScrollCat  = math.max(0, #self._categories * (CAT_ROW_H + T.PadSm) - catH)
end

-- ── Ação: fabricar ────────────────────────────────────────────────────────────

function EUI_CraftingPanel:onCraft()
    if not self._selRecipe then return end
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    pcall(function()
        local rec = self._selRecipe.rec
        if rec and rec.isAvailable and rec:isAvailable(player) then
            ISTimedActionQueue.add(ISCraftAction:new(player, rec, 1))
        end
    end)
end

-- ── Render ────────────────────────────────────────────────────────────────────

function EUI_CraftingPanel:render()
    local cy = self:contentY()
    local cx = self:contentX()

    -- Cabeçalhos de coluna
    local fontSm = T.FontSm
    local fh     = getTextManager():getFontHeight(fontSm)
    local tc     = T.TextDim

    self:drawText("Categorias", cx, cy, tc.r, tc.g, tc.b, tc.a, fontSm)

    local rx = cx + CAT_W + T.Gap + LIST_W + T.Gap
    self:drawText("Detalhe", rx, cy, tc.r, tc.g, tc.b, tc.a, fontSm)

    cy = cy + fh + T.Gap

    -- Divisor vertical entre categorias e lista
    local divX1 = cx + CAT_W + math.floor(T.Gap / 2)
    local divX2 = cx + CAT_W + T.Gap + LIST_W + math.floor(T.Gap / 2)
    local divH  = self.height - cy - T.Pad
    U.drawDivider(self, divX1, cy, 1)
    self:drawRect(divX1, cy, 1, divH, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    self:drawRect(divX2, cy, 1, divH, T.Border.a, T.Border.r, T.Border.g, T.Border.b)

    local listTop = cy + SEARCH_H + T.Gap
    local listH   = self.height - listTop - T.Pad * 2 - T.BtnH - T.Gap

    self:drawCategories(cx, cy, CAT_W, self.height - cy - T.Pad)
    self:drawRecipeList(cx + CAT_W + T.Gap, listTop, LIST_W, listH)
    self:drawDetail(rx, cy, DETAIL_W, listH + SEARCH_H + T.Gap)
end

-- ── Coluna de categorias ──────────────────────────────────────────────────────

function EUI_CraftingPanel:drawCategories(cx, cy, cw, ch)
    local font = T.FontSm
    local fh   = getTextManager():getFontHeight(font)
    local bg   = T.BG2
    self:drawRect(cx, cy, cw, ch, bg.a, bg.r, bg.g, bg.b)

    local yOff = cy - self._scrollCat
    local yEnd = cy + ch

    for _, cat in ipairs(self._categories) do
        if yOff + CAT_ROW_H >= cy and yOff <= yEnd then
            local sel = (cat == self._selCategory)
            local rbg = sel and T.BG_Select or T.BG2
            self:drawRect(cx, yOff, cw, CAT_ROW_H, rbg.a, rbg.r, rbg.g, rbg.b)

            if sel then
                self:drawRect(cx, yOff, 2, CAT_ROW_H, T.Green.a, T.Green.r, T.Green.g, T.Green.b)
            end

            local tc  = sel and T.TextGreen or T.Text
            local name = U.truncate(cat, cw - T.PadSm * 2 - (sel and 4 or 0), font)
            self:drawText(name, cx + T.PadSm + (sel and 4 or 0), yOff + math.floor((CAT_ROW_H - fh) / 2),
                tc.r, tc.g, tc.b, tc.a, font)
        end
        yOff = yOff + CAT_ROW_H + T.PadSm
    end
end

-- ── Lista de receitas ─────────────────────────────────────────────────────────

function EUI_CraftingPanel:drawRecipeList(cx, cy, cw, ch)
    local font = T.FontSm
    local fh   = getTextManager():getFontHeight(font)
    local bg   = T.BG2
    self:drawRect(cx, cy, cw, ch, bg.a, bg.r, bg.g, bg.b)

    local yOff = cy - self._scrollRec
    local yEnd = cy + ch

    for i, r in ipairs(self._filteredRecipes) do
        if yOff + REC_ROW_H >= cy and yOff <= yEnd then
            local sel  = (r == self._selRecipe)
            local alt  = (i % 2 == 0)
            local rbg  = sel and T.BG_Select or (alt and T.BG3 or T.BG2)
            self:drawRect(cx, yOff, cw, REC_ROW_H, rbg.a, rbg.r, rbg.g, rbg.b)

            if sel then
                self:drawRect(cx, yOff, 2, REC_ROW_H, T.Green.a, T.Green.r, T.Green.g, T.Green.b)
            end

            -- Disponibilidade
            local avail = false
            local player = getSpecificPlayer(self.playerNum)
            if player then
                pcall(function() avail = r.rec:isAvailable(player) end)
            end
            local tc = sel and T.TextGreen or (avail and T.Text or T.TextOff)

            local name = U.truncate(r.name, cw - T.PadSm * 2 - 4, font)
            self:drawText(name, cx + T.PadSm + (sel and 4 or 0),
                yOff + math.floor((REC_ROW_H - fh) / 2), tc.r, tc.g, tc.b, tc.a, font)

            -- Ícone de disponível (checkmark)
            if avail then
                local gc = T.Green
                self:drawText("✓", cx + cw - 16, yOff + math.floor((REC_ROW_H - fh) / 2),
                    gc.r, gc.g, gc.b, gc.a, font)
            end
        end
        yOff = yOff + REC_ROW_H + T.PadSm
    end

    -- Scrollbar
    if self._maxScrollRec > 0 then
        local totalH = #self._filteredRecipes * (REC_ROW_H + T.PadSm)
        local ratio  = ch / totalH
        local barH   = math.max(20, math.floor(ch * ratio))
        local barY   = cy + math.floor(self._scrollRec / self._maxScrollRec * (ch - barH))
        local sbg    = T.BG3
        local sfg    = T.Border
        self:drawRect(cx + cw, cy, T.ScrollW, ch, sbg.a, sbg.r, sbg.g, sbg.b)
        self:drawRect(cx + cw + 1, barY, T.ScrollW - 2, barH, sfg.a, sfg.r, sfg.g, sfg.b)
    end
end

-- ── Painel de detalhe ─────────────────────────────────────────────────────────

function EUI_CraftingPanel:drawDetail(cx, cy, cw, ch)
    local bg = T.BG2
    self:drawRect(cx, cy, cw, ch, bg.a, bg.r, bg.g, bg.b)

    local rec = self._selRecipe
    if not rec then
        local tc   = T.TextOff
        local font = T.FontSm
        local msg  = "Selecione uma receita"
        local mw   = getTextManager():MeasureStringX(font, msg)
        self:drawText(msg, cx + math.floor((cw - mw) / 2), cy + 40, tc.r, tc.g, tc.b, tc.a, font)
        return
    end

    local font  = T.FontSm
    local fontM = T.Font
    local fh    = getTextManager():getFontHeight(font)
    local fhM   = getTextManager():getFontHeight(fontM)
    local y     = cy + T.Pad
    local tc    = T.Text
    local dim   = T.TextDim

    -- Nome da receita
    local name = U.truncate(rec.name, cw - T.Pad * 2, fontM)
    self:drawText(name, cx + T.Pad, y, tc.r, tc.g, tc.b, tc.a, fontM)
    y = y + fhM + T.Gap

    -- Categoria
    self:drawText("Categoria: " .. (rec.cat or "?"), cx + T.Pad, y, dim.r, dim.g, dim.b, dim.a, font)
    y = y + fh + T.Gap + 2

    U.drawDivider(self, cx + T.Pad, y, cw - T.Pad * 2)
    y = y + T.Gap + 2

    -- Ingredientes
    local hdr = T.TextGreen
    self:drawText("Ingredientes:", cx + T.Pad, y, hdr.r, hdr.g, hdr.b, hdr.a, font)
    y = y + fh + T.PadSm

    local player = getSpecificPlayer(self.playerNum)
    local ingrs  = {}
    pcall(function()
        local il = rec.rec:getIngredients()
        if il then
            for i = 0, il:size() - 1 do
                local ing = il:get(i)
                if ing then
                    local iname = "?"
                    local qty   = 1
                    local have  = 0
                    pcall(function() iname = ing:getName() or "?" end)
                    pcall(function() qty   = ing:getCount()  or 1  end)
                    if player then
                        pcall(function()
                            have = player:getInventory():getCountType(iname)
                        end)
                    end
                    table.insert(ingrs, { name=iname, qty=qty, have=have })
                end
            end
        end
    end)

    if #ingrs == 0 then
        self:drawText("  (sem ingredientes listados)", cx + T.Pad, y, dim.r, dim.g, dim.b, dim.a, font)
        y = y + fh + T.PadSm
    else
        for _, ing in ipairs(ingrs) do
            local ok  = ing.have >= ing.qty
            local col = ok and T.TextGreen or T.TextRed
            local line = string.format("  %s  %d/%d", U.truncate(ing.name, cw - 80, font), ing.have, ing.qty)
            self:drawText(line, cx + T.Pad, y, col.r, col.g, col.b, col.a, font)
            local sym = ok and "✓" or "✗"
            self:drawText(sym, cx + cw - 20, y, col.r, col.g, col.b, col.a, font)
            y = y + fh + T.PadSm
            if y > cy + ch - fh - T.Pad then break end
        end
    end
end

-- ── Mouse ─────────────────────────────────────────────────────────────────────

function EUI_CraftingPanel:onMouseDown(mx, my)
    EUI_BasePanel.onMouseDown(self, mx, my)
    if my <= T.TitleH then return end

    local cx      = self:contentX()
    local cy      = self:contentY()
    local fontSm  = T.FontSm
    local fh      = getTextManager():getFontHeight(fontSm)

    -- Clique em categoria
    local catX = cx
    local catY = cy + fh + T.Gap
    if U.inRect(mx, my, catX, catY, CAT_W, self.height - catY - T.Pad) then
        local rel = my - catY + self._scrollCat
        local idx = math.floor(rel / (CAT_ROW_H + T.PadSm)) + 1
        if self._categories[idx] then
            self:selectCategory(self._categories[idx])
        end
        return
    end

    -- Clique em receita
    local listTop = cy + fh + T.Gap + SEARCH_H + T.Gap
    local recX    = cx + CAT_W + T.Gap
    local listH   = self.height - listTop - T.Pad * 2 - T.BtnH - T.Gap
    if U.inRect(mx, my, recX, listTop, LIST_W, listH) then
        local rel = my - listTop + self._scrollRec
        local idx = math.floor(rel / (REC_ROW_H + T.PadSm)) + 1
        if self._filteredRecipes[idx] then
            self._selRecipe = self._filteredRecipes[idx]
        end
    end
end

function EUI_CraftingPanel:onMouseWheel(del)
    local mx = self:getMouseX()
    local cx = self:contentX()
    if mx < cx + CAT_W then
        self._scrollCat = U.clamp(self._scrollCat - del * CAT_ROW_H, 0, self._maxScrollCat)
    else
        self._scrollRec = U.clamp(self._scrollRec - del * REC_ROW_H, 0, self._maxScrollRec)
    end
    return true
end

-- ── Registro ──────────────────────────────────────────────────────────────────

Events.OnKeyPressed.Add(function(key)
    if key == EUI.getKey("Crafting") then
        if EUI._craftingPanel then
            EUI._craftingPanel:setVisible(not EUI._craftingPanel:isVisible())
            if EUI._craftingPanel:isVisible() then
                EUI._craftingPanel:loadRecipes()
            end
            return
        end
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local p  = EUI_CraftingPanel:new(
            math.floor((sw - PANEL_W) / 2),
            math.floor((sh - PANEL_H) / 2), 0)
        p:initialise(); p:instantiate(); p:addToUIManager(); p:setVisible(true)
        EUI._craftingPanel = p
    end
end)
