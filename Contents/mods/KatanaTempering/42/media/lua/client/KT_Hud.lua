require "ISUI/ISPanel"
require "KT_Shared"

-- Small draggable panel (never above the player). Position is saved in the character's modData
-- (survives relog). Shows while an eligible blade is tempered/heat-stressed, and for KT.MSG_MS after a result.
KTHud = ISPanel:derive("KTHud")

local options
local function opt(name)
    if not options then return false end
    local ok, v = pcall(function() return options:getOption(name):getValue() end)
    return ok and v or false
end
function KTHud.hidden() return opt("hideHud") end

if PZAPI and PZAPI.ModOptions then -- client preferences (B42 Mod Options screen)
    options = PZAPI.ModOptions:create("KatanaTempering", "Katana Tempering")
    options:addTickBox("hideHud", getText("UI_KT_OptHide"), false, getText("UI_KT_OptHideTip"))
    options:addTickBox("lockHud", getText("UI_KT_OptLock"), false, getText("UI_KT_OptLockTip"))
end

function KTHud:new(x, y)
    local o = ISPanel.new(self, x, y, 230, 34)
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.55 }
    o.borderColor = { r = 0.45, g = 0.45, b = 0.45, a = 0.8 }
    o.lastQuery, o.lastId = 0, nil
    return o
end

function KTHud:onMouseUp(x, y)
    ISPanel.onMouseUp(self, x, y)
    getPlayer():getModData().KTHud = { x = self:getX(), y = self:getY() }
end

function KTHud:update()
    ISPanel.update(self)
    self.moveWithMouse = not opt("lockHud")
    local p = getPlayer()
    local ms = getTimestampMs()
    self.msg = KT.msg and KT.msg.untilMs > ms and KT.msg or nil
    local item = p and p:getPrimaryHandItem()
    self.item = (item and KT.isTarget(item) and KT.opt("Enabled", true)) and item or nil
    self.mins, self.stress = 0, 0
    if self.item then
        local id = item:getID()
        if id ~= self.lastId or ms - self.lastQuery > 10000 then -- refresh authoritative state (also after relog)
            self.lastId, self.lastQuery = id, ms
            sendClientCommand(p, KT.MODULE, "query", { id = id })
        end
        local e, now = KT.cache[id], KT.now()
        self.mins, self.stress = KT.remainingMinutes(e, now), KT.stress(e, now)
    end
    local show = self.msg or (self.item and (self.mins > 0 or self.stress > 0.001))
    self:setVisible((show and not opt("hideHud")) and true or false)
    self:setHeight(self.msg and 52 or 34)
end

function KTHud:render()
    local y = 3
    if self.msg then
        local c = self.msg.good and { 0.5, 1, 0.5 } or { 1, 0.4, 0.3 }
        self:drawText(self.msg.txt, 8, y, c[1], c[2], c[3], 1, UIFont.Small)
        y = y + 18
    end
    if not self.item then return end
    local txt = self.mins > 0 and getText("UI_KT_HudTempered", math.ceil(self.mins)) or getText("UI_KT_HudHeat", math.floor(self.stress * 100 + 0.5))
    self:drawText(txt, 8, y, 1, self.mins > 0 and 0.75 or 0.5, 0.2, 1, UIFont.Small)
    local w, by = self.width - 16, y + 17
    self:drawRect(8, by, w, 3, 0.4, 0.15, 0.15, 0.15)
    self:drawRect(8, by, w * math.min(1, self.mins / math.max(1, KT.duration(self.item))), 3, 1, 1, 0.6, 0.1)
    self:drawRect(8, by + 6, w, 3, 0.4, 0.15, 0.15, 0.15)
    self:drawRect(8, by + 6, w * math.min(1, self.stress), 3, 1, 0.9, 0.2, 0.15)
end

Events.OnGameStart.Add(function()
    local md = getPlayer():getModData().KTHud
    local x = md and md.x or (getCore():getScreenWidth() - 260)
    local y = md and md.y or 200
    x = math.max(0, math.min(getCore():getScreenWidth() - 230, x))
    y = math.max(0, math.min(getCore():getScreenHeight() - 52, y))
    local hud = KTHud:new(x, y)
    hud:initialise(); hud:addToUIManager(); hud:setVisible(false)
    KTHud.instance = hud
end)
