-- sa_survival/server/player_data.lua

local ESX = exports['es_extended']:getSharedObject()
local GetConfig = exports['sa_survival']:GetConfig
local Config = GetConfig()

local oxmysql = exports.ox_mysql -- Caching ox_mysql export

-- ฟังก์ชันสำหรับตั้งค่า State Bag เริ่มต้น
local function initializePlayerStates(playerPed)
    print(string.format('[Survival Core] Initializing NEW survival states for playerPed %s', GetPedSource(playerPed) or "Unknown"))

    local initialStates = {
        ['player:hunger']           = Config.MaxHunger,
        ['player:thirst']           = Config.MaxThirst,
        ['player:fatigue']          = Config.MinFatigue,
        ['player:body_temp']        = Config.NormalBodyTemp,
        ['player:radiation']        = Config.MinRadiation,
        ['player:stress']           = Config.MinStress,
        ['player:bladder']          = Config.MinBladder,
        ['player:bowel']            = Config.MinBowel,
        ['player:immunity']         = Config.MaxImmunity,
        ['player:wetness']          = Config.MinWetness,

        -- สถานะพิเศษ/สภาพแวดล้อมเริ่มต้น
        ['player:is_busy']          = false,
        ['player:in_toxic_zone']    = false,
        ['player:in_radiation_zone']= false,
        ['player:in_shelter']       = true,
        ['player:in_darkness']      = false,
        ['player:is_isolated']      = false,

        -- สถานะอาการ/บาดเจ็บเริ่มต้น
        ['player:status:sick']      = false,
        ['player:status:broken_leg']= false,
        ['player:status:bleeding']  = false,
        ['player:status:poisoned']  = false,
        ['player:status:tired']     = false,
        ['player:status:exhausted'] = false,
        ['player:status:anxiety']   = false,
        ['player:status:panickattack']= false,
        ['player:status:hypothermia']= false,
        ['player:status:heatstroke']= false,
    }

    for k, v in pairs(initialStates) do
        playerPed.state:set(k, v, true)
    end
end

-- เมื่อผู้เล่นโหลดเข้าเกม (ใช้ esx:playerLoaded เพื่อให้แน่ใจว่า ESX พร้อม)
AddEventHandler('esx:playerLoaded', function(xPlayer)
    local src = xPlayer.source
    local playerPed = GetPlayerPed(src)
    local playerIdentifier = xPlayer.getIdentifier()

    if not playerPed then
        print(string.format('[Survival Core] WARNING: playerPed not found for src %d during esx:playerLoaded. Retrying...', src))
        Citizen.CreateThread(function()
            Citizen.Wait(100)
            playerPed = GetPlayerPed(src)
            if playerPed and not playerPed.state['player:hunger'] then
                oxmysql:fetch('SELECT data FROM player_survival_data WHERE identifier = ?', {playerIdentifier}, function(result)
                    if result and result[1] and result[1].data then
                        local loadedData = json.decode(result[1].data)
                        if loadedData then
                            for k, v in pairs(loadedData) do
                                playerPed.state:set(k, v, true)
                            end
                            print(string.format('[Survival Core] Player %s survival data LOADED.', playerIdentifier))
                        else
                            print(string.format('[Survival Core] ERROR: Failed to decode JSON data for player %s. Initializing new states.', playerIdentifier))
                            initializePlayerStates(playerPed)
                        end
                    else
                        print(string.format('[Survival Core] No existing survival data found for player %s. Initializing new states.', playerIdentifier))
                        initializePlayerStates(playerPed)
                    end
                end)
            end
        end)
        return
    end

    if not playerPed.state['player:hunger'] then
        oxmysql:fetch('SELECT data FROM player_survival_data WHERE identifier = ?', {playerIdentifier}, function(result)
            if result and result[1] and result[1].data then
                local loadedData = json.decode(result[1].data)
                if loadedData then
                    for k, v in pairs(loadedData) do
                        playerPed.state:set(k, v, true)
                    end
                    print(string.format('[Survival Core] Player %s survival data LOADED.', playerIdentifier))
                else
                    print(string.format('[Survival Core] ERROR: Failed to decode JSON data for player %s. Initializing new states.', playerIdentifier))
                    initializePlayerStates(playerPed)
                end
            else
                print(string.format('[Survival Core] No existing survival data found for player %s. Initializing new states.', playerIdentifier))
                initializePlayerStates(playerPed)
            end
        end)
    else
        print(string.format('[Survival Core] Player %s already has survival data. Skipping initialization.', playerIdentifier))
    end
end)

-- เมื่อผู้เล่นออกจากเซิร์ฟเวอร์
AddEventHandler('playerDropped', function()
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if xPlayer then
        local playerPed = GetPlayerPed(src)
        local playerIdentifier = xPlayer.getIdentifier()

        if playerPed and playerPed.state then
            local survivalData = {}
            for k, v in pairs(playerPed.state:toTable()) do
                if k:find('^player:') then
                    survivalData[k] = v
                end
            end

            local jsonData = json.encode(survivalData)

            oxmysql:execute('INSERT INTO player_survival_data (identifier, data) VALUES (?, ?) ON DUPLICATE KEY UPDATE data = VALUES(data), last_updated = CURRENT_TIMESTAMP()',
                { identifier = playerIdentifier, data = jsonData },
                function(rowsAffected)
                    if rowsAffected > 0 then
                        print(string.format('[Survival Core] Player %s survival data SAVED/UPDATED successfully.', playerIdentifier))
                    else
                        print(string.format('[Survival Core] ERROR: Failed to save survival data for player %s.', playerIdentifier))
                    end
                end
            )
        else
            print(string.format('[Survival Core] WARNING: playerPed or state bag not found for player %d during playerDropped. Data might not be saved.', src))
        end
    else
        print(string.format('[Survival Core] WARNING: xPlayer not found for src %d during playerDropped.', src))
    end
end)

local function GetPedSource(ped)
    local players = ESX.GetPlayers()
    for _, xPlayer in ipairs(players) do
        if GetPlayerPed(xPlayer.source) == ped then
            return xPlayer.source
        end
    end
    return nil
end