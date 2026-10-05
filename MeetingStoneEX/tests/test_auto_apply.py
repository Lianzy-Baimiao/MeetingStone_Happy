"""Headless WoW API scenarios. Requires lupa; runs against Lua 5.1."""
import argparse
from pathlib import Path
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--lua-runtime", help="Optional directory containing the lupa package")
args = parser.parse_args()
if args.lua_runtime:
    sys.path.insert(0, args.lua_runtime)
from lupa.lua51 import LuaRuntime

SOURCE = Path(__file__).resolve().parents[1] / "AutoApply.lua"
NOTE_SOURCE = SOURCE.with_name("AutoApplyNote.lua")
FIXTURE = r'''
clock, role, grouped, combat, category, cap = 0, 'HEALER', false, false, 2, 5
refreshCalls, deferSearch, blockedSearch, searchFocus = {}, false, false, false
results, states, pendingStates, roles, visible, calls, frames = {}, {}, {}, {}, {}, {}, {}
logs = {}
function print(message) logs[#logs + 1] = message end
deferApply, deferCancel, blockedApply, secret = false, false, false, {}
function BuildEnv() end
function issecretvalue(value) return value ~= nil and secret[value] == true end
function GetTime() return clock end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 1, '', '', '', role end
function IsInGroup() return grouped end
function InCombatLockdown() return combat end
function GameTooltip_Hide() end
GROUP_FINDER_CATEGORY_ID_DUNGEONS = 2
function CreateFrame(_, name, parent)
    local frame = { scripts = {}, shown = true, enabled = true, parent = parent, points = {}, registered = {} }
    function frame:SetSize(width, height) self.width, self.height = width, height end
    function frame:GetSize() return self.width or 210, self.height or 28 end
    function frame:SetPoint(...) self.points[#self.points + 1] = { ... } end
    function frame:ClearAllPoints() self.points = {} end
    function frame:GetNumPoints() return #self.points end
    function frame:GetPoint(index) return unpack(self.points[index]) end
    function frame:SetParent(parent) self.parent = parent end
    function frame:GetParent() return self.parent end
    function frame:SetFrameStrata() end
    function frame:EnableMouse() end
    function frame:SetBackdrop() end
    function frame:SetWidth() end
    function frame:SetWordWrap() end
    function frame:SetAutoFocus() end
    function frame:SetNumeric() end
    function frame:SetMaxLetters() end
    function frame:CreateFontString() return CreateFrame() end
    function frame:SetText(text) self.text = text end
    function frame:GetText() return self.text or '' end
    function frame:SetFocus() self.focused = true end
    function frame:ClearFocus() self.focused = false end
    function frame:SetScript(event, callback) self.scripts[event] = callback end
    function frame:GetScript(event) return self.scripts[event] end
    function frame:IsEnabled() return self.enabled end
    function frame:Enable() self.enabled = true end
    function frame:Disable() self.enabled = false end
    function frame:Hide()
        local wasShown = self.shown
        self.shown = false
        if wasShown and self.scripts.OnHide then self.scripts.OnHide(self) end
    end
    function frame:Show()
        local wasShown = self.shown
        self.shown = true
        if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function frame:SetShown(shown) if shown then self:Show() else self:Hide() end end
    function frame:RegisterEvent(event) self.registered[event] = true end
    function frame:IsShown() return self.shown end
    function frame:IsVisible() return self.shown end
    function frame:HookScript(event, callback)
        local original = self.scripts[event]
        self.scripts[event] = function(...)
            if original then original(...) end
            callback(...)
        end
    end
    frames[#frames + 1] = frame
    return frame
end
UIParent = CreateFrame()
LFGListApplicationDialog = CreateFrame('Frame', nil, UIParent)
LFGListApplicationDialog:Hide()
LFGListApplicationDialog.Description = CreateFrame('ScrollFrame', nil, LFGListApplicationDialog)
LFGListApplicationDialog.Description:SetSize(210, 28)
LFGListApplicationDialog.Description:SetPoint('BOTTOM', LFGListApplicationDialog, 'BOTTOM', 0, 55)
nativeNoteInput = CreateFrame('EditBox', nil, LFGListApplicationDialog.Description)
LFGListApplicationDialog.Description.EditBox = nativeNoteInput
function nativeNoteInput:SetText() error('native note input forbids SetText') end
function StaticPopupSpecial_Show(dialog) dialog:Show() end
function StaticPopupSpecial_Hide(dialog) dialog:Hide() end
panel = CreateFrame()
panel.SignUpButton = CreateFrame()
panel.SearchingBlocker = CreateFrame()
panel.SearchingBlocker.shown = false
panel.RefreshButton = CreateFrame()
panel.RefreshFilterButton = CreateFrame()
panel.SearchBox = { HasFocus = function() return searchFocus end }
function panel:DoSearch()
    self.SearchingBlocker.shown = true
    self.RefreshButton:Disable()
    self.RefreshFilterButton:Disable()
    self.refreshReadyAt = clock + 3
    service.inSearch = true
    if blockedSearch then error('search requires hardware action') end
    refreshCalls[#refreshCalls + 1] = clock
    if onSearch then onSearch() end
    if not deferSearch then finishSearch() end
end
panel.RefreshButton:SetScript('OnClick', function() panel:DoSearch() end)
panel.ActivityDropdown = { GetItem = function() return { categoryId = category } end }
local list = {}
function list:UpdateFilter()
    self.filtered = {}
    for _, id in ipairs(visible) do
        if not results[id].filteredOut then
            self.filtered[#self.filtered + 1] = {
                GetID = function() return id end,
                IsSelf = function() return results[id].isSelf end,
            }
        end
    end
end
function list:GetItemCount() return #self.filtered end
function list:GetItem(index) return self.filtered[index] end
panel.ActivityList = list
function panel:CheckSignUpStatus()
    local count = 0
    for id, status in pairs(states) do
        if status == 'applied' or status == 'invited' or pendingStates[id] == 'applied' then
            count = count + 1
        end
    end
    return count < cap, '申请名额已满'
end
service = {}
Addon = { GetModule = function(_, name) return name == 'BrowsePanel' and panel or service end }
C_LFGList = {}
function C_LFGList.ClearApplicationTextFields() nativeNoteInput.text = '' end
function C_LFGList.GetSearchResultInfo(id) return results[id] end
function C_LFGList.GetSearchResultMemberCounts(id) return roles[id] end
function C_LFGList.GetApplicationInfo(id) return id, states[id] or 'none', pendingStates[id] end
function C_LFGList.GetApplications()
    local ids = {}
    for id, status in pairs(states) do
        if status ~= 'none' then ids[#ids + 1] = id end
    end
    return ids
end
function C_LFGList.GetActivityInfoTable(id)
    return { categoryID = id == 999 and 3 or 2, maxNumPlayers = id == 888 and 10 or 5 }
end
function C_LFGList.ApplyToGroup(id, tank, healer, damage)
    if blockedApply then error('hardware action required') end
    calls[#calls + 1] = { 'apply', id, tank, healer, damage, nativeNoteInput:GetText() }
    if deferApply then pendingStates[id] = 'applied'
    else states[id] = 'applied' end
end
function C_LFGList.CancelApplication(id)
    calls[#calls + 1] = { 'cancel', id }
    if deferCancel then pendingStates[id] = 'cancelled'
    else states[id], pendingStates[id] = 'cancelled', nil end
end
function hooksecurefunc(object, method, callback)
    local original = object[method]
    object[method] = function(...)
        original(...)
        callback(...)
    end
end
function add(id, members, tank, healer, damage, leader, activityID)
    results[id] = { numMembers = members, isDelisted = false,
        leaderName = leader or ('Leader' .. id), activityIDs = { activityID or 100 } }
    roles[id] = { TANK = tank, HEALER = healer, DAMAGER = damage }
    visible[#visible + 1] = id
end
function tick()
    clock = clock + 1
    if panel.refreshReadyAt and clock >= panel.refreshReadyAt then
        panel.RefreshButton:Enable()
        panel.RefreshFilterButton:Enable()
    end
    panel.AutoApplyController:Step()
end
function finishSearch()
    service.inSearch = false
    panel.SearchingBlocker:Hide()
    event('LFG_LIST_SEARCH_RESULTS_RECEIVED')
end
function advance(seconds) for i = 1, seconds do tick() end end
function start() panel.AutoApplyController:Start() end
function event(name, id, status)
    for _, frame in ipairs(frames) do
        if frame.registered[name] and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, name, id, status)
        end
    end
end
'''

TESTS = {
    "button tooltip renders configured wait and finishes showing": '''
        GameTooltip = { lines = {} }
        function GameTooltip:SetOwner(owner) self.owner = owner end
        function GameTooltip:SetText(text) self.title = text; self.lines = {} end
        function GameTooltip:AddLine(text) self.lines[#self.lines + 1] = text end
        function GameTooltip:Show() self.shown = true end
        local controller, button = panel.AutoApplyController, panel.AutoApplyButton
        controller.maxWaitSeconds = 60
        button:GetScript('OnEnter')(button)
        assert(GameTooltip.shown and GameTooltip.owner == button and #GameTooltip.lines == 7)
        assert(GameTooltip.lines[5]:find('60'))
        controller:SetStatus('测试运行状态'); controller.active = true
        button:GetScript('OnEnter')(button)
        assert(#GameTooltip.lines == 8 and GameTooltip.lines[8] == '测试运行状态')
    ''',
    "default wait expires at five minutes and fills next slot": '''
        cap = 1; add(1, 4, 1, 0, 3); add(2, 2, 1, 0, 1); start()
        advance(299); assert(#calls == 1)
        tick(); assert(#calls == 2 and calls[2][1] == 'cancel' and calls[2][2] == 1)
        advance(2); assert(#calls == 3 and calls[3][1] == 'apply' and calls[3][2] == 2)
    ''',
    "note dialog configures wait with or without note": '''
        add(1, 4, 1, 0, 3); local controller = panel.AutoApplyController
        controller:RequestStart(); assert(controller.noteDialog.WaitInput:GetText() == '300')
        controller.noteDialog.WaitInput:SetText('30'); controller:ConfirmNote(false)
        advance(29); assert(#calls == 1); tick(); assert(calls[2][1] == 'cancel')
        controller:Stop(); controller:RequestStart()
        assert(controller.noteDialog.WaitInput:GetText() == '30')
        controller.noteDialog.WaitInput:SetText('60'); nativeNoteInput.text = '测试备注'
        controller:ConfirmNote(true); assert(controller.maxWaitSeconds == 60 and controller.active)
    ''',
    "invalid wait leaves dialog open and performs no operations": '''
        add(1, 4, 1, 0, 3); local controller = panel.AutoApplyController
        controller:RequestStart(); nativeNoteInput.text = '保留备注'
        for _, value in ipairs({ '', '0', '-1', '301', '1.5', 'abc' }) do
            controller.noteDialog.WaitInput:SetText(value); controller:ConfirmNote(false)
            assert(not controller.active and controller.noteDialog:IsShown() and #calls == 0)
            assert(nativeNoteInput:GetText() == '保留备注')
        end
        controller.noteDialog:Hide(); assert(controller.maxWaitSeconds == 300)
    ''',
    "each application has its own deadline": '''
        add(1, 4, 1, 0, 3); add(2, 3, 1, 0, 2)
        panel.AutoApplyController.maxWaitSeconds = 3; start(); tick(); tick()
        assert(#calls == 2); tick(); assert(calls[3][1] == 'cancel' and calls[3][2] == 1)
        tick(); assert(calls[4][1] == 'cancel' and calls[4][2] == 2)
    ''',
    "refresh and leader change preserve deadline and timeout blacklist": '''
        cap = 1; add(1, 4, 1, 0, 3, 'Leader-A'); results[1].partyGUID = 'Party-A'
        local controller = panel.AutoApplyController; controller.maxWaitSeconds = 10; start(); tick()
        states[1], results[1] = 'none', nil
        add(9, 4, 1, 0, 3, 'Leader-B'); results[9].partyGUID = 'Party-A'
        states[9], visible = 'applied', { 9 }; tick(); advance(7)
        assert(#calls == 1); tick(); assert(calls[2][1] == 'cancel' and calls[2][2] == 9)
        add(20, 4, 1, 0, 3, 'Leader-C'); results[20].partyGUID = 'Party-A'
        visible = { 20 }; advance(10); assert(#calls == 2)
    ''',
    "timeout waits for cancel confirmation before filling slot": '''
        cap = 1; deferCancel = true; add(1, 4, 1, 0, 3); add(2, 3, 1, 0, 2)
        panel.AutoApplyController.maxWaitSeconds = 2; start(); advance(3)
        assert(#calls == 2 and calls[2][1] == 'cancel')
        states[1], pendingStates[1] = 'cancelled', nil; tick()
        assert(#calls == 3 and calls[3][1] == 'apply' and calls[3][2] == 2)
    ''',
    "timeout does not withdraw invitations or manual applications": '''
        add(1, 4, 1, 0, 3); add(2, 4, 1, 0, 3); states[2] = 'applied'
        panel.AutoApplyController.maxWaitSeconds = 2; start()
        states[1] = 'invited'; advance(5); assert(#calls == 1)
        states[1] = 'invitedeclined'; tick(); assert(#calls == 1)
    ''',
    "expired while searching is cancelled when results return": '''
        add(1, 4, 1, 0, 3); panel.AutoApplyController.maxWaitSeconds = 2; start(); tick()
        deferSearch = true; panel:DoSearch(); advance(3); assert(#calls == 1)
        finishSearch(); tick(); assert(#calls == 2 and calls[2][1] == 'cancel')
    ''',
    "stop preserves application deadline on restart": '''
        add(1, 4, 1, 0, 3); local controller = panel.AutoApplyController
        controller.maxWaitSeconds = 3; start(); controller:Stop(); advance(5)
        assert(#calls == 1); start(); assert(#calls == 2 and calls[2][1] == 'cancel')
    ''',
    "priority and current role": '''
        add(1, 2, 1, 0, 1); add(2, 4, 1, 0, 3); add(3, 3, 1, 0, 2)
        start(); tick(); tick()
        assert(calls[1][2] == 2 and calls[2][2] == 3 and calls[3][2] == 1)
        assert(not calls[1][3] and calls[1][4] and not calls[1][5])
    ''',
    "uses filters and excludes full roles": '''
        add(1, 4, 1, 1, 2); add(2, 4, 1, 0, 3); results[2].filteredOut = true
        add(3, 2, 1, 0, 1); start(); assert(calls[1][2] == 3)
    ''',
    "tank and damage capacity": '''
        role = 'TANK'; add(1, 4, 1, 1, 2); add(2, 4, 0, 1, 3)
        start(); assert(calls[1][2] == 2 and calls[1][3]); panel.AutoApplyController:Stop()
        calls, visible, states = {}, {}, {}; role = 'DAMAGER'
        add(3, 4, 1, 0, 3); add(4, 4, 1, 1, 2)
        start(); assert(calls[1][2] == 4 and calls[1][5])
    ''',
    "cancels role filled even after removal from list": '''
        add(1, 4, 1, 0, 3); add(2, 2, 1, 0, 1); start()
        roles[1].HEALER, results[1].numMembers, visible = 1, 5, { 2 }
        tick(); assert(calls[2][1] == 'cancel' and calls[2][2] == 1)
        tick(); assert(calls[3][1] == 'apply' and calls[3][2] == 2)
    ''',
    "search transient status does not lose automatic application": '''
        add(1, 3, 1, 0, 2); start(); tick()
        deferSearch = true; panel:DoSearch(); states[1] = 'none'; tick()
        states[1], roles[1].HEALER, results[1].numMembers = 'applied', 1, 4
        finishSearch(); tick()
        assert(#calls == 2 and calls[2][1] == 'cancel' and calls[2][2] == 1)
    ''',
    "leader change keeps automatic application managed": '''
        add(1, 3, 1, 0, 2); start(); tick()
        results[1].leaderName, roles[1].HEALER, results[1].numMembers = 'NewLeader', 1, 4
        tick(); assert(#calls == 2 and calls[2][1] == 'cancel')
    ''',
    "automatic application follows refreshed result ID": '''
        add(1, 3, 1, 0, 2, 'SameLeader'); results[1].partyGUID = 'Party-A'
        start(); tick(); states[1] = 'none'; results[1] = nil
        add(9, 4, 1, 1, 2, 'NewLeader'); results[9].partyGUID = 'Party-A'
        states[9], visible = 'applied', { 9 }; tick()
        assert(#calls == 2 and calls[2][1] == 'cancel' and calls[2][2] == 9)
    ''',
    "automatic application remaps legacy identity without GUID": '''
        add(1, 3, 1, 0, 2, 'SameLeader'); start(); tick()
        states[1], results[1] = 'none', nil
        add(9, 4, 1, 1, 2, 'SameLeader'); states[9], visible = 'applied', { 9 }
        tick(); assert(#calls == 2 and calls[2][1] == 'cancel' and calls[2][2] == 9)
    ''',
    "missing leader still allows roster check for same party": '''
        add(1, 3, 1, 0, 2); results[1].partyGUID = 'Party-A'; start(); tick()
        results[1].leaderName, roles[1].HEALER, results[1].numMembers = '', 1, 4
        tick(); assert(#calls == 2 and calls[2][1] == 'cancel')
    ''',
    "reused ID with different party is never cancelled": '''
        add(1, 3, 1, 0, 2); results[1].partyGUID = 'Party-A'; start(); tick()
        results[1].partyGUID, roles[1].HEALER = 'Party-B', 1
        tick(); assert(#calls == 1)
    ''',
    "terminal application never adopts later manual application": '''
        add(1, 3, 1, 0, 2, 'SameLeader'); start(); tick()
        states[1] = 'declined'; event('LFG_LIST_APPLICATION_STATUS_UPDATED', 1, 'declined')
        add(9, 4, 1, 1, 2, 'SameLeader'); states[9], states[1], visible = 'applied', 'none', { 9 }
        tick(); assert(#calls == 1)
    ''',
    "manual cancellation skips group across refreshed IDs": '''
        add(1, 4, 1, 0, 3, 'Ad-Realm'); add(2, 3, 1, 0, 2); start()
        C_LFGList.CancelApplication(1)
        add(9, 4, 1, 0, 3, 'Ad-Realm'); visible = { 9, 2 }
        tick(); assert(calls[3][2] == 2)
        states[2] = 'declined'; tick(); assert(#calls == 3)
    ''',
    "manual cancel before automation reaches listing": '''
        add(1, 4, 1, 0, 3); add(2, 3, 1, 0, 2); start()
        states[2] = 'applied'; C_LFGList.CancelApplication(2)
        states[2] = 'none'; tick(); assert(#calls == 2)
    ''',
    "does not exceed application limit": '''
        cap = 1; add(1, 4, 1, 0, 3); add(2, 3, 1, 0, 2); start(); tick()
        assert(#calls == 1); states[1] = 'declined'; tick()
        assert(#calls == 2 and calls[2][2] == 2)
    ''',
    "waits for asynchronous application acknowledgement": '''
        deferApply = true; add(1, 4, 1, 0, 3); add(2, 3, 1, 0, 2); start()
        tick(); tick(); assert(#calls == 1)
        states[1], pendingStates[1] = 'applied', nil
        tick(); assert(#refreshCalls == 0 and #calls == 2)
    ''',
    "waits for cancellation to release slot": '''
        deferCancel = true; cap = 1; add(1, 4, 1, 0, 3); add(2, 3, 1, 0, 2)
        start(); C_LFGList.CancelApplication(1); tick(); assert(#calls == 2)
        states[1], pendingStates[1] = 'cancelled', nil
        tick(); assert(#calls == 3 and calls[3][2] == 2)
    ''',
    "preserves invitations even when role filled": '''
        add(1, 4, 1, 0, 3); add(2, 3, 1, 0, 2); start()
        states[1], roles[1].HEALER = 'invited', 1
        tick(); assert(#calls == 1 and panel.AutoApplyController.active)
        states[1] = 'invitedeclined'; tick(); assert(calls[2][2] == 2)
    ''',
    "stops immediately after accepting invitation": '''
        add(1, 4, 1, 0, 3); start(); event('LFG_LIST_APPLICATION_STATUS_UPDATED', 1, 'inviteaccepted')
        assert(not panel.AutoApplyController.active); tick(); assert(#calls == 1)
    ''',
    "does not cancel pre-existing manual applications": '''
        add(1, 4, 1, 1, 2); states[1] = 'applied'
        add(2, 3, 1, 0, 2); start(); tick()
        assert(#calls == 1 and calls[1][2] == 2)
    ''',
    "unknown roster never triggers withdrawal": '''
        add(1, 4, 1, 0, 3); start(); roles[1] = nil; tick()
        assert(#calls == 1 and panel.AutoApplyController.active)
    ''',
    "secret role counts are skipped": '''
        add(1, 4, 1, 0, 3); secret[roles[1]] = true
        start(); assert(#calls == 0 and panel.AutoApplyController.active)
    ''',
    "stops on unacknowledged submission": '''
        deferApply = true; add(1, 4, 1, 0, 3); start()
        for i = 1, 11 do tick() end
        assert(#calls == 1 and not panel.AutoApplyController.active)
    ''',
    "stops on protected API error": '''
        blockedApply = true; add(1, 4, 1, 0, 3); start()
        assert(not panel.AutoApplyController.active)
    ''',
    "stops on blocked addon action event": '''
        add(1, 4, 1, 0, 3); start(); event('ADDON_ACTION_BLOCKED', 'MeetingStoneEX')
        assert(not panel.AutoApplyController.active)
    ''',
    "pauses combat and search": '''
        combat = true; add(1, 4, 1, 0, 3); start(); assert(#calls == 0)
        combat = false; service.inSearch = true; tick(); assert(#calls == 0)
        service.inSearch = false; tick(); assert(#calls == 1)
    ''',
    "stops on spec change and joining group": '''
        add(1, 4, 1, 0, 3); start(); role = 'DAMAGER'; tick()
        assert(not panel.AutoApplyController.active)
        role = 'HEALER'; start(); grouped = true; event('GROUP_ROSTER_UPDATE')
        assert(not panel.AutoApplyController.active)
    ''',
    "stops on closing page or changing category": '''
        add(1, 4, 1, 0, 3); start(); panel.scripts.OnHide()
        assert(not panel.AutoApplyController.active)
        start(); category = 3; tick(); assert(not panel.AutoApplyController.active)
    ''',
    "no raids delisted or self listings": '''
        add(1, 4, 1, 0, 3, nil, 999); add(2, 4, 1, 0, 3, nil, 888)
        add(3, 4, 1, 0, 3); results[3].isDelisted = true
        add(4, 4, 1, 0, 3); results[4].isSelf = true
        add(5, 2, 1, 0, 1); start(); assert(calls[1][2] == 5)
    ''',
    "restart clears manual exclusions": '''
        add(1, 4, 1, 0, 3); start(); C_LFGList.CancelApplication(1)
        panel.AutoApplyController:Stop(); states[1] = 'none'; start()
        assert(#calls == 3 and calls[3][1] == 'apply')
    ''',
    "a reused ID with different leader remains eligible": '''
        add(1, 4, 1, 0, 3, 'Ad-Realm'); start(); C_LFGList.CancelApplication(1)
        results[1].leaderName, states[1] = 'NewLeader-Realm', 'none'
        tick(); assert(#calls == 3 and calls[3][1] == 'apply')
    ''',
    "stop preserves applications and restart resumes tracking": '''
        add(1, 4, 1, 0, 3); start(); panel.AutoApplyController:Stop()
        assert(#calls == 1 and states[1] == 'applied')
        roles[1].HEALER, results[1].numMembers = 1, 5
        start(); assert(#calls == 2 and calls[2][1] == 'cancel')
    ''',
    "withdrawn full group is not retried when slot reopens": '''
        add(1, 4, 1, 0, 3); start(); roles[1].HEALER = 1; tick()
        roles[1].HEALER, states[1] = 0, 'none'; tick()
        assert(#calls == 2 and calls[2][1] == 'cancel')
    ''',
    "delisted managed group is withdrawn": '''
        add(1, 4, 1, 0, 3); start(); results[1].isDelisted = true; tick()
        assert(#calls == 2 and calls[2][1] == 'cancel')
    ''',
    "missing spec and non-dungeon startup are refused": '''
        add(1, 4, 1, 0, 3); role = nil; start()
        assert(not panel.AutoApplyController.active and #calls == 0)
        role, category = 'HEALER', 3; start()
        assert(not panel.AutoApplyController.active and #calls == 0)
    ''',
    "manual application dialog pauses submission": '''
        LFGListApplicationDialog = CreateFrame(); add(1, 4, 1, 0, 3)
        start(); assert(#calls == 0)
        LFGListApplicationDialog.shown = false; tick(); assert(#calls == 1)
    ''',
    "automatic refresh waits seven seconds between searches": '''
        start(); advance(6); assert(#refreshCalls == 0)
        tick(); assert(#refreshCalls == 1 and refreshCalls[1] == 7)
        advance(6); assert(#refreshCalls == 1)
        tick(); assert(#refreshCalls == 2 and refreshCalls[2] == 14)
    ''',
    "disabled refresh button postpones automatic search": '''
        start(); panel.RefreshButton:Disable()
        advance(8)
        assert(#refreshCalls == 0)
        panel.RefreshButton:Enable(); tick(); assert(#refreshCalls == 1)
    ''',
    "search requests never overlap": '''
        deferSearch = true; start(); advance(7)
        advance(8)
        assert(#refreshCalls == 1)
        finishSearch(); tick(); assert(#refreshCalls == 2)
    ''',
    "automatic refresh finds new groups and applies": '''
        onSearch = function() add(1, 4, 1, 0, 3) end
        start(); advance(7); assert(#calls == 0)
        tick(); assert(#calls == 1 and calls[1][2] == 1)
    ''',
    "automatic refresh preserves filters and manual exclusions": '''
        add(1, 4, 1, 0, 3, 'Ad-Realm'); start(); C_LFGList.CancelApplication(1)
        onSearch = function()
            add(9, 4, 1, 0, 3, 'Ad-Realm'); add(2, 4, 1, 0, 3); results[2].filteredOut = true
            add(3, 2, 1, 0, 1); visible = { 9, 2, 3 }
        end
        advance(8)
        assert(#refreshCalls == 1 and #calls == 3 and calls[3][2] == 3)
    ''',
    "refresh continues when application slots are full": '''
        cap = 1; add(1, 4, 1, 0, 3); start(); advance(7)
        assert(#refreshCalls == 1 and #calls == 1)
    ''',
    "manual refresh also postpones next automatic search": '''
        start(); tick(); panel.RefreshButton:GetScript('OnClick')()
        advance(6); assert(#refreshCalls == 1)
        tick(); assert(#refreshCalls == 2 and refreshCalls[2] == 8)
    ''',
    "invitations combat and stop pause automatic refresh": '''
        add(1, 4, 1, 0, 3); start(); states[1] = 'invited'
        for i = 1, 4 do tick() end; assert(#refreshCalls == 0)
        states[1] = 'applied'; combat = true
        for i = 1, 4 do tick() end; assert(#refreshCalls == 0)
        combat = false; tick(); assert(#refreshCalls == 1)
        panel.AutoApplyController:Stop()
        for i = 1, 4 do tick() end; assert(#refreshCalls == 1)
    ''',
    "typing search terms pauses automatic refresh": '''
        searchFocus = true; start()
        advance(8); assert(#refreshCalls == 0)
        searchFocus = false; tick(); assert(#refreshCalls == 1)
    ''',
    "refresh error restores search controls": '''
        blockedSearch = true; start(); advance(7)
        assert(not panel.AutoApplyController.active and not service.inSearch)
        assert(not panel.SearchingBlocker:IsShown() and panel.RefreshButton:IsEnabled())
        assert(panel.RefreshFilterButton:IsEnabled())
    ''',
    "unanswered automatic search restores controls and stops": '''
        deferSearch = true; start()
        advance(17)
        assert(#refreshCalls == 1 and not panel.AutoApplyController.active)
        assert(not service.inSearch and not panel.SearchingBlocker:IsShown())
        assert(panel.RefreshButton:IsEnabled())
    ''',
    "blocked refresh action restores controls": '''
        deferSearch = true; start(); advance(7)
        event('ADDON_ACTION_BLOCKED', 'MeetingStoneEX')
        assert(not panel.AutoApplyController.active and not service.inSearch)
        assert(not panel.SearchingBlocker:IsShown() and panel.RefreshButton:IsEnabled())
    ''',
    "restart during search retains response timeout": '''
        deferSearch = true; start(); advance(7)
        panel.AutoApplyController:Stop(); start()
        for i = 1, 10 do tick() end
        assert(not panel.AutoApplyController.active and #refreshCalls == 1)
        assert(not service.inSearch and panel.RefreshButton:IsEnabled())
    ''',
    "start button prompts before any automatic operation": '''
        add(1, 4, 1, 0, 3); panel.AutoApplyButton:GetScript('OnClick')()
        local controller = panel.AutoApplyController
        assert(controller.noteDialog:IsShown() and not controller.active)
        for i = 1, 4 do tick() end
        assert(#calls == 0 and #refreshCalls == 0)
        assert(LFGListApplicationDialog.Description:GetParent() == controller.noteDialog)
    ''',
    "confirmed note is reused for all applications": '''
        add(1, 4, 1, 0, 3); add(2, 3, 1, 0, 2)
        local controller = panel.AutoApplyController
        controller:RequestStart(); nativeNoteInput.text = '熟练治疗，有经验'
        controller.noteDialog.WithNoteButton:GetScript('OnClick')(); tick()
        assert(controller.active and not controller.noteDialog:IsShown())
        assert(#calls == 2 and calls[1][6] == '熟练治疗，有经验' and calls[2][6] == calls[1][6])
        assert(LFGListApplicationDialog.Description:GetParent() == LFGListApplicationDialog)
        local width, height = LFGListApplicationDialog.Description:GetSize()
        assert(width == 210 and height == 28)
        local point, relative, relativePoint, x, y = LFGListApplicationDialog.Description:GetPoint(1)
        assert(point == 'BOTTOM' and relative == LFGListApplicationDialog and y == 55)
    ''',
    "no-note choice clears stale native note": '''
        nativeNoteInput.text = '旧备注'; add(1, 4, 1, 0, 3)
        local controller = panel.AutoApplyController
        controller:RequestStart(); controller.noteDialog.WithoutNoteButton:GetScript('OnClick')()
        assert(controller.active and calls[1][6] == '' and nativeNoteInput:GetText() == '')
    ''',
    "cancel leaves automation off and restores manual input": '''
        nativeNoteInput.text = '保留备注'; local controller = panel.AutoApplyController
        controller:RequestStart(); controller.noteDialog.CancelButton:GetScript('OnClick')()
        assert(not controller.active and #calls == 0 and not controller.noteDialog:IsShown())
        assert(nativeNoteInput:GetText() == '保留备注')
        assert(LFGListApplicationDialog.Description:GetParent() == LFGListApplicationDialog)
    ''',
    "escape or closing browser page cancels note prompt": '''
        local controller = panel.AutoApplyController
        controller:RequestStart(); assert(controller.noteDialog.hideOnEscape)
        StaticPopupSpecial_Hide(controller.noteDialog)
        assert(not controller.active and not controller.noteInputLayout)
        controller:RequestStart(); panel.scripts.OnHide()
        assert(not controller.noteDialog:IsShown() and not controller.noteInputLayout)
    ''',
    "blank note needs explicit no-note choice": '''
        add(1, 4, 1, 0, 3); local controller = panel.AutoApplyController
        controller:RequestStart(); nativeNoteInput.text = '   '
        controller:ConfirmNote(true)
        assert(not controller.active and controller.noteDialog:IsShown() and #calls == 0)
        controller:ConfirmNote(false); assert(controller.active and calls[1][6] == '')
    ''',
    "native note change stops future automatic submissions": '''
        add(1, 4, 1, 0, 3); add(2, 3, 1, 0, 2); nativeNoteInput.text = '已确认'
        start(); nativeNoteInput.text = '后来修改'; tick()
        assert(not panel.AutoApplyController.active and #calls == 1)
        assert(panel.AutoApplyController.message:find('备注'))
    ''',
    "restart prompts again and retains native note draft": '''
        local controller = panel.AutoApplyController
        controller:RequestStart(); nativeNoteInput.text = '本次备注'; controller:ConfirmNote(true)
        panel.AutoApplyButton:GetScript('OnClick')(); assert(not controller.active)
        panel.AutoApplyButton:GetScript('OnClick')()
        assert(controller.noteDialog:IsShown() and not controller.active)
        assert(nativeNoteInput:GetText() == '本次备注')
    ''',
    "opening manual application restores borrowed note input": '''
        local controller = panel.AutoApplyController
        controller:RequestStart(); LFGListApplicationDialog:Show()
        assert(not controller.noteDialog:IsShown() and not controller.active)
        assert(LFGListApplicationDialog.Description:GetParent() == LFGListApplicationDialog)
    ''',
    "start eligibility is rechecked after editing note": '''
        add(1, 4, 1, 0, 3); local controller = panel.AutoApplyController
        controller:RequestStart(); grouped = true; controller:ConfirmNote(false)
        assert(not controller.active and #calls == 0 and not controller.noteDialog:IsShown())
    ''',
    "existing manual dialog is never borrowed": '''
        LFGListApplicationDialog:Show(); panel.AutoApplyController:RequestStart()
        assert(not panel.AutoApplyController.noteInputLayout and not panel.AutoApplyController.active)
        assert(LFGListApplicationDialog.Description:GetParent() == LFGListApplicationDialog)
    ''',
}

for name, scenario in TESTS.items():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute(FIXTURE)
    lua.execute(SOURCE.read_text(encoding="utf-8"))
    lua.execute(NOTE_SOURCE.read_text(encoding="utf-8"))
    try:
        lua.execute(scenario)
    except Exception as error:
        raise RuntimeError(f"FAIL: {name}") from error
    print(f"PASS: {name}")
print(f"{len(TESTS)} scenarios passed (Lua 5.1).")
