-- sa_survival/client/health_impacts/cl_health_impacts.lua

-- Caching exports และ Config
local GetConfig = exports['sa_survival']:GetConfig
local Config = GetConfig()

-- Caching Client Exports และ lib.notify
local lib_notify = lib.notify
local PlayAnimation = exports['sa_survival']:PlayAnimation
local ApplyScreenEffect = exports['sa_survival']:ApplyScreenEffect
local StopScreenEffectClient = exports['sa_survival']:StopScreenEffectClient
local UpdatePlayerMoveRate = exports['sa_survival']:UpdatePlayerMoveRate

-- ตัวแปร Local สำหรับ Native Functions ที่ใช้บ่อย
local PlayerPedId = PlayerPedId
local SetPedMoveRateOverride = SetPedMoveRateOverride -- จะใช้ผ่าน UpdatePlayerMoveRate
local SetPedConfigFlag = SetPedConfigFlag
local ShakeGameplayCam = ShakeGameplayCam
local StopGameplayCamShake = StopGameplayCamShake
local GetEntityHealth = GetEntityHealth
local GetEntityCoords = GetEntityCoords
local GetGroundZFor_3dCoords = GetGroundZFor_3dCoords
local GetPedLastDamageBone = GetPedLastDamageBone
local ClearPedLastWeaponDamage = ClearPedLastWeaponDamage
local IsPedFalling = IsPedFalling
local TaskPlayAnim = TaskPlayAnim
local RequestAnimDict = RequestAnimDict
local HasAnimDictLoaded = HasAnimDictLoaded
local RemoveAnimDict = RemoveAnimDict
local StopAnimTask = StopAnimTask
local GetRandomFloatInRange = GetRandomFloatInRange -- สำหรับโอกาส

-- ตัวแปรสำหรับตรวจจับ Fall Damage
local lastGroundZ = nil
local lastHealth = nil

-- [[ Client-side State Bag Listeners สำหรับผลกระทบ ]]
Citizen.CreateThread(function()
    local ped = PlayerPedId()
    if ped == 0 then
        Citizen.Wait(1000)
        goto continue_client_thread
    end

    -- Listener สำหรับอาการป่วย
    ped.state:on('player:status:sick', function(key, value, oldValue)
        if value then
            lib_notify({ title = 'สุขภาพ', description = 'คุณรู้สึกไม่สบายตัว', type = 'warning' })
            -- ApplyScreenEffect('ChopVision', -1) -- อาจใช้เอฟเฟกต์เฉพาะสำหรับป่วย
        else
            lib_notify({ title = 'สุขภาพ', description = 'คุณรู้สึกดีขึ้นแล้ว!', type = 'success' })
            -- StopScreenEffectClient('ChopVision')
        end
        UpdatePlayerMoveRate() -- เรียกใช้ฟังก์ชันรวม
    end)

    -- Listener สำหรับขาหัก
    ped.state:on('player:status:broken_leg', function(key, value, oldValue)
        if value then
            lib_notify({ title = 'บาดเจ็บ', description = 'ขาของคุณหัก ทำให้เคลื่อนไหวลำบาก!', type = 'error' })
            SetPedConfigFlag(ped, 32, true) -- CONFIG_FLAG_PED_DRUNK ทำให้เดินเซ (หรือ Animation อื่นๆ)
            PlayAnimation('missfbi5ig_2', 'leg_injury_loop', -1, 8.0, 8.0, 49) -- ตัวอย่าง Animation ขาเจ็บ
        else
            lib_notify({ title = 'บาดเจ็บ', description = 'ขาของคุณหายดีแล้ว!', type = 'success' })
            SetPedConfigFlag(ped, 32, false)
            StopAnimTask(ped, 'missfbi5ig_2', 'leg_injury_loop', 1.0) -- หยุด Animation
        end
        UpdatePlayerMoveRate() -- เรียกใช้ฟังก์ชันรวม
    end)

    -- Listener สำหรับแขนหัก (ใหม่)
    ped.state:on('player:status:broken_arm', function(key, value, oldValue)
        if value then
            lib_notify({ title = 'บาดเจ็บ', description = 'แขนของคุณหัก ทำให้ถืออาวุธและเล็งลำบาก!', type = 'error' })
            PlayAnimation(Config.Injuries.BrokenArmAnim.dict, Config.Injuries.BrokenArmAnim.name, -1, 8.0, 8.0, 49)
            -- อาจทำให้ Ped ไม่สามารถถืออาวุธสองมือได้
            SetPedConfigFlag(ped, 243, true) -- CONFIG_FLAG_PED_INJURED_ARM
        else
            lib_notify({ title = 'บาดเจ็บ', description = 'แขนของคุณหายดีแล้ว!', type = 'success' })
            StopAnimTask(ped, Config.Injuries.BrokenArmAnim.dict, Config.Injuries.BrokenArmAnim.name, 1.0)
            SetPedConfigFlag(ped, 243, false)
        end
    end)

    -- Listener สำหรับบาดเจ็บศีรษะ (ใหม่)
    ped.state:on('player:status:head_injury', function(key, value, oldValue)
        if value then
            lib_notify({ title = 'บาดเจ็บ', description = 'คุณบาดเจ็บที่ศีรษะ การมองเห็นของคุณแย่ลง!', type = 'error' })
            ApplyScreenEffect(Config.Injuries.HeadInjuryScreenEffect, -1)
            ShakeGameplayCam('DRUNK_SHAKE', 0.5) -- สั่นเบาๆ
        else
            lib_notify({ title = 'บาดเจ็บ', description = 'อาการบาดเจ็บที่ศีรษะดีขึ้นแล้ว!', type = 'success' })
            StopScreenEffectClient(Config.Injuries.HeadInjuryScreenEffect)
            StopGameplayCamShake(true)
        end
    end)

    -- Listener สำหรับเลือดออก
    ped.state:on('player:status:bleeding', function(key, value, oldValue)
        if value then
            lib_notify({ title = 'บาดเจ็บ', description = 'คุณกำลังเลือดออก! ควรรีบห้ามเลือด', type = 'error' })
            -- อาจจะแสดง Particle Effect เลือดหยด หรือ Screen effect แดงๆ
        else
            lib_notify({ title = 'บาดเจ็บ', description = 'เลือดหยุดแล้ว!', type = 'success' })
        end
    end)

    -- Listener สำหรับความวิตกกังวล
    ped.state:on('player:status:anxiety', function(key, value, oldValue)
        if value then
            lib_notify({ title = 'ความเครียด', description = 'คุณรู้สึกวิตกกังวล', type = 'warning' })
            ShakeGameplayCam('DRUNK_SHAKE', Config.Stress.ShakeCameraOnAnxiety)
        else
            lib_notify({ title = 'ความเครียด', description = 'คุณรู้สึกสงบลงแล้ว', type = 'success' })
            StopGameplayCamShake(true)
        end
    end)

    -- Listener สำหรับ Panic Attack
    ped.state:on('player:status:panickattack', function(key, value, oldValue)
        if value then
            lib_notify({ title = 'ความเครียด', description = 'คุณกำลังตื่นตระหนกอย่างรุนแรง!', type = 'error' })
            ApplyScreenEffect(Config.Stress.ScreenEffectOnPanicAttack, -1)
            ShakeGameplayCam('DRUNK_SHAKE', Config.Stress.ShakeCameraOnPanicAttack)
            SetPedConfigFlag(ped, 241, true) -- CONFIG_FLAG_PED_COWER (ทำให้ Ped หวาดกลัว)
        else
            lib_notify({ title = 'ความเครียด', description = 'อาการตื่นตระหนกของคุณหายไปแล้ว', type = 'success' })
            StopScreenEffectClient(Config.Stress.ScreenEffectOnPanicAttack)
            StopGameplayCamShake(true)
            SetPedConfigFlag(ped, 241, false)
        end
        UpdatePlayerMoveRate() -- เรียกใช้ฟังก์ชันรวม (Panic Attack อาจส่งผลต่อความเร็ว)
    end)

    ::continue_client_thread::
end)


-- [[ Logic การตรวจจับความเสียหายบน Client-side ]]
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local ped = PlayerPedId()
        if ped == 0 then
            Citizen.Wait(1000)
            goto continue_damage_check
        end

        local currentHealth = GetEntityHealth(ped)

        -- ตรวจจับ Fall Damage
        local playerCoords = GetEntityCoords(ped)
        local groundZ = GetGroundZFor_3dCoords(playerCoords.x, playerCoords.y, playerCoords.z, false)
        if lastGroundZ == nil then lastGroundZ = groundZ end

        if not IsPedFalling(ped) then
            local fallHeight = lastGroundZ - playerCoords.z
            if fallHeight > Config.Injuries.FallDamageMinHeight then
                if lastHealth ~= nil and currentHealth < lastHealth then
                    local damageTaken = lastHealth - currentHealth
                    if damageTaken > 0 then
                        TriggerServerEvent('sa_survival:server:handleDamage', 'fall', damageTaken)
                        lib_notify({ title = 'บาดเจ็บ', description = 'คุณได้รับบาดเจ็บจากการตก!', type = 'warning' })
                    end
                end
            end
            lastGroundZ = playerCoords.z
        else
            lastGroundZ = math.max(lastGroundZ, playerCoords.z)
        end

        -- ตรวจจับการถูกยิง/ฟัน (ผ่าน GetPedLastDamageBone เป็น heuristic)
        if lastHealth ~= nil and currentHealth < lastHealth then
            local damageTaken = lastHealth - currentHealth
            if damageTaken > 0 then
                local bone = GetPedLastDamageBone(ped)
                ClearPedLastWeaponDamage(ped)

                if bone ~= -1 then
                    local damageType = 'unknown'
                    -- ใช้ bone ID ที่มีโอกาสสูงว่าเป็นการยิง/ฟัน
                    -- ควรปรึกษา doc GTA V bone IDs หรือใช้ระบบ Combat ที่แม่นยำกว่า
                    if bone >= 0 and bone <= 100 then -- ส่วนใหญ่จะเป็น bone ของ torso, head, limbs
                        damageType = 'bullet' -- เดาว่าเป็นกระสุน
                    elseif bone >= 200 and bone <= 300 then -- ตัวเลขสมมติสำหรับส่วนอื่น
                        damageType = 'melee' -- เดาว่าเป็น Melee
                    end

                    -- Trigger Server Event เพื่อจัดการ
                    TriggerServerEvent('sa_survival:server:handleDamage', damageType, damageTaken)
                end
            end
        end

        lastHealth = currentHealth
        ::continue_damage_check::
    end
end)

-- [[ Client-side Logic สำหรับอาการป่วย (ไอ, อาเจียน) ]]
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(1000) -- ตรวจสอบทุก 1 วินาที

        local ped = PlayerPedId()
        if ped == 0 then
            goto continue_sickness_effects
        end

        local isSick = ped.state['player:status:sick']

        if isSick then
            -- ไอ
            if GetRandomFloatInRange(0.0, 1.0) <= Config.Sickness.CoughChance then
                -- Play simple cough animation
                RequestAnimDict('ragdoll@human')
                while not HasAnimDictLoaded('ragdoll@human') do Citizen.Wait(0) end
                TaskPlayAnim(ped, 'ragdoll@human', 'sneeze_long', 8.0, -8.0, 1000, 0, 0, false, false, false)
                RemoveAnimDict('ragdoll@human')
                -- Play sound (ต้องมี sound fx)
                -- PlaySoundFrontend(-1, "COUGH", "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
            end

            -- อาเจียน (เมื่อป่วยหนักและมีโอกาส)
            if GetRandomFloatInRange(0.0, 1.0) <= Config.Sickness.VomitChance then
                -- Trigger Server Event for vomit effect (optional)
                TriggerServerEvent('sa_survival:server:triggerVomit', GetEntityCoords(ped))
            end
        end

        ::continue_sickness_effects::
    end
end)

-- Helper: UpdatePlayerMoveRate
-- ฟังก์ชันนี้จะถูกเรียกจาก Listener ต่างๆ เพื่อรวมผลกระทบต่อความเร็ว
exports('UpdatePlayerMoveRate', function()
    local ped = PlayerPedId()
    if ped == 0 then return end

    local currentMoveRate = 1.0

    -- ผลกระทบจาก Fatigue/Exhausted
    if ped.state['player:status:exhausted'] then
        currentMoveRate = math.min(currentMoveRate, 0.5)
    elseif ped.state['player:status:tired'] then
        currentMoveRate = math.min(currentMoveRate, 0.8)
    end

    -- ผลกระทบจาก Bladder/Bowel
    if ped.state['player:bladder'] and ped.state['player:bladder'] >= Config.Bladder.FullThreshold then
        currentMoveRate = math.min(currentMoveRate, 1.0 - Config.Bladder.MoveRatePenalty)
    end
    if ped.state['player:bowel'] and ped.state['player:bowel'] >= Config.Bowel.FullThreshold then
        currentMoveRate = math.min(currentMoveRate, 1.0 - Config.Bowel.MoveRatePenalty)
    end

    -- ผลกระทบจาก Sickness
    if ped.state['player:status:sick'] then
        currentMoveRate = math.min(currentMoveRate, 1.0 - Config.Sickness.MoveRatePenalty)
    end

    -- ผลกระทบจาก BrokenLeg / BrokenArm
    if ped.state['player:status:broken_leg'] then
        currentMoveRate = math.min(currentMoveRate, Config.Injuries.BrokenLegMoveRatePenalty)
    end
    -- if ped.state['player:status:broken_arm'] then
    --     -- อาจจะไม่มีผลต่อความเร็วโดยตรง แต่มีผลต่อการถือปืน
    -- end

    -- ผลกระทบจาก Hypothermia / Heatstroke
    if ped.state['player:status:hypothermia'] then
        currentMoveRate = math.min(currentMoveRate, Config.Temperature.HypothermiaMovePenalty)
    end
    if ped.state['player:status:heatstroke'] then
        currentMoveRate = math.min(currentMoveRate, Config.Temperature.HeatstrokeMovePenalty)
    end

    -- ผลกระทบจาก Panic Attack (อาจจะทำให้สุ่มลดความเร็ว)
    if ped.state['player:status:panickattack'] then
        currentMoveRate = math.min(currentMoveRate, 0.6) -- ตัวอย่าง
    end


    SetPedMoveRateOverride(ped, currentMoveRate)
end)