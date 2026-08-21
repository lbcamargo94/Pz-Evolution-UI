-- EUI_Utils.lua — funções auxiliares compartilhadas por todos os painéis

EUI = EUI or {}
EUI.Utils = {}

local T = EUI.Theme

-- ── Geometria ─────────────────────────────────────────────────────────────────

-- Desenha um retângulo com borda (fundo + contorno separados)
function EUI.Utils.drawBox(el, x, y, w, h, bg, border)
    bg     = bg     or T.BG
    border = border or T.Border
    el:drawRect(x, y, w, h, bg.a, bg.r, bg.g, bg.b)
    el:drawRectBorder(x, y, w, h, border.a, border.r, border.g, border.b)
end

-- Desenha barra de título de painel (fundo escuro + label centralizado)
function EUI.Utils.drawTitle(el, x, y, w, title, font)
    local h  = T.TitleH
    local bg = T.BG_Header
    el:drawRect(x, y, w, h, bg.a, bg.r, bg.g, bg.b)
    -- linha de separação na base do título
    local brd = T.Border
    el:drawRect(x, y + h - 1, w, 1, brd.a, brd.r, brd.g, brd.b)

    local tc = T.Text
    font = font or T.Font
    local tw = getTextManager():MeasureStringX(font, title)
    el:drawText(title, x + math.floor((w - tw) / 2), y + math.floor((h - getTextManager():getFontHeight(font)) / 2), tc.r, tc.g, tc.b, tc.a, font)
end

-- Desenha barra de progresso horizontal
function EUI.Utils.drawBar(el, x, y, w, h, pct, colorFull, colorBg)
    colorFull = colorFull or T.Green
    colorBg   = colorBg   or T.BG3
    pct       = math.max(0, math.min(1, pct))
    el:drawRect(x, y, w, h, colorBg.a, colorBg.r, colorBg.g, colorBg.b)
    if pct > 0 then
        el:drawRect(x, y, math.floor(w * pct), h, colorFull.a, colorFull.r, colorFull.g, colorFull.b)
    end
end

-- Desenha divisor horizontal fino
function EUI.Utils.drawDivider(el, x, y, w)
    local c = T.Border
    el:drawRect(x, y, w, 1, c.a, c.r, c.g, c.b)
end

-- ── Texto ──────────────────────────────────────────────────────────────────────

-- Trunca string com "…" se ultrapassar maxWidth em pixels
function EUI.Utils.truncate(text, maxWidth, font)
    font = font or EUI.Theme.Font
    if getTextManager():MeasureStringX(font, text) <= maxWidth then return text end
    local ellipsis = "…"
    local ew = getTextManager():MeasureStringX(font, ellipsis)
    local out = ""
    for i = 1, #text do
        local s = string.sub(text, 1, i)
        if getTextManager():MeasureStringX(font, s) + ew > maxWidth then
            return out .. ellipsis
        end
        out = s
    end
    return out .. ellipsis
end

-- Formata número grande: 1500 → "1.5k", 2000000 → "2M"
function EUI.Utils.fmtNum(n)
    if n >= 1000000 then return string.format("%.1fM", n / 1000000)
    elseif n >= 1000 then return string.format("%.1fk", n / 1000)
    else return tostring(n) end
end

-- Formata peso: 1.5 → "1,5"
function EUI.Utils.fmtWeight(w)
    return string.format("%.1f", w):gsub("%.", ",")
end

-- ── Hit-test ───────────────────────────────────────────────────────────────────

function EUI.Utils.inRect(mx, my, x, y, w, h)
    return mx >= x and mx <= x + w and my >= y and my <= y + h
end

-- ── Cor de raridade ────────────────────────────────────────────────────────────

local RARITY_COLORS = {
    Common    = { r=0.75, g=0.75, b=0.75, a=1 },
    Uncommon  = { r=0.30, g=0.85, b=0.30, a=1 },
    Rare      = { r=0.25, g=0.50, b=0.95, a=1 },
    Epic      = { r=0.65, g=0.25, b=0.95, a=1 },
    Legendary = { r=0.95, g=0.65, b=0.10, a=1 },
}
function EUI.Utils.rarityColor(item)
    if not item then return RARITY_COLORS.Common end
    -- B42 usa item:getRarity() ou similar; fallback para Common se não existir
    local ok, rarity = pcall(function() return item:getRarity() end)
    return RARITY_COLORS[ok and rarity or "Common"] or RARITY_COLORS.Common
end

-- ── Clamping / Math ────────────────────────────────────────────────────────────

function EUI.Utils.clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function EUI.Utils.lerp(a, b, t)    return a + (b - a) * t              end

-- ── B42 Fluid API ─────────────────────────────────────────────────────────────
-- B42 moveu os dados de fluido para um objeto FluidContainer separado.
-- Estas funções abstraem a diferença entre B41 e B42.

function EUI.Utils.getFluidContainer(item)
    local fc = nil
    pcall(function() fc = item:getFluidContainer() end)
    return fc
end

function EUI.Utils.isFluidItem(item)
    if EUI.Utils.getFluidContainer(item) then return true end
    local ok, v = pcall(function() return item:isDrainable() end)
    return ok and v == true
end

function EUI.Utils.getFluidAmount(item)
    local fc = EUI.Utils.getFluidContainer(item)
    if fc then
        local v = 0
        pcall(function() v = fc:getAmount() or 0 end)
        return v
    end
    local ok, v = pcall(function() return item:getCurrentLiquid() end)
    return (ok and v) or 0
end

function EUI.Utils.getFluidCapacity(item)
    local fc = EUI.Utils.getFluidContainer(item)
    if fc then
        local v = 1
        pcall(function() v = fc:getCapacity() or 1 end)
        return v
    end
    local ok, v = pcall(function() return item:getCapacity() end)
    return (ok and v) or 1
end

function EUI.Utils.getFluidName(item)
    local fc = EUI.Utils.getFluidContainer(item)
    if fc then
        local name = "Vazio"
        pcall(function()
            local ft = fc:getFluidType()
            if ft then name = ft:getName() or "Vazio" end
        end)
        return name
    end
    local ok, v = pcall(function() return item:getFluidName() end)
    return (ok and v) or "Vazio"
end

function EUI.Utils.isBoiledWater(item)
    local fc = EUI.Utils.getFluidContainer(item)
    if fc then
        local v = false
        pcall(function() v = fc.isBoiled and fc:isBoiled() end)
        return v == true
    end
    local ok, v = pcall(function() return item:isBoiledWater() end)
    return ok and v == true
end

function EUI.Utils.isTaintedWater(item)
    local fc = EUI.Utils.getFluidContainer(item)
    if fc then
        local v = false
        pcall(function() v = fc.isTainted and fc:isTainted() end)
        return v == true
    end
    local ok, v = pcall(function() return item:isTaintedWater() end)
    return ok and v == true
end

-- ── B42 Input ────────────────────────────────────────────────────────────────

function EUI.Utils.isShiftDown()
    local ok, v = pcall(function()
        return getKeyboard():isKeyDown(Keyboard.KEY_LSHIFT)
            or getKeyboard():isKeyDown(Keyboard.KEY_RSHIFT)
    end)
    return ok and v == true
end
