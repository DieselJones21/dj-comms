local sessions = {}
local lastEscape = {}

local function notify(src, description, nType)
    if not src or src == 0 then
        print(('[dj-comms] %s'):format(description))
        return
    end

    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Community Service',
        description = description,
        type = nType or 'inform',
        duration = 7000,
    })
end

local function getIdentifier(src, idType)
    if GetPlayerIdentifierByType then
        return GetPlayerIdentifierByType(src, idType)
    end

    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, #idType + 1) == (idType .. ':') then
            return id
        end
    end
end

local function playerName(player)
    if not player then return 'Unknown' end

    local info = player.PlayerData.charinfo
    if info and info.firstname then
        return ('%s %s'):format(info.firstname, info.lastname)
    end

    return GetPlayerName(player.PlayerData.source) or 'Unknown'
end

local function identifiers(src)
    return {
        license = getIdentifier(src, 'license') or 'n/a',
        discord = getIdentifier(src, 'discord') or 'n/a',
    }
end

local function sendWebhook(title, color, fields)
    if type(Config.Webhook) ~= 'string' or Config.Webhook == '' then return end

    PerformHttpRequest(Config.Webhook, function() end, 'POST', json.encode({
        username = 'Community Service',
        embeds = {{
            title = title,
            color = color,
            fields = fields,
            footer = { text = 'dj-comms' },
            timestamp = os.date('!%Y-%m-%dT%H:%M:%SZ'),
        }},
    }), { ['Content-Type'] = 'application/json' })
end

local function getPlayer(src)
    return exports.qbx_core:GetPlayer(src)
end

local function saveMetadata(src, data)
    local player = getPlayer(src)
    if not player then return end

    if exports.qbx_core.SetMetadata then
        exports.qbx_core:SetMetadata(src, 'communityservice', data)
    else
        player.Functions.SetMetaData('communityservice', data)
    end
end

local function readMetadata(player)
    local meta = player and player.PlayerData and player.PlayerData.metadata
    return meta and meta.communityservice or nil
end

local function isActiveIndex(list, index)
    for i = 1, #list do
        if list[i] == index then return true end
    end
    return false
end

local function pickTasks(existing, needed)
    local pool = {}
    for i = 1, #Config.TaskCoords do
        if not isActiveIndex(existing, i) then
            pool[#pool + 1] = i
        end
    end

    local picked = {}
    for _ = 1, needed do
        if #pool == 0 then break end
        local slot = math.random(1, #pool)
        picked[#picked + 1] = pool[slot]
        table.remove(pool, slot)
    end

    return picked
end

local function assignActiveTasks(session)
    session.activeTasks = {}
    local needed = math.min(Config.ActiveTaskCount, session.remaining, #Config.TaskCoords)
    session.activeTasks = pickTasks({}, needed)
end

local function sessionPayload(session)
    return {
        remaining = session.remaining,
        completed = session.completed,
        total = session.total,
        reason = session.reason,
        activeTasks = session.activeTasks,
    }
end

local function persistSession(src, session)
    saveMetadata(src, {
        active = true,
        remaining = session.remaining,
        completed = session.completed,
        total = session.total,
        reason = session.reason,
        sentBy = session.sentBy,
        sentAt = session.sentAt,
    })
end

local function beginSession(src, amount, reason, sentBy, opts)
    opts = opts or {}

    local session = {
        remaining = amount,
        completed = 0,
        total = amount,
        reason = reason,
        sentBy = sentBy,
        sentAt = os.time(),
        activeTasks = {},
        busyIndex = nil,
        busyAt = 0,
    }

    assignActiveTasks(session)
    sessions[src] = session
    persistSession(src, session)

    TriggerClientEvent('dj-comms:client:start', src, sessionPayload(session), {
        teleport = opts.teleport ~= false,
    })

    return session
end

local function finishSession(src, released)
    local session = sessions[src]
    sessions[src] = nil
    saveMetadata(src, nil)

    TriggerClientEvent('dj-comms:client:finish', src)

    local player = getPlayer(src)
    local ids = identifiers(src)
    local completed = session and session.completed or 0
    local total = session and session.total or 0
    local reason = session and session.reason or 'n/a'

    notify(src, released and 'You have been released from community service.' or 'Community service complete. You are free to go.', 'success')

    sendWebhook(released and 'Player Released From Community Service' or 'Community Service Completed', released and 15105570 or 5763719, {
        { name = 'Player', value = ('%s (`%s`)'):format(playerName(player), src), inline = true },
        { name = 'Citizen ID', value = player and player.PlayerData.citizenid or 'n/a', inline = true },
        { name = 'License', value = ids.license, inline = false },
        { name = 'Discord', value = ids.discord, inline = true },
        { name = 'Tasks', value = ('%s / %s'):format(completed, total), inline = true },
        { name = 'Reason', value = reason, inline = false },
        { name = 'Released', value = released and 'Admin released' or 'Finished all tasks', inline = true },
    })
end

local function sendToComms(adminSrc, targetSrc, amount, reason)
    amount = math.floor(tonumber(amount) or 0)
    reason = type(reason) == 'string' and reason:gsub('^%s+', ''):gsub('%s+$', '') or ''

    if amount < Config.MinTasks or amount > Config.MaxTasks then
        notify(adminSrc, ('Task amount must be between %s and %s.'):format(Config.MinTasks, Config.MaxTasks), 'error')
        return false
    end

    if reason == '' then
        notify(adminSrc, 'You must provide a reason.', 'error')
        return false
    end

    local target = getPlayer(targetSrc)
    if not target then
        notify(adminSrc, 'That player is not online.', 'error')
        return false
    end

    local admin = adminSrc > 0 and getPlayer(adminSrc) or nil
    local sentBy = adminSrc > 0 and playerName(admin) or 'Console'

    local addedToExisting = sessions[targetSrc] ~= nil
    local remainingAfter = amount

    if addedToExisting then
        local session = sessions[targetSrc]
        session.remaining = math.min(Config.MaxTasks, session.remaining + amount)
        session.total = math.min(Config.MaxTasks, session.total + amount)
        session.reason = reason
        remainingAfter = session.remaining
        persistSession(targetSrc, session)
        assignActiveTasks(session)
        TriggerClientEvent('dj-comms:client:update', targetSrc, sessionPayload(session))
        notify(targetSrc, ('More community service was added. %s tasks remaining.'):format(session.remaining), 'inform')
        notify(adminSrc, ('Added %s tasks. %s now has %s remaining.'):format(amount, playerName(target), session.remaining), 'success')
    else
        beginSession(targetSrc, amount, reason, sentBy, { teleport = true })
        notify(targetSrc, ('You were sent to community service for %s tasks. Reason: %s'):format(amount, reason), 'error')
        notify(adminSrc, ('Sent %s to community service for %s tasks.'):format(playerName(target), amount), 'success')
    end

    local ids = identifiers(targetSrc)
    sendWebhook('Player Sent To Community Service', 15158332, {
        { name = 'Player', value = ('%s (`%s`)'):format(playerName(target), targetSrc), inline = true },
        { name = 'Citizen ID', value = target.PlayerData.citizenid or 'n/a', inline = true },
        { name = 'License', value = ids.license, inline = false },
        { name = 'Discord', value = ids.discord, inline = true },
        { name = 'Tasks added', value = tostring(amount), inline = true },
        { name = 'Remaining', value = tostring(remainingAfter), inline = true },
        { name = 'Already serving', value = addedToExisting and 'Yes' or 'No', inline = true },
        { name = 'Reason', value = reason, inline = false },
        { name = 'Admin', value = sentBy, inline = true },
    })

    return true
end

local function restoreIfNeeded(src)
    local player = getPlayer(src)
    if not player then return end

    local data = readMetadata(player)
    if not data or not data.active or (tonumber(data.remaining) or 0) <= 0 then
        if sessions[src] then
            sessions[src] = nil
            TriggerClientEvent('dj-comms:client:cleanup', src)
        end
        return
    end

    local session = {
        remaining = data.remaining,
        completed = data.completed or 0,
        total = data.total or data.remaining,
        reason = data.reason or 'n/a',
        sentBy = data.sentBy or 'Unknown',
        sentAt = data.sentAt or os.time(),
        activeTasks = {},
        busyIndex = nil,
        busyAt = 0,
    }

    assignActiveTasks(session)
    sessions[src] = session

    TriggerClientEvent('dj-comms:client:start', src, sessionPayload(session), {
        teleport = false,
        enforceZone = true,
    })
end

local function registerShop()
    local shopCoords = Config.ShopPed.coords
    exports.ox_inventory:RegisterShop(Config.Shop.id, {
        name = Config.Shop.label,
        inventory = Config.Shop.items,
        locations = {
            vec3(shopCoords.x, shopCoords.y, shopCoords.z),
        },
    })
end

lib.callback.register('dj-comms:server:getStatus', function(source)
    local session = sessions[source]
    if not session then
        return { active = false }
    end

    return {
        active = true,
        remaining = session.remaining,
        completed = session.completed,
        total = session.total,
        reason = session.reason,
        activeTasks = session.activeTasks,
    }
end)

lib.callback.register('dj-comms:server:startTask', function(source, taskIndex)
    local session = sessions[source]
    taskIndex = tonumber(taskIndex)
    if not session or not taskIndex or not isActiveIndex(session.activeTasks, taskIndex) then
        return false
    end

    local coord = Config.TaskCoords[taskIndex]
    local ped = GetPlayerPed(source)
    if ped == 0 then return false end

    local dist = #(GetEntityCoords(ped) - vec3(coord.x, coord.y, coord.z))
    if dist > Config.InteractDistance + 1.5 then
        return false
    end

    if session.busyIndex then
        return false
    end

    session.busyIndex = taskIndex
    session.busyAt = os.time()
    return true
end)

lib.callback.register('dj-comms:server:cancelTask', function(source)
    local session = sessions[source]
    if not session then return false end

    session.busyIndex = nil
    session.busyAt = 0
    return true
end)

lib.callback.register('dj-comms:server:completeTask', function(source, taskIndex)
    local session = sessions[source]
    taskIndex = tonumber(taskIndex)
    if not session or not taskIndex then return { ok = false } end

    if session.busyIndex ~= taskIndex then
        return { ok = false }
    end

    local elapsed = os.time() - (session.busyAt or 0)
    local required = math.floor(Config.TaskDuration / 1000) - 1
    if elapsed < required then
        session.busyIndex = nil
        session.busyAt = 0
        return { ok = false }
    end

    local coord = Config.TaskCoords[taskIndex]
    local ped = GetPlayerPed(source)
    if ped == 0 then return { ok = false } end

    local dist = #(GetEntityCoords(ped) - vec3(coord.x, coord.y, coord.z))
    if dist > Config.InteractDistance + 2.0 then
        session.busyIndex = nil
        session.busyAt = 0
        return { ok = false }
    end

    if not isActiveIndex(session.activeTasks, taskIndex) then
        session.busyIndex = nil
        session.busyAt = 0
        return { ok = false }
    end

    for i = #session.activeTasks, 1, -1 do
        if session.activeTasks[i] == taskIndex then
            table.remove(session.activeTasks, i)
            break
        end
    end

    session.remaining = math.max(0, session.remaining - 1)
    session.completed = session.completed + 1
    session.busyIndex = nil
    session.busyAt = 0

    if session.remaining <= 0 then
        finishSession(source, false)
        return { ok = true, finished = true }
    end

    local needed = math.min(Config.ActiveTaskCount, session.remaining) - #session.activeTasks
    if needed > 0 then
        local extra = pickTasks(session.activeTasks, needed)
        for i = 1, #extra do
            session.activeTasks[#session.activeTasks + 1] = extra[i]
        end
    end

    persistSession(source, session)
    return {
        ok = true,
        finished = false,
        remaining = session.remaining,
        completed = session.completed,
        total = session.total,
        reason = session.reason,
        activeTasks = session.activeTasks,
    }
end)

RegisterNetEvent('dj-comms:server:escaped', function()
    local src = source
    local session = sessions[src]
    if not session then return end

    local now = os.time()
    if lastEscape[src] and (now - lastEscape[src]) < 8 then
        return
    end
    lastEscape[src] = now

    local extra = tonumber(Config.EscapePenaltyTasks) or 0
    if extra > 0 then
        session.remaining = math.min(Config.MaxTasks, session.remaining + extra)
        session.total = math.min(Config.MaxTasks, session.total + extra)

        local needed = math.min(Config.ActiveTaskCount, session.remaining) - #session.activeTasks
        if needed > 0 then
            local extraTasks = pickTasks(session.activeTasks, needed)
            for i = 1, #extraTasks do
                session.activeTasks[#session.activeTasks + 1] = extraTasks[i]
            end
        end

        persistSession(src, session)
        notify(src, ('You cannot leave. %s extra task(s) added. %s remaining.'):format(extra, session.remaining), 'error')
        TriggerClientEvent('dj-comms:client:update', src, sessionPayload(session))
    else
        notify(src, 'You cannot leave community service.', 'error')
    end
end)

AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
    if not player or not player.PlayerData then return end
    SetTimeout(1500, function()
        restoreIfNeeded(player.PlayerData.source)
    end)
end)

RegisterNetEvent('QBCore:Server:OnPlayerLoaded', function()
    local src = source
    SetTimeout(1500, function()
        restoreIfNeeded(src)
    end)
end)

AddEventHandler('playerDropped', function()
    sessions[source] = nil
    lastEscape[source] = nil
end)

CreateThread(function()
    while GetResourceState('ox_inventory') ~= 'started' do
        Wait(100)
    end

    registerShop()
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    SetTimeout(2000, function()
        for _, src in ipairs(GetPlayers()) do
            restoreIfNeeded(tonumber(src))
        end
    end)
end)

lib.addCommand('sendcomms', {
    help = 'Send a player to community service',
    params = {
        { name = 'id', type = 'playerId', help = 'Target server ID' },
        { name = 'amount', type = 'number', help = 'Number of sweep tasks (1-150)' },
        { name = 'reason', type = 'longString', help = 'Reason they are being sent' },
    },
    restricted = Config.AdminGroup,
}, function(source, args)
    sendToComms(source, args.id, args.amount, args.reason)
end)

lib.addCommand('removecomms', {
    help = 'Release a player from community service',
    params = {
        { name = 'id', type = 'playerId', help = 'Target server ID' },
    },
    restricted = Config.AdminGroup,
}, function(source, args)
    local target = getPlayer(args.id)
    if not target then
        notify(source, 'That player is not online.', 'error')
        return
    end

    if not sessions[args.id] then
        local data = readMetadata(target)
        if not data or not data.active then
            notify(source, 'That player is not in community service.', 'error')
            return
        end
        sessions[args.id] = {
            remaining = data.remaining or 0,
            completed = data.completed or 0,
            total = data.total or 0,
            reason = data.reason or 'n/a',
            sentBy = data.sentBy or 'Unknown',
            sentAt = data.sentAt or os.time(),
            activeTasks = {},
        }
    end

    finishSession(args.id, true)
    notify(source, ('Released %s from community service.'):format(playerName(target)), 'success')
end)

lib.addCommand('checkcomms', {
    help = 'Check a player\'s community service progress',
    params = {
        { name = 'id', type = 'playerId', help = 'Target server ID' },
    },
    restricted = Config.AdminGroup,
}, function(source, args)
    local target = getPlayer(args.id)
    if not target then
        notify(source, 'That player is not online.', 'error')
        return
    end

    local session = sessions[args.id]
    if not session then
        local data = readMetadata(target)
        if not data or not data.active then
            notify(source, 'That player is not in community service.', 'inform')
            return
        end
        session = data
    end

    notify(source, ('%s: %s/%s done, %s left. Reason: %s'):format(
        playerName(target),
        session.completed or 0,
        session.total or 0,
        session.remaining or 0,
        session.reason or 'n/a'
    ), 'inform')
end)

exports('SendToComms', function(targetSrc, amount, reason, sentBy)
    return sendToComms(0, targetSrc, amount, reason or sentBy or 'Exported send')
end)

exports('RemoveFromComms', function(targetSrc)
    if not sessions[targetSrc] then return false end
    finishSession(targetSrc, true)
    return true
end)

exports('IsInComms', function(targetSrc)
    return sessions[targetSrc] ~= nil
end)

exports('GetCommsStatus', function(targetSrc)
    local session = sessions[targetSrc]
    if not session then return nil end
    return sessionPayload(session)
end)
