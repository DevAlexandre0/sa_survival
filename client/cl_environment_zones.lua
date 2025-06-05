-- sa_survival/client/environment_zones/cl_environment_zones.lua

-- Caching exports และ Config
local GetConfig = exports['sa_survival']:GetConfig
local Config = GetConfig()

-- Caching Client Exports
local ApplyScreenEffect = exports['sa_survival']:ApplyScreenEffect
local StopScreenEffectClient = exports['sa_survival']:StopScreenEffectClient

-- Caching lib.notify
local lib_notify = lib.notify

-- ตัวแปร Local สำหรับ Native Functions ที่ใช้บ่อย
local PlayerPedId = PlayerPedId
local GetEntityCoords = GetEntityCoords
local GetDistanceBetweenCoords = GetDistanceBetweenCoords
local GetCurrentWeatherType = GetCurrentWeatherType
local GetTemperature = GetTemperature
local GetIsVehicleEngineRunning = GetIsVehicleEngineRunning -- สำหรับเช็คว่าอยู่ในรถ
local IsPedInAnyVehicle = IsPedInAnyVehicle
local GetEntityBoneCoords = GetEntityBoneCoords -- สำหรับการยิง Raycast
local StartExpensiveSynchronousShapeTestLosProbe = StartExpensiveSynchronousShapeTestLosProbe -- สำหรับ Raycast
local GetShapeTestResult = GetShapeTestResult
local GetGroundZFor_3dCoords = GetGroundZFor_3dCoords
local GetActivePlayers = GetActivePlayers
local GetPlayerPed = GetPlayerPed
local GetPedNearbyPeds = GetPedNearbyPeds
local GetPlayerFromServerId = GetPlayerFromServerId

-- ตัวแปรสถานะภายใน Client
local isInRadiationZone = false
local isInToxicZone = false
local isInShelter = false
local isInDarkness = false
local isIsolated = false

-- Main Client Tick Loop สำหรับ Environment & Zones
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.MainTickInterval / 2)

        local ped = PlayerPedId()
        if ped == 0 then
            Citizen.Wait(1000)
            goto continue_zone_loop
        end

        local playerCoords = GetEntityCoords(ped)
        local playerState = ped.state

        -- ตรวจสอบ Radiation Zones
        local currentIsInRadiationZone = false
        for _, zone in ipairs(Config.Zones.RadiationZones) do
            if GetDistanceBetweenCoords(playerCoords, zone.coords, true) <= zone.radius then
                currentIsInRadiationZone = true
                break
            end
        end

        if currentIsInRadiationZone ~= isInRadiationZone then
            isInRadiationZone = currentIsInRadiationZone
            TriggerServerEvent('sa_survival:server:updateRadiationZoneStatus', isInRadiationZone)
        end

        -- ตรวจสอบ Toxic Zones
        local currentIsInToxicZone = false
        for _, zone in ipairs(Config.Zones.ToxicZones) do
            if GetDistanceBetweenCoords(playerCoords, zone.coords, true) <= zone.radius then
                currentIsInToxicZone = true
                break
            end
        end

        if currentIsInToxicZone ~= isInToxicZone then
            isInToxicZone = currentIsInToxicZone
            TriggerServerEvent('sa_survival:server:updateToxicZoneStatus', isInToxicZone)
        end

        -- [[ อุณหภูมิและสภาพอากาศ ]]
        local currentBodyTemp = playerState['player:body_temp'] or Config.NormalBodyTemp
        local currentWetness = playerState['player:wetness'] or Config.MinWetness

        local weather = GetCurrentWeatherType()
        local ambientTemp = GetTemperature()

        local newBodyTemp = currentBodyTemp
        local newWetness = currentWetness

        -- ผลกระทบจากสภาพอากาศ
        if weather == 'RAIN' or weather == 'FOGGY' or weather == 'OVERCAST' then
            if not isInShelter then -- ถ้าไม่อยู่ในที่กำบังถึงจะเปียก
                newWetness = math.min(Config.MaxWetness, currentWetness + 5)
            end
            newBodyTemp = newBodyTemp - 0.5
        elseif weather == 'CLEAR' or weather == 'EXTRASUNNY' then
            newWetness = math.max(Config.MinWetness, currentWetness - 5)
            newBodyTemp = newBodyTemp + 0.3
        end

        -- อิทธิพลจากอุณหภูมิแวดล้อม
        if ambientTemp < 10.0 then
            newBodyTemp = newBodyTemp - 0.8
        elseif ambientTemp > 30.0 then
            newBodyTemp = newBodyTemp + 0.8
        end

        -- อิทธิพลจากที่กำบัง
        local currentIsInShelter = false
        -- ตรวจสอบว่าอยู่ในยานพาหนะที่มีเครื่องยนต์ทำงาน
        if IsPedInAnyVehicle(ped, false) and GetIsVehicleEngineRunning(GetVehiclePedIsIn(ped, false)) then
            currentIsInShelter = true
        end
        -- ตรวจสอบว่าอยู่ใน Interior (อาจจะต้องมี Interior ID หรือ Raycast)
        -- GetInteriorFromEntity(ped) ~= 0 หรือ CheckInteriorPoint(playerCoords.x, playerCoords.y, playerCoords.z)
        -- สำหรับตอนนี้ ให้เป็น heuristic ง่ายๆ: หากอยู่ภายใน Interior หรืออยู่ในยานพาหนะที่มีเครื่องยนต์
        if GetInteriorFromEntity(ped) ~= 0 then -- หากอยู่ใน Interior
            currentIsInShelter = true
        end

        if currentIsInShelter ~= isInShelter then
            isInShelter = currentIsInShelter
            playerState:set('player:in_shelter', isInShelter, true) -- อัปเดต State Bag
        end

        if isInShelter then
            newBodyTemp = newBodyTemp + 0.1
            newWetness = Config.MinWetness
        end

        -- Clamp ค่า
        newBodyTemp = math.min(Config.MaxBodyTemp, math.max(Config.MinBodyTemp, newBodyTemp))
        newWetness = math.min(Config.MaxWetness, math.max(Config.MinWetness, newWetness))

        -- [[ ตรวจจับความมืด (Is in Darkness) ]]
        local currentIsInDarkness = false
        -- วิธีง่ายๆ: ตรวจสอบระดับแสงที่ตำแหน่งผู้เล่น
        -- GetActualBrightness() หรือการ Raycast ไปยังแหล่งกำเนิดแสง
        -- วิธีที่ซับซ้อน: Raycast จากหัวผู้เล่นขึ้นไปบนฟ้าเพื่อดูว่ามีแสงอาทิตย์ส่องถึงหรือไม่
        -- สำหรับตอนนี้: ใช้ GetRandomFloatInRange เป็น placeholder เพื่อแสดง Logic
        -- if GetRandomFloatInRange(0.0, 1.0) < 0.5 and GetGameTimer() % 10000 > 5000 then -- ตัวอย่าง: มืด 50% ของเวลา
        --     currentIsInDarkness = true
        -- end
        -- วิธีที่ดีกว่า: ใช้ Native GetLightingFromEntity หรือ GetInteriorAmbientLightColor
        -- หรือตรวจสอบเวลาในเกม
        local currentHour = GetClockHours()
        if currentHour >= 20 or currentHour <= 6 then -- 20:00 - 06:00 ถือว่ามืด
            local headCoords = GetPedBoneCoords(ped, 0) -- HEAD bone
            -- Raycast จากหัวขึ้นไป
            local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(headCoords.x, headCoords.y, headCoords.z, headCoords.x, headCoords.y, headCoords.z + 10.0, 1, ped, 0)
            local _, hit, _, _, _ = GetShapeTestResult(rayHandle)
            if not hit then -- หากไม่มีอะไรบังแสง (ฟ้าเปิด)
                -- ยังคงอาจมืดถ้าไม่มีไฟ
                if GetGameTime() > 10000 then -- หลัง 22:00
                    currentIsInDarkness = true
                end
            end
        end

        if currentIsInDarkness ~= isInDarkness then
            isInDarkness = currentIsInDarkness
            playerState:set('player:in_darkness', isInDarkness, true) -- อัปเดต State Bag
        end

        -- [[ ตรวจจับการอยู่คนเดียว (Is Isolated) ]]
        local currentIsIsolated = true
        local playerPeds = GetActivePlayers()
        for _, pId in ipairs(playerPeds) do
            if pId ~= PlayerId() then
                local otherPed = GetPlayerPed(pId)
                if otherPed ~= 0 and GetDistanceBetweenCoords(playerCoords, GetEntityCoords(otherPed), true) < 100.0 then
                    currentIsIsolated = false
                    break
                end
            end
        end
        -- ตรวจสอบ NPC รอบๆ ตัวด้วย (ถ้าต้องการให้ NPC ทำให้ไม่โดดเดี่ยว)
        local _, nearbyPeds = GetPedNearbyPeds(ped, -1) -- Get all nearby peds
        for i = 1, #nearbyPeds do
            if not IsPedAPlayer(nearbyPeds[i]) and GetDistanceBetweenCoords(playerCoords, GetEntityCoords(nearbyPeds[i]), true) < 50.0 then
                currentIsIsolated = false
                break
            end
        end


        if currentIsIsolated ~= isIsolated then
            isIsolated = currentIsIsolated
            playerState:set('player:is_isolated', isIsolated, true) -- อัปเดต State Bag
        end

        -- อัปเดต State Bag (ส่งไปยัง Server)
        local updatesToSend = {}
        if playerState['player:body_temp'] ~= newBodyTemp then updatesToSend['player:body_temp'] = newBodyTemp end
        if playerState['player:wetness'] ~= newWetness then updatesToSend['player:wetness'] = newWetness end

        if next(updatesToSend) ~= nil then
            TriggerServerEvent('sa_survival:updatePlayerStates', updatesToSend)
        end

        -- ผลกระทบจากอุณหภูมิร่างกาย (Client-side effects)
        local isHypothermia = playerState['player:status:hypothermia']
        local isHeatstroke = playerState['player:status:heatstroke']

        if newBodyTemp <= Config.MinBodyTemp + 1.0 and not isHypothermia then
            TriggerServerEvent('sa_survival:server:triggerTemperatureStatus', 'Hypothermia', 0)
        elseif newBodyTemp >= Config.MaxBodyTemp - 1.0 and not isHeatstroke then
            TriggerServerEvent('sa_survival:server:triggerTemperatureStatus', 'Heatstroke', 0)
        elseif newBodyTemp > Config.MinBodyTemp + 1.0 and isHypothermia then
            TriggerServerEvent('sa_survival:server:triggerTemperatureStatus', 'ClearHypothermia')
        elseif newBodyTemp < Config.MaxBodyTemp - 1.0 and isHeatstroke then
            TriggerServerEvent('sa_survival:server:triggerTemperatureStatus', 'ClearHeatstroke')
        end

        exports['sa_survival']:UpdatePlayerMoveRate() -- เรียกใช้ฟังก์ชันรวม

        ::continue_zone_loop::
    end
end)

-- [[ Client-side State Bag Listeners สำหรับผลกระทบจากสภาพแวดล้อม ]]
Citizen.CreateThread(function()
    local ped = PlayerPedId()
    if ped == 0 then
        Citizen.Wait(1000)
        goto continue_env_listeners
    end

    -- Listener สำหรับพิษ
    ped.state:on('player:status:poisoned', function(key, value, oldValue)
        if value then
            lib_notify({ title = 'อันตราย', description = 'คุณกำลังถูกพิษ!', type = 'error' })
            ApplyScreenEffect(Config.Toxic.ScreenEffect, -1)
            ShakeGameplayCam('DRUNK_SHAKE', 0.5)
        else
            lib_notify({ title = 'ปลอดภัย', description = 'คุณพ้นจากพิษแล้ว!', type = 'success' })
            StopScreenEffectClient(Config.Toxic.ScreenEffect)
            StopGameplayCamShake(true)
        end
        exports['sa_survival']:UpdatePlayerMoveRate() -- เรียกใช้ฟังก์ชันรวม
    end)

    -- Listener สำหรับ Hypothermia
    ped.state:on('player:status:hypothermia', function(key, value, oldValue)
        if value then
            lib_notify({ title = 'สุขภาพ', description = 'คุณกำลังเป็นภาวะตัวเย็นเกิน!', type = 'error' })
            ApplyScreenEffect(Config.Temperature.HypothermiaScreenEffect, -1)
        else
            lib_notify({ title = 'สุขภาพ', description = 'ร่างกายของคุณกลับสู่อุณหภูมิปกติแล้ว', type = 'success' })
            StopScreenEffectClient(Config.Temperature.HypothermiaScreenEffect)
        end
        exports['sa_survival']:UpdatePlayerMoveRate() -- เรียกใช้ฟังก์ชันรวม
    end)

    -- Listener สำหรับ Heatstroke
    ped.state:on('player:status:heatstroke', function(key, value, oldValue)
        if value then
            lib_notify({ title = 'สุขภาพ', description = 'คุณกำลังเป็นโรคลมแดด!', type = 'error' })
            ApplyScreenEffect(Config.Temperature.HeatstrokeScreenEffect, -1)
            ShakeGameplayCam('DRUNK_SHAKE', 0.5)
        else
            lib_notify({ title = 'สุขภาพ', description = 'ร่างกายของคุณกลับสู่อุณหภูมิปกติแล้ว', type = 'success' })
            StopScreenEffectClient(Config.Temperature.HeatstrokeScreenEffect)
            StopGameplayCamShake(true)
        end
        exports['sa_survival']:UpdatePlayerMoveRate() -- เรียกใช้ฟังก์ชันรวม
    end)

    ::continue_env_listeners::
end)