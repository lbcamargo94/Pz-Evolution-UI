-- EUI_BuildingPanel.lua — painel de construção (B42)

EUI = EUI or {}

EUI_BuildingPanel = EUI_BasePanel:derive("EUI_BuildingPanel")

local T = EUI.Theme
local U = EUI.Utils

local PANEL_W   = 580
local PANEL_H   = 540
local CAT_W     = 140
local LIST_W    = 200
local DETAIL_W  = PANEL_W - CAT_W - LIST_W - T.Pad * 4 - T.Gap * 2
local CAT_ROW_H = 28
local REC_ROW_H = 30
local SEARCH_H  = 26

-- Ícones por categoria de construção
local CAT_ICONS = {
    ["Paredes"]      = "🧱",
    ["Pisos"]        = "⬜",
    ["Portas"]       = "🚪",
    ["Janelas"]      = "🪟",
    ["Escadas"]      = "🪜",
    ["Cercas"]       = "🔩",
    ["Móveis"]       = "🪑",
    ["Armazenamento"]= "📦",
    ["Produção"]     = "⚙",
    ["Outros"]       = "🔧",
}

-- ── Constructor ───────────────────────────────────────────────────────────────

function EUI_BuildingPanel:new(x, y, playerNum)
    local o = EUI_BasePanel.new(self, x, y, PANEL_W, PANEL_H, "Construção")
    o.playerNum        = playerNum or 0
    o.showCloseButton  = true
    o._categories      = {}
    o._recipes         = {}
    o._filtered        = {}
    o._selCat          = nil
    o._selRec          = nil
    o._searchText      = ""
    o._scrollCat       = 0
    o._scrollRec       = 0
    o._maxScrollCat    = 0
    o._maxScrollRec    = 0
    return o
end

function EUI_BuildingPanel:initialise()
    EUI_BasePanel.initialise(self)
    self:buildSearch()
    self:buildActionBtn()
    self:loadBuildRecipes()
end

function EUI_BuildingPanel:buildSearch()
    local cx = self:contentX() + CAT_W + T.Gap
    local cy = self:contentY()
    self._searchBox = ISTextEntryBox:new("", cx, cy, LIST_W, SEARCH_H)
    self._searchBox:initialise(); self._searchBox:instantiate()
    self._searchBox.placeholder     = "Buscar construção…"
    self._searchBox.backgroundColor = T.BG3
    self._searchBox.borderColor     = T.Border
    self._searchBox.textColor       = T.Text
    self._searchBox.onTextChange    = function() self:onSearch() end
    self:addChild(self._searchBox)
end

function EUI_BuildingPanel:buildActionBtn()
    local bw = DETAIL_W - T.Pad
    local bh = T.BtnH
    local bx = self:contentX() + CAT_W + T.Gap + LIST_W + T.Gap
    local by = self.height - T.Pad * 2 - bh
    self._btnBuild = EUI_BaseButton:new(bx, by, bw, bh, "Construir", self,
        EUI_BuildingPanel.onBuild, "primary")
    self._btnBuild:initialise(); self._btnBuild:instantiate(); self:addChild(self._btnBuild)
end

-- ── Dados ─────────────────────────────────────────────────────────────────────

function EUI_BuildingPanel:loadBuildRecipes()
    self._categories = {}
    self._recipes    = {}
    local catSet     = {}

    -- B42: ISBuildMenu mantém as receitas de construção
    local ok, menu = pcall(function() return ISBuildMenu end)
    if ok and menu then
        local cats = nil
        pcall(function() cats = menu.getCategories and menu:getCategories() end)
        if cats then
            for i = 0, cats:size() - 1 do
                local cat = cats:get(i)
                if cat then
                    local cname = cat:getName() or "Outros"
                    if not catSet[cname] then
                        catSet[cname] = true
                        table.insert(self._categories, cname)
                    end
                    local recs = cat.getRecipes and cat:getRecipes()
                    if recs then
                        for j = 0, recs:size() - 1 do
                            local rec = recs:get(j)
                            if rec then
                                local rname = "?"
                                pcall(function() rname = rec:getName() or "?" end)
                                table.insert(self._recipes, { name=rname, cat=cname, rec=rec })
                            end
                        end
                    end
                end
            end
        end
    end

    -- Fallback: popula com construções hardcoded comuns do B42
    if #self._recipes == 0 then
        local fallback = {
            { cat="Paredes",        name="Parede de Madeira"        },
            { cat="Paredes",        name="Parede de Metal"          },
            { cat="Paredes",        name="Parede de Toras"          },
            { cat="Pisos",          name="Piso de Madeira"          },
            { cat="Pisos",          name="Piso de Metal"            },
            { cat="Portas",         name="Porta de Madeira"         },
            { cat="Janelas",        name="Janela com Grade"         },
            { cat="Escadas",        name="Escada de Madeira"        },
            { cat="Cercas",         name="Cerca de Arame"           },
            { cat="Cercas",         name="Cerca de Madeira"         },
            { cat="Móveis",         name="Mesa de Trabalho"         },
            { cat="Móveis",         name="Cama"                     },
            { cat="Armazenamento",  name="Caixote de Madeira"       },
            { cat="Produção",       name="Fogão a Lenha"            },
            { cat="Produção",       name="Destilador"               },
        }
        for _, f in ipairs(fallback) do
            if not catSet[f.cat] then
                catSet[f.cat] = true
                table.insert(self._categories, f.cat)
            end
            table.insert(self._recipes, { name=f.name, cat=f.cat, rec=nil })
        end
    end

    table.sort(self._categories)
    if #self._categories > 0 then self:selectCat(self._categories[1]) end
end

function EUI_BuildingPanel:selectCat(cat)
    self._selCat = cat; self._selRec = nil; self._scrollRec = 0
    self:applyFilter()
end

function EUI_BuildingPanel:onSearch()
    self._searchText = self._searchBox:getText() or ""
    self._selRec     = nil; self._scrollRec = 0
    self:applyFilter()
end

function EUI_BuildingPanel:applyFilter()
    local q   = self._searchText:lower()
    local cat = self._selCat
    self._filtered = {}
    for _, r in ipairs(self._recipes) do
        local mCat = not cat or r.cat == cat
        local mQ   = q == "" or r.name:lower():find(q, 1, true)
        if mCat and mQ then table.insert(self._filtered, r) end
    end
    local ch            = self:contentH() - SEARCH_H - T.Gap
    self._maxScrollRec  = math.max(0, #self._filtered * (REC_ROW_H + T.PadSm) - ch)
    self._maxScrollCat  = math.max(0, #self._categories * (CAT_ROW_H + T.PadSm) - self:contentH())
end

-- ── Ação ──────────────────────────────────────────────────────────────────────

function EUI_BuildingPanel:onBuild()
    if not self._selRec or not self._selRec.rec then return end
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    pcall(function() self._selRec.rec:perform(player) end)
end

-- ── Render ────────────────────────────────────────────────────────────────────

function EUI_BuildingPanel:render()
    local cy      = self:contentY()
    local cx      = self:contentX()
    local fontSm  = T.FontSm
    local fh      = getTextManager():getFontHeight(fontSm)
    local dim     = T.TextDim

    -- Cabeçalhos
    self:drawText("Categorias", cx, cy, dim.r, dim.g, dim.b, dim.a, fontSm)
    local rx = cx + CAT_W + T.Gap + LIST_W + T.Gap
    self:drawText("Detalhe", rx, cy, dim.r, dim.g, dim.b, dim.a, fontSm)
    cy = cy + fh + T.Gap

    -- Divisores verticais
    local dh = self.height - cy - T.Pad
    self:drawRect(cx + CAT_W + math.floor(T.Gap/2), cy, 1, dh, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    self:drawRect(rx - math.floor(T.Gap/2), cy, 1, dh, T.Border.a, T.Border.r, T.Border.g, T.Border.b)

    local listTop = cy + SEARCH_H + T.Gap
    local listH   = self.height - listTop - T.Pad * 2 - T.BtnH - T.Gap

    self:drawCategories(cx, cy, CAT_W, self.height - cy - T.Pad)
    self:drawRecipes(cx + CAT_W + T.Gap, listTop, LIST_W, listH)
    self:drawDetail(rx, cy, DETAIL_W, listH + SEARCH_H + T.Gap)
end

function EUI_BuildingPanel:drawCategories(cx, cy, cw, ch)
    local font = T.FontSm
    local fh   = getTextManager():getFontHeight(font)
    local bg   = T.BG2
    self:drawRect(cx, cy, cw, ch, bg.a, bg.r, bg.g, bg.b)

    local yOff = cy - self._scrollCat
    for _, cat in ipairs(self._categories) do
        if yOff + CAT_ROW_H >= cy and yOff <= cy + ch then
            local sel = cat == self._selCat
            local rbg = sel and T.BG_Select or T.BG2
            self:drawRect(cx, yOff, cw, CAT_ROW_H, rbg.a, rbg.r, rbg.g, rbg.b)
            if sel then
                self:drawRect(cx, yOff, 2, CAT_ROW_H, T.Green.a, T.Green.r, T.Green.g, T.Green.b)
            end
            local icon = CAT_ICONS[cat] or "▸"
            local tc   = sel and T.TextGreen or T.Text
            local label = icon .. " " .. U.truncate(cat, cw - T.Pad * 2 - 14, font)
            self:drawText(label, cx + T.PadSm + (sel and 4 or 0),
                yOff + math.floor((CAT_ROW_H - fh) / 2), tc.r, tc.g, tc.b, tc.a, font)
        end
        yOff = yOff + CAT_ROW_H + T.PadSm
    end
end

function EUI_BuildingPanel:drawRecipes(cx, cy, cw, ch)
    local font = T.FontSm
    local fh   = getTextManager():getFontHeight(font)
    local bg   = T.BG2
    self:drawRect(cx, cy, cw, ch, bg.a, bg.r, bg.g, bg.b)

    local yOff = cy - self._scrollRec
    local player = getSpecificPlayer(self.playerNum)

    for i, r in ipairs(self._filtered) do
        if yOff + REC_ROW_H >= cy and yOff <= cy + ch then
            local sel = r == self._selRec
            local rbg = sel and T.BG_Select or (i % 2 == 0 and T.BG3 or T.BG2)
            self:drawRect(cx, yOff, cw, REC_ROW_H, rbg.a, rbg.r, rbg.g, rbg.b)
            if sel then
                self:drawRect(cx, yOff, 2, REC_ROW_H, T.Green.a, T.Green.r, T.Green.g, T.Green.b)
            end

            -- Disponibilidade
            local avail = false
            if player and r.rec then
                pcall(function() avail = r.rec:canBuild(player) end)
            end
            local tc   = sel and T.TextGreen or (avail and T.Text or T.TextOff)
            local name = U.truncate(r.name, cw - T.PadSm * 2 - 18, font)
            self:drawText(name, cx + T.PadSm + (sel and 4 or 0),
                yOff + math.floor((REC_ROW_H - fh) / 2), tc.r, tc.g, tc.b, tc.a, font)
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
        local totalH = #self._filtered * (REC_ROW_H + T.PadSm)
        local ratio  = ch / totalH
        local barH   = math.max(20, math.floor(ch * ratio))
        local barY   = cy + math.floor(self._scrollRec / self._maxScrollRec * (ch - barH))
        self:drawRect(cx + cw, cy, T.ScrollW, ch, T.BG3.a, T.BG3.r, T.BG3.g, T.BG3.b)
        self:drawRect(cx + cw + 1, barY, T.ScrollW - 2, barH, T.Border.a, T.Border.r, T.Border.g, T.Border.b)
    end
end

function EUI_BuildingPanel:drawDetail(cx, cy, cw, ch)
    local bg = T.BG2
    self:drawRect(cx, cy, cw, ch, bg.a, bg.r, bg.g, bg.b)

    local r = self._selRec
    if not r then
        local tc  = T.TextOff; local font = T.FontSm
        local msg = "Selecione uma construção"
        local mw  = getTextManager():MeasureStringX(font, msg)
        self:drawText(msg, cx + math.floor((cw - mw) / 2), cy + 40, tc.r, tc.g, tc.b, tc.a, font)
        return
    end

    local font  = T.Font; local sm = T.FontSm
    local fhM   = getTextManager():getFontHeight(font)
    local fh    = getTextManager():getFontHeight(sm)
    local y     = cy + T.Pad; local tc = T.Text; local dim = T.TextDim

    -- Nome
    self:drawText(U.truncate(r.name, cw - T.Pad * 2, font), cx + T.Pad, y, tc.r, tc.g, tc.b, tc.a, font)
    y = y + fhM + T.Gap

    -- Categoria
    local icon = CAT_ICONS[r.cat] or ""
    self:drawText(icon .. " " .. (r.cat or "?"), cx + T.Pad, y, dim.r, dim.g, dim.b, dim.a, sm)
    y = y + fh + T.Gap

    U.drawDivider(self, cx + T.Pad, y, cw - T.Pad * 2); y = y + T.Gap + 2

    -- Materiais necessários
    local hdr = T.TextGreen
    self:drawText("Materiais:", cx + T.Pad, y, hdr.r, hdr.g, hdr.b, hdr.a, sm)
    y = y + fh + T.PadSm

    local player = getSpecificPlayer(self.playerNum)
    local mats   = {}
    if r.rec then
        pcall(function()
            local ml = r.rec.getMaterials and r.rec:getMaterials()
            if ml then
                for i = 0, ml:size() - 1 do
                    local m = ml:get(i)
                    if m then
                        local mname = "?"; local qty = 1; local have = 0
                        pcall(function() mname = m:getName() or "?" end)
                        pcall(function() qty   = m:getCount()  or 1  end)
                        if player then
                            pcall(function()
                                have = player:getInventory():getCountType(mname)
                            end)
                        end
                        table.insert(mats, { name=mname, qty=qty, have=have })
                    end
                end
            end
        end)
    end

    if #mats == 0 then
        self:drawText("  (verifique no jogo)", cx + T.Pad, y, dim.r, dim.g, dim.b, dim.a, sm)
    else
        for _, m in ipairs(mats) do
            local ok  = m.have >= m.qty
            local col = ok and T.TextGreen or T.TextRed
            local line = string.format("  %s  %d/%d",
                U.truncate(m.name, cw - 80, sm), m.have, m.qty)
            self:drawText(line, cx + T.Pad, y, col.r, col.g, col.b, col.a, sm)
            self:drawText(ok and "✓" or "✗", cx + cw - 20, y, col.r, col.g, col.b, col.a, sm)
            y = y + fh + T.PadSm
            if y > cy + ch - fh - T.Pad then break end
        end
    end

    -- Habilidade necessária
    if r.rec then
        local skill, lvl = nil, 0
        pcall(function()
            skill = r.rec.getRequiredSkill and r.rec:getRequiredSkill()
            lvl   = r.rec.getRequiredSkillLevel and r.rec:getRequiredSkillLevel() or 0
        end)
        if skill then
            U.drawDivider(self, cx + T.Pad, y + T.Gap, cw - T.Pad * 2)
            y = y + T.Gap * 2 + 2
            local playerLvl = 0
            if player then pcall(function() playerLvl = player:getPerkLevel(skill) end) end
            local col = playerLvl >= lvl and T.TextGreen or T.TextRed
            local sname = "?"
            pcall(function() sname = skill:getName() or "?" end)
            self:drawText(string.format("Skill: %s Nível %d", sname, lvl), cx + T.Pad, y,
                col.r, col.g, col.b, col.a, sm)
        end
    end
end

-- ── Mouse ─────────────────────────────────────────────────────────────────────

function EUI_BuildingPanel:onMouseDown(mx, my)
    EUI_BasePanel.onMouseDown(self, mx, my)
    if my <= T.TitleH then return end
    local cx  = self:contentX()
    local cy  = self:contentY()
    local fh  = getTextManager():getFontHeight(T.FontSm)
    local top = cy + fh + T.Gap

    -- Categoria
    if U.inRect(mx, my, cx, top, CAT_W, self.height - top - T.Pad) then
        local rel = my - top + self._scrollCat
        local idx = math.floor(rel / (CAT_ROW_H + T.PadSm)) + 1
        if self._categories[idx] then self:selectCat(self._categories[idx]) end
        return
    end

    -- Receita
    local lx  = cx + CAT_W + T.Gap
    local lTop = top + SEARCH_H + T.Gap
    local lH   = self.height - lTop - T.Pad * 2 - T.BtnH - T.Gap
    if U.inRect(mx, my, lx, lTop, LIST_W, lH) then
        local rel = my - lTop + self._scrollRec
        local idx = math.floor(rel / (REC_ROW_H + T.PadSm)) + 1
        if self._filtered[idx] then self._selRec = self._filtered[idx] end
    end
end

function EUI_BuildingPanel:onMouseWheel(del)
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
    if key == EUI.getKey("Build") then
        if EUI._buildingPanel then
            EUI._buildingPanel:setVisible(not EUI._buildingPanel:isVisible())
            if EUI._buildingPanel:isVisible() then EUI._buildingPanel:loadBuildRecipes() end
            return
        end
        local sw = getCore():getScreenWidth()
        local sh = getCore():getScreenHeight()
        local p  = EUI_BuildingPanel:new(math.floor((sw - PANEL_W) / 2), math.floor((sh - PANEL_H) / 2), 0)
        p:initialise(); p:instantiate(); p:addToUIManager(); p:setVisible(true)
        EUI._buildingPanel = p
    end
end)
