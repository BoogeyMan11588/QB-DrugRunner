local QBCore = exports['qb-core']:GetCoreObject()
local currentDealer = nil
local currentDelivery = nil
local deliveryBlip = nil
local isOnRun = false
local dealerPeds = {}
local currentRun = nil

-- Debug: Validate ped models
local function ValidatePedModels()
    for _, dealer in pairs(Config.Dealers) do
        local model = GetHashKey(dealer.ped.model)
        if not IsModelInCdimage(model) then
            print("^1[RUNNER]^7 Invalid ped model: " .. dealer.ped.model)
            return false
        end
    end
    return true
end

-- Debug: Validate coordinates
local function ValidateCoordinates()
    for _, dealer in pairs(Config.Dealers) do
        if not dealer.coords or 
           not dealer.coords.x or 
           not dealer.coords.y or 
           not dealer.coords.z or 
           not dealer.coords.w then
            print("^1[RUNNER]^7 Invalid coordinates for dealer: " .. dealer.name)
            return false
        end
    end
    return true
end

-- Function to load dealer model
local function LoadDealerModel(model)
    print("^2[RUNNER]^7 Loading model: " .. model)
    RequestModel(model)
    local timeout = 0
    while not HasModelLoaded(model) do
        Wait(50)
        timeout = timeout + 1
        if timeout > 100 then
            print("^1[RUNNER]^7 Model load timeout: " .. model)
            break
        end
    end
    if HasModelLoaded(model) then
        print("^2[RUNNER]^7 Model loaded successfully: " .. model)
    end
end

-- Function to create dealer peds
local function CreateDealerPeds()
    print("^2[RUNNER]^7 Starting to create dealer peds")
    for k, v in pairs(Config.Dealers) do
        if v.ped then
            print("^2[RUNNER]^7 Creating dealer: " .. v.name)
            local modelHash = GetHashKey(v.ped.model)
            LoadDealerModel(modelHash)
            print("^2[RUNNER]^7 Spawning ped at coords: x:" .. v.coords.x .. " y:" .. v.coords.y .. " z:" .. v.coords.z)
            local ped = CreatePed(4, modelHash, v.coords.x, v.coords.y, v.coords.z - 1.0, v.coords.w, false, true)
            if DoesEntityExist(ped) then
                print("^2[RUNNER]^7 Ped created successfully for: " .. v.name)
                SetEntityHeading(ped, v.coords.w)
                FreezeEntityPosition(ped, true)
                SetEntityInvincible(ped, true)
                SetBlockingOfNonTemporaryEvents(ped, true)
                if v.ped.scenario then
                    TaskStartScenarioInPlace(ped, v.ped.scenario, 0, true)
                end
                exports['qb-target']:AddTargetEntity(ped, {
                    options = {
                        {
                            type = "client",
                            event = "qb-drugrun:client:startRun",
                            icon = "fas fa-cannabis",
                            label = "Start Drug Run",
                        }
                    },
                    distance = 2.0
                })
                dealerPeds[k] = ped
            else
                print("^1[RUNNER]^7 Failed to create ped for: " .. v.name)
            end
        end
    end
    print("^2[RUNNER]^7 Finished creating dealer peds")
end

-- Function to create dealer blips
local function CreateDealerBlips()
    for k, v in pairs(Config.Dealers) do
        if v.blip then
            local blip = AddBlipForCoord(v.coords.x, v.coords.y, v.coords.z)
            SetBlipSprite(blip, 140)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, 0.8)
            SetBlipAsShortRange(blip, true)
            SetBlipColour(blip, 2)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName("Drug Dealer")
            EndTextCommandSetBlipName(blip)
        end
    end
end

-- Function to check available drugs
local function GetAvailableDrugs()
    local availableDrugs = {}
    local Player = QBCore.Functions.GetPlayerData()
    
    for drugType, drugData in pairs(Config.Drugs) do
        local hasItem = QBCore.Functions.HasItem(drugData.itemName)
        if hasItem then
            -- Get the actual item data to access the amount
            for _, item in pairs(Player.items) do
                if item and item.name == drugData.itemName then
                    availableDrugs[drugType] = item.amount
                    break
                end
            end
        end
    end
    return availableDrugs
end

-- Custom PS-Dispatch alert
local function AlertPolice()  
    exports['ps-dispatch']:DrugTrafficking()
end

-- Function to start drug run
local function StartDrugRun()
    if isOnRun then 
        QBCore.Functions.Notify('You\'re already on a run!', 'error')
        return 
    end

    -- Check cooldown first
    QBCore.Functions.TriggerCallback('qb-drugrun:server:checkCooldown', function(canStart, remainingTime)
        if not canStart then
            local minutes = math.floor(remainingTime / 60)
            local seconds = remainingTime % 60
            QBCore.Functions.Notify(string.format('You need to wait %d:%02d minutes before starting another run', minutes, seconds), 'error')
            return
        end
        
        -- Continue with run if not on cooldown
        local availableDrugs = GetAvailableDrugs()
        if next(availableDrugs) == nil then
            QBCore.Functions.Notify('You don\'t have any drugs to deliver!', 'error')
            return
        end
        
        local drugMenu = {
            {
                header = "Choose Drug to Deliver",
                isMenuHeader = true
            }
        }
        
        for drugType, amount in pairs(availableDrugs) do
            table.insert(drugMenu, {
                header = Config.Drugs[drugType].label,
                txt = "Amount Available: " .. amount,
                params = {
                    event = "qb-drugrun:client:confirmRun",
                    args = {
                        drugType = drugType,
                        amount = amount
                    }
                }
            })
        end
        
        exports['qb-menu']:openMenu(drugMenu)
    end)
end

-- Initialization
CreateThread(function()
    while not QBCore do
        Wait(100)
    end
    print("^2[RUNNER]^7 Resource starting...")
    if not ValidatePedModels() then
        print("^1[RUNNER]^7 One or more ped models are invalid! Check your config.")
        return
    end
    if not ValidateCoordinates() then
        print("^1[RUNNER]^7 One or more dealer coordinates are invalid! Check your config.")
        return
    end
    CreateDealerPeds()
    CreateDealerBlips()
    print("^2[RUNNER]^7 Resource started successfully")
end)

-- Check delivery zone
CreateThread(function()
    while true do
        Wait(1000)
        if isOnRun and currentDelivery and currentRun then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local dist = #(pos - vector3(currentDelivery.x, currentDelivery.y, currentDelivery.z))
            
            -- Check if player still has the drugs
            local hasDrugs = QBCore.Functions.HasItem(Config.Drugs[currentRun.drugType].itemName)
            if not hasDrugs then
                QBCore.Functions.Notify('You lost the drugs! Run cancelled.', 'error')
                RemoveBlip(deliveryBlip)
                currentDelivery = nil
                currentRun = nil
                isOnRun = false
                return
            end

            if dist < 5.0 then
                -- Trigger server-side police check
                QBCore.Functions.TriggerCallback('qb-drugrun:server:checkPoliceNearby', function(policeNearby)
                    if policeNearby then
                        QBCore.Functions.Notify('Lose the police, you can\'t drop with them on you!', 'error')
                        Wait(3000) -- Cooldown before next check
                    else
                        TriggerServerEvent('qb-drugrun:server:completedRun', currentRun)
                        RemoveBlip(deliveryBlip)
                        currentDelivery = nil
                        currentRun = nil
                        isOnRun = false
                    end
                end, pos)
            end
        end
    end
end)

-- Cleanup peds on resource stop
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        for _, ped in pairs(dealerPeds) do
            DeleteEntity(ped)
        end
    end
end)

RegisterNetEvent('qb-drugrun:client:startRun', function()
    StartDrugRun()
    if math.random(100) <= Config.PoliceAlert.chance then
        AlertPolice()
    end
end)

RegisterNetEvent('qb-drugrun:client:confirmRun', function(data)
    QBCore.Functions.TriggerCallback('qb-drugrun:server:getCops', function(cops)
        if cops >= Config.MinimumPolice then
            -- Set run as started but don't show location yet
            isOnRun = true
            currentRun = {
                drugType = data.drugType,
                amount = data.amount
            }
            
            QBCore.Functions.Notify('Drug run started. Delivering ' .. Config.Drugs[data.drugType].label, 'success')
            TriggerServerEvent('qb-drugrun:server:startRun', data.drugType, data.amount)
            
            -- Show "getting location" message
            QBCore.Functions.Notify('Getting the dropoff location...', 'primary', 15000)
            
            -- Wait 15 seconds before showing delivery location
            SetTimeout(15000, function()
                currentDelivery = Config.DeliveryLocations[math.random(#Config.DeliveryLocations)]
                deliveryBlip = AddBlipForCoord(currentDelivery.x, currentDelivery.y, currentDelivery.z)
                SetBlipSprite(deliveryBlip, 1)
                SetBlipRoute(deliveryBlip, true)
                SetBlipRouteColour(deliveryBlip, 5)
                
                QBCore.Functions.Notify('Dropoff location received!', 'success')
            end)
        else
            QBCore.Functions.Notify('Not enough police in the city.', 'error')
        end
    end)
end)