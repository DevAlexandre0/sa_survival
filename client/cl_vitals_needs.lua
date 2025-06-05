-- sa_survival/client/vitals_needs/cl_vitals_needs.lua

-- Caching exports และ Config
local GetConfig = exports['sa_survival']:GetConfig
local Config = GetConfig()

-- ตัวแปร Local สำหรับ Native Functions ที่ใช้บ่อย
local PlayerPedId = PlayerPedId
local IsPedRunning = IsPedRunning
local IsPedSprinting = IsPedSprinting
local IsPedSwimming = IsPedSwimming
local IsPedInVehicle = IsPedInVehicle
local GetVehiclePedIsIn = GetVehiclePedIsIn
local GetVehicleClass = GetVehicleClass
local GetEntityHealth = GetEntityHealth
local SetEntityHealth = SetEntityHealth

-- Caching Client Exports และ lib.notify
local lib_notify = lib.notify
local UpdatePlayerMoveRate = exports['sa_survival']:UpdatePlayerMoveRate -- เรียกใช้ฟังก์ชันรวม

-- Pre-calculate thresholds
local HUNGER_CRITICAL_THRESHOLD = Config.MaxHunger * Config.HungerCriticalThreshold
local THIRST_CRITICAL_THRESHOLD = Config.MaxThirst * Config.ThirstCriticalThreshold
local FATIGUE_TIRED_THRESHOLD = Config.MaxFatigue * 0.7
local FATIGUE_EXHAUSTED_THRESHOLD = Config.MaxFatigue * 0.9

-- Main Client Tick Loop สำหรับ Vitals & Needs
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(Config.MainTickInterval)

        local ped = PlayerPedId()
        if ped == 0 then
            Citizen.Wait(1000)
            goto continue_loop
        end

        local playerState = ped.state

        local currentHunger     = playerState['player:hunger']    or Config.MaxHunger
        local currentThirst     = playerState['player:thirst']    or Config.MaxThirst
        local currentFatigue    = playerState['player:fatigue']   or Config.MinFatigue
        local currentBladder    = playerState['player:bladder']   or Config.MinBladder
        local currentBowel      = playerState['player:bowel']     or Config.MinBowel
        local currentRadiation  = playerState['player:radiation'] or Config.MinRadiation
        local currentStress     = playerState['player:stress']    or Config.MinStress
        local currentImmunity   = playerState['player:immunity']  or Config.MaxImmunity
        local currentWetness    = playerState['player:wetness']   or Config.MinWetness
        local currentBodyTemp   = playerState['player:body_temp'] or Config.NormalBodyTemp

        local isExhausted        = playerState['player:status:exhausted']
        local isTired            = playerState['player:status:tired']
        local isSick             = playerState['player:status:sick']
        local isBleeding         = playerState['player:status:bleeding']
        local inRadiationZone    = playerState['player:in_radiation_zone']
        local isIsolated         = playerState['player:is_isolated']
        local inDarkness         = playerState['player:in_darkness']

        local newHunger = currentHunger
        local newThirst = currentThirst
        local newFatigue = currentFatigue
        local newRadiation = currentRadiation
        local newStress = currentStress
        local newImmunity = currentImmunity
        local newBladder = currentBladder
        local newBowel = currentBowel

        -- คำนวณการลด/เพิ่มสถานะตามกิจกรรม
        if IsPedSprinting(ped) then
            newHunger = newHunger - (Config.HungerDecayRate * 2)
            newThirst = newThirst - (Config.ThirstDecayRate * 2.5)
            newFatigue = newFatigue + (Config.FatigueIncreaseRate * 3)
        elseif IsPedRunning(ped) then
            newHunger = newHunger - (Config.HungerDecayRate * 1.5)
            newThirst = newThirst - (Config.ThirstDecayRate * 1.8)
            newFatigue = newFatigue + (Config.FatigueIncreaseRate * 2)
        elseif IsPedSwimming(ped) then
            newHunger = newHunger - (Config.HungerDecayRate * 2.5)
            newThirst = newThirst - (Config.ThirstDecayRate * 3)
            newFatigue = newFatigue + (Config.FatigueIncreaseRate * 4)
        else
            newHunger = newHunger - Config.HungerDecayRate
            newThirst = newThirst - Config.ThirstDecayRate
            newFatigue = newFatigue + Config.FatigueIncreaseRate
        end

        -- ตรวจสอบว่าอยู่ในยานพาหนะประเภทใด
        if IsPedInVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            local vehicleClass = GetVehicleClass(vehicle)
            if vehicleClass >= 0 and vehicleClass <= 7 then
                newThirst = math.min(newThirst, currentThirst - (Config.ThirstDecayRate * 0.5))
            end
        end

        -- อัตราการเพิ่มของ Bladder/Bowel
        newBladder = newBladder + Config.BladderIncreaseRate
        newBowel = newBowel + Config.BowelIncreaseRate

        -- ลดรังสีแบบ Passive (เมื่อไม่อยู่ในโซนรังสี)
        if not inRadiationZone then
            newRadiation = math.max(Config.MinRadiation, currentRadiation - Config.PassiveRadiationDecay)
        end

        -- ลดความเครียดแบบ Passive (เมื่อไม่อยู่ในสถานการณ์เครียด)
        -- Logic stress จะถูกจัดการใน ProcessPlayerStress บน Server
        -- ดังนั้นตรงนี้จะไม่ลด passive stress แล้ว

        -- จัดการภูมิคุ้มกัน
        if isSick or isBleeding then
            newImmunity = math.max(Config.MinImmunity, currentImmunity - Config.ImmunityDecayRate)
        elseif currentImmunity < Config.MaxImmunity then
            newImmunity = math.min(Config.MaxImmunity, currentImmunity + Config.ImmunityRegenRate)
        end


        -- Clamp ค่าให้อยู่ในช่วง Min/Max
        newHunger = math.max(Config.MinHunger, newHunger)
        newThirst = math.max(Config.MinThirst, newThirst)
        newFatigue = math.min(Config.MaxFatigue, math.max(Config.MinFatigue, newFatigue))
        newBladder = math.min(Config.MaxBladder, newBladder)
        newBowel = math.min(Config.MaxBowel, newBowel)
        newRadiation = math.min(Config.MaxRadiation, math.max(Config.MinRadiation, newRadiation)) -- Radiation ถูกจัดการโดย ProcessPlayerRadiation ด้วย
        newStress = math.min(Config.MaxStress, math.max(Config.MinStress, newStress)) -- Stress ถูกจัดการโดย ProcessPlayerStress ด้วย
        newImmunity = math.min(Config.MaxImmunity, math.max(Config.MinImmunity, newImmunity))


        -- สร้างตารางเพื่อส่งการอัปเดตไปยัง Server
        local updatesToSend = {}
        if playerState['player:hunger'] ~= newHunger then updatesToSend['player:hunger'] = newHunger end
        if playerState['player:thirst'] ~= newThirst then updatesToSend['player:thirst'] = newThirst end
        if playerState['player:fatigue'] ~= newFatigue then updatesToSend['player:fatigue'] = newFatigue end
        if playerState['player:bladder'] ~= newBladder then updatesToSend['player:bladder'] = newBladder end
        if playerState['player:bowel'] ~= newBowel then updatesToSend['player:bowel'] = newBowel end
        if playerState['player:radiation'] ~= newRadiation then updatesToSend['player:radiation'] = newRadiation end
        if playerState['player:stress'] ~= newStress then updatesToSend['player:stress'] = newStress end
        if playerState['player:immunity'] ~= newImmunity then updatesToSend['player:immunity'] = newImmunity end
        -- ... เพิ่ม wetness, body_temp หากต้องการให้ client คำนวณด้วย

        -- ส่งการอัปเดตไปยัง Server หากมีการเปลี่ยนแปลง
        if next(updatesToSend) ~= nil then
            TriggerServerEvent('sa_survival:updatePlayerStates', updatesToSend)
        end

        -- [[ ผลกระทบด้านสุขภาพจากความหิว/กระหาย (Client-side) ]]
        local healthUpdate = 0

        if newHunger <= HUNGER_CRITICAL_THRESHOLD then
            healthUpdate = healthUpdate + Config.DamageOnCriticalHunger
            lib_notify({ title = 'คำเตือน Survival', description = 'คุณกำลังหิวมากจนเลือดลด!', type = 'error', duration = 1000 })
        end

        if newThirst <= THIRST_CRITICAL_THRESHOLD then
            healthUpdate = healthUpdate + Config.DamageOnCriticalThirst
            lib_notify({ title = 'คำเตือน Survival', description = 'คุณกำลังกระหายน้ำมากจนเลือดลด!', type = 'error', duration = 1000 })
        end

        -- [[ ผลกระทบจาก Bladder/Bowel (Client-side) ]]
        local hasBladderProblem = false
        local hasBowelProblem = false

        if newBladder >= Config.Bladder.CriticalThreshold then
            healthUpdate = healthUpdate + Config.Bladder.DamagePerTick
            lib_notify({ title = 'คำเตือน', description = 'กระเพาะปัสสาวะของคุณกำลังจะระเบิด!', type = 'error', duration = 1000 })
            hasBladderProblem = true
        elseif newBladder >= Config.Bladder.FullThreshold then
            lib_notify({ title = 'ไม่ไหวแล้ว', description = 'คุณต้องการเข้าห้องน้ำด่วน!', type = 'warning', duration = 2000 })
            hasBladderProblem = true
        end

        if newBowel >= Config.Bowel.CriticalThreshold then
            healthUpdate = healthUpdate + Config.Bowel.DamagePerTick
            lib_notify({ title = 'คำเตือน', description = 'คุณกำลังจะขับถ่ายโดยไม่ตั้งใจ!', type = 'error', duration = 1000 })
            hasBowelProblem = true
        elseif newBowel >= Config.Bowel.FullThreshold then
            lib_notify({ title = 'ไม่ไหวแล้ว', description = 'คุณรู้สึกปวดท้องอย่างรุนแรง!', type = 'warning', duration = 2000 })
            hasBowelProblem = true
        end

        -- ลดเลือดเมื่อถึงเกณฑ์วิกฤต (จาก Hunger/Thirst/Bladder/Bowel)
        if healthUpdate > 0 then
            local currentHealth = GetEntityHealth(ped)
            SetEntityHealth(ped, math.max(0, currentHealth - healthUpdate))
        end

        exports['sa_survival']:UpdatePlayerMoveRate() -- เรียกใช้ฟังก์ชันรวมเพื่ออัปเดตความเร็ว

        ::continue_loop::
    end
end)