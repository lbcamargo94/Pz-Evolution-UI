-- EUI_Keybinds.lua — registra keybinds do mod no sistema do PZ (B42)
-- Arquivo em shared/ para que os binds apareçam na tela de controles do jogo

EUI = EUI or {}
EUI.Keys = {}  -- mapa id → keycode padrão (para fallback)

local CAT = "PZ Evolution UI"

local KEY_DEFS = {
    { id="Inventory",   default=Keyboard.KEY_I   },
    { id="Character",   default=Keyboard.KEY_C   },
    { id="Crafting",    default=Keyboard.KEY_B   },
    { id="Vehicle",     default=Keyboard.KEY_V   },
    { id="Generator",   default=Keyboard.KEY_G   },
    { id="Build",       default=Keyboard.KEY_F   },
    { id="Animals",     default=Keyboard.KEY_N   },
    { id="Cooking",     default=Keyboard.KEY_K   },
    { id="Exercise",    default=Keyboard.KEY_X   },
    { id="Liquid",      default=Keyboard.KEY_L   },
    { id="Chicken",     default=Keyboard.KEY_H   },
    { id="Collect",     default=Keyboard.KEY_O   },
    { id="Bottle",      default=Keyboard.KEY_U   },
    { id="Livestock",   default=Keyboard.KEY_M   },
    { id="EUI_Settings",default=Keyboard.KEY_F11 },
}

-- Registra defaults; Keymap pode ser nil em B42 (RuntimeException escapa de pcall no Kahlua)
for _, kd in ipairs(KEY_DEFS) do
    EUI.Keys[kd.id] = kd.default
    if Keymap ~= nil then
        pcall(function() Keymap.addKey(CAT, kd.id, kd.default) end)
    end
end

-- Retorna o keycode atual do bind (respeita remapeamento do jogador)
function EUI.getKey(id)
    local key = 0
    if Keymap ~= nil then
        pcall(function() key = Keymap.getKey(CAT, id) end)
    end
    if not key or key == 0 then key = EUI.Keys[id] or 0 end
    return key
end
