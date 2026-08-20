fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'traffic-lights-overhaul'
author 'Storms Technologies'
description 'Realistic US-style traffic signal control with emergency vehicle preemption.'
version '0.2.0'

client_scripts {
    'config.lua',
    'client/traffic_ai.lua',
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

files {
    'README.md'
}
