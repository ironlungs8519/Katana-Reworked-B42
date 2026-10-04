require "ISUI/ISPanel"
require "KT_Shared"

-- Small draggable panel (not above the player). Position is saved in the character's modData,
-- so it survives relogs. Only visible while an eligible, tempered/heat-stressed weapon is equipped.
KTHud = ISPanel:derive("KTHud")

function KTHud:new(x, y)
    local o = ISPanel.new(self, x, y, 150, 34)
    o.backgroundColor = { r = 0, g = 0, b = 0, a = 0.55 }
    o.borderColor = { r = 0.45, g = 0.45, b = 0.45, a = 0.8 }
    o.moveWithMouse = true
    o.lastQuery, o.lastId = 0, nil
    return o
end

function KTHud:onMouseUp(x, y)
    ISPanel.onMouseUp(self, x, y)
    local md = getPlayer():getModData()
    md.KTHud = { x = self:getX(), y = self:getY() }
end

function KTHud:update()
    ISPanel.update(self)
    local p = getPlayer()
    local item = p and p:getPrimaryHandItem()
    if not (item and KT.isTarget(item)) or not KT.opt("Enabled", true) then self.item = nil; self:setVisible(false) return end
    local id, ms = item:getID(), getTimestampMs()
    if id ~= self.lastId or ms - self.lastQuery > 10000 then -- refresh authoritative state (also after relog)
        self.lastId, self.lastQuery = id, ms
        sendClientCommand(p, KT.MODULE, "query", { id = id })
    end
    local e, now = KT.cache[id], KT.now()
    self.mins, self.stress = KT.remainingMinutes(e, now), KT.stress(e, now)
    self.item = item
    self:setVisible(self.mins > 0 or self.stress > 0.001 or self.dragging)
end

function KTHud:render()
    if not self.item then return end
    local txt = self.mins > 0 and getText("UI_KT_HudTempered", math.ceil(self.mins)) or getText("UI_KT_HudHeat", math.floor(self.stress * 100 + 0.5))
    self:drawText(txt, 8, 3, 1, self.mins > 0 and 0.75 or 0.5, 0.2, 1, UIFont.Small)
    local w = self.width - 16
    self:drawRect(8, 20, w, 3, 0.4, 0.15, 0.15, 0.15)
    self:drawRect(8, 20, w * math.min(1, self.mins / math.max(1, KT.opt("DurationMinutes", 30))), 3, 1, 1, 0.6, 0.1)
    self:drawRect(8, 26, w, 3, 0.4, 0.15, 0.15, 0.15)
    self:drawRect(8, 26, w * math.min(1, self.stress), 3, 1, 0.9, 0.2, 0.15)
end

Events.OnGameStart.Add(function()
    local md = getPlayer():getModData().KTHud
    local x = md and md.x or (getCore():getScreenWidth() - 200)
    local y = md and md.y or 200
    x = math.max(0, math.min(getCore():getScreenWidth() - 150, x))
    y = math.max(0, math.min(getCore():getScreenHeight() - 34, y))
    local hud = KTHud:new(x, y)
    hud:initialise(); hud:addToUIManager(); hud:setVisible(false)
end)
