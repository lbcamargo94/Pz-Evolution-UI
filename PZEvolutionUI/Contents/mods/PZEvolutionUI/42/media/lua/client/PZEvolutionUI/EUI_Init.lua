-- EUI_Init.lua — ponto de entrada do PZ Evolution UI
-- Carregado primeiro pelo engine (nome alfabético + pasta client/)
-- Ordem: Theme → Utils → BasePanel → BaseButton → painéis específicos

-- Namespace global (EUI.log já foi criado por shared/EUI_Logger.lua)
EUI = EUI or {}
EUI.VERSION = "0.6.0"
EUI.MOD_ID  = "PZEvolutionUI"

-- EUI.log.setLevel("DEBUG")  ← descomente para habilitar logs de debug

EUI.log.info("PZ Evolution UI " .. EUI.VERSION .. " inicializando…")

-- Os arquivos em client/ são carregados automaticamente pelo engine na ordem
-- alfabética da pasta. A hierarquia de nomes garante a ordem correta:
--   core/EUI_BaseButton.lua
--   core/EUI_BasePanel.lua
--   core/EUI_Theme.lua
--   core/EUI_Utils.lua
--   panels/EUI_*.lua

Events.OnGameStart.Add(function()
    EUI.log.info("mod carregado com sucesso — " .. EUI.VERSION)
end)
