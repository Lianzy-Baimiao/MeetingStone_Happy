-- LfgService.lua
-- @Author : DengSir (tdaddon@163.com)
-- @Link   : https://dengsir.github.io/
-- @Date   : 2018-1-17 10:29:00

BuildEnv(...)

LfgService = Addon:NewModule('LfgService', 'AceEvent-3.0', 'AceBucket-3.0', 'AceTimer-3.0', 'AceHook-3.0')

function LfgService:OnInitialize()
    self.activityHash = {}
    self.activityList = {}
    self.activityRemoved = {}

    self:RegisterEvent('LFG_LIST_SEARCH_RESULTS_RECEIVED')
    self:RegisterEvent('LFG_LIST_SEARCH_FAILED', 'LFG_LIST_SEARCH_RESULTS_RECEIVED')
    self:RegisterEvent('LFG_LIST_APPLICATION_STATUS_UPDATED', 'LFG_LIST_SEARCH_RESULT_UPDATED')
    self:RegisterEvent('LFG_LIST_SEARCH_RESULT_UPDATED')

    -- self:RegisterBucketEvent('LFG_LIST_SEARCH_RESULT_UPDATED', 0.1, 'LFG_LIST_SEARCH_RESULT_UPDATED_BUCKET')

    self:SecureHook(C_LFGList, 'Search', 'C_LFGList_Search')
end

function LfgService:C_LFGList_Search()
    self.inSearch = true
    self.dirty = true
    -- /ms diag: when the request left (any caller, ours or Blizzard's).
    self.searchSentAt = GetTime()
end

function LfgService:GetActivity(id)
    return self.activityHash[id]
end

function LfgService:GetActivityCount()
    return #self.activityList
end

function LfgService:GetActivityList()
    return self.activityList
end

function LfgService:RemoveActivity(id)
    self.activityRemoved[id] = true

    local activity = self:GetActivity(id)
    if not activity then
        return
    end
    tDeleteItem(self.activityList, activity)
    self.activityHash[id] = nil
end

function LfgService:IsActivityRemoved(id)
    return self.activityRemoved[id]
end

function LfgService:UpdateActivity(id)
    if self:IsActivityRemoved(id) then
        return
    end

    local activity = self:GetActivity(id)
    if not activity then
        self:CacheActivity(id)
        self:SendMessage('MEETINGSTONE_ACTIVITIES_COUNT_UPDATED', #self.activityList)
    else
		--activity:Update() 
        --if activity:GetNumMembers() == 5 then
		if not activity:Update() then
            self:RemoveActivity(id)
        end
    end
end

function LfgService:IterateActivities()
    return pairs(self.activityList)
end

function LfgService:CacheActivity(id)
    if not self:_CacheActivity(id) then
        self:RemoveActivity(id)
    end
end

function LfgService:_CacheActivity(id)
    local activity = Activity:New(id)
    if not activity:Update() then
        return
    end
    if self.activityId and activity:GetActivityID() ~= self.activityId then
        return
    end

    if activity:HasInvalidContent() then
        return
    end
    if not activity:IsValidCustomActivity() then
        return
    end

    tinsert(self.activityList, activity)
    self.activityHash[id] = activity

    return true
end

function LfgService:LFG_LIST_SEARCH_RESULTS_RECEIVED(event)
    local started = debugprofilestop()
    table.wipe(self.activityList)
    table.wipe(self.activityHash)
    table.wipe(self.activityRemoved)

    self.inSearch = false
    local applications = C_LFGList.GetApplications()

    self.activityApps = self.activityApps or {} --abyui 9.1.5 applications also in SearchResults
    table.wipe(self.activityApps)

    for _, id in ipairs(applications) do
        self.activityApps[id] = true
        self:CacheActivity(id)
    end

    local _, resultList = C_LFGList.GetSearchResults()
    for _, id in ipairs(resultList) do
        if not self.activityApps[id] then
            self:CacheActivity(id)
        end
    end

    self:SendMessage('MEETINGSTONE_ACTIVITIES_COUNT_UPDATED', self:GetActivityCount())
    self:SendMessage('MEETINGSTONE_ACTIVITIES_RESULT_RECEIVED', event == 'LFG_LIST_SEARCH_FAILED')

    -- /ms diag: arrival time and the client-side cost of caching the results.
    self.resultAt = GetTime()
    self.resultCost = debugprofilestop() - started
    self.resultFailed = event == 'LFG_LIST_SEARCH_FAILED'
end

function LfgService:LFG_LIST_SEARCH_RESULT_UPDATED_BUCKET(results)
    for id in pairs(results) do
        self:UpdateActivity(id)
    end
    self:SendMessage('MEETINGSTONE_ACTIVITIES_RESULT_UPDATED')
end

function LfgService:LFG_LIST_SEARCH_RESULT_UPDATED(_, id)
    if self.inSearch then
        return
    end
    self:UpdateActivity(id)
    self:SendMessage('MEETINGSTONE_ACTIVITIES_RESULT_UPDATED')
end

function LfgService:Search(categoryId, baseFilter, activityId, isMPlus)
    self.ourSearch = true
    self.activityId = activityId
    local filterVal = categoryId == GROUP_FINDER_CATEGORY_ID_DUNGEONS and 1 or 0
    local advFilter = isMPlus and categoryId == GROUP_FINDER_CATEGORY_ID_DUNGEONS and (not activityId) and C_LFGList.GetAdvancedFilter() or nil

    local languages = C_LFGList.GetLanguageSearchFilter();
    C_LFGList.Search(categoryId, filterVal, baseFilter, languages ,nil ,advFilter)
    self.ourSearch = false
    self.dirty = false
end

function LfgService:IsDirty()
    return self.dirty
end

-- In a boss fight, a Mythic+ key or a rated match (chat lockdown, 12.x) every field is
-- secret: MeetingStone can neither test them nor use them as table keys. Report the
-- member as unknown then, as for a missing member; Blizzard's own icons still show.
function LfgService:GetSearchResultMemberInfo(...)
    local info = C_LFGList.GetSearchResultPlayerInfo(...)
	if (info) and not issecretvalue(info) then
		local role, class, classLocalized, spec, isLeader = info.assignedRole, info.classFilename, info.className, info.specName, info.isLeader
		if issecretvalue(role) or issecretvalue(class) or issecretvalue(classLocalized) or issecretvalue(spec) or issecretvalue(isLeader) then
			return
		end
		return role, class, classLocalized, spec, isLeader;
	end
end    