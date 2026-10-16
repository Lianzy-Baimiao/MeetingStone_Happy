BuildEnv(...)

local BrowsePanel = Addon:GetModule('BrowsePanel')
local Controller = BrowsePanel.AutoApplyController

local function NoteInput()
    local application = LFGListApplicationDialog
    local description = application and application.Description
    return description, description and description.EditBox
end

function Controller:RestoreNoteInput()
    local saved = self.noteInputLayout
    if not saved then
        return
    end
    self.noteInputLayout = nil
    saved.frame.EditBox:ClearFocus()
    saved.frame:ClearAllPoints()
    saved.frame:SetParent(saved.parent)
    saved.frame:SetSize(saved.width, saved.height)
    for _, point in ipairs(saved.points) do
        saved.frame:SetPoint(unpack(point))
    end
    saved.frame:SetShown(saved.shown)
end

function Controller:ConfirmNote(withNote)
    if not self.noteDialog or not self.noteDialog:IsShown() then
        return
    end
    local waitSeconds = tonumber(self.noteDialog.WaitInput:GetText())
    if not waitSeconds or waitSeconds < 1 or waitSeconds > 300 or waitSeconds ~= math.floor(waitSeconds) then
        self.noteDialog.Message:SetText('最大等待时间请输入 1–300 的整数秒，最长 5 分钟。')
        self.noteDialog.WaitInput:SetFocus()
        return
    end
    local _, editBox = NoteInput()
    if withNote and (not editBox or not editBox:GetText():find('%S')) then
        self.noteDialog.Message:SetText('请填写备注，或选择“无备注开始”。')
        if editBox then
            editBox:SetFocus()
        end
        return
    end
    if not withNote then
        -- The native input forbids SetText. Use the game's own clear operation.
        local ok, err = pcall(C_LFGList.ClearApplicationTextFields)
        if not ok then
            self:SetStatus('无法清空申请备注，请手动清空后重试。')
            self.noteDialog.Message:SetText(self.message)
            print('|cff00ff00集合石自动申请：|r' .. self.message .. ' ' .. tostring(err))
            return
        end
        if editBox and editBox:GetText() ~= '' then
            self.noteDialog.Message:SetText('备注未能清空，请手动清空后重试。')
            return
        end
    end
    self.maxWaitSeconds = waitSeconds
    self.noteDialog:Hide()
    -- Restore the native input before Start reads its value and submits anything.
    self:Start()
end

function Controller:CreateNoteDialog()
    local dialog = CreateFrame('Frame', 'MeetingStoneEXAutoApplyNoteDialog', UIParent, 'BackdropTemplate')
    dialog:Hide()
    -- 20px taller than before the 10-12 hint line, so the note box keeps its gap.
    dialog:SetSize(420, 300)
    dialog:SetFrameStrata('DIALOG')
    dialog:SetPoint('CENTER', UIParent, 'CENTER')
    dialog:EnableMouse(true)
    dialog.hideOnEscape = true
    -- Drag by the window background. The engine moves it; nothing runs per frame.
    dialog:SetMovable(true)
    dialog:SetClampedToScreen(true)
    dialog:RegisterForDrag('LeftButton')
    dialog:SetScript('OnDragStart', function(frame) frame:StartMoving() end)
    dialog:SetScript('OnDragStop', function(frame)
        frame:StopMovingOrSizing()
        -- Remembered for this session only, not in layout-local.txt.
        frame:SetUserPlaced(false)
        self.noteDialogPosition = { frame:GetLeft(), frame:GetTop() }
    end)
    dialog:SetBackdrop({
        bgFile = [[Interface\DialogFrame\UI-DialogBox-Background]],
        edgeFile = [[Interface\DialogFrame\UI-DialogBox-Border]],
        edgeSize = 32, tileSize = 32, tile = true,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    local title = dialog:CreateFontString(nil, 'ARTWORK', 'GameFontNormalLarge')
    title:SetPoint('TOP', 0, -20)
    title:SetText('自动申请：是否添加备注？')
    local message = dialog:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    message:SetPoint('TOP', title, 'BOTTOM', 0, -12)
    message:SetWidth(365)
    message:SetWordWrap(true)
    dialog.Message = message
    local hint = dialog:CreateFontString(nil, 'ARTWORK', 'GameFontDisableSmall')
    hint:SetPoint('TOP', message, 'BOTTOM', 0, -6)
    hint:SetWidth(365)
    hint:SetWordWrap(true)
    hint:SetText('提示：可在搜索框输入 10-12 这样的查询语句，筛选对应层数的队伍。')
    dialog.Hint = hint

    local waitLabel = dialog:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    waitLabel:SetPoint('BOTTOMLEFT', 38, 85)
    waitLabel:SetText('最大等待时间')
    local waitInput = CreateFrame('EditBox', nil, dialog, 'InputBoxTemplate')
    waitInput:SetSize(65, 24)
    waitInput:SetPoint('LEFT', waitLabel, 'RIGHT', 15, 0)
    waitInput:SetAutoFocus(false)
    waitInput:SetNumeric(true)
    waitInput:SetMaxLetters(3)
    waitInput:SetScript('OnEnterPressed', function(input) input:ClearFocus() end)
    waitInput:SetScript('OnEscapePressed', function() dialog:Hide() end)
    dialog.WaitInput = waitInput
    local waitUnit = dialog:CreateFontString(nil, 'ARTWORK', 'GameFontHighlight')
    waitUnit:SetPoint('LEFT', waitInput, 'RIGHT', 8, 0)
    waitUnit:SetText('秒（1–300）')
    local waitHint = dialog:CreateFontString(nil, 'ARTWORK', 'GameFontDisableSmall')
    waitHint:SetPoint('BOTTOMLEFT', 38, 61)
    waitHint:SetText('默认 300 秒（5 分钟），每个队伍分别计时。')

    local withNote = CreateFrame('Button', nil, dialog, 'UIPanelButtonTemplate')
    withNote:SetSize(115, 24)
    withNote:SetPoint('BOTTOMLEFT', 28, 20)
    withNote:SetText('带备注开始')
    withNote:SetScript('OnClick', function() self:ConfirmNote(true) end)
    dialog.WithNoteButton = withNote

    local withoutNote = CreateFrame('Button', nil, dialog, 'UIPanelButtonTemplate')
    withoutNote:SetSize(115, 24)
    withoutNote:SetPoint('LEFT', withNote, 'RIGHT', 8, 0)
    withoutNote:SetText('无备注开始')
    withoutNote:SetScript('OnClick', function() self:ConfirmNote(false) end)
    dialog.WithoutNoteButton = withoutNote

    local cancel = CreateFrame('Button', nil, dialog, 'UIPanelButtonTemplate')
    cancel:SetSize(115, 24)
    cancel:SetPoint('LEFT', withoutNote, 'RIGHT', 8, 0)
    cancel:SetText('取消')
    cancel:SetScript('OnClick', function() dialog:Hide() end)
    dialog.CancelButton = cancel
    local close = CreateFrame('Button', nil, dialog, 'UIPanelCloseButton')
    close:SetPoint('TOPRIGHT', -4, -4)
    close:SetScript('OnClick', function() dialog:Hide() end)
    dialog:SetScript('OnHide', function()
        waitInput:ClearFocus()
        self:RestoreNoteInput()
        -- Remove it from the escape-close popup list too.
        StaticPopupSpecial_Hide(dialog)
    end)
    self.noteDialog = dialog
    return dialog
end

function Controller:RequestStart()
    if self.active then
        return
    end
    local role, reason = self:GetStartRole()
    if not role then
        self:SetStatus(reason)
        print('|cff00ff00集合石自动申请：|r' .. self.message)
        return
    end
    if LFGListApplicationDialog and LFGListApplicationDialog:IsShown() then
        self:SetStatus('请先完成或关闭手动申请窗口，再开启自动申请。')
        print('|cff00ff00集合石自动申请：|r' .. self.message)
        return
    end
    local description, editBox = NoteInput()
    if not description or not editBox then
        self:SetStatus('游戏申请备注输入框不可用，请稍后重试。')
        print('|cff00ff00集合石自动申请：|r' .. self.message)
        return
    end
    local dialog = self.noteDialog or self:CreateNoteDialog()
    if dialog:IsShown() then
        editBox:SetFocus()
        return
    end
    local points = {}
    for index = 1, description:GetNumPoints() do
        points[index] = { description:GetPoint(index) }
    end
    local width, height = description:GetSize()
    self.noteInputLayout = {
        frame = description, parent = description:GetParent(), points = points,
        width = width, height = height, shown = description:IsShown(),
    }
    -- Reuse the securely registered input; a separate edit box cannot submit notes.
    description:ClearAllPoints()
    description:SetParent(dialog)
    description:SetSize(340, 48)
    description:SetPoint('TOP', dialog.Hint, 'BOTTOM', 0, -12)
    description:Show()
    dialog.Message:SetText('填写一次，本次自动申请都会附带此备注。\n不需要备注可直接选择“无备注开始”。')
    dialog.WaitInput:SetText(tostring(self.maxWaitSeconds))
    StaticPopupSpecial_Show(dialog)
    -- StaticPopupSpecial_Show anchors popups at the top of the screen; reopen
    -- where it was last dragged this session instead.
    local position = self.noteDialogPosition
    if position then
        dialog:ClearAllPoints()
        dialog:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', position[1], position[2])
    end
    editBox:SetFocus()
end

BrowsePanel:HookScript('OnHide', function()
    if Controller.noteDialog then
        Controller.noteDialog:Hide()
    end
end)
if LFGListApplicationDialog then
    LFGListApplicationDialog:HookScript('OnShow', function()
        if Controller.noteDialog then
            Controller.noteDialog:Hide()
        end
    end)
end
