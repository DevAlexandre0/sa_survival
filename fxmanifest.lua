-- my_survival_script/fxmanifest.lua
fx_version 'cerulean'
game 'gta5'

name 'My Survival Core'
author 'Your Name'
description 'Core systems for a comprehensive survival system using ox_lib State Bags.'
version '1.0.0'

dependencies {
    'es_extended',
    'ox_mysql',
    'ox_lib',
    'ox_target',
    'core_inventory' -- เพิ่ม core_inventory เป็น dependency
}

shared_scripts {
    '@es_extended/locale.lua',
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    'client/main.lua',
    'client/vitals_needs/cl_vitals_needs.lua',
    'client/health_impacts/cl_health_impacts.lua',
    'client/environment_zones/cl_environment_zones.lua',
    'client/item_interaction/cl_item_interaction.lua'
}

server_scripts {
    '@ox_mysql/lib/MySQL.lua',
    'server/sv_main.lua',
    'server/main_loop.lua',
    'server/player_data.lua',
    'server/vitals_needs/sv_vitals_needs.lua',
    'server/health_impacts/sv_health_impacts.lua',
    'server/environment_zones/sv_environment_zones.lua',
    'server/item_interaction/sv_item_interaction.lua'
}

exports {
    'GetConfig', -- สามารถ Export GetConfig จาก root ได้เลย
    'PlayAnimation',
    'ApplyScreenEffect',
    'StopScreenEffectClient'
}

server_exports {
    'ApplyStatusEffect',
    'ClearStatusEffect',
    'SetPlayerBusy',
    'ProcessPlayerSickness',
    'ProcessPlayerInjuries',
    'ProcessPlayerStress',
    'ProcessPlayerZones',
    'ProcessPlayerToxins',
    'ProcessPlayerRadiation',
    'ProcessPlayerTemperatureEffects'
}