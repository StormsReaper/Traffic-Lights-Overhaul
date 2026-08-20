fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'traffic-lights-overhaul'
author 'Storms Technologies'
description 'Realistic US-style traffic signal control with adaptive traffic, emergency preemption, pedestrians, coordination, lane analysis, and time-of-day operation.'
version '0.4.0-test'

client_scripts {
    'config.lua',
    'client/coordination.lua',
    'client/features.lua',
    'client/lane_analyzer.lua',
    'client/traffic_ai.lua',
    'client/debug.lua',
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'README.md'
}
