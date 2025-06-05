-- sa_survival/server/item_interaction/sv_item_interaction.lua

-- Caching exports และ Config
local GetConfig = exports['sa_survival']:GetConfig
local Config = GetConfig()
local ApplyStatusEffect = exports['sa_survival']:ApplyStatusEffect
local ClearStatusEffect = exports['sa_survival']:ClearStatusEffect

-- Caching lib.notify
local lib_notify = lib.notify

-- ตัวแกร Local สำหรับ Native Functions ที่ใช้บ่อย
local GetPlayerPed = GetPlayerPed
local DoesEntityExist = DoesEntityExist
local GetEntityHealth = GetEntityHealth
local SetEntityHealth = SetEntityHealth

-- ** [IMPORTANT] Caching Inventory Exports ของคุณที่นี่ **
-- ตอนนี้ใช้ชื่อ resource 'core_inventory'
local InventoryAddItem = exports.core_inventory.AddItem
local InventoryRemoveItem = exports.core_inventory.RemoveItem
-- local InventoryHasItem = exports.core_inventory.HasItem -- โดยปกติจะเช็ค HasItem บน Client ก่อน

-- Event สำหรับการร้องขอใช้ไอเท็มจาก Client
RegisterNetEvent('sa_survival:server:useSurvivalItem')
AddEventHandler('sa_survival:server:useSurvivalItem', function(itemName)
    local src = source
    local playerPed = GetPlayerPed(src)

    if not playerPed or not DoesEntityExist(playerPed) then
        print(string.format('[Survival Core: Item Interaction] PlayerPed not found for src %d', src))
        return
    end

    local itemData = Config.SurvivalItems[itemName]

    if not itemData then
        lib_notify({ source = src, title = 'ข้อผิดพลาด', description = 'ไม่พบข้อมูลไอเท็มนี้', type = 'error' })
        print(string.format('[Survival Core: Item Interaction] Unknown item: %s used by player %d', itemName, src))
        return
    end

    -- ** Logic การตรวจสอบ Inventory ของผู้เล่นและหักไอเท็ม **
    local success, message = InventoryRemoveItem(src, itemName, 1, false) -- 'false' means don't force remove if not enough. Adjust as per your Inventory's AddItem/RemoveItem docs.
    if not success then
        lib_notify({ source = src, title = 'ข้อผิดพลาด', description = message or 'คุณไม่มีไอเท็มนี้ หรือไม่สามารถหักไอเท็มได้', type = 'error' })
        print(string.format('[Survival Core: Item Interaction] Failed to remove item %s from player %d: %s', itemName, src, message or 'Unknown reason'))
        return
    end
    -- ** จบ Logic การตรวจสอบ Inventory **

    -- ตรวจสอบว่าผู้เล่นกำลัง "busy"
    if playerPed.state['player:is_busy'] then
        lib_notify({ source = src, title = 'กำลังดำเนินการ', description = 'คุณกำลังทำกิจกรรมอื่นอยู่', type = 'warning' })
        InventoryAddItem(src, itemName, 1, false) -- คืนไอเท็มหาก busy
        return
    end

    exports['sa_survival']:SetPlayerBusy(src, true)

    -- Trigger Client Event เพื่อเล่น Animation และ Effects (รวมถึง ProgressBar)
    TriggerClientEvent('sa_survival:client:playItemAnimationAndProgressBar', src, itemData.animation.dict, itemData.animation.name, itemData.duration, itemData.label)

    lib.callback.wait(itemData.duration)

    -- ประมวลผล Effect ของไอเท็ม
    local playerState = playerPed.state

    if itemData.effect.hunger then
        local newHunger = math.min(Config.MaxHunger, playerState['player:hunger'] + itemData.effect.hunger)
        if playerState['player:hunger'] ~= newHunger then
            playerState:set('player:hunger', newHunger, true)
            lib_notify({ source = src, title = 'สถานะ', description = itemData.label .. ' ช่วยลดความหิวของคุณ', type = 'success' })
        end
    end

    if itemData.effect.thirst then
        local newThirst = math.min(Config.MaxThirst, playerState['player:thirst'] + itemData.effect.thirst)
        if playerState['player:thirst'] ~= newThirst then
            playerState:set('player:thirst', newThirst, true)
            lib_notify({ source = src, title = 'สถานะ', description = itemData.label .. ' ช่วยลดความกระหายของคุณ', type = 'success' })
        end
    end

    if itemData.effect.radiation_decrease then
        local newRadiation = math.max(Config.MinRadiation, playerState['player:radiation'] - itemData.effect.radiation_decrease)
        if playerState['player:radiation'] ~= newRadiation then
            playerState:set('player:radiation', newRadiation, true)
            lib_notify({ source = src, title = 'สถานะ', description = itemData.label .. ' ช่วยลดรังสีในร่างกายของคุณ', type = 'success' })
        end
    end

    if itemData.effect.health_regen then
        local currentHealth = GetEntityHealth(playerPed)
        local newHealth = math.min(200, currentHealth + itemData.effect.health_regen)
        if currentHealth ~= newHealth then
            SetEntityHealth(playerPed, newHealth)
            lib_notify({ source = src, title = 'สถานะ', description = itemData.label .. ' ช่วยฟื้นฟูสุขภาพของคุณ', type = 'success' })
        end
    end

    if itemData.effect.clear_status then
        ClearStatusEffect(src, itemData.effect.clear_status)
    end
    if itemData.effect.clear_status_2 then
        ClearStatusEffect(src, itemData.effect.clear_status_2)
    end

    if itemData.effect.add_status then
        ApplyStatusEffect(src, itemData.effect.add_status.name, itemData.effect.add_status.duration, {})
    end

    exports['sa_survival']:SetPlayerBusy(src, false)
end)

-- Event สำหรับรับการโต้ตอบกับวัตถุจาก Client
RegisterNetEvent('sa_survival:server:interactWithObject')
AddEventHandler('sa_survival:server:interactWithObject', function(pointId)
    local src = source
    local playerPed = GetPlayerPed(src)

    if not playerPed or not DoesEntityExist(playerPed) then
        print(string.format('[Survival Core: Item Interaction] PlayerPed not found for src %d', src))
        return
    end

    local pointData = Config.InteractionPoints[pointId]
    if not pointData then
        lib_notify({ source = src, title = 'ข้อผิดพลาด', description = 'ไม่พบจุดโต้ตอบนี้', type = 'error' })
        print(string.format('[Survival Core: Item Interaction] Unknown interaction point: %s by player %d', pointId, src))
        return
    end

    -- ** Logic การเพิ่มไอเท็มเข้า Inventory ของผู้เล่น **
    local success, message = InventoryAddItem(src, pointData.item_gain, pointData.amount, false)
    if success then
        lib_notify({ source = src, title = 'เก็บของ', description = 'คุณได้รับ ' .. pointData.amount .. 'x ' .. (Config.SurvivalItems[pointData.item_gain] and Config.SurvivalItems[pointData.item_gain].label or pointData.item_gain) .. ' จาก ' .. pointData.label, type = 'success' })
        print(string.format('[Survival Core: Item Interaction] Player %d collected %dx %s from %s', src, pointData.amount, pointData.item_gain, pointData.label))
    else
        lib_notify({ source = src, title = 'ข้อผิดพลาด', description = message or 'ไม่สามารถเพิ่มไอเท็มได้', type = 'error' })
        print(string.format('[Survival Core: Item Interaction] Failed to add item %s to player %d: %s', pointData.item_gain, src, message or 'Unknown reason'))
    end
    -- ** จบ Logic การเพิ่มไอเท็ม **
end)

-- Event สำหรับรับคำสั่งการขับถ่ายจาก Client
RegisterNetEvent('sa_survival:server:performExcretion')
AddEventHandler('sa_survival:server:performExcretion', function(excreteType)
    local src = source
    local playerPed = GetPlayerPed(src)
    if not playerPed or not DoesEntityExist(playerPed) then return end

    local playerState = playerPed.state
    local notified = false

    if excreteType == 'bladder' then
        local currentBladder = playerState['player:bladder'] or Config.MinBladder
        if currentBladder > Config.Bladder.FullThreshold then
            playerState:set('player:bladder', Config.MinBladder, true)
            lib_notify({ source = src, title = 'โล่งอก', description = 'คุณได้ปลดปล่อยกระเพาะปัสสาวะแล้ว!', type = 'success' })
            notified = true
        else
            lib_notify({ source = src, title = 'ยังไม่ถึงเวลา', description = 'คุณยังไม่ปวดปัสสาวะมากพอ', type = 'info' })
        end
    elseif excreteType == 'bowel' then
        local currentBowel = playerState['player:bowel'] or Config.MinBowel
        if currentBowel > Config.Bowel.FullThreshold then
            playerState:set('player:bowel', Config.MinBowel, true)
            lib_notify({ source = src, title = 'สบายตัว', description = 'คุณได้ขับถ่ายแล้ว!', type = 'success' })
            notified = true
        else
            lib_notify({ source = src, title = 'ยังไม่ถึงเวลา', description = 'คุณยังไม่ปวดท้องมากพอ', type = 'info' })
        end
    end
end)

-- Event สำหรับเริ่มกระบวนการ Crafting/Processing
RegisterNetEvent('sa_survival:server:startCrafting')
AddEventHandler('sa_survival:server:startCrafting', function(recipeId)
    local src = source
    local playerPed = GetPlayerPed(src)
    if not playerPed or not DoesEntityExist(playerPed) then return end

    local recipe = Config.Crafting.Recipes[recipeId]
    if not recipe then
        lib_notify({ source = src, title = 'ข้อผิดพลาด', description = 'สูตรการทำนี้ไม่ถูกต้อง', type = 'error' })
        print(string.format('[Survival Core: Crafting] Unknown recipe: %s by player %d', recipeId, src))
        return
    end

    if playerPed.state['player:is_busy'] then
        lib_notify({ source = src, title = 'กำลังดำเนินการ', description = 'คุณกำลังทำกิจกรรมอื่นอยู่', type = 'warning' })
        return
    end

    -- ตรวจสอบส่วนผสมใน Inventory และหักออก
    for ingredientItem, requiredAmount in pairs(recipe.ingredients) do
        local hasItem = InventoryRemoveItem(src, ingredientItem, requiredAmount, false) -- 'false' means don't force remove if not enough
        if not hasItem then
            lib_notify({ source = src, title = 'ข้อผิดพลาด', description = 'คุณไม่มี ' .. requiredAmount .. 'x ' .. (Config.SurvivalItems[ingredientItem] and Config.SurvivalItems[ingredientItem].label or ingredientItem) .. ' เพียงพอ', type = 'error' })
            -- คืนไอเท็มที่หักไปแล้วหากมีส่วนผสมไม่พอ
            for k, v in pairs(recipe.ingredients) do
                if k ~= ingredientItem then
                    InventoryAddItem(src, k, v, false)
                end
            end
            return
        end
    end

    exports['sa_survival']:SetPlayerBusy(src, true)

    TriggerClientEvent('sa_survival:client:startCraftingProcess', src, recipe.animation.dict, recipe.animation.name, recipe.duration, recipe.label)

    lib.callback.wait(recipe.duration)

    -- เพิ่มผลลัพธ์เข้า Inventory
    local success, message = InventoryAddItem(src, recipe.result_item, recipe.result_amount, false)
    if success then
        lib_notify({ source = src, title = 'ทำสำเร็จ!', description = recipe.success_message, type = 'success' })
    else
        lib_notify({ source = src, title = 'ทำไม่สำเร็จ', description = recipe.fail_message .. (message or ''), type = 'error' })
    end

    exports['sa_survival']:SetPlayerBusy(src, false)
end)