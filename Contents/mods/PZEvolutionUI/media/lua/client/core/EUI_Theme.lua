-- EUI_Theme.lua — design tokens centralizados
-- Todos os painéis importam daqui; mudar aqui muda tudo.

EUI = EUI or {}

EUI.Theme = {
    -- ── Fundos ────────────────────────────────────────────────────────────────
    BG         = { r=0.07, g=0.07, b=0.09, a=0.97 },   -- painel principal
    BG2        = { r=0.10, g=0.10, b=0.13, a=0.97 },   -- seção interna
    BG3        = { r=0.13, g=0.13, b=0.17, a=0.95 },   -- item / linha
    BG_Hover   = { r=0.17, g=0.17, b=0.22, a=1.00 },   -- hover de linha
    BG_Select  = { r=0.12, g=0.28, b=0.18, a=1.00 },   -- selecionado
    BG_Header  = { r=0.05, g=0.05, b=0.07, a=0.99 },   -- cabeçalho / barra de título

    -- ── Bordas ────────────────────────────────────────────────────────────────
    Border     = { r=0.20, g=0.20, b=0.26, a=0.85 },
    BorderFocus= { r=0.22, g=0.65, b=0.38, a=1.00 },   -- foco / destaque verde

    -- ── Acentos ───────────────────────────────────────────────────────────────
    Green      = { r=0.22, g=0.75, b=0.42, a=1.00 },   -- ação positiva
    GreenHover = { r=0.28, g=0.90, b=0.52, a=1.00 },
    Red        = { r=0.82, g=0.22, b=0.22, a=1.00 },   -- perigo / morte
    RedHover   = { r=0.95, g=0.28, b=0.28, a=1.00 },
    Yellow     = { r=0.90, g=0.70, b=0.15, a=1.00 },   -- aviso
    Blue       = { r=0.25, g=0.55, b=0.90, a=1.00 },   -- informação

    -- ── Texto ─────────────────────────────────────────────────────────────────
    Text       = { r=0.92, g=0.92, b=0.93, a=1.00 },
    TextDim    = { r=0.60, g=0.60, b=0.65, a=1.00 },
    TextOff    = { r=0.38, g=0.38, b=0.42, a=1.00 },
    TextGreen  = { r=0.22, g=0.88, b=0.50, a=1.00 },
    TextRed    = { r=0.95, g=0.35, b=0.35, a=1.00 },
    TextYellow = { r=0.95, g=0.78, b=0.22, a=1.00 },

    -- ── Espaçamento ───────────────────────────────────────────────────────────
    Pad        = 8,     -- padding padrão
    PadLg      = 14,    -- padding grande (cabeçalhos, seções)
    PadSm      = 4,     -- padding pequeno (ícones, badges)
    Gap        = 6,     -- gap entre elementos
    TitleH     = 30,    -- altura da barra de título dos painéis
    RowH       = 26,    -- altura de linha de item
    BtnH       = 26,    -- altura de botão
    BtnHSm     = 20,    -- altura de botão pequeno
    ScrollW    = 10,    -- largura da scrollbar

    -- ── Fontes ────────────────────────────────────────────────────────────────
    FontSm     = UIFont.Small,
    Font       = UIFont.Medium,
    FontLg     = UIFont.Large,
    FontTitle  = UIFont.Title,
}

-- Atalhos rápidos para as cores mais usadas
function EUI.Theme:c(key) return self[key] end
