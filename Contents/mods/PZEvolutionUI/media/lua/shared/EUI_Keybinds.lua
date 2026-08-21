-- EUI_Keybinds.lua — registra keybinds do mod no sistema do PZ (B42)
-- Arquivo em shared/ para que os binds apareçam na tela de controles do jogo

if not getCore then return end

local function addKey(id, defaultKey)
    -- B42: Keymap.addKey(category, action, key)
    pcall(function()
        Keymap.addKey("PZ Evolution UI", id, defaultKey)
    end)
end

-- Painéis (teclas padrão — jogador pode remapear nas opções do jogo)
addKey("Inventory",  Keyboard.KEY_I)
addKey("Character",  Keyboard.KEY_C)
addKey("Crafting",   Keyboard.KEY_B)
addKey("Vehicle",    Keyboard.KEY_V)
addKey("Generator",  Keyboard.KEY_G)
addKey("Build",      Keyboard.KEY_F)
addKey("Animals",    Keyboard.KEY_N)
addKey("Cooking",    Keyboard.KEY_K)
addKey("Exercise",   Keyboard.KEY_X)
addKey("Liquid",     Keyboard.KEY_L)
addKey("Chicken",    Keyboard.KEY_H)
addKey("Collect",    Keyboard.KEY_O)
addKey("Bottle",     Keyboard.KEY_W)

-- Configurações
addKey("EUI_Settings", Keyboard.KEY_F11)
