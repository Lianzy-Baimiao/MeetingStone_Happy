
local WIDGET, VERSION = 'AutoHideController', 2

local GUI = LibStub('NetEaseGUI-2.0')
local AutoHideController = GUI:NewClass('AutoHideController', 'Frame', VERSION)
if not AutoHideController then
    return
end

LibStub('AceTimer-3.0'):Embed(AutoHideController)

AutoHideController._Objects = AutoHideController._Objects or {}
AutoHideController.ESCHandler = AutoHideController.ESCHandler or CreateFrame('Frame', nil, UIParent)
AutoHideController.ESCHandler:Hide()

-- SetPropagateKeyboardInput is blocked in combat (ADDON_ACTION_BLOCKED). Keys pass
-- through by default; only ESC that closes a menu out of combat is kept from the game.
local function PassKeys(frame)
    if not InCombatLockdown() and not frame:GetPropagateKeyboardInput() then
        frame:SetPropagateKeyboardInput(true)
    end
end

PassKeys(AutoHideController.ESCHandler)
AutoHideController.ESCHandler:SetScript('OnShow', PassKeys)
AutoHideController.ESCHandler:SetScript('OnKeyDown', function(self, key)
    if key ~= GetBindingKey('TOGGLEGAMEMENU') then
        return
    end
    local found = false
    for object in pairs(AutoHideController._Objects) do
        if object:IsVisible() then
            object:OnTimer()
            found = true
        end
    end
    self:Hide()
    if found and not InCombatLockdown() then
        self:SetPropagateKeyboardInput(false)
    end
end)


function AutoHideController:Constructor()
    self:SetScript('OnUpdate', self.OnUpdate)
    self:SetScript('OnHide', self.OnTimer)
    self:SetScript('OnShow', self.OnShow)
    self._Objects[self] = true
end

function AutoHideController:GetOwner()
    return self:GetParent():GetOwner()
end

function AutoHideController:IsOwnerVisible()
    return self:GetOwner() and self:GetOwner():IsVisible()
end

function AutoHideController:IsOwnerOver()
    return self:GetOwner() and self:GetOwner():IsMouseOver()
end

function AutoHideController:IsMenuOver()
    return self:GetParent():IsMouseOver()
end

function AutoHideController:OnUpdate(elapsed)
    if not self:IsOwnerVisible() or self:Fire('OnUpdateCheck') then
        return self:OnTimer()
    end
    
    self.updater = (self.updater or 0) - elapsed
    if self.updater > 0 then
        return
    end
    self.updater = 0.5

    if self:IsOwnerOver() or self:IsMenuOver() then
        self:CancelAllTimers()
        self.timer = nil
    elseif not self.timer then
        self.timer = self:ScheduleTimer('OnTimer', self:GetAutoHideDelay())
    end
end

function AutoHideController:OnTimer()
    self:GetParent():Hide()
    self:CancelAllTimers()
    self.timer = nil
end

function AutoHideController:OnShow()
    -- In combat the handler cannot let keys through again; while it would keep
    -- them, leave it hidden (ESC then reaches the game, the menu still auto-hides).
    if InCombatLockdown() and not self.ESCHandler:GetPropagateKeyboardInput() then
        return
    end
    self.ESCHandler:Show()
end

function AutoHideController:SetAutoHideDelay(delay)
    self.autoHideDelay = delay
end

function AutoHideController:GetAutoHideDelay()
    return self.autoHideDelay or 1.5
end
