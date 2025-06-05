
local GetConfig = exports['sa_survival']:GetConfig
local Config = GetConfig()
local lib_notify = lib.notify
RegisterNetEvent('sa_survival:updatePlayerStates')
AddEventHandler('sa_survival:updatePlayerStates', function(updates)
    local src = source
    local playerPed = GetPlayerPed(src)

    if playerPed and DoesEntityExist(playerPed) then
        local playerState = playerPed.state
        for key, value in pairs(updates) do
            playerState:set(key, value, true)
        end
    end
end)
RegisterNetEvent('sa_survival:server:applyStatusEffect')
AddEventHandler('sa_survival:server:applyStatusEffect', function(effectName, duration, effectData)
    local src = source
    exports['sa_survival']:ApplyStatusEffect(src, effectName, duration, effectData)
end)
RegisterNetEvent('sa_survival:server:clearStatusEffect')
AddEventHandler('sa_survival:server:clearStatusEffect', function(effectName)
    local src = source
    exports['sa_survival']:ClearStatusEffect(src, effectName)
end)