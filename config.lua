-- sa_survival/config.lua

Config = {}

-- [[ ค่าเริ่มต้นและสูงสุดของสถานะต่างๆ ]]
Config.MaxHunger     = 1000000
Config.MinHunger     = 0
Config.MaxThirst     = 1000000
Config.MinThirst     = 0
Config.MaxFatigue    = 1000000
Config.MinFatigue    = 0
Config.MaxBladder    = 1000000
Config.MinBladder    = 0
Config.MaxBowel      = 1000000
Config.MinBowel      = 0
Config.MaxRadiation  = 1000000
Config.MinRadiation  = 0
Config.MaxStress     = 1000000
Config.MinStress     = 0
Config.MaxImmunity   = 100
Config.MinImmunity   = 0
Config.MaxWetness    = 100
Config.MinWetness    = 0

Config.NormalBodyTemp = 37.0
Config.MinBodyTemp    = 30.0
Config.MaxBodyTemp    = 42.0

-- [[ อัตราการเปลี่ยนแปลงสถานะ (Decay/Regen) ]]
Config.MainTickInterval = 5000 -- รอบการทำงานของ Main Server Tick (5000 ms = 5 วินาที)

-- อัตราการลดลงต่อ MainTickInterval (สำหรับสถานะที่ลดลง)
Config.HungerDecayRate    = 500
Config.ThirstDecayRate    = 800

-- อัตราการเพิ่มขึ้นต่อ MainTickInterval (สำหรับสถานะที่เพิ่มขึ้นเอง)
Config.FatigueIncreaseRate = 100
Config.BladderIncreaseRate = 150
Config.BowelIncreaseRate   = 70

-- อัตราการลดลงแบบ Passive (สำหรับรังสีและความเครียด)
Config.PassiveRadiationDecay = 50
Config.PassiveStressDecay    = 100

-- อัตราการฟื้นฟู/ลดภูมิคุ้มกัน
Config.ImmunityRegenRate = 1
Config.ImmunityDecayRate = 0.5

-- [[ ผลกระทบเบื้องต้นจากสถานะวิกฤต ]]
Config.DamageOnCriticalHunger = 1
Config.DamageOnCriticalThirst = 1
Config.HungerCriticalThreshold = 0.1
Config.ThirstCriticalThreshold = 0.1

-- [[ การตั้งค่าสำหรับ Bladder & Bowel ]]
Config.Bladder = {
    FullThreshold = 900000,
    CriticalThreshold = 980000,
    MoveRatePenalty = 0.1,
    DamagePerTick = 0.5
}

Config.Bowel = {
    FullThreshold = 900000,
    CriticalThreshold = 980000,
    MoveRatePenalty = 0.15,
    DamagePerTick = 0.7
}

-- [[ การตั้งค่าสำหรับระบบการพักผ่อน (Resting/Sleeping) ]]
Config.Resting = {
    DurationPerSleepTick = 1000,
    FatigueHealRate = 15000,
    HungerIncreaseRate = 1000,
    ThirstIncreaseRate = 1500,
    StressHealRate = 5000,
    MinSleepDuration = 5,
    MaxSleepDuration = 30,
    SleepLocations = {
        ['bed_1'] = {coords = vector3(100.0, 300.0, 50.0), heading = 0.0, type = 'bed', message = 'กด [E] เพื่อนอนหลับ', animation = {dict = 'WORLD_HUMAN_SLEEP_BED', name = 'WORLD_HUMAN_SLEEP_BED'}},
        ['sleeping_bag_1'] = {coords = vector3(120.0, 320.0, 50.0), heading = 90.0, type = 'sleeping_bag', message = 'กด [E] เพื่อนอนหลับ', animation = {dict = 'misssolow_1', name = 'solo_mid_sleeping'}}
    }
}

-- [[ การตั้งค่าสำหรับ Health Impacts ]]
Config.Sickness = {
    ChanceFromDirtyWater = 0.3,
    ChanceFromRottenFood = 0.5,
    ChanceFromLowImmunity = 0.05,
    ImmunityThresholdForSickness = 20,
    InitialDuration = 300,
    DamagePerTick = 0.5,
    MoveRatePenalty = 0.1,
    VomitChance = 0.1, -- โอกาสอาเจียนเมื่อป่วย (Client-side)
    CoughChance = 0.2 -- โอกาสไอเมื่อป่วย (Client-side)
}

Config.Injuries = {
    FallDamageMinHeight = 5.0,
    ChanceBrokenLegFromFall = 0.2,
    ChanceBleedingFromFall = 0.3,
    BulletWoundBleedChance = 0.8,
    MeleeWoundBleedChance = 0.5,
    BleedingDamagePerTick = 1,
    BrokenLegMoveRatePenalty = 0.7,
    BrokenLegArmourPenalty = 0.5,
    BrokenArmChance = 0.1, -- โอกาสแขนหัก
    HeadInjuryChance = 0.05, -- โอกาสบาดเจ็บศีรษะ
    HeadInjuryScreenEffect = 'Drunk', -- เอฟเฟกต์หน้าจอเมื่อบาดเจ็บศีรษะ
    BrokenArmAnim = {dict = 'missmic5_3_ext_m_p2', name = 'broken_arm_idle'} -- ตัวอย่าง Animation แขนหัก
}

Config.Stress = {
    DarknessIncreaseRate = 20,
    IsolationIncreaseRate = 10,
    CombatIncreaseRate = 50, -- เพิ่มความเครียด 50 หน่วยต่อ Tick เมื่ออยู่ในสถานการณ์ต่อสู้
    CombatStressRadius = 50.0, -- รัศมีที่ถือว่าอยู่ในสถานการณ์ต่อสู้
    PassiveDecayInShelter = 200,
    ShakeCameraOnAnxiety = 0.2,
    ShakeCameraOnPanicAttack = 0.5,
    ScreenEffectOnPanicAttack = 'ChopVision'
}

-- [[ การตั้งค่าสำหรับ Environment Zones ]]
Config.Radiation = {
    DamageThreshold = 0.7, -- รังสีถึง 70% ของ MaxRadiation จะเริ่มลดเลือด
    DamagePerTick = 2, -- ลดเลือด 2 หน่วยเมื่อได้รับรังสีสูง
    ImmunityDecayRate = 0.5 -- ลดภูมิคุ้มกันเมื่อได้รับรังสี
}

Config.Toxic = {
    DamagePerTick = 1, -- ลดเลือด 1 หน่วยต่อ Tick เมื่อถูกพิษ
    ScreenEffect = 'ChopVision'
}

Config.Temperature = {
    HypothermiaDamagePerTick = 1,
    HeatstrokeDamagePerTick = 1,
    HypothermiaMovePenalty = 0.7,
    HeatstrokeMovePenalty = 0.7,
    HypothermiaScreenEffect = 'Cold',
    HeatstrokeScreenEffect = 'Heat'
}

-- [[ ข้อมูลไอเท็ม Survival ]]
Config.SurvivalItems = {
    ['water_bottle'] = {
        label = 'ขวดน้ำ',
        effect = {
            thirst = 300000
        },
        animation = {dict = 'mp_player_intdrink@backward', name = 'loop'},
        duration = 2000,
        hotkey = 191 -- F10
    },
    ['canned_food'] = {
        label = 'อาหารกระป๋อง',
        effect = {
            hunger = 400000
        },
        animation = {dict = 'mp_player_int_uppers@eat', name = 'eat'},
        duration = 2000,
        hotkey = 190 -- F9
    },
    ['bandages'] = {
        label = 'ผ้าพันแผล',
        effect = {
            clear_status = 'Bleeding',
            health_regen = 10
        },
        animation = {dict = 'amb@medic@standing@kneel@base', name = 'base'},
        duration = 3000,
        hotkey = 189 -- F8
    },
    ['painkillers'] = {
        label = 'ยาแก้ปวด',
        effect = {
            clear_status = 'Anxiety',
            clear_status_2 = 'PanicAttack'
        },
        animation = {dict = 'base@generic@tablet', name = 'use'},
        duration = 1500,
        hotkey = 188 -- F7
    },
    ['antirad'] = {
        label = 'ยาต้านรังสี',
        effect = {
            radiation_decrease = 500000
        },
        animation = {dict = 'base@generic@tablet', name = 'use'},
        duration = 1500,
        hotkey = 187 -- F6
    },
    ['dirty_water'] = {
        label = 'น้ำสกปรก',
        effect = {
            thirst = 100000,
            add_status = {name = 'Sick', duration = 300, cause = 'dirty_water'}
        },
        animation = {dict = 'mp_player_intdrink@backward', name = 'loop'},
        duration = 2000
    },
    ['berries'] = {
        label = 'เบอร์รี่',
        effect = {
            hunger = 50000
        },
        animation = {dict = 'mp_player_int_uppers@eat', name = 'eat'},
        duration = 1500
    },
    ['purified_water'] = {
        label = 'น้ำสะอาด',
        effect = {
            thirst = 500000
        },
        animation = {dict = 'mp_player_intdrink@backward', name = 'loop'},
        duration = 2000
    },
    ['cooked_meat'] = {
        label = 'เนื้อสุก',
        effect = {
            hunger = 600000
        },
        animation = {dict = 'mp_player_int_uppers@eat', name = 'eat'},
        duration = 2000
    },
    ['purification_tablet'] = {
        label = 'เม็ดกรองน้ำ',
    },
    ['raw_meat'] = {
        label = 'เนื้อดิบ',
        effect = {
            add_status = {name = 'Sick', duration = 600, cause = 'rotten_food'}
        }
    },
    ['splint'] = {
        label = 'เฝือก',
        effect = {
            clear_status = 'BrokenLeg',
            clear_status_2 = 'BrokenArm'
        },
        animation = {dict = 'amb@medic@standing@kneel@base', name = 'base'},
        duration = 4000
    },
    ['antidote'] = {
        label = 'ยาแก้พิษ',
        effect = {
            clear_status = 'Poisoned',
            clear_status_2 = 'Sick' -- อาจจะรักษาอาการป่วยบางชนิด
        },
        animation = {dict = 'base@generic@tablet', name = 'use'},
        duration = 1500
    }
}

-- [[ จุดโต้ตอบในโลก (Interaction Points) ]]
Config.InteractionPoints = {
    ['berry_bush_1'] = {
        coords = vector3(100.0, 200.0, 30.0),
        radius = 2.0,
        label = 'พุ่มเบอร์รี่',
        item_gain = 'berries',
        amount = 3,
        message = 'เก็บเบอร์รี่',
        animation = {dict = 'world_human_gardener', name = 'plant_pot'},
        duration = 3000,
        type = 'collect_item'
    },
    ['water_source_1'] = {
        coords = vector3(150.0, 250.0, 40.0),
        radius = 3.0,
        label = 'แหล่งน้ำ',
        item_gain = 'dirty_water',
        amount = 1,
        message = 'ตักน้ำสกปรก',
        animation = {dict = 'amb@world_human_gardener@female@base', name = 'base_r_2_to_c_r_2'},
        duration = 4000,
        type = 'collect_item'
    }
}

-- [[ การตั้งค่าสำหรับ Bladder & Bowel Excretion Locations ]]
Config.Excretion = {
    ExcreteLocations = {
        ['toilet_1'] = {coords = vector3(200.0, 50.0, 70.0), radius = 1.5, message = 'ใช้ห้องน้ำ', type = 'toilet', animation = {dict = 'amb@world_human_toilet', name = 'male_a_loop'}, duration = 5000},
        ['bush_excrete_1'] = {coords = vector3(210.0, 55.0, 70.0), radius = 2.0, message = 'ขับถ่ายในพุ่มไม้', type = 'bush', animation = {dict = 'amb@world_human_gardener@female@base', name = 'base_r_2_to_c_r_2'}, duration = 4000}
    }
}

-- [[ การตั้งค่าสำหรับระบบ Crafting/Processing ]]
Config.Crafting = {
    Recipes = {
        ['purify_water'] = {
            label = 'กรองน้ำสกปรก',
            ingredients = {
                ['dirty_water'] = 1,
                ['purification_tablet'] = 1
            },
            result_item = 'purified_water',
            result_amount = 1,
            duration = 5000,
            animation = {dict = 'amb@world_human_device@female@idle_a', name = 'idle_b'},
            success_message = 'คุณกรองน้ำจนสะอาดแล้ว!',
            fail_message = 'การกรองน้ำล้มเหลว',
        },
        ['cook_meat'] = {
            label = 'ทำอาหาร (เนื้อดิบ)',
            ingredients = {
                ['raw_meat'] = 1,
                -- ['wood'] = 1
            },
            result_item = 'cooked_meat',
            result_amount = 1,
            duration = 8000,
            animation = {dict = 'anim_amb_fire', name = 'fire_look_at'},
            success_message = 'คุณทำอาหารเสร็จแล้ว!',
            fail_message = 'อาหารไหม้!',
        }
    },
    CraftingLocations = {
        ['campfire_1'] = {coords = vector3(170.0, 350.0, 60.0), radius = 3.0, message = 'ทำอาหาร/กรองน้ำ', type = 'campfire'},
        ['stove_1'] = {coords = vector3(180.0, 360.0, 60.0), radius = 2.0, message = 'ทำอาหาร/กรองน้ำ', type = 'stove'}
    }
}

-- [[ การตั้งค่าสำหรับ Environment Zones ]]
Config.Zones = {
    RadiationZones = {
        {coords = vector3(200.0, 100.0, 30.0), radius = 50.0},
        {coords = vector3(-500.0, 2000.0, 100.0), radius = 100.0}
    },
    ToxicZones = {
        {coords = vector3(100.0, 0.0, 20.0), radius = 30.0}
    }
}
Config.CombatDetection = {
    NPCRadius = 30.0, -- รัศมีที่ถือว่ามี NPC อยู่รอบๆ
    PlayerRadius = 50.0, -- รัศมีที่ถือว่ามีผู้เล่นคนอื่นอยู่รอบๆ
    NPCRelationship = 255 -- HOSTILE = 5, NEUTRAL = 255 (ปรับตามต้องการ)
}

-- Export Config เพื่อให้ Sub-Systems เข้าถึงได้
exports('GetConfig', function()
    return Config
end)