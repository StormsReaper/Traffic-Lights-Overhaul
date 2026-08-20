fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'traffic-lights-overhaul'
author 'Storms Technologies'
description 'Realistic US-style traffic signal control with adaptive traffic, emergency preemption, pedestrians, coordination, and time-of-day operation.'
version '0.3.0'

client_scripts {
    'config.lua',
    'client/coordination.lua',
    'client/features.lua',
    'client/traffic_ai.lua',
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'README.md'
}
