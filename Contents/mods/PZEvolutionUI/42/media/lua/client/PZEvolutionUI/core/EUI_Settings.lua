-- EUI_Settings.lua — sistema de configurações persistentes

EUI = EUI or {}

local SAVE_FILE = "EUI_settings.json"

-- Valores padrão
EUI.Settings = {
    -- HUD
    hudEnabled    = true,
    hudPosition   = "bottomLeft",  -- bottomLeft | bottomRight | topLeft | topRight
    hudOpacity    = 0.9,

    -- Veículo
    autoOpenVehicle = true,

    -- Raios de scan
    animalRadius  = 12,
    chickenRadius = 16,

    -- Tema de cor
    theme         = "dark",  -- dark | darker | green

    -- Painéis habilitados
    panelInventory  = true,
    panelCharacter  = true,
    panelVehicle    = true,
    panelCrafting   = true,
    panelGenerator  = true,
    panelBuilding   = true,
    panelAnimal     = true,
    panelCooking    = true,
    panelExercise   = true,
    panelLiquid     = true,
    panelChicken    = true,
    panelCollect    = true,
    panelBottle     = true,
}

-- ── Persistência ──────────────────────────────────────────────────────────────

function EUI.saveSettings()
    local ok, err = pcall(function()
        local lines = { "{" }
        local keys  = {}
        for k in pairs(EUI.Settings) do table.insert(keys, k) end
        table.sort(keys)
        for i, k in ipairs(keys) do
            local v   = EUI.Settings[k]
            local val
            if type(v) == "string"  then val = '"' .. v .. '"'
            elseif type(v) == "boolean" then val = v and "true" or "false"
            elseif type(v) == "number"  then val = tostring(v)
            end
            local comma = i < #keys and "," or ""
            table.insert(lines, string.format('  "%s": %s%s', k, val, comma))
        end
        table.insert(lines, "}")
        local json = table.concat(lines, "\n")
        local fw   = getFileWriter(SAVE_FILE, true, false)
        fw:write(json)
        fw:close()
    end)
    if not ok then print("[EUI] Erro ao salvar configurações: " .. tostring(err)) end
end

function EUI.loadSettings()
    local ok, err = pcall(function()
        local fr = getFileReader(SAVE_FILE, true)
        if not fr then return end
        local lines = {}
        local line  = fr:readLine()
        while line ~= nil do
            table.insert(lines, line)
            line = fr:readLine()
        end
        fr:close()
        local json = table.concat(lines, "\n")

        -- Parser JSON simples (só trata os tipos que usamos)
        for k, v in json:gmatch('"([%w_]+)"%s*:%s*([^,}\n]+)') do
            v = v:match("^%s*(.-)%s*$")  -- trim
            if EUI.Settings[k] ~= nil then
                if v == "true"  then EUI.Settings[k] = true
                elseif v == "false" then EUI.Settings[k] = false
                elseif v:sub(1,1) == '"' then EUI.Settings[k] = v:match('"(.*)"')
                else
                    local n = tonumber(v)
                    if n then EUI.Settings[k] = n end
                end
            end
        end
    end)
    if not ok then print("[EUI] Erro ao carregar configurações: " .. tostring(err)) end
end

function EUI.applyTheme()
    local t = EUI.Settings.theme
    if t == "darker" then
        EUI.Theme.BG1  = { r=0.04, g=0.04, b=0.04, a=0.97 }
        EUI.Theme.BG2  = { r=0.06, g=0.06, b=0.06, a=0.97 }
        EUI.Theme.BG3  = { r=0.09, g=0.09, b=0.09, a=0.95 }
    elseif t == "green" then
        EUI.Theme.BG1  = { r=0.03, g=0.07, b=0.03, a=0.97 }
        EUI.Theme.BG2  = { r=0.04, g=0.09, b=0.04, a=0.97 }
        EUI.Theme.BG3  = { r=0.06, g=0.12, b=0.06, a=0.95 }
    else  -- dark (padrão)
        EUI.Theme.BG1  = { r=0.07, g=0.07, b=0.08, a=0.97 }
        EUI.Theme.BG2  = { r=0.10, g=0.10, b=0.12, a=0.97 }
        EUI.Theme.BG3  = { r=0.13, g=0.13, b=0.16, a=0.95 }
    end
end

-- Carrega ao iniciar o jogo
Events.OnGameStart.Add(function()
    EUI.loadSettings()
    EUI.applyTheme()
    print("[EUI] Configurações carregadas.")
end)
