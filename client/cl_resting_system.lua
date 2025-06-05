-- sa_survival/client/resting_system/cl_resting_system.lua

-- Caching exports และ Config
local GetConfig = exports['sa_survival']:GetConfig
local Config = GetConfig()
local PlayAnimation = exports['sa_survival']:PlayAnimation
local SetPlayerBusy = exports['sa_survival']:SetPlayerBusy

-- Caching lib.notify และ lib.progressBar
local lib_notify = lib.notify
local lib_progressBar = lib.progressBar

-- ตัวแปร Local สำหรับ Native Functions ที่ใช้บ่อย
local PlayerPedId = PlayerPedId
local GetEntityCoords = GetEntityCoords
local GetDistanceBetweenCoords = GetDistanceBetweenCoords
local IsControlJustReleased = IsControlJustReleased
local TaskStartScenarioInPlace = TaskStartScenarioInPlace -- สำหรับ Animation ทั่วไป
local ClearPedTasksImmediately = ClearPedTasksImmediately

-- [[ Logic สำหรับการโต้ตอบกับจุดพักผ่อนโดยใช้ ox_target ]]
Citizen.CreateThread(function()
    -- เพิ่มจุดพักผ่อนเข้าไปใน ox_target
    local restTargetOptions = {}
    for id, point in pairs(Config.Resting.SleepLocations) do
        table.insert(restTargetOptions, {
            name = id,
            coords = point.coords,
            radius = 2.0, -- รัศมีการโต้ตอบ
            options = {
                {
                    event = 'sa_survival:client:startRestingInteraction', -- Event ใหม่สำหรับการพักผ่อน
                    icon = 'fas fa-bed', -- ไอคอนเตียง
                    label = point.message,
                    item_id = id,
                    distance = 2.0
                }
            }
        })
    end
    lib.addPointTargets(restTargetOptions)

    -- Register the event that will be triggered by ox_target for resting
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

        SetPlayerBusy(source, true) -- ตั้งให้ busy ชั่วคราวบน client

        -- ถามผู้เล่นว่าจะนอนนานแค่ไหน (ตัวอย่าง: ให้เลือก 5, 10, 20, 30 วินาที)
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

                -- เล่น Animation การนอนหลับ (ถ้าเป็นเตียง ใช้วิธี TaskStartScenarioInPlace)
                if pointData.type == 'bed' then
                    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_SLEEP_BED', 0, true)
                elseif pointData.type == 'sleeping_bag' then
                    -- อาจจะใช้ TaskStartScenarioInPlace('WORLD_HUMAN_SLEEP_TENT_GUY') หรือ PlayAnimation
                    PlayAnimation('misssolow_1', 'solo_mid_sleeping', -1, 8.0, 8.0, 49) -- ตัวอย่าง Animation ถุงนอน
                end

                lib_progressBar({
                    duration = duration,
                    label = 'กำลังนอนหลับ...',
                    use: Current Weapon = false,
                    disable: All Controls = true,
                    onComplete = function()
                        ClearPedTasksImmediately(ped) -- หยุด Animation
                        TriggerServerEvent('sa_survival:server:startResting', duration) -- ส่งระยะเวลาไป Server
                        SetPlayerBusy(source, false)
                    end,
                    onCancel = function()
                        ClearPedTasksImmediately(ped) -- หยุด Animation
                        lib_notify({ title = 'ถูกยกเลิก', description = 'การนอนหลับถูกยกเลิก', type = 'error' })
                        SetPlayerBusy(source, false)
                        TriggerServerEvent('sa_survival:server:cancelBusyState')
                    end
                })
            end,
            onCancel = function()
                SetPlayerBusy(source, false) -- ยกเลิก busy ถ้าผู้เล่นยกเลิกเมนู
            end
        })
    end)
end)