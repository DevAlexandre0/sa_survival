
local ESX = exports['es_extended']:getSharedObject()
local GetConfig = exports['sa_survival']:GetConfig
local Config = GetConfig()
    
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.MainTickInterval)

        local players = ESX.GetPlayers()

        for _, xPlayer in ipairs(players) do
            local src = xPlayer.source
            local playerPed = GetPlayerPed(src)

            if playerPed and DoesEntityExist(playerPed) then
                local playerState = playerPed.state

                if playerState['player:hunger'] ~= nil then

                    ProcessPlayerSickness(src, playerState)
                    ProcessPlayerInjuries(src, playerState)
                    ProcessPlayerStress(src, playerState)

                    ProcessPlayerZones(src, playerState)
                    ProcessPlayerToxins(src, playerState)
                    ProcessPlayerRadiation(src, playerState)
                    ProcessPlayerTemperatureEffects(src, playerState)

                end
            end
        end
    end
end)