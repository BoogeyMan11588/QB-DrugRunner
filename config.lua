Config = {}

Config.MinimumPolice = 1

Config.Drugs = {
    ['smallcocaine'] = {
        label = 'Small Cocaine',
        itemName = 'coke_small_brick',
        minPrice = 1500,
        maxPrice = 3000,
        minAmount = 1,
        maxAmount = 10
    },
    ['largecocaine'] = {
        label = 'Large Cocaine',
        itemName = 'coke_brick',
        minPrice = 3000,
        maxPrice = 6000,
        minAmount = 1,
        maxAmount = 10
    },
    ['weed'] = {
        label = 'Weed',
        itemName = 'weed_brick',
        minPrice = 800,
        maxPrice = 1500,
        minAmount = 1,
        maxAmount = 5
    },
}

Config.Dealers = {
    {
        coords = vector4(1976.69, 3819.63, 33.45, 122.13),
        name = "Sandy Dealer",
        ped = {
            model = 'a_m_m_hillbilly_01',
            scenario = 'WORLD_HUMAN_SMOKING'
        },
        blip = false
    },
    {
        coords = vector4(-1038.75, -1129.11, 2.16, 38.0),
        name = "South Side Dealer",
        ped = {
            model = 'g_m_y_salvagoon_01',
            scenario = 'WORLD_HUMAN_STAND_IMPATIENT'
        },
        blip = false
    }
}

Config.DeliveryLocations = {
    vector4(-753.68, -1512.05, 5.02, 20.68), -- helo pad 349
    vector4(1221.75, -2922.09, 5.87, 64.94), -- port 17
    vector4(2816.6, -668.35, 1.14, 264.67), -- water 450
    vector4(3804.92, 4443.88, 4.01, 7.45), -- water 1053
    vector4(167.35, 7036.9, 2.01, 115.04) -- beach 389
}

Config.PoliceAlert = {
    chance = 35,
    cooldown = 10000
}