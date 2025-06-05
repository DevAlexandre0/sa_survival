-- sa_survival/server/resting_system/sv_resting_system.lua

-- Caching exports และ Config
local GetConfig = exports['sa_survival']:GetConfig
local Config = GetConfig()

-- Caching lib.notify
local lib_notify = lib.notify

-- ตัวแปร Local สำหรับ Native Functions ที่ใช้บ่อยบน Server
local GetPlayerPed = GetPlayerPed
local DoesEntityExist = DoesEntityExist

-- Event สำหรับรับคำสั่งการเริ่มพักผ่อนจาก Client
RegisterNetEvent('sa_survival:server:startResting')
AddEventHandler('sa_survival:server:startResting', function(duration)
    local src = source
    local playerPed = GetPlayerPed(src)
    if not playerPed or not DoesEntityExist(playerPed) then
        lib_notify({ source = src, title = 'ข้อผิดพลาด', description = 'ไม่สามารถเริ่มพักผ่อนได้', type = 'error' })
        return
    end

    if playerPed.state['player:is_busy'] then
        lib_notify({ source = src, title = 'กำลังดำเนินการ', description = 'คุณกำลังทำกิจกรรมอื่นอยู่', type = 'warning' })
        return
    end

    duration = math.min(duration, Config.Resting.MaxSleepDuration * 1000)
    duration = math.max(duration, Config.Resting.MinSleepDuration * 1000)

    exports['sa_survival']:SetPlayerBusy(src, true)

    local sleepTicks = math.floor(duration / Config.Resting.DurationPerSleepTick)
    local currentTick = 0

    lib_notify({ source = src, title = 'พักผ่อน', description = 'คุณกำลังนอนหลับพักผ่อน...', type = 'info' })

    local sleepLoop = lib.callback.loop(Config.Resting.DurationPerSleepTick, function()
        currentTick = currentTick + 1
        if currentTick > sleepTicks then
            lib.callback.cancel(sleepLoop)
            exports['sa_survival']:SetPlayerBusy(src, false)
            lib_notify({ source = src, title = 'พักผ่อน', description = 'คุณตื่นขึ้นมาแล้ว รู้สึกสดชื่นขึ้น!', type = 'success' })
            return
        end

        local playerState = playerPed.state

        local newFatigue = math.max(Config.MinFatigue, playerState['player:fatigue'] - Config.Resting.FatigueHealRate)
        if playerState['player:fatigue'] ~= newFatigue then
            playerState:set('player:fatigue', newFatigue, true)
        end

        local newStress = math.max(Config.MinStress, playerState['player:stress'] - Config.Resting.StressHealRate)
        if playerState['player:stress'] ~= newStress then
            playerState:set('player:stress', newStress, true)
        end

        local newHunger = math.min(Config.MaxHunger, playerState['player:hunger'] + Config.Resting.HungerIncreaseRate)
        if playerState['player:hunger'] ~= newHunger then
            playerState:set('player:hunger', newHunger, true)
        end
        local newThirst = math.min(Config.MaxThirst, playerState['player:thirst'] + Config.Resting.ThirstIncreaseRate)
        if playerState['player:thirst'] ~= newThirst then
            playerState:set('player:thirst', newThirst, true)
        end

        if newFatigue <= Config.MinFatigue then
            lib.callback.cancel(sleepLoop)
            exports['sa_survival']:SetPlayerBusy(src, false)
            lib_notify({ source = src, title = 'พักผ่อน', description = 'คุณพักผ่อนเพียงพอแล้ว!', type = 'success' })
        end
    end)
end)