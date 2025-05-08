# runner
QB-Drug Running Script





# copy - paste into ps-dispatch/shared/config.lua
```
    ['drugtrafficking'] = {
        radius = 120.0,
        sprite = 469,
        color = 52,
        scale = 0,
        length = 2,
        sound = 'Lose_1st',
        sound2 = 'GTAO_FM_Events_Soundset',
        offset = true,
        flash = true
    },
```

# copy - paste into ps-dispatch/client/alerts.lua
```
    local function DrugTrafficking()
    local coords = GetEntityCoords(cache.ped)

    local dispatchData = {
        message = locale('drugtraff'),
        codeName = 'drugtrafficking',
        code = '10-13',
        icon = 'fas fa-tablets',
        priority = 2,
        coords = coords,
        gender = GetPlayerGender(),
        street = GetStreetAndZone(coords),
        alertTime = nil,
        jobs = { 'leo' }
    }

    TriggerServerEvent('ps-dispatch:server:notify', dispatchData)
end
exports('DrugTrafficking', DrugTrafficking)`
```
