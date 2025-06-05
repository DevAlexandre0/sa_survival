-- sa_survival/server/environment_zones/sv_environment_zones.lua

-- Caching exports และ Config
local GetConfig = exports['sa_survival']:GetConfig
local Config = GetConfig()
local ApplyStatusEffect = exports['sa_survival']:ApplyStatusEffect
local ClearStatusEffect = exports['sa_survival']:ClearStatusEffect
local lib_notify = lib.notify

-- ตัวแปร Local สำหรับ Native Functions ที่ใช้บ่อยบน Server
local GetPlayerPed = GetPlayerPed
local DoesEntityExist = DoesEntityExist
local GetEntityHealth = GetEntityHealth
local SetEntityHealth = SetEntityHealth

-- [[ Server-side Logic สำหรับ Environment Zones ]]
-- Event สำหรับ Client เพื่อแจ้งว่าผู้เล่นเข้า/ออกจาก Radiation Zone
RegisterNetEvent('sa_survival:server:updateRadiationZoneStatus')
AddEventHandler('sa_survival:server:updateRadiationZoneStatus', function(inZone)
    local src = source
    local playerPed = GetPlayerPed(src)
    if playerPed and DoesEntityExist(playerPed) then
        local playerState = playerPed.state
        if playerState['player:in_radiation_zone'] ~= inZone then
            playerState:set('player:in_radiation_zone', inZone, true)
            if inZone then
                lib_notify({ source = src, title = 'สิ่งแวดล้อม', description = 'คุณเข้าสู่พื้นที่กัมมันตรังสีแล้ว!', type = 'error' })
            else
                lib_notify({ source = src, title = 'สิ่งแวดล้อม', description = 'คุณออกจากพื้นที่กัมมันตรังสีแล้ว', type = 'success' })
            end
        end
    end
end)

-- Event สำหรับ Client เพื่อแจ้งว่าผู้เล่นเข้า/ออกจาก Toxic Zone
RegisterNetEvent('sa_survival:server:updateToxicZoneStatus')
AddEventHandler('sa_survival:server:updateToxicZoneStatus', function(inZone)
    local src = source
    local playerPed = GetPlayerPed(src)
    if playerPed and DoesEntityExist(playerPed) then
        local playerState = playerPed.state
        if playerState['player:in_toxic_zone'] ~= inZone then
            playerState:set('player:in_toxic_zone', inZone, true)
            if inZone then
                lib_notify({ source = src, title = 'สิ่งแวดล้อม', description = 'คุณเข้าสู่พื้นที่พิษแล้ว!', type = 'error' })
            else
                lib_notify({ source = src, title = 'สิ่งแวดล้อม', description = 'คุณออกจากพื้นที่พิษแล้ว', type = 'success' })
            end
        end
    end
end)

-- Event สำหรับ Client เพื่อแจ้งสถานะ Hypothermia/Heatstroke
RegisterNetEvent('sa_survival:server:triggerTemperatureStatus')
AddEventHandler('sa_survival:server:triggerTemperatureStatus', function(statusType, duration)
    local src = source
    if statusType == 'Hypothermia' then
        ApplyStatusEffect(src, 'Hypothermia', duration, {})
    elseif statusType == 'Heatstroke' then
        ApplyStatusEffect(src, 'Heatstroke', duration, {})
    elseif statusType == 'ClearHypothermia' then
        ClearStatusEffect(src, 'Hypothermia')
    elseif statusType == 'ClearHeatstroke' then
        ClearStatusEffect(src, 'Heatstroke')
    end
end)

---@param src number Player source ID
---@param playerState table The player's state bag (passed by reference)
function ProcessPlayerZones(src, playerState)
    -- Server ไม่จำเป็นต้องมี Logic ซับซ้อนที่นี่ เพราะ Client เป็นผู้ตรวจจับโซน
    -- แต่ถ้ามี Logic ที่ Server ต้องควบคุม (เช่น การสร้างโซนแบบไดนามิก) ก็จะอยู่ที่นี่
end
exports('ProcessPlayerZones', ProcessPlayerZones)

---@param src number Player source ID
---@param playerState table The player's state bag (passed by reference)
function ProcessPlayerToxins(src, playerState)
    local inToxicZone = playerState['player:in_toxic_zone']
    local isPoisoned = playerState['player:status:poisoned']
    local ped = GetPlayerPed(src)

    if inToxicZone and not isPoisoned then
        ApplyStatusEffect(src, 'Poisoned', 0, {})
        lib_notify({ source = src, title = 'สิ่งแวดล้อม', description = 'คุณกำลังสัมผัสสารพิษ!', type = 'error' })
    elseif not inToxicZone and isPoisoned then
        ClearStatusEffect(src, 'Poisoned')
        lib_notify({ source = src, title = 'สิ่งแวดล้อม', description = 'คุณพ้นจากสารพิษแล้ว', type = 'success' })
    end

    -- ผลกระทบจากพิษ (เมื่อ isPoisoned)
    if isPoisoned and ped and DoesEntityExist(ped) then
        local currentHealth = GetEntityHealth(ped)
        SetEntityHealth(ped, math.max(0, currentHealth - Config.Toxic.DamagePerTick))
        lib_notify({ source = src, title = 'อันตราย', description = 'คุณกำลังถูกพิษ!', type = 'error', duration = 1000 })
    end
end
exports('ProcessPlayerToxins', ProcessPlayerToxins)

---@param src number Player source ID
---@param playerState table The player's state bag (passed by reference)
function ProcessPlayerRadiation(src, playerState)
    local inRadiationZone = playerState['player:in_radiation_zone']
    local currentRadiation = playerState['player:radiation'] or Config.MinRadiation
    local ped = GetPlayerPed(src)

    if inRadiationZone then
        local newRadiation = math.min(Config.MaxRadiation, currentRadiation + Config.PassiveRadiationDecay * 2)
        if playerState['player:radiation'] ~= newRadiation then
            playerState:set('player:radiation', newRadiation, true)
        end

        if newRadiation >= (Config.MaxRadiation * Config.Radiation.DamageThreshold) and ped and DoesEntityExist(ped) then
            local currentHealth = GetEntityHealth(ped)
            SetEntityHealth(ped, math.max(0, currentHealth - Config.Radiation.DamagePerTick))
            lib_notify({ source = src, title = 'อันตราย', description = 'คุณกำลังได้รับผลกระทบจากรังสี!', type = 'error' })
        end
        -- ลดภูมิคุ้มกันเมื่ออยู่ในโซนรังสี
        local newImmunity = math.max(Config.MinImmunity, playerState['player:immunity'] - Config.Radiation.ImmunityDecayRate)
        if playerState['player:immunity'] ~= newImmunity then
            playerState:set('player:immunity', newImmunity, true)
        end
    end
end
exports('ProcessPlayerRadiation', ProcessPlayerRadiation)

---@param src number Player source ID
---@param playerState table The player's state bag (passed by reference)
function ProcessPlayerTemperatureEffects(src, playerState)
    local isHypothermia = playerState['player:status:hypothermia']
    local isHeatstroke = playerState['player:status:heatstroke']
    local ped = GetPlayerPed(src)

    if isHypothermia and ped and DoesEntityExist(ped) then
        local currentHealth = GetEntityHealth(ped)
        SetEntityHealth(ped, math.max(0, currentHealth - Config.Temperature.HypothermiaDamagePerTick))
        lib_notify({ source = src, title = 'สุขภาพ', description = 'ร่างกายคุณกำลังเย็นเกินไป!', type = 'error', duration = 1000 })
    end
    if isHeatstroke and ped and DoesEntityExist(ped) then
        local currentHealth = GetEntityHealth(ped)
        SetEntityHealth(ped, math.max(0, currentHealth - Config.Temperature.HeatstrokeDamagePerTick))
        lib_notify({ source = src, title = 'สุขภาพ', description = 'ร่างกายคุณกำลังร้อนเกินไป!', type = 'error', duration = 1000 })
    end
end
exports('ProcessPlayerTemperatureEffects', ProcessPlayerTemperatureEffects)