local inComms = false
local sweeping = false
local status = {
    remaining = 0,
    completed = 0,
    total = 0,
    reason = '',
    activeTasks = {},
}

local taskPoints = {}
local taskBlips = {}
local areaBlip
local statusPed
local shopPed
local pedsReady = false
local rebuildTasks
local commsZone

local function notify(key, nType, ...)
    lib.notify({
        title = locale('notify_title'),
        description = locale(key, ...),
        type = nType or 'inform',
        duration = 7000,
    })
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelValid(hash) then return false end

    lib.requestModel(hash, 5000)
    return HasModelLoaded(hash)
end

local function spawnPed(data)
    if not loadModel(data.model) then return nil end

    local c = data.coords
    local ped = CreatePed(0, data.model, c.x, c.y, c.z - 1.0, c.w, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetEntityInvincible(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedCanRagdoll(ped, false)
    SetPedDiesWhenInjured(ped, false)
    SetEntityProofs(ped, true, true, true, true, true, true, true, true)

    if data.scenario then
        TaskStartScenarioInPlace(ped, data.scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(data.model)
    return ped
end

local function showStatusMenu()
    local data = lib.callback.await('dj-comms:server:getStatus', false)
    if not data or not data.active then
        notify('error_not_serving_self', 'inform')
        return
    end

    lib.registerContext({
        id = 'dj_comms_status',
        title = locale('status_title'),
        options = {
            {
                title = locale('status_completed'),
                description = tostring(data.completed),
                icon = 'check',
            },
            {
                title = locale('status_remaining'),
                description = tostring(data.remaining),
                icon = 'broom',
            },
            {
                title = locale('status_total'),
                description = tostring(data.total),
                icon = 'list',
            },
            {
                title = locale('status_reason'),
                description = data.reason or 'n/a',
                icon = 'gavel',
            },
        },
    })

    lib.showContext('dj_comms_status')
end

local function openShop()
    exports.ox_inventory:openInventory('shop', { type = Config.Shop.id, id = 1 })
end

local function setupPeds()
    if pedsReady then return end
    pedsReady = true

    statusPed = spawnPed(Config.StatusPed)
    shopPed = spawnPed(Config.ShopPed)

    if statusPed then
        exports.ox_target:addLocalEntity(statusPed, {
            {
                name = 'dj_comms_status',
                icon = 'fa-solid fa-clipboard-list',
                label = locale('target_status'),
                distance = 2.0,
                onSelect = showStatusMenu,
            },
        })
    end

    if shopPed then
        exports.ox_target:addLocalEntity(shopPed, {
            {
                name = 'dj_comms_shop',
                icon = 'fa-solid fa-basket-shopping',
                label = locale('target_shop'),
                distance = 2.0,
                onSelect = openShop,
            },
        })
    end
end

local function clearTaskVisuals()
    for _, point in pairs(taskPoints) do
        if point and point.remove then
            point:remove()
        end
    end
    taskPoints = {}

    for _, blip in pairs(taskBlips) do
        if blip and DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end
    taskBlips = {}

    if areaBlip and DoesBlipExist(areaBlip) then
        RemoveBlip(areaBlip)
        areaBlip = nil
    end

    lib.hideTextUI()
end

local function createAreaBlip()
    if areaBlip and DoesBlipExist(areaBlip) then
        RemoveBlip(areaBlip)
    end

    local c = Config.Zone.center
    areaBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(areaBlip, Config.Blips.area.sprite)
    SetBlipColour(areaBlip, Config.Blips.area.color)
    SetBlipScale(areaBlip, Config.Blips.area.scale)
    SetBlipAsShortRange(areaBlip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Blips.area.label)
    EndTextCommandSetBlipName(areaBlip)
end

local function startSweep(taskIndex)
    if sweeping or not inComms then return end

    local allowed = lib.callback.await('dj-comms:server:startTask', false, taskIndex)
    if not allowed then
        notify('error_cannot_start', 'error')
        return
    end

    sweeping = true
    lib.hideTextUI()

    local coord = Config.TaskCoords[taskIndex]
    SetEntityHeading(cache.ped, coord.w)

    local success = lib.progressCircle({
        duration = Config.TaskDuration,
        label = locale('sweeping'),
        position = 'bottom',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            sprint = true,
        },
        anim = {
            dict = Config.Sweep.dict,
            clip = Config.Sweep.clip,
            flag = Config.Sweep.flag,
        },
        prop = {
            model = Config.Sweep.prop.model,
            bone = Config.Sweep.prop.bone,
            pos = Config.Sweep.prop.pos,
            rot = Config.Sweep.prop.rot,
        },
    })

    if not success then
        lib.callback.await('dj-comms:server:cancelTask', false)
        sweeping = false
        notify('sweep_cancelled', 'inform')
        return
    end

    local result = lib.callback.await('dj-comms:server:completeTask', false, taskIndex)
    sweeping = false

    if not result or not result.ok then
        notify('error_sweep_invalid', 'error')
        return
    end

    if result.finished then
        return
    end

    status.remaining = result.remaining
    status.completed = result.completed
    status.total = result.total
    status.reason = result.reason
    status.activeTasks = result.activeTasks
    notify('sweep_done', 'success', result.remaining)
    rebuildTasks()
end

local function addTaskPoint(taskIndex)
    local coord = Config.TaskCoords[taskIndex]
    if not coord then return end

    local blip = AddBlipForCoord(coord.x, coord.y, coord.z)
    SetBlipSprite(blip, Config.Blips.task.sprite)
    SetBlipColour(blip, Config.Blips.task.color)
    SetBlipScale(blip, Config.Blips.task.scale)
    SetBlipAsShortRange(blip, false)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(Config.Blips.task.label)
    EndTextCommandSetBlipName(blip)
    taskBlips[taskIndex] = blip

    taskPoints[taskIndex] = lib.points.new({
        coords = vec3(coord.x, coord.y, coord.z),
        distance = Config.InteractDistance,
        nearby = function()
            if sweeping then return end
            if IsControlJustReleased(0, 38) then
                startSweep(taskIndex)
            end
        end,
        onEnter = function()
            if sweeping then return end
            lib.showTextUI(locale('sweep_prompt'))
        end,
        onExit = function()
            lib.hideTextUI()
        end,
    })
end

rebuildTasks = function()
    clearTaskVisuals()
    if not inComms then return end

    createAreaBlip()

    for i = 1, #status.activeTasks do
        addTaskPoint(status.activeTasks[i])
    end
end

local function applyStatus(data)
    status.remaining = data.remaining or 0
    status.completed = data.completed or 0
    status.total = data.total or 0
    status.reason = data.reason or ''
    status.activeTasks = data.activeTasks or {}
end

local function teleportTo(coords)
    local ped = cache.ped
    if cache.vehicle then
        TaskLeaveVehicle(ped, cache.vehicle, 16)
        Wait(500)
    end

    SetEntityCoords(ped, coords.x, coords.y, coords.z, false, false, false, false)
    SetEntityHeading(ped, coords.w)
end

local function insideZone()
    if commsZone and commsZone.contains then
        return commsZone:contains(GetEntityCoords(cache.ped))
    end

    return #(GetEntityCoords(cache.ped) - Config.Zone.center) <= Config.Zone.radius
end

local function isDowned()
    local playerState = LocalPlayer and LocalPlayer.state
    if playerState and (playerState.isDead or playerState.inLaststand or playerState.laststand) then
        return true
    end

    return IsPedDeadOrDying(cache.ped, true) or IsPedFatallyInjured(cache.ped)
end

local function destroyCommsZone()
    if commsZone then
        commsZone:remove()
        commsZone = nil
    end
end

local function ensureCommsZone()
    if commsZone then return end

    commsZone = lib.zones.sphere({
        coords = Config.Zone.center,
        radius = Config.Zone.radius,
        debug = false,
        onExit = function()
            if not inComms or sweeping then return end
            teleportTo(Config.StartCoords)
            if not isDowned() then
                TriggerServerEvent('dj-comms:server:escaped')
            end
        end,
    })
end

local function startComms(data, opts)
    opts = opts or {}
    applyStatus(data)
    inComms = true
    sweeping = false
    ensureCommsZone()

    if opts.teleport or (opts.enforceZone and not insideZone()) then
        teleportTo(Config.StartCoords)
    end

    rebuildTasks()
    notify('started', 'inform', status.remaining)
end

local function stopComms(teleportOut)
    inComms = false
    sweeping = false
    destroyCommsZone()
    clearTaskVisuals()
    status = {
        remaining = 0,
        completed = 0,
        total = 0,
        reason = '',
        activeTasks = {},
    }

    if teleportOut then
        teleportTo(Config.FinishCoords)
    end
end

CreateThread(function()
    setupPeds()
end)

CreateThread(function()
    while true do
        if inComms and status.activeTasks and #status.activeTasks > 0 then
            local marker = Config.Markers
            for i = 1, #status.activeTasks do
                local coord = Config.TaskCoords[status.activeTasks[i]]
                if coord then
                    DrawMarker(
                        marker.type,
                        coord.x, coord.y, coord.z + marker.zOffset,
                        0.0, 0.0, 0.0,
                        180.0, 0.0, 0.0,
                        marker.scale.x, marker.scale.y, marker.scale.z,
                        marker.color.r, marker.color.g, marker.color.b, marker.color.a,
                        marker.bob,
                        false,
                        2,
                        marker.rotate,
                        nil, nil, false
                    )
                end
            end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

RegisterNetEvent('dj-comms:client:start', function(data, opts)
    startComms(data, opts)
end)

RegisterNetEvent('dj-comms:client:update', function(data)
    applyStatus(data)
    if inComms then
        rebuildTasks()
    else
        startComms(data, { teleport = false, enforceZone = true })
    end
end)

RegisterNetEvent('dj-comms:client:finish', function()
    stopComms(true)
end)

RegisterNetEvent('dj-comms:client:cleanup', function()
    stopComms(false)
end)

local function tryRestore()
    local data = lib.callback.await('dj-comms:server:getStatus', false)
    if data and data.active then
        startComms(data, { teleport = false, enforceZone = true })
    end
end

AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    SetTimeout(2000, tryRestore)
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', function()
    stopComms(false)
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    clearTaskVisuals()
    destroyCommsZone()

    if statusPed and DoesEntityExist(statusPed) then
        exports.ox_target:removeLocalEntity(statusPed)
        DeleteEntity(statusPed)
    end

    if shopPed and DoesEntityExist(shopPed) then
        exports.ox_target:removeLocalEntity(shopPed)
        DeleteEntity(shopPed)
    end
end)

CreateThread(function()
    Wait(2500)
    if LocalPlayer.state.isLoggedIn then
        tryRestore()
    end
end)
