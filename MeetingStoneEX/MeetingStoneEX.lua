BuildEnv(...)

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded


debug = IsAddOnLoaded('!!!!!tdDevTools') and print or nop
Addon = LibStub('AceAddon-3.0'):GetAddon('MeetingStone')
GUI = LibStub('NetEaseGUI-2.0')

local gameLocale = GetLocale()

local BrowsePanel = Addon:GetModule('BrowsePanel')
local MainPanel = Addon:GetModule('MainPanel')
local Profile = Addon:GetModule('Profile')
local LfgService = Addon:GetModule('LfgService')

if not MEETINGSTONE_UI_DB.IGNORE_LIST then
    MEETINGSTONE_UI_DB.IGNORE_LIST = {}
end

local _dungeon = C_LFGList.GetAvailableActivityGroups(GROUP_FINDER_CATEGORY_ID_DUNGEONS, bit.bor(Enum.LFGListFilter.CurrentSeason, Enum.LFGListFilter.PvE))
if #_dungeon > 0 then
    MEETINGSTONE_UI_DB.Dungeon_LIST = _dungeon
elseif  not MEETINGSTONE_UI_DB.Dungeon_LIST then   
    MEETINGSTONE_UI_DB.Dungeon_LIST = { 323, 324, 326, 371, 381, 261 ,280,281}
end    

-- if not MEETINGSTONE_UI_DB.CLEAR_IGNORE_LIST_V1 then
--     MEETINGSTONE_UI_DB.CLEAR_IGNORE_LIST_V1 = false
--     MEETINGSTONE_UI_DB.IGNORE_LIST = {}
--     MEETINGSTONE_UI_DB.CLEAR_IGNORE_LIST_V1 = true
-- end

-- if MEETINGSTONE_UI_DB.CLEAR_IGNORE_LIST_V1 == false then
--     MEETINGSTONE_UI_DB.IGNORE_LIST = {}
--     MEETINGSTONE_UI_DB.CLEAR_IGNORE_LIST_V1 = true
-- end

if MEETINGSTONE_UI_DB.filters then
    for k, v in pairs(MEETINGSTONE_UI_DB.filters) do
        table.insert(MEETINGSTONE_UI_DB.IGNORE_LIST, {
            leader = k,
            time = v,
            dep = '旧数据结构转化',
        })
    end
    MEETINGSTONE_UI_DB.filters = nil
end

for i, v in ipairs(MEETINGSTONE_UI_DB.IGNORE_LIST) do
    if v.leader == nil then
        table.remove(MEETINGSTONE_UI_DB.IGNORE_LIST, i)
    end
    v.titles = nil
    if v.time == true then
        v.time = ''
    end
end

table.sort(MEETINGSTONE_UI_DB.IGNORE_LIST, function(a, b)
    if a.time == b.time then
        return a.leader < b.leader
    end
    if type(a.time) == type(b.time) and type(a.time) == 'string' then
        return a.time > b.time
    end
    return type(a.time) == 'string'
end)

BrowsePanel.IgnoreWithTitle = {}
BrowsePanel.IgnoreWithLeader = {}
BrowsePanel.IgnoreLeaderOnly = {}
for i, v in ipairs(MEETINGSTONE_UI_DB.IGNORE_LIST) do
    if v.t == 1 then
        BrowsePanel.IgnoreWithLeader[v.leader] = true
    elseif v.t == 2 then
        BrowsePanel.IgnoreLeaderOnly[v.leader] = true
    end
end
if MEETINGSTONE_UI_DB.IGNORE_TIPS_LOG == nil then
    MEETINGSTONE_UI_DB.IGNORE_TIPS_LOG = true
end

if MEETINGSTONE_UI_DB.FILTER_MULTY == nil then
    MEETINGSTONE_UI_DB.FILTER_MULTY = true
end

--职责过滤
local function CheckJobsFilter(data, tcount, hcount, dcount, activity, hasDungeon)
    local enabled = C_LFGList.GetAdvancedFilter()
    local isSeasonDungeon = activity and containsValue(enabled.activities,activity:GetGroupID()) or false
    if not hasDungeon and isSeasonDungeon then
        local enabled = C_LFGList.GetAdvancedFilter()
        if enabled.needsMyClass then
            local _, myclass, _2 = UnitClass("player")
            for i = 1, activity:GetNumMembers() do
                local _, class = LfgService:GetSearchResultMemberInfo(activity:GetID(), i)
                if class == myclass then
                    return false
                end
            end
        end 
        return (not enabled.needsHealer and not enabled.needsDamage or (enabled.needsHealer and data.HEALER < hcount) or (enabled.needsDamage and data.DAMAGER < dcount)) 
            and (not enabled.hasTank or data.TANK >= tcount )
            and (not enabled.hasHealer or data.HEALER >= hcount )
            or false
             
    else  
        if MEETINGSTONE_UI_DB.FILTER_MULTY then
            return (not MEETINGSTONE_UI_DB.FILTER_TANK and not MEETINGSTONE_UI_DB.FILTER_HEALTH and not MEETINGSTONE_UI_DB.FILTER_DAMAGE)
                or (MEETINGSTONE_UI_DB.FILTER_TANK and data.TANK < tcount)
                or (MEETINGSTONE_UI_DB.FILTER_HEALTH and data.HEALER < hcount)
                or (MEETINGSTONE_UI_DB.FILTER_DAMAGE and data.DAMAGER < dcount)
                or false
        else
            return (not MEETINGSTONE_UI_DB.FILTER_TANK or data.TANK < tcount)
            and (not MEETINGSTONE_UI_DB.FILTER_HEALTH or data.HEALER < hcount)
            and (not MEETINGSTONE_UI_DB.FILTER_DAMAGE or data.DAMAGER < dcount)
            or false
        end
    end
end
--PVP职责过滤
local function CheckPVPJobsFilter(data, hcount, dcount)
    if MEETINGSTONE_UI_DB.FILTER_HEALTH and data.HEALER >= hcount then
        return false
    end
    if (MEETINGSTONE_UI_DB.FILTER_TANK or MEETINGSTONE_UI_DB.FILTER_DAMAGE) and data.TANK + data.DAMAGER >= dcount then
        return false
    end
    return true
end

--添加过滤功能
BrowsePanel.ActivityList:RegisterFilter(function(activity, ...)
    local leader = activity:GetLeader()
    if leader == nil then
        return false
    end
    if BrowsePanel.IgnoreLeaderOnly[leader] then
        local ist = true
        for i, v in ipairs(MEETINGSTONE_UI_DB.IGNORE_LIST) do
            if v.leader == leader then
                ist = false
                break
            end
        end
        if ist then
            table.insert(MEETINGSTONE_UI_DB.IGNORE_LIST, 1, {
                leader = leader,
                time = date('%Y-%m-%d %H:%M', time()),
                dep = '由指定队长名屏蔽',
                t = 2,
            })
        end
        return false
    end
   
    local data = C_LFGList.GetSearchResultMemberCounts(activity:GetID())
    if data then
        local activityItem = BrowsePanel.ActivityDropdown:GetItem()
        if not activityItem then
            return
        end
        local categoryId = activityItem.categoryId
        local activityId = activityItem.activityId

        --修复自定义搜索文本时会有不对应的内容出现
        if categoryId ~= activity:GetCategoryID() then
            return false
        end    

        --任务1 地下堡121 地下城2 团队3 jjc4 评级9 自定义6
        if categoryId == 2 then
            if not CheckJobsFilter(data, 1, 1, 3, activity, activityId ~= nil)then
                return false
            end
        elseif categoryId == 3 then
            if not CheckJobsFilter(data, 2, 6, 22) then
                return false
            end   
        elseif categoryId == 4 then 
            if activityId == 6 and (not CheckPVPJobsFilter(data, 1, 2)) then
                return false
            end
            if activityId == 7 and (not CheckPVPJobsFilter(data, 1, 3)) then
                return false
            end
        elseif categoryId == 9 then   
            if not CheckPVPJobsFilter(data, 3, 7) then
                return false
            end
        end    
            
    end

    if Profile:GetEnableIgnoreTitle() then
        local title = activity:GetSummary()
        if BrowsePanel.IgnoreWithTitle[title] then
            if not BrowsePanel.IgnoreWithLeader[leader] then
                BrowsePanel.IgnoreWithLeader[leader] = true
                table.insert(MEETINGSTONE_UI_DB.IGNORE_LIST, 1, {
                    leader = leader,
                    time = date('%Y-%m-%d %H:%M', time()),
                    dep = '由指定标题传染屏蔽',
                    t = 1,
                })
                if MEETINGSTONE_UI_DB.IGNORE_TIPS_LOG then
                    print('标题 ' .. title .. ' 传染屏蔽 ' .. leader)
                end
            end
            return false
        end
        -- if BrowsePanel.IgnoreWithLeader[leader] then
        --     if not BrowsePanel.IgnoreWithTitle[title] then
        --         BrowsePanel.IgnoreWithTitle[title] = true
        --         -- if MEETINGSTONE_UI_DB.IGNORE_TIPS_LOG then
        --         --     print('账号 ' .. leader .. ' 传染屏蔽 ' .. title)
        --         -- end
        --     end
        --     return false
        -- end
    end
    if BrowsePanel.IgnoreWithLeader[leader] then        
        return false
    end

    if MEETINGSTONE_UI_DB['SCORE'] then
        if not activity:GetLeaderScore() or activity:GetLeaderScore() < MEETINGSTONE_UI_DB['SCORE'] then
            return false
        end
    end

    if BrowsePanel.ActivityDropdown:GetText() == activitytypeText1 and BrowsePanel.MDSearchs then
        if BrowsePanel.MDSearchs[activity:GetName()] then
            --return activity:Match(...)
        else
            return false
        end
    end
	
	local classFilter = MEETINGSTONE_UI_DB.ClassNeed == false
	local allnoCheck = true
	


	for i = 1, activity:GetNumMembers() do
		local role, class, classLocalized, specLocalized = LfgService:GetSearchResultMemberInfo(activity:GetID(), i)
		if MEETINGSTONE_UI_DB[class] == true  then
			if MEETINGSTONE_UI_DB.ClassNeed then
				classFilter = true
			else
				classFilter = false
			end
		end
	end
	 
	
	if classFilter == false then
		for classID = 1,GetNumClasses() do
			local className, classFile, classID = GetClassInfo(classID)
			if MEETINGSTONE_UI_DB[classFile] == true  then
				allnoCheck = false
			end
		end
	end
	if allnoCheck == false and classFilter == false then
		return false
	end
    --改动结束
    return activity:Match(...)
end)


function BrowsePanel:CreateBlzFilterPanel()
    -- body
    local BlzFilterPanel = CreateFrame('Frame', nil, self, 'SimplePanelTemplate')
	
    do
        GUI:Embed(BlzFilterPanel, 'Refresh')
        BlzFilterPanel:SetSize(200, 480)
        BlzFilterPanel:SetPoint('TOPRIGHT', MainPanel, 'TOPLEFT', 0, 0)
        BlzFilterPanel:SetFrameLevel(self.ActivityList:GetFrameLevel() + 5)
        BlzFilterPanel:EnableMouse(true)
        local Label = BlzFilterPanel:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
        do
            Label:SetPoint('TOP', 0, -10)
            Label:SetText('地下城搜索')
        end
    end
    self.BlzFilterPanel = BlzFilterPanel
    BlzFilterPanel:SetShown(false)


    local Dungeons = MEETINGSTONE_UI_DB.Dungeon_LIST

    local enabled = C_LFGList.GetAdvancedFilter()
    -- enabled.needsTank = false
    -- enabled.needsHealer = false
    -- enabled.needsDamage = false
    -- enabled.needsMyClass = false
    -- enabled.hasTank = false
    -- enabled.hasHealer = false
    -- enabled.activities = Dungeons
    -- C_LFGList.SaveAdvancedFilter(enabled)
    
    self.MD = {}

    function containsValue(array,value)
        for i,v in ipairs(array) do
            if v == value then
                return true,i
            end
        end
        return false,i        
    end

    
    function saveAdvFilter()
        -- enabled.difficultyNormal = false
        -- enabled.difficultyHeroic = false
        -- enabled.difficultyMythic = false
        -- enabled.difficultyMythicPlus = true
        -- if enabled.minimumRating == 0 then
        --    enabled.minimumRating = 1
        -- end    
        for i,v in ipairs(enabled.activities) do
            local stats,index = containsValue(Dungeons,v)
            if not stats then
                table.remove(enabled.activities,index)
            end    
        end
        C_LFGList.SaveAdvancedFilter(enabled)
    end   
    
    function createCheckBox(index,text,checked,value,cbEvent,cbFunc) 
        local Box = Addon:GetClass('CheckBox'):New(BlzFilterPanel.Inset)

        text = string.gsub(text, "塔扎维什：索·莉亚的宏图", "塔扎维什：宏图")
        text = string.gsub(text, "塔扎维什：琳彩天街", "塔扎维什：天街")
        text = string.gsub(text, "葛拉克朗殞命之地 - 恆龍黎明", "殞命")
        text = string.gsub(text, "姆多茲諾高地 - 恆龍黎明", "高地")
        text = string.gsub(text, "迦拉克隆的陨落 - 永恒黎明", "陨落")
        text = string.gsub(text, "姆诺兹多的崛起 - 永恒黎明", "崛起")

        Box.Check:SetText(text)
        Box.Check:SetChecked(checked)
        Box.dataValue = value
        Box:SetCallback(cbEvent,cbFunc)
        if index == 1 then
            Box:SetPoint('TOPLEFT', 10, 0)
            Box:SetPoint('TOPRIGHT', -10, 0)
        else
            if index == #Dungeons+1 then
                Box:SetPoint('TOPLEFT', self.MD[index-1], 'BOTTOMLEFT', 0, -10)
                Box:SetPoint('TOPRIGHT', self.MD[index-1], 'BOTTOMRIGHT', 0, -10)
            else
                Box:SetPoint('TOPLEFT', self.MD[index-1], 'BOTTOMLEFT')
                Box:SetPoint('TOPRIGHT', self.MD[index-1], 'BOTTOMRIGHT')  
            end       
        end
        table.insert(self.MD, Box)

        return Box
    end
    function createFilterBox(index,text,min,cbEvent,cbFunc,DB_Name)
        local Box = Addon:GetClass('FilterBox'):New(BlzFilterPanel.Inset)
        Box.Check:SetText(text)
        Box.MinBox:SetText(min)
        Box.MinBox:SetMinMaxValues(min, 9999)
        Box.MaxBox:SetText(9999)
        Box.MaxBox:SetMinMaxValues(9999, 9999)
        Box.Text:Hide()
        Box.MaxBox:Hide()
        Box:SetCallback(cbEvent,cbFunc)
        Box:SetPoint('TOPLEFT', self.MD[index-1], 'BOTTOMLEFT', 0, -10)
        Box:SetPoint('TOPRIGHT', self.MD[index-1], 'BOTTOMRIGHT', 0, -10)    
        table.insert(self.MD, Box)
    end    
    
    function roleFunc(box)
        local value = box.Check:GetChecked()
        local key = box.dataValue
        enabled[key] = value        
        saveAdvFilter()
    end  


    
    for i, id in ipairs(Dungeons) do
        local name = C_LFGList.GetActivityGroupInfo(id)
        createCheckBox(i,name,containsValue(enabled.activities,id),id,'OnChanged',function(box)
            local value = box.Check:GetChecked()
            local stats,index = containsValue(enabled.activities,box.dataValue)
            if value then
                if not stats then
                    table.insert(enabled.activities,box.dataValue)
                end
            else
                if stats then
                    table.remove(enabled.activities,index)
                end    
            end
            saveAdvFilter()
        end)        
    end


    createCheckBox(#self.MD + 1, PLAYER_DIFFICULTY1,enabled.difficultyNormal,"difficultyNormal",'OnChanged', roleFunc)
    createCheckBox(#self.MD + 1, PLAYER_DIFFICULTY2,enabled.difficultyHeroic,"difficultyHeroic",'OnChanged', roleFunc)
    createCheckBox(#self.MD + 1, PLAYER_DIFFICULTY6,enabled.difficultyMythic,"difficultyMythic",'OnChanged', roleFunc)
    createCheckBox(#self.MD + 1, PLAYER_DIFFICULTY_MYTHIC_PLUS,enabled.difficultyMythicPlus,"difficultyMythicPlus",'OnChanged', roleFunc)


    local availTank, availHealer, availDPS = C_LFGList.GetAvailableRoles();
    if availTank then 
        createCheckBox(#self.MD + 1, LFG_LIST_NEEDS_TANK,enabled.needsTank,"needsTank",'OnChanged', roleFunc)
    end  
    if availHealer then 
        createCheckBox(#self.MD + 1, LFG_LIST_NEEDS_HEALER,enabled.needsHealer,"needsHealer",'OnChanged',roleFunc)
    end  
    if availDPS then 
        createCheckBox(#self.MD + 1, LFG_LIST_NEEDS_DAMAGE,enabled.needsDamage,"needsDamage",'OnChanged', roleFunc)
    end    
    createCheckBox(#self.MD + 1, string.format(LFG_LIST_CLASS_AVAILABLE, PlayerUtil.GetClassName()),enabled.needsMyClass,"needsMyClass",'OnChanged', roleFunc)
    createCheckBox(#self.MD + 1, LFG_LIST_HAS_TANK,enabled.hasTank,"hasTank",'OnChanged', roleFunc)
    createCheckBox(#self.MD + 1, LFG_LIST_HAS_HEALER,enabled.hasHealer,"hasHealer",'OnChanged', roleFunc)

    createFilterBox(#self.MD + 1, LFG_LIST_MINIMUM_RATING,enabled.minimumRating,'OnChanged',function(box) 
        enabled.minimumRating = box.MinBox:GetNumber()
    end)
     
    local ResetFilterButton = CreateFrame('Button', nil, BlzFilterPanel, 'UIPanelButtonTemplate')
    do
        ResetFilterButton:SetSize(160, 22)
        ResetFilterButton:SetPoint('BOTTOM', BlzFilterPanel, 'BOTTOM', 0, 3)
        ResetFilterButton:SetText('搜索')
        ResetFilterButton:SetScript('OnClick', function(button)
            saveAdvFilter()
            --C_LFGList.ClearSearchTextFields()
            --self.ActivityDropdown:SetValue('2-0-0-0')
            button:Disable()
            self:DoSearch()
            C_Timer.After(3,function()
                button:Enable()
            end)
        end)
    end
	
end

 

-- local function CreateScoreFilter(self, text, score)
--     local DB_Name = 'SCORE'
--     if MEETINGSTONE_UI_DB[DB_Name] == nil then
--         MEETINGSTONE_UI_DB[DB_Name] = false
--     end

--     local filterScoreCheckBox = GUI:GetClass('CheckBox'):New(self)
--     do
--         filterScoreCheckBox:SetSize(24, 24)
--         filterScoreCheckBox:SetPoint('TOPLEFT', self.SearchBox, 'TOPLEFT', 0, 26)
--         filterScoreCheckBox:SetText(text)
--         filterScoreCheckBox:SetChecked(MEETINGSTONE_UI_DB[DB_Name])
--         filterScoreCheckBox:SetScript("OnClick", function()
--             if MEETINGSTONE_UI_DB[DB_Name] then
--                 MEETINGSTONE_UI_DB[DB_Name] = nil
--             else
--                 MEETINGSTONE_UI_DB[DB_Name] = score
--             end
--             self.ActivityList:Refresh()
--         end)
--         GUI:Embed(filterScoreCheckBox, 'Tooltip')
--         filterScoreCheckBox:SetTooltip("说明", "过滤队长是0分的队伍, 可能有助于减少广告")
--         filterScoreCheckBox:SetTooltipAnchor("ANCHOR_TOPLEFT")
--     end
-- end

function BrowsePanel:CreateExSearchButton()

    local ExFilterPanel = CreateFrame('Frame', nil, self, 'SimplePanelTemplate')
	
    do
        GUI:Embed(ExFilterPanel, 'Refresh')
        ExFilterPanel:SetSize(200, 180)
        ExFilterPanel:SetPoint('TOPRIGHT', MainPanel, 'TOPLEFT', 0, -10)
        ExFilterPanel:SetFrameLevel(self.ActivityList:GetFrameLevel() + 5)
        ExFilterPanel:EnableMouse(true)
        local Label = ExFilterPanel:CreateFontString(nil, 'ARTWORK', 'GameFontNormal')
        do
            Label:SetPoint('TOPLEFT', 15, -10)
            Label:SetText('组队过滤器')
        end
    end
    self.ExFilterPanel = ExFilterPanel
    ExFilterPanel:SetShown(false)


    function CreateMemberFilter(text, DB_Name, tooltip,index)
        if MEETINGSTONE_UI_DB[DB_Name] == nil then
            MEETINGSTONE_UI_DB[DB_Name] = false
        end
        local Box = Addon:GetClass('CheckBox'):New(ExFilterPanel.Inset)
        Box.Check:SetText(text)
        Box.Check:SetChecked(MEETINGSTONE_UI_DB[DB_Name])
        Box:SetPoint('TOPLEFT', 10, 10-20*index)
        Box:SetPoint('TOPRIGHT', -10, 10-20*index)
        Box:SetCallback('OnChanged', function()
            MEETINGSTONE_UI_DB[DB_Name] = not MEETINGSTONE_UI_DB[DB_Name]
            self.ActivityList:Refresh()
        end)

        if tooltip then
            GUI:Embed(Box.Check, 'Tooltip')
            Box.Check:SetTooltip("说明", tooltip)
            Box.Check:SetTooltipAnchor("ANCHOR_BOTTOMRIGHT")
        end
    end

    
    CreateMemberFilter( '坦克', 'FILTER_TANK', "隐藏已有坦克职业的队伍，允许多选",1)
    CreateMemberFilter('治疗', 'FILTER_HEALTH', "隐藏已有治疗职业的队伍，允许多选",2)
    CreateMemberFilter( '输出', 'FILTER_DAMAGE', "隐藏输出职业满的队伍，允许多选",3)
    CreateMemberFilter('多选-"或"条件', 'FILTER_MULTY',
        '上方几项多选时，将过滤出同时满足所有条件的队伍\n而多选的同时再勾选本项后，将过滤出满足勾选的任意一项条件的队伍\n一般而言，用于玩家想同时以多个职责加入队伍的时候\n例如战士想查找缺T或DPS的队伍',4)

    -- CreateMemberFilter(self, 'BOTTOM', MainPanel, 80, '同职过滤', 'FILTER_JOB',
    --     "五人副本时，隐藏已有同职责" .. UnitClass("player") .. "的队伍")
    -- CreateScoreFilter(self, '过滤队长0分队伍', 1)

    CreateMemberFilter( '显示屏蔽提示', 'IGNORE_TIPS_LOG',
        "屏蔽了队长或同标题玩家时，聊天框里显示一次提示信息",5)
end

--添加大秘境过滤功能
function BrowsePanel:EX_INIT()
    self:CreateBlzFilterPanel()
    self:CreateExSearchButton()
end

function BrowsePanel:ToggleActivityMenu(anchor, activity)
    local usable, reason = self:CheckSignUpStatus(activity)

    GUI:ToggleMenu(anchor, {
        {
            text = activity:GetName(), isTitle = true, notCheckable = true
        },
        {
            text = '申请加入',
            func = function()
                self:SignUp(activity)
            end,
            disabled = not usable or activity:IsDelisted() or activity:IsApplication(),
            tooltipTitle = not (activity:IsDelisted() or activity:IsApplication()) and '申请加入',
            tooltipText = reason,
            tooltipWhileDisabled = true,
            tooltipOnButton = true,
        },
        {
            text = WHISPER_LEADER,
            func = function()
                ChatFrame_SendTell(activity:GetLeader())
            end,
            disabled = not activity:GetLeader(), -- or not activity:IsApplication(),
            tooltipTitle = not activity:IsApplication() and WHISPER,
            tooltipText = not activity:IsApplication() and LFG_LIST_MUST_SIGN_UP_TO_WHISPER,
            tooltipOnButton = true,
            tooltipWhileDisabled = true,
        },
        {
            --20220603 易安玥 修改到新的举报菜单
            text = LFG_LIST_REPORT_GROUP_FOR,
            func = function()
                LFGList_ReportListing(activity:GetID(), activity:GetLeader());
                LFGListSearchPanel_UpdateResultList(LFGListFrame.SearchPanel);
            end,
        },
        {
            text = '屏蔽队长',
            func = function()
                local name = activity:GetLeader()
                BrowsePanel.IgnoreLeaderOnly[name] = true
                if MEETINGSTONE_UI_DB.IGNORE_TIPS_LOG then
                    print(name .. " 已加入黑名单")
                end
                BrowsePanel.ActivityList:Refresh()
            end,
        },
        {
            text = '屏蔽同标题玩家',
            hidden = function()
                return not Profile:GetEnableIgnoreTitle()
            end,
            func = function()
                local title = activity:GetSummary() -- or activity:GetComment()
                if MEETINGSTONE_UI_DB.IGNORE_TIPS_LOG then
                    print('添加过滤：', title)
                end
                BrowsePanel.IgnoreWithTitle[title] = true
                BrowsePanel.ActivityList:Refresh()
            end,
        },
		{
            text = '复制队长名字',
            func = function()                
                local name = activity:GetLeader()
                print(name)
                GUI:CallUrlDialog(name)
            end,
        },
        { text = CANCEL },
    }, 'cursor')
end

function BrowsePanel:GetExSearchs()
    local filters = {}
    for _, box in ipairs(self.MD) do
        filters[box.dungeonName] = {
            enable = not not box.Check:GetChecked(),
        }
    end
    return filters
end


BrowsePanel:EX_INIT()