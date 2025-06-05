-- sa_survival/server/health_impacts/sv_health_impacts.lua

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
local GetPedArmour = GetPedArmour
local GetPlayersInArea = GetPlayersInArea -- สำหรับ Combat Stress

-- [[ ฟังก์ชันประมวลผลสำหรับ Server-side ]]

---@param src number Player source ID
---@param playerState table The player's state bag (passed by reference)
function ProcessPlayerSickness(src, playerState)
    local isSick = playerState['player:status:sick']
    local currentImmunity = playerState['player:immunity'] or Config.MaxImmunity
    local ped = GetPlayerPed(src)
    if not ped or not DoesEntityExist(ped) then return end

    -- Logic การเกิดโรคจากภูมิคุ้มกันต่ำ
    if currentImmunity < Config.Sickness.ImmunityThresholdForSickness and not isSick then
        if math.random() <= Config.Sickness.ChanceFromLowImmunity then
            ApplyStatusEffect(src, 'Sick', Config.Sickness.InitialDuration, {cause = 'low_immunity'})
            lib_notify({ source = src, title = 'อาการป่วย', description = 'คุณรู้สึกไม่สบายตัวอย่างกะทันหัน เพราะภูมิคุ้มกันต่ำ!', type = 'warning' })
        end
    end

    -- ผลกระทบจากการป่วย (ถ้าป่วยอยู่)
    if isSick then
        local newImmunity = math.max(Config.MinImmunity, currentImmunity - Config.ImmunityDecayRate)
        if playerState['player:immunity'] ~= newImmunity then
            playerState:set('player:immunity', newImmunity, true)
        end

        local currentHealth = GetEntityHealth(ped)
        SetEntityHealth(ped, math.max(0, currentHealth - Config.Sickness.DamagePerTick))
    end
end
exports('ProcessPlayerSickness', ProcessPlayerSickness)

---@param src number Player source ID
---@param playerState table The player's state bag (passed by reference)
function ProcessPlayerInjuries(src, playerState)
    local isBleeding = playerState['player:status:bleeding']
    local isBrokenLeg = playerState['player:status:broken_leg']
    local isBrokenArm = playerState['player:status:broken_arm'] -- ใหม่
    local isHeadInjury = playerState['player:status:head_injury'] -- ใหม่

    local ped = GetPlayerPed(src)
    if not ped or not DoesEntityExist(ped) then return end

    -- ผลกระทบจากการเลือดออก
    if isBleeding then
        local currentHealth = GetEntityHealth(ped)
        SetEntityHealth(ped, math.max(0, currentHealth - Config.Injuries.BleedingDamagePerTick))
        lib_notify({ source = src, title = 'บาดเจ็บ', description = 'คุณเสียเลือด!', type = 'error', duration = 1000 })
    end

    -- ผลกระทบจากขาหัก (ลดเกราะ, ลดเลือด)
    if isBrokenLeg then
        local currentArmour = GetPedArmour(ped)
        if currentArmour > 0 then
            SetPedArmour(ped, math.max(0, currentArmour - Config.Injuries.BrokenLegArmourPenalty))
        end
        -- เลือดอาจลดช้าๆ ด้วย
        -- SetEntityHealth(ped, math.max(0, GetEntityHealth(ped) - 0.1))
    end

    -- ผลกระทบจากแขนหัก (ไม่มีผลต่อเลือดโดยตรง)
    if isBrokenArm then
        -- อาจลดความแม่นยำในการยิง, ลดน้ำหนักที่ถือได้
    end

    -- ผลกระทบจากบาดเจ็บศีรษะ (ไม่มีผลต่อเลือดโดยตรง)
    if isHeadInjury then
        -- อาจลด Max Health ชั่วคราว หรือทำให้เป็นลม
    end
end
exports('ProcessPlayerInjuries', ProcessPlayerInjuries)

---@param src number Player source ID
---@param playerState table The player's state bag (passed by reference)
function ProcessPlayerStress(src, playerState)
    local currentStress = playerState['player:stress'] or Config.MinStress
    local isAnxiety = playerState['player:status:anxiety']
    local isPanicAttack = playerState['player:status:panickattack']
    local inDarkness = playerState['player:in_darkness'] or false
    local isIsolated = playerState['player:is_isolated'] or false
    local inShelter = playerState['player:in_shelter'] or false
    local newStress = currentStress
    local ped = GetPlayerPed(src)
    if not ped or not DoesEntityExist(ped) then return end

    -- ปัจจัยเพิ่มความเครียด
    if inDarkness then
        newStress = newStress + Config.Stress.DarknessIncreaseRate
    end
    if isIsolated then
        newStress = newStress + Config.Stress.IsolationIncreaseRate
    end

    -- Logic การเพิ่มความเครียดจากการต่อสู้
    local playerCoords = GetEntityCoords(ped)
    local nearbyHostilePeds = GetPedsInArea(playerCoords.x, playerCoords.y, playerCoords.z, Config.Stress.CombatStressRadius, ped) -- GetPedsInArea ต้องการ param เพิ่ม
    local inCombat = false
    for _, otherPed in ipairs(nearbyHostilePeds) do
        if not IsPedAPlayer(otherPed) and GetPedRelationshipGroupHash(otherPed) == GetHashKey('AMBIENT_GANG_LOST') then -- ตัวอย่าง NPC hostile
             inCombat = true
             break
        end
        -- TODO: ตรวจสอบผู้เล่นคนอื่นที่กำลังยิง/ต่อสู้ด้วย
    end
    -- วิธีที่ดีกว่า: ตรวจสอบการยิงปืนของผู้เล่นเอง หรือการโดนโจมตี
    -- local weaponHash = GetSelectedPedWeapon(ped)
    -- if IsPedShooting(ped) or weaponHash ~= GetHashKey('WEAPON_UNARMED') then
    --     inCombat = true
    -- end

    -- ตรวจสอบว่าผู้เล่นกำลังอยู่ในสถานการณ์ต่อสู้กับ NPC/ผู้เล่นคนอื่น
    local activePlayers = GetActivePlayers()
    for _, pId in ipairs(activePlayers) do
        if pId ~= PlayerId() then -- อย่าเทียบกับตัวเอง
            local otherPed = GetPlayerPed(pId)
            if otherPed ~= 0 then
                if GetDistanceBetweenCoords(playerCoords, GetEntityCoords(otherPed), true) < Config.Stress.CombatStressRadius then
                    -- ตรวจสอบว่าผู้เล่นคนอื่นกำลังยิงปืน หรือโดนยิง
                    -- สมมติว่ามี State Bag 'player:is_shooting' หรือ 'player:is_being_shot'
                    -- if otherPed.state['player:is_shooting'] or otherPed.state['player:is_being_shot'] then
                    --     inCombat = true
                    --     break
                    -- end
                end
            end
        end
    end
    -- สำหรับตอนนี้: สมมติว่า Client ส่งสัญญาณมาถ้าอยู่ใน Combat
    if playerState['player:in_combat'] then -- State Bag นี้ต้องถูก Client อัปเดต
        newStress = newStress + Config.Stress.CombatIncreaseRate
    end


    -- ปัจจัยลดความเครียด
    if inShelter and not inDarkness and not isIsolated then
        newStress = newStress - Config.Stress.PassiveDecayInShelter
    else
        newStress = newStress - Config.PassiveStressDecay
    end

    newStress = math.min(Config.MaxStress, math.max(Config.MinStress, newStress))

    if playerState['player:stress'] ~= newStress then
        playerState:set('player:stress', newStress, true)
    end

    -- ผลกระทบจากความเครียด (ยังคงอยู่ที่เดิม)
    if newStress >= (Config.MaxStress * 0.9) and not isPanicAttack then
        ApplyStatusEffect(src, 'PanicAttack', 0, {})
        lib_notify({ source = src, title = 'ความเครียด', description = 'คุณกำลังตื่นตระหนก!', type = 'error' })
    elseif newStress >= (Config.MaxStress * 0.7) and not isAnxiety then
        ApplyStatusEffect(src, 'Anxiety', 0, {})
        lib_notify({ source = src, title = 'ความเครียด', description = 'คุณเริ่มมีอาการวิตกกังวล!', type = 'warning' })
    elseif newStress < (Config.MaxStress * 0.7) and isAnxiety then
        ClearStatusEffect(src, 'Anxiety')
        lib_notify({ source = src, title = 'ความเครียด', description = 'คุณรู้สึกผ่อนคลายขึ้นแล้ว', type = 'success' })
    elseif newStress < (Config.MaxStress * 0.9) and isPanicAttack then
        ClearStatusEffect(src, 'PanicAttack')
        lib_notify({ source = src, title = 'ความเครียด', description = 'อาการตื่นตระหนกของคุณหายไปแล้ว', type = 'success' })
    end
end
exports('ProcessPlayerStress', ProcessPlayerStress)

-- [[ Net Events สำหรับ Client-side triggers ของการบาดเจ็บ ]]
RegisterNetEvent('sa_survival:server:handleDamage')
AddEventHandler('sa_survival:server:handleDamage', function(damageType, damageAmount)
    local src = source
    local playerPed = GetPlayerPed(src)
    if not playerPed or not DoesEntityExist(playerPed) then return end

    local playerState = playerPed.state

    -- Logic การเกิดเลือดออก
    if damageType == 'bullet' and math.random() <= Config.Injuries.BulletWoundBleedChance then
        if not playerState['player:status:bleeding'] then
            ApplyStatusEffect(src, 'Bleeding', 0, {cause = 'bullet_wound'})
        end
    elseif damageType == 'melee' and math.random() <= Config.Injuries.MeleeWoundBleedChance then
        if not playerState['player:status:bleeding'] then
            ApplyStatusEffect(src, 'Bleeding', 0, {cause = 'melee_wound'})
        end
    end

    -- Logic การเกิดขาหักจากการตก
    if damageType == 'fall' then
        if math.random() <= Config.Injuries.ChanceBrokenLegFromFall then
            if not playerState['player:status:broken_leg'] then
                ApplyStatusEffect(src, 'BrokenLeg', 0, {cause = 'fall'})
            end
        end
        if math.random() <= Config.Injuries.ChanceBleedingFromFall then
            if not playerState['player:status:bleeding'] then
                ApplyStatusEffect(src, 'Bleeding', 0, {cause = 'fall'})
            end
        end
    end

    -- Logic การเกิดแขนหัก (ใหม่)
    if (damageType == 'bullet' or damageType == 'melee' or damageType == 'fall') and math.random() <= Config.Injuries.BrokenArmChance then
        if not playerState['player:status:broken_arm'] then
            ApplyStatusEffect(src, 'BrokenArm', 0, {cause = damageType})
        end
    end

    -- Logic การเกิดบาดเจ็บศีรษะ (ใหม่)
    if (damageType == 'bullet' or damageType == 'melee' or damageType == 'fall') and math.random() <= Config.Injuries.HeadInjuryChance then
        if not playerState['player:status:head_injury'] then
            ApplyStatusEffect(src, 'HeadInjury', 0, {cause = damageType})
        end
    end

    -- TODO: เพิ่ม Logic การบาดเจ็บอื่นๆ (เช่น ไฟไหม้, ระเบิด)
end)

-- Net Events สำหรับ Client-side triggers ของการป่วย (นอกเหนือจาก Immunity ต่ำ)
RegisterNetEvent('sa_survival:server:triggerSickness')
AddEventHandler('sa_survival:server:triggerSickness', function(cause, duration)
    local src = source
    local playerPed = GetPlayerPed(src)
    if not playerPed or not DoesEntityExist(playerPed) then return end

    local playerState = playerPed.state
    if not playerState['player:status:sick'] then
        local chance = 0
        if cause == 'dirty_water' then
            chance = Config.Sickness.ChanceFromDirtyWater
        elseif cause == 'rotten_food' then
            chance = Config.Sickness.ChanceFromRottenFood
        else
            chance = 1.0 -- ถ้าสาเหตุอื่นที่ไม่ใช่ random chance ให้ป่วยแน่นอน
        end

        if math.random() <= chance then
            ApplyStatusEffect(src, 'Sick', duration or Config.Sickness.InitialDuration, {cause = cause})
            lib_notify({ source = src, title = 'อาการป่วย', description = 'คุณรู้สึกไม่สบายตัวจาก ' .. cause .. '!', type = 'warning' })
        end
    end
end)