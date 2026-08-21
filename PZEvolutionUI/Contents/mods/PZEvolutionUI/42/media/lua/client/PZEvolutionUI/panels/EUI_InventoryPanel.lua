-- EUI_InventoryPanel.lua — painel de inventário e loot redesenhado

EUI = EUI or {}

-- ── EUI_ItemRow ───────────────────────────────────────────────────────────────
-- Representa uma linha de item dentro de uma lista de inventário

EUI_ItemRow = ISPanel:derive("EUI_ItemRow")
local T = EUI.Theme
local U = EUI.Utils

function EUI_ItemRow:new(x, y, w, item, playerNum)
    local o = ISPanel.new(self, x, y, w, T.RowH)
    o.item       = item
    o.playerNum  = playerNum or 0
    o._hovered   = false
    o._selected  = false
    return o
end

function EUI_ItemRow:initialise() ISPanel.initialise(self) end

function EUI_ItemRow:prerender()
    local bg
    if self._selected then
        bg = T.BG_Select
    elseif self._hovered then
        bg = T.BG_Hover
    else
        bg = T.BG3
    end
    self:drawRect(0, 0, self.width, self.height, bg.a, bg.r, bg.g, bg.b)
end

function EUI_ItemRow:render()
    if not self.item then return end

    local item   = self.item
    local font   = T.FontSm
    local fh     = getTextManager():getFontHeight(font)
    local ty     = math.floor((self.height - fh) / 2)
    local x      = T.PadSm

    -- Ícone do item (textura)
    local iconSz = self.height - 4
    local tex    = item:getTex()
    if tex then
        self:drawTextureScaled(tex, x, 2, iconSz, iconSz, 1, 1, 1, 1)
    end
    x = x + iconSz + T.PadSm

    -- Nome do item (truncado)
    local name     = item:getName() or "?"
    local rarColor = U.rarityColor(item)
    local maxNameW = self.width - x - 80
    name = U.truncate(name, maxNameW, font)
    self:drawText(name, x, ty, rarColor.r, rarColor.g, rarColor.b, rarColor.a, font)

    -- Peso (direita)
    local wStr  = U.fmtWeight(item:getWeight() or 0) .. " kg"
    local ww    = getTextManager():MeasureStringX(font, wStr)
    local dim   = T.TextDim
    self:drawText(wStr, self.width - ww - T.PadSm, ty, dim.r, dim.g, dim.b, dim.a, font)

    -- Durabilidade (se aplicável) — barra compacta abaixo do nome
    local hasDur = pcall(function() return item:getConditionMax() end)
    if hasDur then
        local ok, cond    = pcall(function() return item:getCondition()    end)
        local ok2, condMax = pcall(function() return item:getConditionMax() end)
        if ok and ok2 and condMax and condMax > 0 then
            local pct = cond / condMax
            local barW = math.min(80, maxNameW)
            local barY = self.height - 4
            local col  = pct > 0.5 and T.Green or (pct > 0.25 and T.Yellow or T.Red)
            U.drawBar(self, x, barY, barW, 2, pct, col)
        end
    end
end

function EUI_ItemRow:onMouseMove()     self._hovered = true  end
function EUI_ItemRow:onMouseMoveOutside() self._hovered = false end

-- ── EUI_InventoryList ─────────────────────────────────────────────────────────
-- Lista scrollável de itens

EUI_InventoryList = ISScrollingListBox:derive("EUI_InventoryList")

function EUI_InventoryList:new(x, y, w, h, playerNum)
    local o = ISScrollingListBox.new(self, x, y, w, h)
    o.playerNum   = playerNum or 0
    o.itemHeight  = T.RowH
    o._items      = {}
    o._selected   = nil
    o.drawBorder  = false
    return o
end

function EUI_InventoryList:initialise()
    ISScrollingListBox.initialise(self)
end

function EUI_InventoryList:prerender()
    local bg = T.BG2
    self:drawRect(0, 0, self.width, self.height, bg.a, bg.r, bg.g, bg.b)
end

function EUI_InventoryList:render()
    -- Scrollbar customizada
    local total = #self._items * T.RowH
    if total > self.height then
        local ratio   = self.height / total
        local barH    = math.max(20, math.floor(self.height * ratio))
        local barY    = math.floor((self.joypadY or 0) / total * self.height)
        local sx      = self.width - T.ScrollW
        local sbg     = T.BG3
        local sfg     = T.Border
        self:drawRect(sx, 0, T.ScrollW, self.height, sbg.a, sbg.r, sbg.g, sbg.b)
        self:drawRect(sx + 1, barY, T.ScrollW - 2, barH, sfg.a, sfg.r, sfg.g, sfg.b)
    end
end

function EUI_InventoryList:populateFromInventory(inventory)
    self._items = {}
    self:clear()
    if not inventory then return end
    local items = inventory:getItems()
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and not item:isHidden() then
            self:addItem(item:getName() or "?", item)
        end
    end
end

function EUI_InventoryList:doDrawItem(y, item, alt)
    if not item or not item.item then return end
    local it     = item.item
    local font   = T.FontSm
    local fh     = getTextManager():getFontHeight(font)
    local ty     = y + math.floor((T.RowH - fh) / 2)
    local x      = T.PadSm
    local sel    = (self.selected == item.index)

    -- Fundo de linha
    local bg = sel and T.BG_Select or (alt and T.BG3 or T.BG2)
    self:drawRect(0, y, self.width - T.ScrollW, T.RowH, bg.a, bg.r, bg.g, bg.b)

    -- Ícone
    local iconSz = T.RowH - 4
    local tex    = it.getTex and it:getTex()
    if tex then self:drawTextureScaled(tex, x, y + 2, iconSz, iconSz, 1, 1, 1, 1) end
    x = x + iconSz + T.PadSm

    -- Nome
    local name     = it:getName() or "?"
    local rarColor = U.rarityColor(it)
    local maxW     = self.width - x - 70 - T.ScrollW
    name = U.truncate(name, maxW, font)
    self:drawText(name, x, ty, rarColor.r, rarColor.g, rarColor.b, rarColor.a, font)

    -- Peso
    local wStr = U.fmtWeight(it.getWeight and it:getWeight() or 0) .. " kg"
    local ww   = getTextManager():MeasureStringX(font, wStr)
    local dim  = T.TextDim
    self:drawText(wStr, self.width - ww - T.ScrollW - T.PadSm, ty, dim.r, dim.g, dim.b, dim.a, font)

    -- Barra de durabilidade
    local ok,  cond    = pcall(function() return it:getCondition()    end)
    local ok2, condMax = pcall(function() return it:getConditionMax() end)
    if ok and ok2 and condMax and condMax > 0 then
        local pct = cond / condMax
        local col = pct > 0.5 and T.Green or (pct > 0.25 and T.Yellow or T.Red)
        U.drawBar(self, x, y + T.RowH - 3, math.min(70, maxW), 2, pct, col)
    end
end

-- ── EUI_InventoryPage ─────────────────────────────────────────────────────────
-- Substitui ISInventoryPage — janela principal com dois painéis (player + loot)

EUI_InventoryPage = EUI_BasePanel:derive("EUI_InventoryPage")

local PANEL_W       = 380
local PANEL_H       = 580
local SEARCH_H      = 28
local TOOLBAR_H     = 34
local SPLIT_GAP     = 4

function EUI_InventoryPage:new(x, y, playerNum)
    local totalW = PANEL_W * 2 + SPLIT_GAP + T.Pad * 2
    local o = EUI_BasePanel.new(self, x, y, totalW, PANEL_H, "Inventário")
    o.playerNum      = playerNum or 0
    o.showCloseButton = true
    o._searchPlayer  = ""
    o._searchLoot    = ""
    o._sortMode      = "name"   -- "name" | "weight" | "type"
    return o
end

function EUI_InventoryPage:initialise()
    EUI_BasePanel.initialise(self)
    self:buildUI()
end

function EUI_InventoryPage:buildUI()
    local cy = self:contentY()
    local cx = self:contentX()
    local cw = self:contentW()

    -- Largura de cada sub-painel
    local paneW = math.floor((cw - SPLIT_GAP) / 2)

    -- ── Lado esquerdo: inventário do jogador ──────────────────────────────────

    local lx = cx

    -- Label "Meu Inventário"
    self._lblPlayer = ISLabel:new(lx, cy, T.TitleH, "Meu Inventário", T.Text.r, T.Text.g, T.Text.b, T.Text.a, T.Font, false)
    self._lblPlayer:initialise()
    self:addChild(self._lblPlayer)

    -- Label de peso do jogador
    self._lblPlayerWeight = ISLabel:new(lx + paneW - 90, cy, T.TitleH, "0,0 / 0,0 kg", T.TextDim.r, T.TextDim.g, T.TextDim.b, T.TextDim.a, T.FontSm, false)
    self._lblPlayerWeight:initialise()
    self:addChild(self._lblPlayerWeight)

    cy = cy + T.TitleH + T.Gap

    -- Campo de busca — inventário do jogador
    self._searchPlayerInput = ISTextEntryBox:new("", lx, cy, paneW, SEARCH_H)
    self._searchPlayerInput:initialise()
    self._searchPlayerInput:instantiate()
    self._searchPlayerInput.placeholder = "Buscar item…"
    self._searchPlayerInput.backgroundColor = T.BG3
    self._searchPlayerInput.borderColor     = T.Border
    self._searchPlayerInput.textColor       = T.Text
    self:addChild(self._searchPlayerInput)

    cy = cy + SEARCH_H + T.Gap

    -- Lista de itens do jogador
    local listH = PANEL_H - cy - TOOLBAR_H - T.Pad * 2
    self._listPlayer = EUI_InventoryList:new(lx, cy, paneW, listH, self.playerNum)
    self._listPlayer:initialise()
    self._listPlayer:instantiate()
    self:addChild(self._listPlayer)

    -- ── Lado direito: loot / container ───────────────────────────────────────

    local rx = cx + paneW + SPLIT_GAP
    local cy2 = self:contentY()

    self._lblLoot = ISLabel:new(rx, cy2, T.TitleH, "Container", T.Text.r, T.Text.g, T.Text.b, T.Text.a, T.Font, false)
    self._lblLoot:initialise()
    self:addChild(self._lblLoot)

    self._lblLootWeight = ISLabel:new(rx + paneW - 90, cy2, T.TitleH, "0,0 kg", T.TextDim.r, T.TextDim.g, T.TextDim.b, T.TextDim.a, T.FontSm, false)
    self._lblLootWeight:initialise()
    self:addChild(self._lblLootWeight)

    cy2 = cy2 + T.TitleH + T.Gap

    self._searchLootInput = ISTextEntryBox:new("", rx, cy2, paneW, SEARCH_H)
    self._searchLootInput:initialise()
    self._searchLootInput:instantiate()
    self._searchLootInput.placeholder = "Buscar item…"
    self._searchLootInput.backgroundColor = T.BG3
    self._searchLootInput.borderColor     = T.Border
    self._searchLootInput.textColor       = T.Text
    self:addChild(self._searchLootInput)

    cy2 = cy2 + SEARCH_H + T.Gap

    self._listLoot = EUI_InventoryList:new(rx, cy2, paneW, listH, self.playerNum)
    self._listLoot:initialise()
    self._listLoot:instantiate()
    self:addChild(self._listLoot)

    -- ── Toolbar inferior ──────────────────────────────────────────────────────
    local toolY = PANEL_H - TOOLBAR_H - T.Pad
    local btnW  = 110
    local btnH  = T.BtnH

    -- Botão "Pegar Tudo"
    self._btnTakeAll = EUI_BaseButton:new(cx, toolY + math.floor((TOOLBAR_H - btnH) / 2), btnW, btnH, "← Pegar Tudo", self, EUI_InventoryPage.onTakeAll, "primary")
    self._btnTakeAll:initialise()
    self._btnTakeAll:instantiate()
    self:addChild(self._btnTakeAll)

    -- Botão "Transferir Tudo"
    self._btnTransferAll = EUI_BaseButton:new(cx + btnW + T.Gap, toolY + math.floor((TOOLBAR_H - btnH) / 2), btnW + 10, btnH, "Transferir Tudo →", self, EUI_InventoryPage.onTransferAll, "ghost")
    self._btnTransferAll:initialise()
    self._btnTransferAll:instantiate()
    self:addChild(self._btnTransferAll)

    -- Ordenação
    local sortX = cx + cw - 180
    local sorts = { { id="name", label="A-Z" }, { id="weight", label="Peso" }, { id="type", label="Tipo" } }
    for i, s in ipairs(sorts) do
        local bx = sortX + (i - 1) * (50 + T.Gap)
        local sb = EUI_BaseButton:new(bx, toolY + math.floor((TOOLBAR_H - T.BtnHSm) / 2), 50, T.BtnHSm, s.label, self, function(btn) self:setSortMode(s.id) end, "icon")
        sb:initialise()
        sb:instantiate()
        sb._sortId = s.id
        self:addChild(sb)
    end
end

function EUI_InventoryPage:update()
    EUI_BasePanel.update(self)
    self:refreshInventories()
end

function EUI_InventoryPage:refreshInventories()
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end

    -- Inventário do jogador
    local inv = player:getInventory()
    self._listPlayer:populateFromInventory(inv)

    -- Peso
    local curW = inv.getCapacityWeight and inv:getCapacityWeight() or 0
    local maxW = player.getMaxWeight and player:getMaxWeight() or 0
    self._lblPlayerWeight:setName(U.fmtWeight(curW) .. " / " .. U.fmtWeight(maxW) .. " kg")

    -- Loot container (se aberto)
    local lootInv = getPlayerLoot(self.playerNum)
    if lootInv then
        self._listLoot:populateFromInventory(lootInv.getInventory and lootInv:getInventory() or lootInv)
        local cname = lootInv.getName and lootInv:getName() or "Container"
        self._lblLoot:setName(cname)
        local lw = lootInv.getCapacityWeight and lootInv:getCapacityWeight() or 0
        self._lblLootWeight:setName(U.fmtWeight(lw) .. " kg")
    end
end

function EUI_InventoryPage:setSortMode(mode)
    self._sortMode = mode
    -- TODO: re-ordenar listas
end

function EUI_InventoryPage:onTakeAll()
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    local lootInv = getPlayerLoot(self.playerNum)
    if not lootInv then return end
    ISTimedActionQueue.add(ISTransferInventory:new(player, lootInv.getInventory and lootInv:getInventory() or lootInv, player:getInventory()))
end

function EUI_InventoryPage:onTransferAll()
    local player = getSpecificPlayer(self.playerNum)
    if not player then return end
    local lootInv = getPlayerLoot(self.playerNum)
    if not lootInv then return end
    ISTimedActionQueue.add(ISTransferInventory:new(player, player:getInventory(), lootInv.getInventory and lootInv:getInventory() or lootInv))
end

-- ── Registro no hook do jogo ──────────────────────────────────────────────────

local function onOpenInventory(playerNum)
    if EUI._inventoryPage and EUI._inventoryPage:isVisible() then
        EUI._inventoryPage:setVisible(false)
        return
    end

    local sw = getCore():getScreenWidth()
    local sh = getCore():getScreenHeight()
    local page = EUI_InventoryPage:new(
        math.floor((sw - (PANEL_W * 2 + SPLIT_GAP + EUI.Theme.Pad * 2)) / 2),
        math.floor((sh - PANEL_H) / 2),
        playerNum or 0
    )
    page:initialise()
    page:instantiate()
    page:addToUIManager()
    page:setVisible(true)
    EUI._inventoryPage = page
end

-- Intercepta a abertura do inventário vanilla
Events.OnKeyPressed.Add(function(key)
    -- Key 18 = 'I' (inventário) por padrão no PZ
    -- Verifica o bind real do jogo
    if key == EUI.getKey("Inventory") then
        -- Cancela o vanilla e abre o EUI
        -- (O hook correto depende da versão B42; ajustar se necessário)
        onOpenInventory(0)
    end
end)
