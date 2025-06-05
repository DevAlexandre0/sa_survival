-- sa_survival/server/sv_main.lua

-- Caching exports
local ESX = exports['es_extended']:getSharedObject()
local GetConfig = exports['sa_survival']:GetConfig
Config = GetConfig() -- Global for reload

-- Caching lib.notify
local lib_notify = lib and lib.notify or function() end

-- Utility: setPlayerStateIfChanged
local function setPlayerStateIfChanged(playerState, key, value)
    if playerState[key] ~= value then
        playerState:set(key, value, true)
    end
end

-- Utility: tryRemoveItem (example for core_inventory)
local InventoryRemoveItem = exports.core_inventory.RemoveItem
local function tryRemoveItem(src, item, amount)
    local success = InventoryRemoveItem(src, item, amount, false)
    if not success then
        lib_notify({ source = src, title = 'Inventory', description = 'Not enough items!', type = 'error' })
    end
    return success
end

-- Admin command: reload config
RegisterCommand('sa_reloadconfig', function(source, args, rawCommand)
    package.loaded['config'] = nil
    Config = require('config')
    print('[Survival Core] Config reloaded!')
end, true)

-- Main Server Tick Loop
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.MainTickInterval)

        local players = ESX.GetPlayers()

        for _, xPlayer in ipairs(players) do
            local src = xPlayer.source
            local playerPed = GetPlayerPed(src)

            if playerPed and DoesEntityExist(playerPed) then
                local playerState = playerPed.state

                -- Optimization: Skip if not in survival mode
                if not playerState['player:survival_mode'] then
                    goto continue_loop
                end

                if playerState['player:hunger'] ~= nil then
                    -- (Assumes these functions are defined elsewhere)
                    ProcessPlayerSickness(src, playerState)
                    ProcessPlayerInjuries(src, playerState)
                    ProcessPlayerStress(src, playerState)
                    ProcessPlayerZones(src, playerState)
                    ProcessPlayerToxins(src, playerState)
                    ProcessPlayerRadiation(src, playerState)
                    ProcessPlayerTemperatureEffects(src, playerState)
                else
                    print(string.format('[Survival Core][WARNING] player:hunger state missing for player %d. Skipping state update!', src))
                end
            end
            ::continue_loop::
        end
    end
end)

-- Example usage in a subsystem:
-- setPlayerStateIfChanged(playerState, 'player:hunger', newHunger)
-- tryRemoveItem(src, "water", 1)
