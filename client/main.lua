-- sa_survival/client/main.lua

-- ดึง Config ที่จำเป็น
local Config = exports['sa_survival']:GetConfig()

-- Caching lib.notify for client-side use
local lib_notify = lib.notify

-- [[ Animation & Screen Effect System (Client-side) ]]
---@param animDict string Animation dictionary (e.g., "amb@medic@standing@kneel@base")
---@param animName string Animation name (e.g., "base")
---@param duration number Duration in milliseconds. Use -1 for indefinite.
---@param blendIn number Blend in duration (ms)
---@param blendOut number Blend out duration (ms)
---@param flag number Animation flags (e.g., 49 for `2 + 16 + 32 = 49` which is `Loop + UpperBody + StopOnFinish`)
function PlayAnimation(animDict, animName, duration, blendIn, blendOut, flag)
    local ped = PlayerPedId()
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(0)
    end
    TaskPlayAnim(ped, animDict, animName, blendIn, blendOut, duration, flag, 0, false, false, false)
    RemoveAnimDict(animDict)

    if duration > 0 then
        lib.callback.timer(duration, function()
            StopAnimTask(ped, animDict, animName, 1.0)
        end)
    end
end
exports('PlayAnimation', PlayAnimation)

---@param effectName string Name of the screen effect (e.g., "Drunk", "ChopVision", "PeyoteOut")
---@param duration number Duration in milliseconds. Use -1 for indefinite.
function ApplyScreenEffect(effectName, duration)
    StartScreenEffect(effectName, duration, true)
end
exports('ApplyScreenEffect', ApplyScreenEffect)

---@param effectName string Name of the screen effect to stop
function StopScreenEffect(effectName)
    StopScreenEffect(effectName)
    StopGameplayCamShake(true) -- Stop camera shake
end
exports('StopScreenEffectClient', StopScreenEffect)

-- [[ Client-side State Bag Listeners (สำหรับทดสอบหรือ UI) ]]
Citizen.CreateThread(function()
    local playerPed = PlayerPedId()

    playerPed.state:on('player:hunger', function(key, value, oldValue)
        -- ในอนาคตจะส่งไป NUI เพื่ออัปเดต HUD
    end)

    playerPed.state:on('player:status:exhausted', function(key, value, oldValue)
        if value then
            lib_notify({ title = 'คุณรู้สึกเหนื่อยล้ามาก!', description = 'คุณเคลื่อนที่ช้าลงและมองเห็นไม่ชัดเจน', type = 'error' })
            ApplyScreenEffect('ChopVision', -1)
            ShakeGameplayCam('DRUNK_SHAKE', 1.0)
            -- SetPedMoveRateOverride ถูกจัดการใน UpdatePlayerMoveRate
        else
            lib_notify({ title = 'คุณหายเหนื่อยแล้ว!', description = 'กลับมาสดชื่นอีกครั้ง', type = 'success' })
            StopScreenEffectClient('ChopVision')
            StopGameplayCamShake(true)
            -- SetPedMoveRateOverride ถูกจัดการใน UpdatePlayerMoveRate
        end
        exports['sa_survival']:UpdatePlayerMoveRate() -- เรียกใช้ฟังก์ชันรวม
    end)
end)

-- Helper function สำหรับ DrawText3D (ถ้ายังต้องการใช้ในอนาคต)
local function DrawText3D(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(true)
    AddTextComponentString(text)
    SetDrawOrigin(x, y, z, 0)
    DrawText(0.0, 0.0)
    ClearDrawOrigin()
end