BuildEnv(...)

-- Only uses the normal LFG API; no simulated clicks or protected-action bypasses.
local BrowsePanel = Addon:GetModule('BrowsePanel')
local LfgService = Addon:GetModule('LfgService')
local Controller = { tracked = {}, skipped = {}, skippedIDs = {}, skippedGUIDs = {}, maxWaitSeconds = 300 }
BrowsePanel.AutoApplyController = Controller

local ROLE_LIMIT = { TANK = 1, HEALER = 1, DAMAGER = 3 }
local ROLE_NAME = { TANK = '坦克', HEALER = '治疗', DAMAGER = '输出' }
local REFRESH_INTERVAL = 7
-- The once-a-second driver runs only while active (set in Start, cleared in Stop).
local ticker, OnTick
local function Public(value)
    return not issecretvalue or not issecretvalue(value)
end

local function CurrentRole()
    local spec = GetSpecialization()
    return spec and select(5, GetSpecializationInfo(spec))
end

local function ApplicationNote()
    local dialog = LFGListApplicationDialog
    local editBox = dialog and dialog.Description and dialog.Description.EditBox
    return editBox and editBox:GetText()
end

local function Result(id)
    local info = C_LFGList.GetSearchResultInfo(id)
    if not info or not Public(info) or not Public(info.activityIDs) or
        not Public(info.leaderName) or not Public(info.numMembers) or
        not Public(info.isDelisted) then
        return
    end
    local activityID = info.activityIDs and info.activityIDs[1]
    if not activityID or not Public(activityID) then
        return
    end
    -- A result ID can change after a search. Keep manual exclusions across refreshes.
    local key = info.leaderName and info.leaderName ~= '' and
        (info.leaderName .. '\031' .. tostring(activityID)) or nil
    return info, key, activityID
end

local function PartyGUID(info)
    local guid = info and info.partyGUID
    return Public(guid) and type(guid) == 'string' and guid ~= '' and guid or nil
end

local function Finished(status)
    return status == 'cancelled' or status == 'declined' or status == 'declined_full' or
        status == 'declined_delisted' or status == 'failed' or status == 'timeout' or
        status == 'timedout' or status == 'invitedeclined'
end

local function Application(id)
    local _, status, pending = C_LFGList.GetApplicationInfo(id)
    if not Public(status) or not Public(pending) then
        return nil, nil, false
    end
    return status or 'none', pending, true
end

local function Waiting(status, pending)
    return status == 'applied' or pending == 'applied'
end

local function Invited(status, pending)
    return status == 'invited' or pending == 'invited' or
        status == 'inviteaccepted' or pending == 'inviteaccepted'
end

local function HasRoom(id, info, role)
    local counts = C_LFGList.GetSearchResultMemberCounts(id)
    if not counts or not Public(counts) or not Public(counts[role]) or
        type(counts[role]) ~= 'number' or type(info.numMembers) ~= 'number' then
        return nil
    end
    return info.numMembers < 5 and counts[role] < ROLE_LIMIT[role]
end

function Controller:SetStatus(message)
    self.message = message
end

function Controller:Stop(message)
    self.active = false
    if ticker then
        ticker:SetScript('OnUpdate', nil)
    end
    self.button:SetText('自动申请')
    self:SetStatus(message or '已停止；已提交的申请保留，可手动取消。')
end

function Controller:GetStartRole()
    local item = BrowsePanel.ActivityDropdown:GetItem()
    if not item or item.categoryId ~= GROUP_FINDER_CATEGORY_ID_DUNGEONS then
        return nil, '请先选择地下城，并设置好过滤条件。'
    end
    if IsInGroup() then
        return nil, '请在未组队时开启自动申请。'
    end
    local role = CurrentRole()
    if not ROLE_LIMIT[role] then
        return nil, '无法识别当前专精职责，请先选择专精。'
    end
    return role
end

function Controller:Start()
    local role, reason = self:GetStartRole()
    if not role then
        self:SetStatus(reason)
        print('|cff00ff00集合石自动申请：|r' .. self.message)
        return
    end
    self.role = role
    self.note = ApplicationNote()
    -- Continue managing our outstanding applications after a stop/start.
    -- Pre-existing manual applications are never added to this table.
    self.skipped, self.skippedIDs, self.skippedGUIDs = {}, {}, {}
    self.pending = nil
    if not LfgService.inSearch and not BrowsePanel.SearchingBlocker:IsShown() then
        self.refreshStarted = nil
    end
    self.nextRefreshAt = GetTime() + REFRESH_INTERVAL
    self.active = true
    self.elapsed = 0
    if ticker then
        ticker:SetScript('OnUpdate', OnTick)
    end
    self.button:SetText('停止申请')
    self:SetStatus('按' .. ROLE_NAME[role] .. '职责自动申请中。')
    self:Step()
end

function Controller:Exclude(id)
    if not self.active then
        return
    end
    local info, key = Result(id)
    local tracked = self.tracked[id]
    key = key or (tracked and tracked.key)
    if key then
        self.skipped[key] = true
    end
    local guid = PartyGUID(info) or (tracked and tracked.guid)
    if guid then
        self.skippedGUIDs[guid] = true
    end
    self.skippedIDs[id] = key or true
end

function Controller:ForgetApplication(id)
    -- A cancelled result can have a new ID before the next tracking sync.
    local info, key = Result(id)
    local guid = PartyGUID(info)
    self:Exclude(id)
    for trackedID, tracked in pairs(self.tracked) do
        local sameParty
        if guid and tracked.guid then
            sameParty = guid == tracked.guid
        else
            sameParty = key and key == tracked.key
        end
        if trackedID == id or sameParty then
            self:Exclude(trackedID)
            self.tracked[trackedID] = nil
        end
    end
end

function Controller:ManualCancel(id)
    if self.autoCancel then
        return
    end
    -- Stopping disables actions, not ownership cleanup for later manual requests.
    self:ForgetApplication(id)
    if not self.active then
        return
    end
    -- Wait for the server to release the application slot before filling it.
    self.pending = { id = id, action = 'cancel', at = GetTime() }
    self:SetStatus('已跳过手动取消的队伍，等待补申。')
end

function Controller:ResetSearch()
    -- DoSearch changes these before calling the game API. Restore the controls
    -- if our automatic search throws or never receives a response.
    self.refreshStarted = nil
    LfgService.inSearch = false
    LfgService.ourSearch = false
    BrowsePanel.SearchingBlocker:Hide()
    BrowsePanel.RefreshButton:Enable()
    BrowsePanel.RefreshFilterButton:Enable()
end

function Controller:RefreshSearch()
    local refresh = BrowsePanel.RefreshButton
    if GetTime() < self.nextRefreshAt or not refresh:IsEnabled() or
        BrowsePanel.inUpdateFilters or BrowsePanel.searchedInFrame then
        return false
    end
    local onClick = refresh:GetScript('OnClick')
    if not onClick then
        return false
    end
    self.nextRefreshAt = GetTime() + REFRESH_INTERVAL
    self.refreshStarted = GetTime()
    self:SetStatus('正在自动刷新地下城队伍。')
    -- Call the existing handler so its filters and built-in cooldown still apply.
    local ok, err = pcall(onClick, refresh, 'LeftButton')
    if not ok or not self.active then
        self:ResetSearch()
        if not ok then
            self:Stop('自动刷新接口不可用，已停止；请尝试手动刷新。')
            print('|cff00ff00集合石自动申请：|r' .. self.message .. ' ' .. tostring(err))
        end
    elseif not LfgService.inSearch and not BrowsePanel.SearchingBlocker:IsShown() then
        self.refreshStarted = nil
    end
    return true
end

function Controller:SyncTracked(applications)
    -- Refreshes can replace result IDs; leadership changes can replace names.
    -- Only recover requests we submitted, using the party GUID when available.
    local recovered = {}
    for id, tracked in pairs(self.tracked) do
        local status, pending, known = Application(id)
        local info, key = Result(id)
        local guid = PartyGUID(info)
        local differentParty = tracked.guid and guid and tracked.guid ~= guid
        if known and Finished(status) and not Waiting(status, pending) then
            -- A terminal result must never adopt a later manual application.
        elseif known and Waiting(status, pending) and not differentParty then
            tracked.key = key or tracked.key
            tracked.guid = guid or tracked.guid
            tracked.missingSince = nil
            recovered[id] = tracked
        else
            local match
            for _, currentID in ipairs(applications) do
                local currentStatus, currentPending, currentKnown = Application(currentID)
                local currentInfo, currentKey = Result(currentID)
                local currentGUID = PartyGUID(currentInfo)
                local sameParty
                if tracked.guid and currentGUID then
                    sameParty = tracked.guid == currentGUID
                else
                    sameParty = tracked.key and tracked.key == currentKey
                end
                if currentKnown and Waiting(currentStatus, currentPending) and sameParty then
                    if match then
                        match = nil -- Ambiguous identity: do not cancel either listing.
                        break
                    end
                    match = currentID
                end
            end
            if match then
                local currentInfo, currentKey = Result(match)
                tracked.key = currentKey or tracked.key
                tracked.guid = PartyGUID(currentInfo) or tracked.guid
                tracked.missingSince = nil
                recovered[match] = tracked
            elseif not differentParty then
                -- A temporary 'none' is not confirmation of a withdrawal.
                tracked.missingSince = tracked.missingSince or GetTime()
                if not known or GetTime() - tracked.missingSince < 10 then
                    recovered[id] = tracked
                end
            end
        end
    end
    self.tracked = recovered
end

function Controller:Run()
    if not self.active then
        return
    end
    if not BrowsePanel:IsVisible() then
        self:Stop('查找页面已关闭，自动申请已停止。')
        return
    end
    if IsInGroup() then
        self:Stop('已进入队伍，自动申请已停止。')
        return
    end
    if CurrentRole() ~= self.role then
        self:Stop('专精职责已改变，请重新开启自动申请。')
        return
    end
    local item = BrowsePanel.ActivityDropdown:GetItem()
    if not item or item.categoryId ~= GROUP_FINDER_CATEGORY_ID_DUNGEONS then
        self:Stop('已离开地下城分类，自动申请已停止。')
        return
    end
    if InCombatLockdown() then
        self:SetStatus('战斗中暂停，脱战后继续。')
        return
    end
    if self.note ~= nil and ApplicationNote() ~= self.note then
        self:Stop('申请备注已被修改，请重新开启并确认备注。')
        print('|cff00ff00集合石自动申请：|r' .. self.message)
        return
    end

    if self.partyInvitePending then
        self:SetStatus('收到组队邀请，暂停申请；请处理邀请。')
        return
    end
    -- Never withdraw an invitation because its roster already includes the player.
    local applications = C_LFGList.GetApplications() or {}
    for _, id in ipairs(applications) do
        local status, pending, known = Application(id)
        if not known then
            self:SetStatus('队伍数据暂不可读取，等待更新。')
            return
        end
        if Invited(status, pending) then
            self:SetStatus('收到组队邀请，暂停申请；请处理邀请。')
            return
        end
    end

    -- Do not discard application identities while the search cache is changing.
    if LfgService.inSearch or BrowsePanel.SearchingBlocker:IsShown() then
        if self.refreshStarted and GetTime() - self.refreshStarted >= 10 then
            self:ResetSearch()
            self:Stop('自动刷新未收到游戏响应，已停止；请尝试手动刷新。')
            print('|cff00ff00集合石自动申请：|r' .. self.message)
            return
        end
        self:SetStatus('等待搜索结果。')
        return
    end
    self.refreshStarted = nil

    -- Pauses cover withdrawals as well as new applications and searches.
    if LFGListApplicationDialog and LFGListApplicationDialog:IsShown() then
        self:SetStatus('正在手动申请，暂时暂停。')
        return
    end
    if BrowsePanel.SearchBox and BrowsePanel.SearchBox:HasFocus() then
        self:SetStatus('正在编辑搜索条件，暂时暂停。')
        return
    end

    if self.pending then
        local request = self.pending
        local status, pending, known = Application(request.id)
        if not known then
            return
        end
        local done
        if request.action == 'apply' then
            done = status ~= 'none' or (pending and pending ~= 'applied')
        else
            done = not Waiting(status, pending) and pending ~= 'cancelled'
        end
        if done then
            self.pending = nil
        elseif GetTime() - request.at >= 10 then
            self:Stop('游戏未确认申请操作，已停止；请尝试手动申请。')
            print('|cff00ff00集合石自动申请：|r' .. self.message)
            return
        else
            self:SetStatus('等待游戏确认上一项申请操作。')
            return
        end
    end

    self:SyncTracked(applications)
    -- Read live results even when MeetingStone removed a full group from its cache.
    for id, tracked in pairs(self.tracked) do
        local status, pending, known = Application(id)
        if known then
            if Waiting(status, pending) and not pending then
                local info = Result(id)
                local expired = tracked.waitDeadline and GetTime() >= tracked.waitDeadline
                if expired or (info and (info.isDelisted or HasRoom(id, info, tracked.role) == false)) then
                    self:Exclude(id)
                    self.pending = { id = id, action = 'cancel', at = GetTime() }
                    self.autoCancel = true
                    local ok, err = pcall(C_LFGList.CancelApplication, id)
                    self.autoCancel = false
                    if not ok then
                        error(err)
                    end
                    self:SetStatus(expired and '已超过最大等待时间，加入本轮黑名单，撤销后补申。' or
                        '职责名额已满或队伍已下架，撤销后补申。')
                    return
                end
            end
        end
    end

    -- Refresh even at the application cap, so roster changes remain discoverable.
    if self:RefreshSearch() then
        return
    end
    local usable, reason = BrowsePanel:CheckSignUpStatus(nil, true)
    if not usable then
        self:SetStatus(reason or '等待可用的申请名额。')
        return
    end

    -- Use the complete filtered list, including rows below the scroll viewport.
    local list = BrowsePanel.ActivityList
    list:UpdateFilter()
    local candidates = {}
    for index = 1, list:GetItemCount() do
        local activity = list:GetItem(index)
        local id = activity:GetID()
        local info, key, activityID = Result(id)
        local guid = PartyGUID(info)
        local status, pending, known = Application(id)
        local oldKey = self.skippedIDs[id]
        local excluded = oldKey == true or oldKey == key
        if info and key and not info.isDelisted and not self.skipped[key] and
            not (guid and self.skippedGUIDs[guid]) and not excluded and
            known and status == 'none' and not pending and not activity:IsSelf() then
            local details = C_LFGList.GetActivityInfoTable(activityID)
            if details and Public(details) and Public(details.categoryID) and Public(details.maxNumPlayers) and
                details.categoryID == GROUP_FINDER_CATEGORY_ID_DUNGEONS and details.maxNumPlayers == 5 and
                HasRoom(id, info, self.role) then
                candidates[#candidates + 1] = { id = id, key = key, guid = guid, members = info.numMembers }
            end
        end
    end
    table.sort(candidates, function(a, b)
        if a.members ~= b.members then
            return a.members > b.members
        end
        return a.id < b.id
    end)
    local candidate = candidates[1]
    if not candidate then
        self:SetStatus('暂无符合条件的队伍，等待下一次自动刷新。')
        return
    end
    -- Attempt each listing once per session, including declines and timeouts.
    self.skipped[candidate.key] = true
    self.tracked[candidate.id] = {
        key = candidate.key, guid = candidate.guid, role = self.role,
        waitDeadline = GetTime() + self.maxWaitSeconds,
    }
    self.pending = { id = candidate.id, action = 'apply', at = GetTime() }
    C_LFGList.ApplyToGroup(candidate.id, self.role == 'TANK', self.role == 'HEALER', self.role == 'DAMAGER')
    self:SetStatus('已按' .. ROLE_NAME[self.role] .. '申请 ' .. candidate.members .. '/5 人队伍，继续补申。')
end

function Controller:Step()
    local ok, err = pcall(self.Run, self)
    if not ok then
        self.autoCancel = false
        self:Stop('申请接口不可用，已停止；请尝试手动申请。')
        print('|cff00ff00集合石自动申请：|r' .. self.message .. ' ' .. tostring(err))
    end
end

-- Same template and fonts as RefreshButton.
local button = CreateFrame('Button', nil, BrowsePanel, 'UIMenuButtonStretchTemplate')
Controller.button = button
BrowsePanel.AutoApplyButton = button
-- The bottom bar belongs to role and quick filters (EX and skins). Sit left of
-- RefreshButton; both anchors give it RefreshButton's height wherever it moves.
button:SetWidth(74)
button:SetPoint('TOPRIGHT', BrowsePanel.RefreshButton, 'TOPLEFT', -2, 0)
button:SetPoint('BOTTOMRIGHT', BrowsePanel.RefreshButton, 'BOTTOMLEFT', -2, 0)
button:SetNormalFontObject('GameFontNormal')
button:SetHighlightFontObject('GameFontHighlight')
button:SetDisabledFontObject('GameFontDisable')
button:SetText('自动申请')
button:SetScript('OnClick', function()
    if Controller.active then
        Controller:Stop()
    else
        Controller:RequestStart()
    end
end)
button:SetScript('OnEnter', function(self)
    GameTooltip:SetOwner(self, 'ANCHOR_TOP')
    GameTooltip:SetText('自动申请地下城队伍')
    GameTooltip:AddLine('按当前专精职责，从过滤后的队伍中优先申请人数最多的队伍。', 1, 1, 1, true)
    GameTooltip:AddLine('开启前可填写申请备注，或选择无备注开始。', 1, 1, 1, true)
    GameTooltip:AddLine('搜索返回后约 7 秒再次搜索，并遵守刷新按钮的冷却。', 1, 1, 1, true)
    GameTooltip:AddLine('职责满员时撤销本功能提交的申请，再补申其他队伍。', 1, 1, 1, true)
    GameTooltip:AddLine('最大等待 ' .. Controller.maxWaitSeconds .. ' 秒；超时撤销并加入本轮黑名单。', 1, 1, 1, true)
    GameTooltip:AddLine('可随时点击原有取消按钮；手动取消的队伍本次不会重申。', 1, 0.82, 0, true)
    GameTooltip:AddLine('停止再开启会清空跳过名单；停止时保留已提交申请。', 1, 1, 1, true)
    if Controller.message then
        GameTooltip:AddLine(Controller.message, 0.3, 1, 0.3, true)
    end
    GameTooltip:Show()
end)
button:SetScript('OnLeave', GameTooltip_Hide)

hooksecurefunc(C_LFGList, 'CancelApplication', function(id)
    Controller:ManualCancel(id)
end)
hooksecurefunc('DeclineGroup', function()
    Controller.partyInvitePending = nil
end)
hooksecurefunc('AcceptGroup', function()
    Controller.partyInvitePending = nil
    if Controller.active then
        Controller:Stop('已接受邀请，自动申请已停止。')
    end
end)
hooksecurefunc(BrowsePanel, 'DoSearch', function()
    if Controller.active then
        -- Manual refreshes also postpone the next automatic search.
        Controller.nextRefreshAt = GetTime() + REFRESH_INTERVAL
    end
end)
BrowsePanel:HookScript('OnHide', function()
    if Controller.active then
        Controller:Stop('查找页面已关闭，自动申请已停止。')
    end
end)

-- The quick-join toggles hang off SearchBox's right edge. In the classic UI
-- build the whole search row sits 40px further right, so their labels would run
-- under this button. Narrow the borrowed SearchBox just enough (never below
-- MIN_SEARCH_WIDTH, never wider than the width BrowsePanel:OnShow just set).
local MIN_SEARCH_WIDTH = 160
local searchBaseWidth, rowCheckPending
local hookedRowChecks = {}

local function ScreenEdge(region, edge, scaleOwner)
    local value = region and region[edge] and region[edge](region)
    if not value then
        return
    end
    local owner = scaleOwner or region
    return value * (owner.GetEffectiveScale and owner:GetEffectiveScale() or 1)
end

local KeepSearchRowClear

local function QueueSearchRowCheck()
    if rowCheckPending then
        return
    end
    rowCheckPending = true
    C_Timer.After(0, function()
        rowCheckPending = nil
        KeepSearchRowClear()
    end)
end

KeepSearchRowClear = function()
    local box = BrowsePanel.SearchBox
    if not (searchBaseWidth and BrowsePanel:IsVisible() and button:IsShown() and box and
        box.GetParent and box.GetWidth and box.SetWidth and box:GetParent() == BrowsePanel) then
        return
    end
    local left, top, bottom = ScreenEdge(button, 'GetLeft'), ScreenEdge(button, 'GetTop'), ScreenEdge(button, 'GetBottom')
    local boxRight = ScreenEdge(box, 'GetRight')
    if not (left and top and bottom and boxRight) then
        return
    end
    -- Signed: negative is spare room, so a narrowed box can widen back again.
    local overlap
    for _, child in ipairs({ BrowsePanel:GetChildren() }) do
        if child ~= button and child.GetObjectType and child:GetObjectType() == 'CheckButton' then
            if not hookedRowChecks[child] and child.SetText then
                -- Spec/role names and skin fonts change label widths.
                hookedRowChecks[child] = true
                hooksecurefunc(child, 'SetText', QueueSearchRowCheck)
            end
            local label = child.Text or (child.GetFontString and child:GetFontString())
            local cLeft = ScreenEdge(child, 'GetLeft')
            local cTop, cBottom = ScreenEdge(child, 'GetTop'), ScreenEdge(child, 'GetBottom')
            -- A FontString reports positions in its parent's scale.
            local right = label and ScreenEdge(label, 'GetRight', child)
            -- Only toggles that follow SearchBox's right edge can be moved by
            -- narrowing it; the classic score filter sits above the box instead.
            if child:IsShown() and cLeft and cTop and cBottom and right and
                cLeft >= boxRight - 1 and cLeft < left and cTop > bottom and cBottom < top then
                overlap = math.max(overlap or -math.huge, right + 6 - left)
            end
        end
    end
    local width = searchBaseWidth
    if overlap then
        local scale = box.GetEffectiveScale and box:GetEffectiveScale() or 1
        local needed = math.floor(box:GetWidth() - overlap / scale)
        width = math.max(MIN_SEARCH_WIDTH, math.min(searchBaseWidth, needed))
    end
    if math.abs(box:GetWidth() - width) > 0.5 then
        box:SetWidth(width)
    end
end

BrowsePanel:HookScript('OnShow', function()
    local box = BrowsePanel.SearchBox
    searchBaseWidth = box and box.GetWidth and box:GetWidth() or nil
    QueueSearchRowCheck()
end)

local events = CreateFrame('Frame')
ticker = events
events:RegisterEvent('LFG_LIST_SEARCH_RESULTS_RECEIVED')
events:RegisterEvent('LFG_LIST_SEARCH_FAILED')
events:RegisterEvent('LFG_LIST_APPLICATION_STATUS_UPDATED')
events:RegisterEvent('PARTY_INVITE_REQUEST')
events:RegisterEvent('PARTY_INVITE_CANCEL')
events:RegisterEvent('GROUP_ROSTER_UPDATE')
events:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
events:RegisterEvent('ADDON_ACTION_BLOCKED')
events:RegisterEvent('ADDON_ACTION_FORBIDDEN')
events:SetScript('OnEvent', function(_, event, id, status)
    if event == 'LFG_LIST_SEARCH_RESULTS_RECEIVED' or event == 'LFG_LIST_SEARCH_FAILED' then
        -- Give completed results a full application window, even after a slow search.
        Controller.refreshStarted = nil
        if Controller.active then
            Controller.nextRefreshAt = GetTime() + REFRESH_INTERVAL
        end
        return
    end
    -- Observe invitations while stopped too, so restarting cannot ignore one.
    if event == 'PARTY_INVITE_REQUEST' then
        Controller.partyInvitePending = true
    elseif event == 'PARTY_INVITE_CANCEL' or (event == 'GROUP_ROSTER_UPDATE' and IsInGroup()) then
        Controller.partyInvitePending = nil
    end
    if event == 'LFG_LIST_APPLICATION_STATUS_UPDATED' and
        (Finished(status) or status == 'inviteaccepted') then
        Controller:ForgetApplication(id)
    end
    if not Controller.active then
        return
    end
    if event == 'ADDON_ACTION_BLOCKED' or event == 'ADDON_ACTION_FORBIDDEN' then
        if id == 'MeetingStoneEX' or id == 'MeetingStone' then
            if Controller.refreshStarted then
                Controller:ResetSearch()
            end
            Controller:Stop('游戏阻止了自动申请操作，请使用手动申请。')
            print('|cff00ff00集合石自动申请：|r' .. Controller.message)
        end
    elseif event == 'LFG_LIST_APPLICATION_STATUS_UPDATED' then
        if status == 'inviteaccepted' then
            Controller:Stop('已接受邀请，自动申请已停止。')
        end
    elseif event == 'GROUP_ROSTER_UPDATE' and IsInGroup() then
        Controller:Stop('已进入队伍，自动申请已停止。')
    elseif event == 'PLAYER_SPECIALIZATION_CHANGED' and id == 'player' then
        Controller:Stop('专精已改变，请重新开启自动申请。')
    end
end)
OnTick = function(_, elapsed)
    if not Controller.active then
        return
    end
    Controller.elapsed = (Controller.elapsed or 0) + elapsed
    if Controller.elapsed >= 1 then
        Controller.elapsed = 0
        Controller:Step()
    end
end
