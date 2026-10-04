if isClient() then return end
require "KT_Shared"

local data      -- persistent, server-only truth: id -> {untilT, stress, stressT}
local snaps = {}   -- id -> {cond, sharp, head}
local started = {} -- username -> ms of last accepted action start
local tick = 0

local function D()
    if not data then data = ModData.getOrCreate("KatanaTempering") end
    return data
end

local function call(item, fn, ...)
    local ok, v = pcall(function(...) return item[fn](item, ...) end, ...)
    if ok then return v end
end

local function sync(player, item)
    if syncItemFields then pcall(syncItemFields, player, item) end
end

local function players()
    local list = {}
    if isServer() then
        local o = getOnlinePlayers()
        for i = 0, o:size() - 1 do list[#list + 1] = o:get(i) end
    else
        for i = 0, getNumActivePlayers() - 1 do
            local p = getSpecificPlayer(i)
            if p then list[#list + 1] = p end
        end
    end
    return list
end

local function sendState(player, item)
    local e = D()[KT.key(item)] or {}
    sendServerCommand(player, KT.MODULE, "state", { id = item:getID(), untilT = e.untilT, stress = e.stress, stressT = e.stressT })
end

local function result(player, status)
    sendServerCommand(player, KT.MODULE, "result", { status = status })
end

-- wear n (float/int) scaled by percent; ints get probabilistic rounding so slow wear stays fair
local function scaled(drop, pct, isInt)
    local v = drop * pct / 100
    if not isInt then return v end
    local whole = math.floor(v)
    if ZombRandFloat(0, 1) < (v - whole) then whole = whole + 1 end
    return whole
end

local applied = {}
local function makeHattori(player, item)
    local md = item:getModData()
    md.KT_Hattori = true
    item:setName(getText("ItemName_KT_Hattori"))
    pcall(function() item:setCustomName(true) end)
    KT.applyHattoriStats(item)
    applied[KT.key(item)] = true
    if player then sync(player, item) end
end

local lastEq = {}
local function guard(player)
    local item = player:getPrimaryHandItem()
    -- snapshots are only valid while the item stays equipped: repairs/sharpening done from the inventory
    -- (vanilla or Preventative Maintenance 2) must never be mistaken for combat wear and "refunded"
    local who = player:getUsername()
    local curId = item and KT.key(item) or nil
    if lastEq[who] and lastEq[who] ~= curId then snaps[lastEq[who]] = nil end
    lastEq[who] = curId
    if item and KT.isHattori(item) and not applied[KT.key(item)] then -- stats are re-applied each session
        applied[KT.key(item)] = true
        KT.applyHattoriStats(item); sync(player, item)
    end
    local immune = KT.isSharpImmune(item)
    if not (KT.isTarget(item) or immune) then return end
    local id = KT.key(item)
    local now = KT.now()
    local e = D()[id]
    local pct = KT.isTarget(item) and ((e and e.untilT and e.untilT > now) and KT.opt("HardenedWearPercent", 0) or KT.opt("BaseWearPercent", 100)) or 100
    local sharpPct = immune and 0 or pct

    -- another mod's repair just happened while equipped (Preventative Maintenance 2 counts every repair): rebaseline
    local st = item:getModData().PMTwo_stats
    local rc = st and st.true_repair_count or 0
    local cur = { rc = rc, cond = item:getCondition(), sharp = item:hasSharpness() and item:getSharpness() or nil, head = item:hasHeadCondition() and item:getHeadCondition() or nil }
    local snap = snaps[id]
    if snap and snap.rc ~= rc then snap = nil end
    if snap and (pct < 100 or sharpPct < 100) then
        local changed = false
        if cur.sharp and snap.sharp and cur.sharp < snap.sharp then
            cur.sharp = snap.sharp - scaled(snap.sharp - cur.sharp, sharpPct, false)
            item:setSharpness(cur.sharp); changed = true
        end
        if pct < 100 and KT.opt("ProtectCondition", true) then
            if cur.cond < snap.cond then
                cur.cond = snap.cond - scaled(snap.cond - cur.cond, pct, true)
                item:setCondition(cur.cond); changed = true
            end
            if cur.head and snap.head and cur.head < snap.head then
                cur.head = snap.head - scaled(snap.head - cur.head, pct, true)
                item:setHeadCondition(cur.head); changed = true
            end
        end
        if changed then sync(player, item) end
    end
    snaps[id] = cur
end

local function temper(player, args)
    if not KT.opt("Enabled", true) then return result(player, "denied") end
    local inv = player:getInventory()
    local weapon = inv:getItemById(args.weaponId or -1)
    local torch = inv:getItemById(args.torchId or -1)
    if not KT.isTarget(weapon) or not torch or torch:getFullType() ~= KT.TORCH then return result(player, "denied") end

    -- must have announced a start and actually waited (anti-spam / anti-forged-command)
    local t0 = started[player:getUsername()]
    started[player:getUsername()] = nil
    if not t0 or getTimestampMs() - t0 < 2000 then return result(player, "denied") end

    if not KT.meetsSkills(player) then return result(player, "denied") end
    if KT.opt("RequireWeldingMask", false) and not KT.hasMask(player) then return result(player, "denied") end
    local units = KT.opt("TorchUnitsPerUse", 1)
    if units > 0 and (torch:getCurrentUses() or 0) < units then return result(player, "denied") end
    for _ = 1, units do torch:Use() end
    sync(player, torch)

    local now = KT.now()
    local id = KT.key(weapon)
    local e = D()[id] or {}
    local stress = KT.stress(e, now)
    local status = "ok"

    if stress > 0.001 then
        if ZombRandFloat(0, 100) < KT.breakChance(stress, player, weapon) then
            weapon:setCondition(0)
            if weapon:hasSharpness() then weapon:setSharpness(0) end
            D()[id] = nil; snaps[id] = nil
            sync(player, weapon); sendState(player, weapon)
            return result(player, "cracked")
        end
        local dmg = math.ceil(weapon:getConditionMax() * KT.opt("EarlyReheatDamagePercent", 15) / 100)
        weapon:setCondition(math.max(1, weapon:getCondition() - dmg))
        status = "damaged"
    end

    D()[id] = {
        untilT = now + KT.duration(weapon) / 60,
        stress = math.min(2, stress + 1),
        stressT = now,
    }
    snaps[id] = nil
    sync(player, weapon); sendState(player, weapon)
    result(player, status)
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= KT.MODULE then return end
    args = args or {}
    if command == "fx" then
        -- authoritative start: server validates, stamps, relays to nearby clients using ITS position data
        local ms = getTimestampMs()
        local last = started[player:getUsername()]
        if last and ms - last < 1500 then return end
        started[player:getUsername()] = ms
        sendServerCommand(KT.MODULE, "fx", { pid = player:getOnlineID(), x = player:getX(), y = player:getY(), z = player:getZ() })
    elseif command == "makeHattori" then -- admin / debug only
        local item = player:getInventory():getItemById(args.id or -1)
        local admin = (not isServer() and isDebugEnabled()) or (player.getAccessLevel and player:getAccessLevel() == "Admin")
        if admin and item and item:getFullType() == "Base.Katana" then makeHattori(player, item) end
    elseif command == "temper" then
        temper(player, args)
    elseif command == "query" then
        local item = player:getInventory():getItemById(args.id or -1)
        if item then sendState(player, item) end
    end
end)

-- Preventative Maintenance 2: wrap its repair/sharpen so the touched item is re-baselined deterministically
-- (its own changes can never be mistaken for combat wear). Done lazily: load order of the two mods is unknown.
local pm2Wrapped = false
local function wrapPM2()
    if pm2Wrapped or not PMTwoServer or not PMTwoServer.DoSharpen or not PMTwoServer.DoRepair then return end
    pm2Wrapped = true
    local sharpen, repair = PMTwoServer.DoSharpen, PMTwoServer.DoRepair
    PMTwoServer.DoSharpen = function(player, item, ...)
        local ok, err = pcall(sharpen, player, item, ...)
        if item then snaps[KT.key(item)] = nil end
        if not ok then error(err, 0) end
    end
    PMTwoServer.DoRepair = function(player, item, ...)
        local ok, err = pcall(repair, player, item, ...)
        if item then snaps[KT.key(item)] = nil end
        if not ok then error(err, 0) end
    end
end

Events.OnTick.Add(function()
    tick = tick + 1
    if tick % 5 == 0 then
        wrapPM2()
        for _, p in ipairs(players()) do guard(p) end
    end
    if tick % 3600 == 0 then -- prune spent entries
        local now, d = KT.now(), D()
        for k, e in pairs(d) do
            if type(e) == "table" and (e.untilT or 0) < now and KT.stress(e, now) <= 0 then d[k] = nil end
        end
    end
end)

-- extremely rare: a katana generated in a container may become the Hattori blade
Events.OnFillContainer.Add(function(room, ctype, container)
    if not KT.opt("HattoriEnabled", false) then return end -- default off: loot tables untouched
    local chance = KT.opt("HattoriChancePercent", 2)
    if chance <= 0 or not container then return end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if it:getFullType() == "Base.Katana" and not KT.isHattori(it) and ZombRandFloat(0, 100) < chance then
            makeHattori(nil, it)
        end
    end
end)
