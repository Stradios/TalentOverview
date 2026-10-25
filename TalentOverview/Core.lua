------------------------------------------------------------------------
-- TalentOverview: Core
-- Main window, bottom bar (search / spec dropdown / apply / reset / builds), events.
-- Target client: WoW 3.3.5a (Lua 5.1, old frame API)
------------------------------------------------------------------------
TalentOverview = TalentOverview or {}
local TO = TalentOverview

-- Layout constants -----------------------------------------------------
TO.ICON  = 36      -- talent icon size
TO.STEP  = 43      -- distance between talent icons
TO.COLS  = 4
TO.ROWS  = 11
TO.TEX   = "Interface\\AddOns\\TalentOverview\\Textures\\"

TO.COLORS = {
    locked = { 0.45, 0.45, 0.45 },
    open   = { 1.00, 0.82, 0.00 },
    max    = { 0.20, 1.00, 0.20 },
}

TO.TREE_W   = TO.COLS * TO.STEP - (TO.STEP - TO.ICON)   -- 165
TO.TREE_H   = TO.ROWS * TO.STEP - (TO.STEP - TO.ICON)   -- 466
TO.TREE_GAP = 100                                       -- space between the three trees
TO.TREE_TOP = 78                                        -- distance from window top to the first talent row

local WIN_W = 1280                                      -- wide enough for three trees plus the pictures
local WIN_H = TO.TREE_TOP + TO.TREE_H + 96
TO.TREE_X0 = (WIN_W - (3 * TO.TREE_W + 2 * TO.TREE_GAP)) / 2
TO.WIN_W, TO.WIN_H = WIN_W, WIN_H
TO.ART_TOP = 22                                         -- the background starts below the title bar

local DEFAULTS = {
    alphaEnabled = false,   -- transparency off unless the user enables it in the options
    alpha        = 0.85,
    specBg       = true,    -- show the talent tree pictures (off = plain parchment colour)
    classIcon    = true,    -- ring shows the class icon (false: the character's face)
    metalFrame   = false,   -- false: the game's classic frame, true: retail-style metal frame
    useElvUI     = true,    -- skin the window with ElvUI when ElvUI is loaded
}

------------------------------------------------------------------------
-- Round textures. SetPortraitToTexture clips an icon to a circle, so no
-- square corners are left behind the ring.
------------------------------------------------------------------------
function TO:SetRoundTexture(tex, path)
    if SetPortraitToTexture then
        SetPortraitToTexture(tex, path)
    else
        tex:SetTexture(path)
    end
end

------------------------------------------------------------------------
-- Shared helper: a round icon button (circular icon + ring + soft shadow)
------------------------------------------------------------------------
function TO:CreateRoundButton(parent, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(size)
    b:SetHeight(size)

    b.shadow = b:CreateTexture(nil, "BACKGROUND")
    b.shadow:SetWidth(size + 16)
    b.shadow:SetHeight(size + 16)
    b.shadow:SetPoint("CENTER", b, "CENTER", 0, -1)
    b.shadow:SetTexture(TO.TEX .. "shadow")

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints(b)

    -- created after the icon, so it draws on top of it (same layer = creation order)
    b.ring = b:CreateTexture(nil, "ARTWORK")
    b.ring:SetAllPoints(b)
    b.ring:SetTexture(TO.TEX .. "ring")

    b.count = b:CreateFontString(nil, "OVERLAY")
    b.count:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -2)

    return b
end

function TO:SetState(b, state)
    local c = TO.COLORS[state]
    b.ring:SetVertexColor(c[1], c[2], c[3])
    b.icon:SetDesaturated((state == "locked") and 1 or nil)
    if state == "locked" then
        b.icon:SetVertexColor(0.7, 0.7, 0.7)
    else
        b.icon:SetVertexColor(1, 1, 1)
    end
end

------------------------------------------------------------------------
-- Talent point helpers
------------------------------------------------------------------------
function TO:GetPreviewSpent()
    local sum = 0
    for tab = 1, (GetNumTalentTabs() or 0) do
        local _, _, _, _, prev = GetTalentTabInfo(tab)
        sum = sum + (prev or 0)
    end
    return sum
end

function TO:GetUnspent()
    local u = GetUnspentTalentPoints() or 0
    return u - self:GetPreviewSpent()
end

------------------------------------------------------------------------
-- Main frame
------------------------------------------------------------------------
local f = CreateFrame("Frame", "TalentOverviewFrame", UIParent)
TO.frame = f
f:SetFrameStrata("HIGH")
f:SetWidth(WIN_W)
f:SetHeight(WIN_H)
f:SetPoint("CENTER")
f:EnableMouse(true)
f:SetMovable(true)
f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")
f:Hide()
tinsert(UISpecialFrames, "TalentOverviewFrame")   -- ESC closes it

f:SetScript("OnDragStart", function(self) self:StartMoving() end)
f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint(1)
    if TalentOverviewDB then TalentOverviewDB.pos = { point, relPoint, x, y } end
end)

------------------------------------------------------------------------
-- Header
------------------------------------------------------------------------
local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", f, "TOP", 0, -4)
title:SetText("Talents")
TO.title = title

local points = f:CreateFontString(nil, "OVERLAY")
points:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
points:SetPoint("TOPLEFT", f, "TOPLEFT", 70, -34)
TO.pointsText = points

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetFrameLevel(f:GetFrameLevel() + 50)   -- above the chooser and the border
TO.closeButton = close                        -- placed by TO:ApplyFrameStyle (Chrome.lua)

------------------------------------------------------------------------
-- Bottom bar: search, spec dropdown, apply / reset / builds
------------------------------------------------------------------------
local function Label(text, x, y)
    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    fs:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, y)
    fs:SetTextColor(1, 0.82, 0)
    fs:SetText(text)
    return fs
end

Label("Search", 28, 72)

local search = CreateFrame("EditBox", "TalentOverviewSearch", f, "InputBoxTemplate")
search:SetWidth(150)
search:SetHeight(20)
search:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 34, 48)
search:SetAutoFocus(false)
search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
search:SetScript("OnTextChanged", function(self)
    local t = strlower(strtrim(self:GetText() or ""))
    TO.searchText = t
    TO:UpdateTrees()
end)

-- spec dropdown, where the old Settings button was --------------------------
local drop = CreateFrame("Frame", "TalentOverviewSpecDrop", f, "UIDropDownMenuTemplate")
drop:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 186, 44)
TO.specDrop = drop

local function SetDropWidth(width)
    -- stock 3.3.5 takes (width, frame); later and some custom clients take (frame, width).
    -- Try one order and fall back to the other instead of guessing from the build number.
    if not pcall(UIDropDownMenu_SetWidth, drop, width) then
        pcall(UIDropDownMenu_SetWidth, width, drop)
    end
end

local function DropInit(self, level)
    local active = GetActiveTalentGroup() or 1
    for group = 1, (GetNumTalentGroups() or 1) do
        local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
        -- Specs.lua loads after this file, and Initialize may call us immediately
        info.text = TO.GroupSpecName and TO:GroupSpecName(group) or ("Specialization " .. group)
        info.arg1 = group
        info.checked = (group == active)
        info.func = function(_, arg1)
            if arg1 ~= (GetActiveTalentGroup() or 1) then SetActiveTalentGroup(arg1) end
        end
        UIDropDownMenu_AddButton(info, level)
    end
    local info = UIDropDownMenu_CreateInfo and UIDropDownMenu_CreateInfo() or {}
    info.text = "Choose specialization..."
    info.notCheckable = 1
    info.func = function()
        TO.chooserSkipped = {}
        TO:ShowChooser(GetActiveTalentGroup() or 1)
    end
    UIDropDownMenu_AddButton(info, level)
end
UIDropDownMenu_Initialize(drop, DropInit)
SetDropWidth(140)

local apply = CreateFrame("Button", "TalentOverviewApply", f, "UIPanelButtonTemplate")
apply:SetWidth(100)
apply:SetHeight(24)
apply:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 26, 14)
apply:SetText("Apply Changes")
apply:SetScript("OnClick", function()
    if TO:GetPreviewSpent() > 0 then LearnPreviewTalents(false) end
end)
TO.applyButton = apply

local reset = CreateFrame("Button", "TalentOverviewReset", f, "UIPanelButtonTemplate")
reset:SetWidth(80)
reset:SetHeight(24)
reset:SetPoint("LEFT", apply, "RIGHT", 6, 0)
reset:SetText("Reset")
reset:SetScript("OnClick", function()
    if ResetGroupPreviewTalentPoints then
        ResetGroupPreviewTalentPoints(false, GetActiveTalentGroup() or 1)
    end
end)
TO.resetButton = reset

local builds = CreateFrame("Button", "TalentOverviewBuildsButton", f, "UIPanelButtonTemplate")
builds:SetWidth(80)
builds:SetHeight(24)
builds:SetPoint("LEFT", reset, "RIGHT", 6, 0)
builds:SetText("Builds")
builds:SetScript("OnClick", function() TO:ToggleBuilds() end)

------------------------------------------------------------------------
-- Refresh
------------------------------------------------------------------------
function TO:UpdateBar()
    local unspent = self:GetUnspent()
    self.pointsText:SetText("Talent points available: |cff" ..
        ((unspent > 0) and "33ff33" or "ffffff") .. unspent .. "|r")

    if self:GetPreviewSpent() > 0 then
        self.applyButton:Enable()
        self.resetButton:Enable()
    else
        self.applyButton:Disable()
        self.resetButton:Disable()
    end

    -- the dropdown shows the active specialization's name
    _G["TalentOverviewSpecDropText"]:SetText(self:GroupSpecName(GetActiveTalentGroup() or 1))
end

function TO:DefaultScale()
    return math.min(1,
        (UIParent:GetHeight() - 30) / WIN_H,
        (UIParent:GetWidth() - 30) / WIN_W)
end

-- Reads TalentOverviewDB and applies it to the window. Called on load and
-- whenever the options panel changes something.
function TO:ApplySettings()
    local db = TalentOverviewDB
    if not db then return end
    f:SetAlpha(db.alphaEnabled and db.alpha or 1)
    f:SetScale(db.scale or self:DefaultScale())
    self:UpdateBackground()
    if self.ApplyFrameStyle then self:ApplyFrameStyle() end
end

function TO:OpenOptions()
    if self.optionsPanel then
        -- 3.3.5 quirk: the first call only opens the window, the second selects the category
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
        InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    end
end

function TO:Refresh()
    if self.suspend or not f:IsShown() then return end
    self:BuildTrees()
    self:BuildGlyphs()
    self:CheckChooser()          -- may assign the main tree of a character that already has points
    self:UpdateBackground()
    self:UpdateTrees()
    self:UpdateGlyphs()
    self:UpdateBuilds()
    self:UpdateBar()
    self:UpdateTitle()
end

f:SetScript("OnShow", function()
    if TO.TrySkin then TO:TrySkin() end
    TO:Refresh()
end)

function TO:Toggle()
    if f:IsShown() then
        f:Hide()
    else
        if UnitLevel("player") < 10 then
            DEFAULT_CHAT_FRAME:AddMessage("|cffffd100TalentOverview:|r talents unlock at level 10.")
            return
        end
        f:Show()
    end
end

-- The stock frame is shown by some events (e.g. using a glyph item); close it.
local hideTimer = CreateFrame("Frame")
hideTimer:Hide()
hideTimer:SetScript("OnUpdate", function(self, elapsed)
    self.t = (self.t or 0) + elapsed
    if self.t > 0.1 then
        self:Hide()
        self.t = 0
        if PlayerTalentFrame and PlayerTalentFrame:IsShown() then
            pcall(HideUIPanel, PlayerTalentFrame)
        end
    end
end)

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGIN")
for _, e in ipairs({
    "PLAYER_TALENT_UPDATE", "PREVIEW_TALENT_POINTS_CHANGED", "CHARACTER_POINTS_CHANGED",
    "ACTIVE_TALENT_GROUP_CHANGED", "GLYPH_ADDED", "GLYPH_REMOVED", "GLYPH_UPDATED",
    "USE_GLYPH", "PLAYER_LEVEL_UP",
}) do
    pcall(ev.RegisterEvent, ev, e)   -- never error on an event this client lacks
end

ev:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= "TalentOverview" then return end
        TalentOverviewDB = TalentOverviewDB or {}
        for k, v in pairs(DEFAULTS) do
            if TalentOverviewDB[k] == nil then TalentOverviewDB[k] = v end
        end
        local db = TalentOverviewDB
        db.builds = db.builds or {}
        TO:ApplySettings()
        if db.pos then
            f:ClearAllPoints()
            f:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
        end

    elseif event == "PLAYER_LOGIN" then
        -- take over the N key and the micro-button
        ToggleTalentFrame = function() TO:Toggle() end
        TO.lastGroups = GetNumTalentGroups() or 1
        TO:UpdateBackground()

    elseif event == "USE_GLYPH" then
        if not f:IsShown() then f:Show() end
        hideTimer.t = 0
        hideTimer:Show()

    else
        -- learned Dual Talent Specialization: open the window so the player can choose
        local n = GetNumTalentGroups() or 1
        if TO.lastGroups and n > TO.lastGroups and not f:IsShown() then
            TO:Toggle()
        end
        TO.lastGroups = n
        if event == "ACTIVE_TALENT_GROUP_CHANGED" then TO:HideChooser() end
        TO:Refresh()
    end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_TALENTOVERVIEW1 = "/to"
SLASH_TALENTOVERVIEW2 = "/talentoverview"
SlashCmdList["TALENTOVERVIEW"] = function(msg)
    msg = strlower(strtrim(msg or ""))
    local cmd, arg = msg:match("^(%S+)%s*(%S*)$")
    if cmd == "scale" and tonumber(arg) then
        TalentOverviewDB.scale = math.max(0.4, math.min(1.5, tonumber(arg)))
        TO:ApplySettings()
    elseif cmd == "reset" then
        f:ClearAllPoints()
        f:SetPoint("CENTER")
        TalentOverviewDB.pos = nil
        TalentOverviewDB.scale = nil
        TO:ApplySettings()
    elseif cmd == "config" or cmd == "options" or cmd == "settings" then
        TO:OpenOptions()
    elseif cmd == "builds" then
        TO:ToggleBuilds()
    else
        TO:Toggle()
    end
end

DEFAULT_CHAT_FRAME:AddMessage("|cffffd100TalentOverview 1.8 loaded.|r Press N. Options: /to config")
