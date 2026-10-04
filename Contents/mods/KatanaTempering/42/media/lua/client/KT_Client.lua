require "KT_Shared"
require "ISUI/ISModalDialog"

KT.cache = KT.cache or {}

-- one torch sound per character at a time: never overlaps itself (local or relayed)
local sounds = {}
function KT.stopTorch(p)
    local h = sounds[p]
    if h then pcall(function() p:getEmitter():stopSound(h) end) sounds[p] = nil end
end
function KT.playTorch(p)
    KT.stopTorch(p)
    sounds[p] = p:getEmitter():playSound("KT_TorchTemper")
    return sounds[p]
end

-- result message: shown in the draggable panel for MSG_MS (default 4.5s), halo if panel is hidden
KT.MSG_MS = 4500

local function findTorch(player)
    local items = player:getInventory():getAllTypeRecurse("BlowTorch")
    local units = KT.opt("TorchUnitsPerUse", 1)
    for i = 0, items:size() - 1 do
        local t = items:get(i)
        if (t:getCurrentUses() or 0) >= units then return t end
    end
end

local function begin(player, weapon, torch)
    ISInventoryPaneContextMenu.transferIfNeeded(player, weapon)
    ISInventoryPaneContextMenu.transferIfNeeded(player, torch)
    ISTimedActionQueue.add(KTTemperAction:new(player, weapon, torch))
end

local function onConfirm(_, button, player, weapon, torch)
    if button.internal == "YES" then begin(player, weapon, torch) end
end

local function startTemper(player, weapon)
    local torch = findTorch(player)
    if not torch then return end
    local stress = KT.stress(KT.cache[weapon:getID()], KT.now())
    if stress > 0.001 then
        local chance = math.floor(KT.breakChance(stress, player, weapon) + 0.5)
        local w, h = 380, 150
        local m = ISModalDialog:new(getCore():getScreenWidth() / 2 - w / 2, getCore():getScreenHeight() / 2 - h / 2, w, h,
            getText("UI_KT_Confirm", chance), true, nil, onConfirm, player:getPlayerNum(), player, weapon, torch)
        m:initialise(); m:addToUIManager()
    else
        begin(player, weapon, torch)
    end
end

Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    if not KT.opt("Enabled", true) then return end
    local player = getSpecificPlayer(playerNum)
    local weapon
    for _, v in ipairs(items) do
        local it = instanceof(v, "InventoryItem") and v or (v.items and v.items[1])
        if KT.isTarget(it) then weapon = it break end
    end
    if not weapon then return end
    sendClientCommand(player, KT.MODULE, "query", { id = weapon:getID() })

    if (isDebugEnabled() or isAdmin()) and weapon:getFullType() == "Base.Katana" then
        context:addOption(getText("ContextMenu_KT_MakeHattori"), nil, function()
            sendClientCommand(player, KT.MODULE, "makeHattori", { id = weapon:getID() })
        end)
    end
    local opt = context:addOption(getText("ContextMenu_KT_Temper"), player, startTemper, weapon)
    local tip = ISToolTip:new(); tip:initialise(); tip:setVisible(false)
    local now, e = KT.now(), KT.cache[weapon:getID()]
    local lines, ok = {}, true
    local left = KT.remainingMinutes(e, now)
    if left > 0 then lines[#lines + 1] = getText("UI_KT_Tempered", math.ceil(left)) end
    local stress = KT.stress(e, now)
    if stress > 0.001 then
        lines[#lines + 1] = getText("UI_KT_Stress", math.floor(stress * 100 + 0.5), math.floor(KT.breakChance(stress, player, weapon) + 0.5))
    end
    if not findTorch(player) then ok = false; lines[#lines + 1] = getText("UI_KT_NoTorch") end
    local skillOk, rm, rt, rw = KT.meetsSkills(player)
    if not skillOk then ok = false; lines[#lines + 1] = getText("UI_KT_NoSkill", rm, rt, rw) end
    if KT.opt("RequireWeldingMask", false) and not KT.hasMask(player) then ok = false; lines[#lines + 1] = getText("UI_KT_NoMask") end
    tip.description = table.concat(lines, " <LINE> ")
    opt.toolTip = tip
    if not ok then opt.notAvailable = true end
end)

local function say(player, key, good)
    local txt = getText("UI_KT_" .. key)
    if KTHud and KTHud.instance and not KTHud.hidden() then
        KT.msg = { txt = txt, good = good, untilMs = getTimestampMs() + KT.MSG_MS }
    elseif HaloTextHelper and (good and HaloTextHelper.addGoodText or HaloTextHelper.addBadText) then
        (good and HaloTextHelper.addGoodText or HaloTextHelper.addBadText)(player, txt)
    else
        player:Say(txt)
    end
end

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= KT.MODULE then return end
    if command == "state" then
        KT.cache[args.id] = { untilT = args.untilT, stress = args.stress, stressT = args.stressT }
    elseif command == "result" then
        say(getPlayer(), args.status, args.status == "ok")
    elseif command == "fx" and isClient() then -- other players' tempering (own is played locally)
        local me = getPlayer()
        if args.pid == me:getOnlineID() then return end
        local p = getPlayerByOnlineID(args.pid)
        if p and p:DistTo(me) < 25 then
            KT.playTorch(p)
            KTSparks.add(p, 300)
        end
    end
end)
