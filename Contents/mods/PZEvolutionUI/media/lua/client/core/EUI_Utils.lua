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
