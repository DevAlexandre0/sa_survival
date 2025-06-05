-- sa_survival/client/item_interaction/cl_item_interaction.lua

-- Caching exports และ Config
local GetConfig = exports['sa_survival']:GetConfig
local Config = GetConfig()

-- Caching Client Exports
local PlayAnimation = exports['sa_survival']:PlayAnimation
local SetPlayerBusy = exports['sa_survival']:SetPlayerBusy

-- Caching lib.notify และ lib.progressBar
local lib_notify = lib.notify
local lib_progressBar = lib.progressBar

-- ตัวแปร Local สำหรับ Native Functions ที่ใช้บ่อย
local PlayerPedId = PlayerPedId
local IsControlJustReleased = IsControlJustReleased
local GetEntityCoords = GetEntityCoords
local IsPedInAnyVehicle = IsPedInAnyVehicle

-- Caching Inventory Exports ของคุณ (Client-side)
local InventoryHasItem = exports.core_inventory.HasItem

-- กำหนดข้อมูลไอเท็มที่ Client สามารถ "ใช้" ได้ (เพื่อส่งไปยัง Server)
local CLIENT_USABLE_ITEMS_HOTKEYS = {}
for itemName, itemData in pairs(Config.SurvivalItems) do
    if itemData.hotkey then
        CLIENT_USABLE_ITEMS_HOTKEYS[itemName] = { hotkey = itemData.hotkey }
    end
end

-- [[ Event Listener สำหรับ Client เพื่อเล่น Animation และ ProgressBar สำหรับ Item Use/Crafting ]]
RegisterNetEvent('sa_survival:client:playItemAnimationAndProgressBar')
AddEventHandler('sa_survival:client:playItemAnimationAndProgressBar', function(animDict, animName, duration, itemLabel)
    local ped = PlayerPedId()
    if ped == 0 then return end

    if IsPedInAnyVehicle(ped, false) then
        -- อาจจะเลือก animation อื่น หรือไม่อนุญาต
    end

    PlayAnimation(animDict, animName, duration, 8.0, 8.0, 49)

    lib_progressBar({
        duration = duration,
        label = 'กำลังใช้ ' .. itemLabel .. '...',
        use: Current Weapon = false,
        disable: All Controls = true,
        animDict = animDict,
        anim = animName,
        onComplete = function()
            -- Client-side actions after progress bar completes (if any)
        end,
        onCancel = function()
            lib_notify({ title = 'ถูกยกเลิก', description = 'การ ' .. itemLabel .. ' ถูกยกเลิก', type = 'error' })
            TriggerServerEvent('sa_survival:server:cancelBusyState')
        end
    })
end)

-- [[ Logic สำหรับการใช้ไอเท็มจาก Hotkey (Placeholder สำหรับการทดสอบ) ]]
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)

        local ped = PlayerPedId()
        if ped == 0 then
            Citizen.Wait(1000)
            goto continue_hotkey_loop
        end

        local isBusy = ped.state['player:is_busy'] or false
        if isBusy then
            Citizen.Wait(500)
            goto continue_hotkey_loop
        end

        for itemName, data in pairs(CLIENT_USABLE_ITEMS_HOTKEYS) do
            if IsControlJustReleased(0, data.hotkey) then
                local hasItem = InventoryHasItem(itemName, 1)
                if hasItem then
                    TriggerServerEvent('sa_survival:server:useSurvivalItem', itemName)
                    lib_notify({ title = 'ใช้ไอเท็ม', description = 'กำลังใช้ ' .. (Config.SurvivalItems[itemName] and Config.SurvivalItems[itemName].label or itemName) .. '...', type = 'info' })

                    -- Logic เพิ่มเติมสำหรับไอเท็มที่อาจทำให้ป่วย (Client-side decision based on item config)
                    local itemConfig = Config.SurvivalItems[itemName]
                    if itemConfig and itemConfig.effect and itemConfig.effect.add_status and itemConfig.effect.add_status.cause then
                        if itemConfig.effect.add_status.cause == 'dirty_water' or itemConfig.effect.add_status.cause == 'rotten_food' then
                            TriggerServerEvent('sa_survival:server:triggerSickness', itemConfig.effect.add_status.cause, itemConfig.effect.add_status.duration)
                        end
                    end
                else
                    lib_notify({ title = 'ข้อผิดพลาด', description = 'คุณไม่มี ' .. (Config.SurvivalItems[itemName] and Config.SurvivalItems[itemName].label or itemName) .. ' อยู่ใน Inventory', type = 'error' })
                end
                Citizen.Wait(500)
                break
            end
        end

        ::continue_hotkey_loop::
    end
end)


-- [[ Logic สำหรับการโต้ตอบกับวัตถุในโลกโดยใช้ ox_target ]]
Citizen.CreateThread(function()
    local targetOptions = {}

    -- เพิ่มจุดโต้ตอบปกติ
    for id, point in pairs(Config.InteractionPoints) do
        table.insert(targetOptions, {
            name = id,
            coords = point.coords,
            radius = point.radius,
            options = {
                {
                    event = 'sa_survival:client:startInteraction',
                    icon = 'fas fa-hand-rock',
                    label = point.message,
                    item_id = id,
                    distance = point.radius
                }
            }
        })
    end

    -- เพิ่มจุดโต้ตอบสำหรับการขับถ่าย
    if Config.Excretion and Config.Excretion.ExcreteLocations then
        for id, point in pairs(Config.Excretion.ExcreteLocations) do
            table.insert(targetOptions, {
                name = id,
                coords = point.coords,
                radius = point.radius,
                options = {
                    {
                        event = 'sa_survival:client:startExcretion',
                        icon = 'fas fa-toilet',
                        label = point.message,
                        excrete_type = point.type,
                        item_id = id,
                        distance = point.radius
                    }
                }
            })
        end
    end

    -- เพิ่มจุดโต้ตอบสำหรับการ Crafting
    if Config.Crafting and Config.Crafting.CraftingLocations then
        for id, point in pairs(Config.Crafting.CraftingLocations) do
            table.insert(targetOptions, {
                name = id,
                coords = point.coords,
                radius = point.radius,
                options = {
                    {
                        event = 'sa_survival:client:openCraftingMenu',
                        icon = 'fas fa-fire-alt',
                        label = point.message,
                        location_id = id,
                        distance = point.radius
                    }
                }
            })
        end
    end

    -- เพิ่มจุดโต้ตอบสำหรับการนอนหลับ
    if Config.Resting and Config.Resting.SleepLocations then
        for id, point in pairs(Config.Resting.SleepLocations) do
            table.insert(targetOptions, {
                name = id,
                coords = point.coords,
                radius = 2.0, -- รัศมีการโต้ตอบ
                options = {
                    {
                        event = 'sa_survival:client:startRestingInteraction',
                        icon = 'fas fa-bed',
                        label = point.message,
                        item_id = id,
                        distance = 2.0
                    }
                }
            })
        end
    end

    lib.addPointTargets(targetOptions)

    RegisterNetEvent('sa_survival:client:startInteraction')
    AddEventHandler('sa_survival:client:startInteraction', function(data)
        local interactionId = data.item_id
        local ped = PlayerPedId()
        if ped == 0 then return end
        local isBusy = ped.state['player:is_busy'] or false
        if isBusy then
            lib_notify({ title = 'กำลังดำเนินการ', description = 'คุณกำลังทำกิจกรรมอื่นอยู่', type = 'warning' })
            return
        end
        local pointData = Config.InteractionPoints[interactionId]
        if not pointData then
            lib_notify({ title = 'ข้อผิดพลาด', description = 'ข้อมูลจุดโต้ตอบไม่ถูกต้อง', type = 'error' })
            return
        end
        SetPlayerBusy(source, true)
        if pointData.animation then
            lib_progressBar({
                duration = pointData.duration,
                label = 'กำลัง ' .. pointData.label .. '...',
                use: Current Weapon = false,
                disable: All Controls = true,
                animDict = pointData.animation.dict,
                anim = pointData.animation.name,
                onComplete = function()
                    TriggerServerEvent('sa_survival:server:interactWithObject', interactionId)
                    SetPlayerBusy(source, false)
                end,
                onCancel = function()
                    lib_notify({ title = 'ถูกยกเลิก', description = 'การเก็บของถูกยกเลิก', type = 'error' })
                    SetPlayerBusy(source, false)
                    TriggerServerEvent('sa_survival:server:cancelBusyState')
                end
            })
        else
            TriggerServerEvent('sa_survival:server:interactWithObject', interactionId)
            SetPlayerBusy(source, false)
        end
    end)

    RegisterNetEvent('sa_survival:client:startExcretion')
    AddEventHandler('sa_survival:client:startExcretion', function(data)
        local excreteType = data.excrete_type
        local interactionId = data.item_id

        local ped = PlayerPedId()
        if ped == 0 then return end
        local isBusy = ped.state['player:is_busy'] or false
        if isBusy then
            lib_notify({ title = 'กำลังดำเนินการ', description = 'คุณกำลังทำกิจกรรมอื่นอยู่', type = 'warning' })
            return
        end

        local pointData = Config.Excretion.ExcreteLocations[interactionId]
        if not pointData then
            lib_notify({ title = 'ข้อผิดพลาด', description = 'ข้อมูลจุดขับถ่ายไม่ถูกต้อง', type = 'error' })
            return
        end

        SetPlayerBusy(source, true)

        lib_progressBar({
            duration = pointData.duration,
            label = 'กำลัง ' .. pointData.label .. '...',
            use: Current Weapon = false,
            disable: All Controls = true,
            animDict = pointData.animation.dict,
            anim = pointData.animation.name,
            onComplete = function()
                TriggerServerEvent('sa_survival:server:performExcretion', excreteType)
                SetPlayerBusy(source, false)
            end,
            onCancel = function()
                lib_notify({ title = 'ถูกยกเลิก', description = 'การขับถ่ายถูกยกเลิก', type = 'error' })
                SetPlayerBusy(source, false)
                TriggerServerEvent('sa_survival:server:cancelBusyState')
            end
        })
    end)

    RegisterNetEvent('sa_survival:client:openCraftingMenu')
    AddEventHandler('sa_survival:client:openCraftingMenu', function(data)
        local locationId = data.location_id
        local ped = PlayerPedId()
        if ped == 0 then return end
        local isBusy = ped.state['player:is_busy'] or false
        if isBusy then
            lib_notify({ title = 'กำลังดำเนินการ', description = 'คุณกำลังทำกิจกรรมอื่นอยู่', type = 'warning' })
            return
        end

        local recipes = {}
        for recipeId, recipeData in pairs(Config.Crafting.Recipes) do
            local hasIngredients = true
            local ingredientsText = {}
            for ingredientItem, requiredAmount in pairs(recipeData.ingredients) do
                if not InventoryHasItem(ingredientItem, requiredAmount) then
                    hasIngredients = false
                end
                table.insert(ingredientsText, requiredAmount .. 'x ' .. (Config.SurvivalItems[ingredientItem] and Config.SurvivalItems[ingredientItem].label or ingredientItem))
            end

            table.insert(recipes, {
                label = recipeData.label,
                description = 'ส่วนผสม: ' .. table.concat(ingredientsText, ', ') .. ' | ผลลัพธ์: ' .. recipeData.result_amount .. 'x ' .. (Config.SurvivalItems[recipeData.result_item] and Config.SurvivalItems[recipeData.result_item].label or recipeData.result_item),
                value = recipeId,
                disabled = not hasIngredients
            })
        end

        lib.menu.create({
            title = 'เลือกสิ่งที่ต้องการทำ',
            options = recipes,
            onSelect = function(selectedOption)
                local recipeId = selectedOption.value
                TriggerServerEvent('sa_survival:server:startCrafting', recipeId)
            end,
            onCancel = function()
                lib_notify({ title = 'ยกเลิก', description = 'ยกเลิกการทำอาหาร/กรองน้ำ', type = 'info' })
            end
        })
    end)

    RegisterNetEvent('sa_survival:client:startRestingInteraction')
    AddEventHandler('sa_survival:client:startRestingInteraction', function(data)
        local sleepLocationId = data.item_id

        local ped = PlayerPedId()
        if ped == 0 then return end
        local isBusy = ped.state['player:is_busy'] or false
        if isBusy then
            lib_notify({ title = 'กำลังดำเนินการ', description = 'คุณกำลังทำกิจกรรมอื่นอยู่', type = 'warning' })
            return
        end

        local pointData = Config.Resting.SleepLocations[sleepLocationId]
        if not pointData then
            lib_notify({ title = 'ข้อผิดพลาด', description = 'ข้อมูลจุดพักผ่อนไม่ถูกต้อง', type = 'error' })
            return
        end

        SetPlayerBusy(source, true)

        lib.menu.create({
            title = 'นอนหลับพักผ่อน',
            options = {
                {
                    label = '5 วินาที',
                    value = 5000,
                    description = 'พักผ่อนเล็กน้อย',
                },
                {
                    label = '10 วินาที',
                    value = 10000,
                    description = 'พักผ่อนปานกลาง',
                },
                {
                    label = '20 วินาที',
                    value = 20000,
                    description = 'พักผ่อนนานขึ้น',
                },
                {
                    label = '30 วินาที',
                    value = 30000,
                    description = 'พักผ่อนอย่างเต็มที่',
                },
            },
            onSelect = function(selectedOption)
                local duration = selectedOption.value

                if pointData.animation then
                    PlayAnimation(pointData.animation.dict, pointData.animation.name, -1, 8.0, 8.0, 49)
                elseif pointData.type == 'bed' then
                    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_SLEEP_BED', 0, true)
                end

                lib_progressBar({
                    duration = duration,
                    label = 'กำลังนอนหลับ...',
                    use: Current Weapon = false,
                    disable: All Controls = true,
                    onComplete = function()
                        ClearPedTasksImmediately(ped)
                        TriggerServerEvent('sa_survival:server:startResting', duration)
                        SetPlayerBusy(source, false)
                    end,
                    onCancel = function()
                        ClearPedTasksImmediately(ped)
                        lib_notify({ title = 'ถูกยกเลิก', description = 'การนอนหลับถูกยกเลิก', type = 'error' })
                        SetPlayerBusy(source, false)
                        TriggerServerEvent('sa_survival:server:cancelBusyState')
                    end
                })
            end,
            onCancel = function()
                SetPlayerBusy(source, false)
            end
        })
    end)
end)