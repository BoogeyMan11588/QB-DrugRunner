local QBCore = exports['qb-core']:GetCoreObject()
local playerCooldowns = {}

-- Function to load and decode version.json
local function GetVersionData()
    local resourceName = GetCurrentResourceName()
    local versionFile = LoadResourceFile(resourceName, "version.json")
    if versionFile then
        local success, data = pcall(json.decode, versionFile)
        if success and data then
            return data
        else
            print("^1[RUNNER] Error decoding version.json: " .. (data or "Unknown error") .. "^7")
            return nil
        end
    else
        print("^1[RUNNER] Error loading version.json^7")
        return nil
    end
end

-- Get version data and set currentVersion
local versionData = GetVersionData()
local currentVersion = versionData and versionData.version or "unknown"


-- Function to check version against GitHub
local function CheckVersion()
    -- Updated URL to match your repository structure
    local url = 'https://raw.githubusercontent.com/BoogeyMan11588/QB-DrugRunner/main/version.json'
    
    PerformHttpRequest(url, function(err, text, headers)
        if err ~= 200 then
            print('^1[RUNNER] Failed to check for updates (Error Code: ' .. tostring(err) .. ')^7')
            return
        end
        
        local success, data = pcall(function() return json.decode(text) end)
        if not success or not data then
            print('^1[RUNNER] Failed to parse version data^7')
            return
        end
        
        if data.version ~= currentVersion then
            print('^3───────────────────────────────────────────────────^7')
            print('^3              DRUG RUNNER UPDATE AVAILABLE         ^7')
            print('^3───────────────────────────────────────────────────^7')
            print('^3^7 Current Version: ^1' .. currentVersion .. '^7')
            print('^3^7 Latest Version: ^2' .. data.version .. '^7')
            print('^3^7 Changes in latest version:^7')
            for _, change in ipairs(data.changelog or {"No changelog provided."}) do
                print('^3^7 * ' .. change)
            end
            print('^3^7 Download: https://github.com/BoogeyMan11588/QB-DrugRunner')
        else
            print('^2[RUNNER]^7 You are running the latest version!')
        end
    end, 'GET', '', {['User-Agent'] = 'QB-DrugRunner Version Checker'})
end

-- Print banner and check version on resource start
CreateThread(function()
    print([[
┌─────────────────────────────────┐
│       D R U G R U N N E R       │
└─────────────────────────────────┘
    Drug Run Script - v]] .. currentVersion .. [[
    Server-side initialized
    ]])
    
    Wait(2000) -- Wait 2 seconds before checking version
    CheckVersion()
end)

-- Get number of police online
QBCore.Functions.CreateCallback('qb-drugrun:server:getCops', function(source, cb)
    local cops = 0
    local players = QBCore.Functions.GetQBPlayers()
    
    for _, v in pairs(players) do
        if v.PlayerData.job.name == "police" and v.PlayerData.job.onduty then
            cops = cops + 1
        end
    end
    cb(cops)
end)

-- Start run event - only verify drugs, don't remove them
RegisterNetEvent('qb-drugrun:server:startRun', function(drugType, amount)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local drugData = Config.Drugs[drugType]
    if not drugData then return end

    -- Verify they have the drugs
    local item = Player.Functions.GetItemByName(drugData.itemName)
    if not item or item.amount < amount then
        TriggerClientEvent('QBCore:Notify', src, 'You don\'t have enough ' .. drugData.label, 'error')
        return
    end

    -- Notify run start
    TriggerClientEvent('QBCore:Notify', src, 'Drug run started with ' .. drugData.label, 'success')
end)

-- Complete run event - handle drug removal and payment here
RegisterNetEvent('qb-drugrun:server:completedRun', function(currentRun)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Check cooldown
    local playerIdentifier = Player.PlayerData.citizenid
    if playerCooldowns[playerIdentifier] and (os.time() - playerCooldowns[playerIdentifier]) < 300 then
        TriggerClientEvent('QBCore:Notify', src, 'You need to wait before doing another run', 'error')
        return
    end

    -- Verify they still have the drugs
    local drugData = Config.Drugs[currentRun.drugType]
    local item = Player.Functions.GetItemByName(drugData.itemName)
    
    if not item or item.amount < currentRun.amount then
        TriggerClientEvent('QBCore:Notify', src, 'Nice try, but where are the drugs?', 'error')
        return
    end

    -- Remove drugs and give payment only on successful delivery
    Player.Functions.RemoveItem(drugData.itemName, currentRun.amount)
    TriggerClientEvent('inventory:client:ItemBox', src, QBCore.Shared.Items[drugData.itemName], "remove")

    -- Calculate and give payment
    local price = math.random(drugData.minPrice, drugData.maxPrice)
    local totalPrice = currentRun.amount * price
    
    Player.Functions.AddMoney('cash', totalPrice)
    
    -- Success notification
    TriggerClientEvent('QBCore:Notify', src, string.format('Delivery completed!\nAmount: %dx %s\nPayment: $%d', 
        currentRun.amount, 
        drugData.label, 
        totalPrice
    ), 'success')
    
    -- Set cooldown
    playerCooldowns[playerIdentifier] = os.time()
end)

-- Optional: Add cooldown cleanup
CreateThread(function()
    while true do
        Wait(300000) -- Clean up every 5 minutes
        local currentTime = os.time()
        for identifier, lastRun in pairs(playerCooldowns) do
            if (currentTime - lastRun) > 300 then -- 5 minute cooldown
                playerCooldowns[identifier] = nil
            end
        end
    end
end)
-- Add cooldown check callback
QBCore.Functions.CreateCallback('qb-drugrun:server:checkCooldown', function(source, cb)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local playerIdentifier = Player.PlayerData.citizenid
    
    if playerCooldowns[playerIdentifier] and (os.time() - playerCooldowns[playerIdentifier]) < 300 then
        -- Player is on cooldown
        local remainingTime = 300 - (os.time() - playerCooldowns[playerIdentifier])
        cb(false, remainingTime)
    else
        -- Player is not on cooldown
        cb(true, 0)
    end
end)

QBCore.Functions.CreateCallback('qb-drugrun:server:checkPoliceNearby', function(source, cb, coords)
    local policeNearby = false
    local players = QBCore.Functions.GetPlayers()
    
    for _, playerId in ipairs(players) do
        local Player = QBCore.Functions.GetPlayer(playerId)
        if Player and Player.PlayerData.job.name == "police" and Player.PlayerData.job.onduty then
            local ped = GetPlayerPed(playerId)
            local policeCoords = GetEntityCoords(ped)
            local distance = #(vector3(coords.x, coords.y, coords.z) - policeCoords)
            
            if distance <= 50.0 then -- 50.0 unit radius, adjust as needed
                policeNearby = true
                break
            end
        end
    end
    
    cb(policeNearby)
end)

-- Optional: Add anti-exploit check
RegisterNetEvent('qb-drugrun:server:validateRun', function(coords)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    -- Get player's current position
    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)

    -- Check if player is too far from reported coords (potential teleport/cheating)
    if #(playerCoords - coords) > 10.0 then
        print(string.format("^1[RUNNER]^7 Potential cheater detected: %s (ID: %s)", 
            Player.PlayerData.name, 
            Player.PlayerData.citizenid
        ))
        -- You can add additional anti-cheat measures here
    end
end)

-- Optional: Add server-side debug command
QBCore.Commands.Add('runnerinfo', 'Check drug runner info (Admin Only)', {}, false, function(source)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if Player.PlayerData.job.grade.level >= 4 then -- Adjust admin level as needed
        local numCooldowns = 0
        for _ in pairs(playerCooldowns) do numCooldowns = numCooldowns + 1 end
        
        TriggerClientEvent('QBCore:Notify', src, string.format(
            'Runner Info:\nActive Cooldowns: %d\nConfig Drugs: %d\nDelivery Locations: %d', 
            numCooldowns, 
            #Config.Drugs, 
            #Config.DeliveryLocations
        ), 'primary')
    end
end, 'admin')
