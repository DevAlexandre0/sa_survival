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

-- [[ Status Effect System (Server-side) ]]
---@param source number Player source ID
---@param effectName string Name of the status effect (e.g., 'Sick', 'BrokenLeg', 'Poisoned')
---@param duration number Duration in seconds. Use 0 for permanent until cleared.
---@param effectData table Optional data associated with the effect
function ApplyStatusEffect(source, effectName, duration, effectData)
    local playerPed = GetPlayerPed(source)
    if playerPed then
        local effectKey = 'player:status:' .. effectName:lower()
        if playerPed.state[effectKey] ~= true then
            playerPed.state:set(effectKey, true, true)
            print(string.format('[Survival Core] Player %d applied effect: %s', source, effectName))

            if duration > 0 then
                lib.callback.timer(duration * 1000, function()
                    ClearStatusEffect(source, effectName)
                end)
            end

            lib_notify({
                source = source,
                title = 'Status Applied',
                description = 'คุณได้รับผลกระทบ: ' .. effectName,
                type = 'warning',
                duration = 5000
            })
        end
    end
end
exports('ApplyStatusEffect', ApplyStatusEffect)

---@param source number Player source ID
---@param effectName string Name of the status effect to clear
function ClearStatusEffect(source, effectName)
    local playerPed = GetPlayerPed(source)
    if playerPed then
        local effectKey = 'player:status:' .. effectName:lower()
        if playerPed.state[effectKey] == true then
            playerPed.state:set(effectKey, false, true)
            print(string.format('[Survival Core] Player %d cleared effect: %s', source, effectName))
            lib_notify({
                source = source,
                title = 'Status Cleared',
                description = 'ผลกระทบ ' .. effectName .. ' หายไปแล้ว',
                type = 'success',
                duration = 5000
            })
        end
    end
end
exports('ClearStatusEffect', ClearStatusEffect)

-- [[ Player Busy State (Server-side) ]]
---@param source number Player source ID
---@param isBusy boolean True if busy, false otherwise
function SetPlayerBusy(source, isBusy)
    local playerPed = GetPlayerPed(source)
    if playerPed then
        if playerPed.state['player:is_busy'] ~= isBusy then
            playerPed.state:set('player:is_busy', isBusy, true)
        end
    end
end
exports('SetPlayerBusy', SetPlayerBusy)

-- [[ Event Handlers ]]
-- เมื่อผู้เล่นออกจากเซิร์ฟเวอร์ (สำหรับ Debug/Console Log)
AddEventHandler('playerDropped', function()
    local src = source
    print(string.format('[Survival Core] Player %d dropped. (State Bags remain for now).', src))
    -- เมื่อผู้เล่นหลุด ให้ยกเลิกสถานะ busy
    exports['sa_survival']:SetPlayerBusy(src, false)
    -- TODO: อาจจะต้องยกเลิก lib.callback.timer/loop ทั้งหมดที่เกี่ยวข้องกับผู้เล่นคนนี้ด้วย
    -- (ox_lib อาจมีฟังก์ชันสำหรับการจัดการ timers ของผู้เล่น)
end)

-- Event Handler สำหรับ Client ที่ยกเลิก Progress Bar
RegisterNetEvent('sa_survival:server:cancelBusyState')
AddEventHandler('sa_survival:server:cancelBusyState', function()
    local src = source
    exports['sa_survival']:SetPlayerBusy(src, false)
    lib_notify({ source = src, title = 'ถูกยกเลิก', description = 'กิจกรรมของคุณถูกยกเลิก', type = 'error' })
end)

-- Event สำหรับ Client ที่ Trigger เมื่อเกิดอาการอาเจียน
RegisterNetEvent('sa_survival:server:triggerVomit')
AddEventHandler('sa_survival:server:triggerVomit', function(coords)
    local src = source
    -- TODO: เพิ่ม Logic สำหรับสร้าง Particle Effect/Prop อาเจียนที่ตำแหน่ง coords
    -- TriggerClientEvent('sa_survival:client:spawnVomitEffect', src, coords)
    lib_notify({ source = src, title = 'อาการป่วย', description = 'คุณอาเจียนออกมา!', type = 'warning' })
end)
