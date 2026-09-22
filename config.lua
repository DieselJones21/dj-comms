Config = {}

-- Discord webhook. Leave empty to disable logging.
-- Logs when a player is sent to comms and when they finish.
Config.Webhook = 'https://discord.com/api/webhooks/1551813937803038731/HtMNLMEtxyKMdxConydQU8OiPr69U09DmVFuJHr8rYYkZl83jqc7cK10B8t6B8Ao79Pe'

-- Admin ACE group used by lib.addCommand
Config.AdminGroup = 'group.admin'

-- Task limits. Amount has no forced minimum besides 1 (a send with 0 tasks is ignored).
Config.MinTasks = 1
Config.MaxTasks = 150

-- How many sweep arrows / map blips are shown at once.
-- Finished spots disappear and a new unused spot is assigned while work remains.
Config.ActiveTaskCount = 4

-- Sweep duration in milliseconds
Config.TaskDuration = 12000

-- How close the player must be to press E / complete a task
Config.InteractDistance = 1.8

-- Extra tasks added when a player leaves the comms zone (0 to disable).
-- Still capped by Config.MaxTasks.
Config.EscapePenaltyTasks = 1

Config.Zone = {
    center = vector3(142.00, -962.00, 21.21),
    radius = 40.0,
}

-- Where players are placed when sent to community service.
-- You did not provide a start coord, so this sits in the plaza next to your task spots.
Config.StartCoords = vector4(147.20, -964.50, 21.21, 70.0)

-- Where players are teleported after finishing (or being released).
Config.FinishCoords = vector4(237.15, -406.08, 47.92, 172.01)

-- Sweep task spots. Heading is used to face the player while sweeping.
Config.TaskCoords = {
    vector4(142.05, -954.51, 21.21, 119.52),
    vector4(143.92, -948.67, 21.21, 84.49),
    vector4(140.28, -960.53, 21.21, 13.84),
    vector4(137.83, -965.08, 21.21, 124.17),
    vector4(136.14, -970.71, 21.21, 127.92),
    vector4(133.49, -977.12, 21.21, 128.00),
    vector4(143.52, -949.21, 24.76, 117.16),
    vector4(141.71, -954.68, 24.76, 127.77),
    vector4(139.66, -960.15, 24.76, 129.73),
    vector4(137.26, -966.01, 24.76, 117.33),
    vector4(135.08, -971.35, 24.76, 217.82),
    vector4(133.42, -976.78, 24.76, 104.36),
    vector4(150.13, -970.71, 21.21, 108.68),
    vector4(151.70, -962.91, 21.21, 147.69),
}

-- 3rd-eye supervisor: shows completed / remaining / total / reason
Config.StatusPed = {
    model = `s_m_y_construct_01`,
    coords = vector4(149.35, -959.40, 21.21, 160.0),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
}

-- 3rd-eye shop ped: ox_inventory shop with base QBX food and drinks
Config.ShopPed = {
    model = `mp_m_shopkeep_01`,
    coords = vector4(151.85, -968.10, 21.21, 70.0),
    scenario = 'WORLD_HUMAN_STAND_IMPATIENT',
}

Config.Shop = {
    id = 'comms_shop',
    label = 'Comms Commissary',
    items = {
        { name = 'sandwich', price = 8 },
        { name = 'tosti', price = 8 },
        { name = 'twerks_candy', price = 4 },
        { name = 'snikkel_candy', price = 4 },
        { name = 'water_bottle', price = 5 },
        { name = 'kurkakola', price = 5 },
        { name = 'coffee', price = 6 },
    },
}

Config.Markers = {
    type = 2, -- floating chevron / arrow
    bob = true,
    rotate = true,
    scale = vector3(0.35, 0.35, 0.35),
    color = { r = 255, g = 200, b = 40, a = 180 },
    zOffset = 1.15,
}

Config.Blips = {
    area = {
        sprite = 280,
        color = 5,
        scale = 0.85,
        label = 'Community Service',
    },
    task = {
        sprite = 1,
        color = 5,
        scale = 0.65,
        label = 'Sweep Task',
    },
}

Config.Sweep = {
    dict = 'amb@world_human_janitor@male@idle_a',
    clip = 'idle_a',
    flag = 49,
    prop = {
        model = `prop_tool_broom`,
        bone = 28422,
        pos = vector3(-0.005, 0.0, 0.0),
        rot = vector3(360.0, 30.0, 150.0),
    },
}
