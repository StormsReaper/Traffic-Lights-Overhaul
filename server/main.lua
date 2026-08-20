CreateThread(function()
    print('^2[TLO]^7 Traffic Lights Overhaul v0.1.0 started.')
    print('^2[TLO]^7 Client-side signal discovery and emergency preemption enabled.')
end)

RegisterCommand('tlo_status', function(source)
    if source == 0 then
        print('[TLO] The controller runs client-side. Use /tlo_debug in-game for local diagnostics.')
        return
    end

    TriggerClientEvent('chat:addMessage', source, {
        color = { 255, 200, 0 },
        args = { 'Traffic Lights Overhaul', 'Controller active. Use /tlo_debug to toggle local diagnostics.' }
    })
end, false)
