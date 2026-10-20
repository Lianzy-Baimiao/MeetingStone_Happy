
BuildEnv(...)

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
local DisableAddOn = C_AddOns and C_AddOns.DisableAddOn or DisableAddOn


debug = IsAddOnLoaded('!!!!!tdDevTools') and print or nop

Addon = LibStub('AceAddon-3.0'):NewAddon('MeetingStone', 'AceEvent-3.0', 'LibModule-1.0', 'LibClass-2.0', 'AceHook-3.0')

GUI = LibStub('NetEaseGUI-2.0')

function Addon:OnInitialize()
    -- /ms diag: before any module can receive LFG_LIST_AVAILABILITY_UPDATE.
    self.loadedAt = GetTime()
    self:SecureHook('LFGListUtil_OpenBestWindow', function()
        HideUIPanel(PVEFrame)
        self:Toggle()
    end)
    -- self:RawHook('SetItemRef', true)

    self:RegisterMessage('MEETINGSTONE_NEW_VERSION')
    self:RegisterMessage('MEETINGSTONE_FILTER_DATA_UPDATED')

    self.mountCache = setmetatable({}, {
        __index = function(t, k)
            for _, id in ipairs(C_MountJournal.GetMountIDs()) do
                local displayId = C_MountJournal.GetMountInfoExtraByID(id)
                if displayId == k then
                    local v = select(11, C_MountJournal.GetMountInfoByID(id))
                    t[k] = v
                    return v
                end
            end
        end
    })
    self:RegisterEvent('COMPANION_LEARNED', function()
        wipe(self.mountCache)
    end)

    local lfgTooManyDialog = _G.StaticPopupDialogs['LFG_LIST_ENTRY_EXPIRED_TOO_MANY_PLAYERS']
    if lfgTooManyDialog and lfgTooManyDialog.text and strlenutf8(lfgTooManyDialog.text) == #lfgTooManyDialog.text then
        lfgTooManyDialog.text = L['你的队伍成员已经达到当前活动的人数上限，活动已经自动解散。']
    end
	--显示职业图标
	InitMeetingStoneClass()
	
	--2022-11-18 部分人反馈小图标隐藏后打不开，增加命令打开方式 /ms  、 /meetingstone
	SlashCmdList["MeetingStone"] = function(msg)
		-- /ms diag | mem | clean: on-demand reports, nothing runs until typed.
		local cmd = strlower(strtrim(msg or ''))
		if cmd == 'diag' then
			return Addon:PrintSearchDiagnostics()
		elseif cmd == 'mem' then
			return Addon:PrintMemoryReport()
		elseif cmd == 'clean' then
			return Addon:CleanUnusedData()
		end
		Addon:CheckLevel()
		MainPanel:Show()
	end;
    _G["SLASH_MeetingStone1"] = "/ms";
    _G["SLASH_MeetingStone2"] = "/meetingstone";
end

function Addon:OnEnable()
    if IsAddOnLoaded('RaidBuilder') then
        DisableAddOn('RaidBuilder')
        GUI:CallWarningDialog(L.FoundRaidBuilder, true, nil, ReloadUI)
        return
    end

    if Profile:GetLastVersion() < 70200.06 then
        --SetCVar('profanityFilter', 1)
    end

    Profile:SaveLastVersion()
end

function Addon:MEETINGSTONE_NEW_VERSION(_, version, url, isSupport, changeLog)
    version = format('%.02f', tonumber(version) or 0)
    if not isSupport then
        self.url = url
        self.changeLog = changeLog

        self:ShowNewVersion(url, changeLog)
    end

    if changeLog then
        System:Logf(L.NewVersionWithChangeLog, version, url, changeLog)
    else
        System:Logf(L.NewVersion, version, url)
    end
end

function Addon:Toggle()
	Addon:CheckLevel()
    if Logic:IsSupport() then
        if MainPanel:IsShown() then
            Addon:HideModule('MainPanel')
        else
            if ApplicantPanel:HasNewPending() then
                MainPanel:SelectPanel(ManagerPanel)
			-- 10.0 屏蔽最新活动和攻略 by 易安玥
            -- elseif DataCache:GetObject('ActivitiesData'):IsNew() then
                -- MainPanel:SelectPanel(ActivitiesParent)
            -- elseif App:HasNewFollower() then
                -- MainPanel:SelectPanel(AppParent)
            elseif C_LFGList.HasActiveEntryInfo() then
                MainPanel:SelectPanel(ManagerPanel)
            end
			
            Addon:ShowModule('MainPanel')
        end
    else
        self:ShowNewVersion(self.url, self.changeLog)
    end
end

function Addon:ShowNewVersion(url, changeLog)
    if changeLog then
        GUI:CallUrlDialog(url, format(L.NotSupportVersionWithChangeLog, changeLog), 1)
    else
        GUI:CallUrlDialog(url, L.NotSupportVersion, 1)
    end
end

function Addon:FindMount(id)
    if not id then
        return
    end
    return self.mountCache[id]
end

function Addon:MEETINGSTONE_FILTER_DATA_UPDATED(_, data)
    ClearCheckContentCache()
    self.filterPinyin = #data.pinyin > 0 and data.pinyin or nil
    self.filterNormal = #data.normal > 0 and data.normal or nil
end

function Addon:GetFilterData()
    return self.filterPinyin, self.filterNormal
end

-- function Addon:SetItemRef(link, text, button, chatFrame)
--     local type, panel = strsplit(':', link)
--     if type == 'meetingstonepanel' then
--         panel = self:GetModule(panel, true)
--         if panel and MainPanel:GetPanelIndex(panel) then
--             Addon:ToggleModule('MainPanel')
--             MainPanel:SelectPanel(panel)
--         end
--         return
--     elseif type == 'meetingstonedialog' then
--         panel = _ENV[panel]
--         if panel then
--             ToggleFrame(panel)
--         end
--         return
--     end
--     return self.hooks.SetItemRef(link, text, button, chatFrame)
-- end
function Addon:CheckLevel()
	local level = UnitLevel("player")
    if level<50 then
		print('11.0后等级低于50级无法使用集合石')
	end
end

---- On-demand reports (/ms diag, /ms mem, /ms clean). Nothing below runs until typed.

local function Say(text)
    print('|cff00ffff集合石|r ' .. text)
end

local function Seconds(from, to)
    if not (from and to) then
        return '—'
    end
    return format('%.1f 秒', to - from)
end

-- Why "搜寻中" lasts as long as it does, from timestamps the modules keep.
function Addon:PrintSearchDiagnostics()
    local now = GetTime()
    local opened = BrowsePanel.openedAt
    local sent, result = LfgService.searchSentAt, LfgService.resultAt
    Say(format('界面载入 → 活动列表就绪：%s（活动列表重建 %d 次）',
        BrowsePanel.menuReadyAt and Seconds(self.loadedAt, BrowsePanel.menuReadyAt) or '尚未收到',
        BrowsePanel.menuBuilds or 0))
    if not opened then
        Say('本次载入后还没有打开过集合石。')
    elseif sent and sent >= opened then
        Say(format('打开窗口 → 发出搜索：%s（插件侧）', Seconds(opened, sent)))
    else
        Say('打开窗口后没有发出新搜索（结果仍在 5 分钟有效期内）。')
    end
    if sent then
        if result and result >= sent then
            Say(format('发出搜索 → 服务器返回：%s（暴雪服务器）；处理 %d 支队伍用时 %.0f 毫秒%s',
                Seconds(sent, result), LfgService:GetActivityCount(), LfgService.resultCost or 0,
                LfgService.resultFailed and '，搜索失败' or ''))
        else
            Say(format('最近一次搜索已发出 %s，仍在等待服务器返回。', Seconds(sent, now)))
        end
    end
    Say(format('当前：%s%s', BrowsePanel.SearchingBlocker:IsShown() and '显示“搜寻中”' or '未显示“搜寻中”',
        BrowsePanel.searchPending and '，有一次搜索待发出' or ''))
end

local CHARACTER_DB_KEYS = {
    profiles = true,    -- AceDB profiles: settings, history, recent players
    profileKeys = true, -- AceDB character -> profile map
    Remix = true,       -- MeetingStoneEX
}

-- Rough Lua 5.1 size: 40 B per hash node, 16 B per array slot, 56 B per table,
-- 24 B + length per distinct string. Saved variables hold plain data only.
local function EstimateSize(value, seen)
    local kind = type(value)
    if kind == 'string' then
        if seen[value] then
            return 0
        end
        seen[value] = true
        return 24 + #value
    elseif kind ~= 'table' or seen[value] then
        return 0
    end
    seen[value] = true
    local size, count = 56, #value
    size = size + count * 16
    for k, v in pairs(value) do
        if not (type(k) == 'number' and k >= 1 and k <= count and k % 1 == 0) then
            size = size + 40
        end
        size = size + EstimateSize(k, seen) + EstimateSize(v, seen)
    end
    return size
end

local function UnusedCharacterKeys()
    local keys = {}
    for k in pairs(MEETINGSTONE_CHARACTER_DB or {}) do
        if not CHARACTER_DB_KEYS[k] then
            tinsert(keys, k)
        end
    end
    sort(keys, function(a, b) return tostring(a) < tostring(b) end)
    return keys
end

local function CountUI(frame)
    local frames, regions = 1, frame:GetNumRegions()
    for _, child in ipairs({ frame:GetChildren() }) do
        local f, r = CountUI(child)
        frames, regions = frames + f, regions + r
    end
    return frames, regions
end

local UpdateMemory = C_AddOns and C_AddOns.UpdateAddOnMemoryUsage or UpdateAddOnMemoryUsage
local GetMemory = C_AddOns and C_AddOns.GetAddOnMemoryUsage or GetAddOnMemoryUsage

local function AddonMemory()
    UpdateMemory()
    return GetMemory('MeetingStone') / 1024, GetMemory('MeetingStoneEX') / 1024
end

-- What the memory is: one full collection splits temporary garbage from what stays,
-- then the saved data is measured. A full collection stalls for a moment.
function Addon:PrintMemoryReport()
    if InCombatLockdown() then
        return Say('战斗中不统计内存，请脱战后再输入 /ms mem。')
    end
    local before, beforeEX = AddonMemory()
    collectgarbage('collect')
    local after, afterEX = AddonMemory()

    local seen = {}
    local profiles = EstimateSize(MEETINGSTONE_CHARACTER_DB and MEETINGSTONE_CHARACTER_DB.profiles, seen)
    local unused, unusedKeys = 0, UnusedCharacterKeys()
    for _, k in ipairs(unusedKeys) do
        unused = unused + EstimateSize(MEETINGSTONE_CHARACTER_DB[k], seen)
    end
    local ui = MEETINGSTONE_UI_DB or {}
    local ignore = EstimateSize(ui.IGNORE_LIST, seen)
    local account = EstimateSize(ui, seen)
    local ok, frames, regions = pcall(CountUI, MainPanel)

    Say(format('MeetingStone 常驻 %.1f MB（回收前 %.1f MB，%.1f MB 是可回收的临时数据：每次搜索、刷新列表生成后丢弃的表）',
        after, before, max(before - after, 0)))
    if beforeEX > 0 then
        Say(format('MeetingStoneEX 常驻 %.1f MB（回收前 %.1f MB）', afterEX, beforeEX))
    end
    Say(format('本角色存档约 %.0f KB：设置、搜索/创建记录、最近玩家', profiles / 1024))
    if #unusedKeys > 0 then
        Say(format('|cffff8000本角色存档中有本插件不读取的旧数据约 %.1f MB（%s，多为其他集合石版本留下）。每次登录都会载入，可输入 /ms clean 删除。|r',
            unused / 1048576, table.concat(unusedKeys, ', ')))
    end
    Say(format('账号存档约 %.0f KB，其中屏蔽列表 %d 条约 %.0f KB', (ignore + account) / 1024,
        ui.IGNORE_LIST and #ui.IGNORE_LIST or 0, ignore / 1024))
    Say(format('搜索结果 %d 支队伍；标题过滤缓存 %d 条（上限 2048，满了清空）', LfgService:GetActivityCount(),
        CheckContentCacheSize and CheckContentCacheSize() or 0))
    if ok then
        Say(format('主窗口界面：%d 个框体、%d 个纹理/文字（创建后复用，不随搜索增长）', frames, regions))
    end
    Say('其余为程序代码、库与静态数据。估算值，供判断占用来源。')
end

-- Opt-in removal of per-character saved data this addon never reads.
function Addon:CleanUnusedData()
    if InCombatLockdown() then
        return Say('战斗中不能清理，请脱战后再输入 /ms clean。')
    end
    local keys = UnusedCharacterKeys()
    if #keys == 0 then
        return Say('本角色存档没有需要清理的旧数据。')
    end
    local seen, size = {}, 0
    for _, k in ipairs(keys) do
        size = size + EstimateSize(MEETINGSTONE_CHARACTER_DB[k], seen)
    end
    GUI:CallMessageDialog(format(
        '删除本角色存档中本插件不读取的旧数据（%s，约 %.1f MB）？\n\n设置、搜索记录、最近玩家和屏蔽列表不受影响。删除后重载或下线即写入存档，无法恢复。',
        table.concat(keys, ', '), size / 1048576), function(result)
        if not result then
            return
        end
        -- The dialog can still be answered after combat has started.
        if InCombatLockdown() then
            return Say('战斗中不能清理，请脱战后再输入 /ms clean。')
        end
        collectgarbage('collect')
        local before = AddonMemory()
        for _, k in ipairs(keys) do
            MEETINGSTONE_CHARACTER_DB[k] = nil
        end
        collectgarbage('collect')
        Say(format('已删除旧数据，MeetingStone 常驻 %.1f MB → %.1f MB。', before, (AddonMemory())))
    end)
end
