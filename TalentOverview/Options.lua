------------------------------------------------------------------------
-- TalentOverview: Options
-- Appears under  Game Menu > Interface > AddOns > TalentOverview
-- (also: /to config)
------------------------------------------------------------------------
local TO = TalentOverview

local panel = CreateFrame("Frame", "TalentOverviewOptions", UIParent)
panel.name = "TalentOverview"
TO.optionsPanel = panel

local scroll = CreateFrame("ScrollFrame", "TalentOverviewOptScroll", panel, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -6)
scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 6)
local content = CreateFrame("Frame", "TalentOverviewOptContent", scroll)
content:SetWidth(390)
content:SetHeight(470)
scroll:SetScrollChild(content)

local title = content:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", content, "TOPLEFT", 16, -16)
title:SetText("TalentOverview")

local sub = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
sub:SetText("All talent trees and glyphs in one window.  Open it with N.")

local function db() return TalentOverviewDB end

-- Any change made here asks for a UI reload (the window applies it right away too).
StaticPopupDialogs["TALENTOVERVIEW_RELOAD"] = {
    text = "TalentOverview: your settings were changed.\n\nReload the UI to apply them completely?",
    button1 = "Reload UI",
    button2 = "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
    preferredIndex = 3,
}
local function AskReload()
    if panel.loading then return end
    StaticPopup_Show("TALENTOVERVIEW_RELOAD")
end

local function Header(text, y)
    local h = content:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    h:SetPoint("TOPLEFT", content, "TOPLEFT", 16, y)
    h:SetText(text)
    local line = content:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -3)
    line:SetPoint("RIGHT", content, "RIGHT", -16, 0)
    return h
end

local function Checkbox(name, label, y, set)
    local cb = CreateFrame("CheckButton", name, content, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y)
    _G[name .. "Text"]:SetText(label)
    cb:SetScript("OnClick", function(self)
        set(self:GetChecked() and true or false)
        TO:ApplySettings()
        panel.refresh()
        AskReload()
    end)
    return cb
end

local function Slider(name, minV, maxV, step, lowText, highText)
    local s = CreateFrame("Slider", name, content, "OptionsSliderTemplate")
    s:SetWidth(240)
    s:SetHeight(16)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    _G[name .. "Low"]:SetText(lowText)
    _G[name .. "High"]:SetText(highText)
    s:HookScript("OnMouseUp", AskReload)          -- ask once the slider is let go
    return s
end

-- Appearance
Header("Appearance", -56)
local bgCheck = Checkbox("TalentOverviewOptBg",
    "Show talent tree pictures", -74,
    function(v) db().specBg = v end)
local metalCheck = Checkbox("TalentOverviewOptMetal",
    "Use the metal window frame", -98,
    function(v) db().metalFrame = v end)
local iconCheck = Checkbox("TalentOverviewOptClassIcon",
    "Class icon in the portrait ring", -122,
    function(v) db().classIcon = v end)
local elvCheck
local nextY = -146
if ElvUI then
    elvCheck = Checkbox("TalentOverviewOptElvUI", "Skin the window with ElvUI", -146,
        function(v) db().useElvUI = v end)
    nextY = -170
end

-- Window
Header("Window", nextY - 8)
local alphaCheck = Checkbox("TalentOverviewOptAlphaOn", "Enable transparency", nextY - 26,
    function(v) db().alphaEnabled = v end)
local alphaSlider = Slider("TalentOverviewOptAlpha", 0.25, 1, 0.05, "25%", "100%")
alphaSlider:SetWidth(150)
alphaSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 215, nextY - 38)
alphaSlider:SetScript("OnValueChanged", function(self, value)
    if not db() then return end
    _G["TalentOverviewOptAlphaText"]:SetText(format("Opacity: %d%%", value * 100 + 0.5))
    if panel.loading then return end
    db().alpha = value
    TO:ApplySettings()
end)

local scaleSlider = Slider("TalentOverviewOptScale", 0.4, 1.5, 0.05, "40%", "150%")
scaleSlider:SetWidth(170)
scaleSlider:SetPoint("TOPLEFT", content, "TOPLEFT", 48, nextY - 84)
scaleSlider:SetScript("OnValueChanged", function(self, value)
    if not db() then return end
    _G["TalentOverviewOptScaleText"]:SetText(format("Window scale: %d%%", value * 100 + 0.5))
    if panel.loading then return end
    db().scale = value
    TO:ApplySettings()
end)

local resetBtn = CreateFrame("Button", "TalentOverviewOptReset", content, "UIPanelButtonTemplate")
resetBtn:SetWidth(130)
resetBtn:SetHeight(22)
resetBtn:SetPoint("TOPLEFT", content, "TOPLEFT", 240, nextY - 76)
resetBtn:SetText("Reset position")
resetBtn:SetScript("OnClick", function() SlashCmdList["TALENTOVERVIEW"]("reset") panel.refresh() end)

-- About: the game cannot open a browser, so the links are boxes to copy from
Header("About", nextY - 128)
local function LinkRow(label, url, y, icon)
    local lead = content:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    if icon then
        local t = content:CreateTexture(nil, "ARTWORK")
        t:SetTexture(TO.TEX .. icon)
        t:SetWidth(32)
        t:SetHeight(32)
        t:SetPoint("TOPLEFT", content, "TOPLEFT", 36, y + 6)
        lead:SetPoint("LEFT", t, "RIGHT", 4, 0)
    else
        lead:SetPoint("TOPLEFT", content, "TOPLEFT", 20, y - 5)
    end
    lead:SetText(label)
    local eb = CreateFrame("EditBox", nil, content)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(272)
    eb:SetHeight(22)
    eb:SetTextInsets(6, 6, 0, 0)
    eb:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    eb:SetBackdropColor(0, 0, 0, 0.6)
    eb:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
    eb:SetPoint("TOPLEFT", content, "TOPLEFT", 76, y - 3)
    eb:SetText(url)
    eb:SetCursorPosition(0)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnTextChanged", function(self) if self:GetText() ~= url then self:SetText(url) end end)
    return eb
end
LinkRow("GitHub", "https://github.com/Stradios/TalentOverview", nextY - 152)
LinkRow("", "https://ko-fi.com/stradiostv", nextY - 184, "kofi")
local credit = content:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
credit:SetPoint("TOPLEFT", content, "TOPLEFT", 20, nextY - 218)
credit:SetText("By Stradios. Click a link, press Ctrl+C to copy it.")

-- push database values into the widgets
function panel.refresh()
    local d = db()
    if not d then return end
    panel.loading = true
    alphaCheck:SetChecked(d.alphaEnabled)
    bgCheck:SetChecked(d.specBg)
    metalCheck:SetChecked(d.metalFrame)
    iconCheck:SetChecked(d.classIcon ~= false)
    if elvCheck then elvCheck:SetChecked(d.useElvUI ~= false) end
    alphaSlider:SetValue(d.alpha or 0.85)
    scaleSlider:SetValue(d.scale or TO:DefaultScale())
    if d.alphaEnabled then
        alphaSlider:SetAlpha(1)
        alphaSlider:EnableMouse(true)
    else
        alphaSlider:SetAlpha(0.4)        -- looks disabled; the checkbox decides whether it applies
        alphaSlider:EnableMouse(false)
    end
    panel.loading = false
end
panel:SetScript("OnShow", function()
    panel.refresh()
    if TO.SkinOptions then TO:SkinOptions({ checks = { alphaCheck, bgCheck, metalCheck, iconCheck, elvCheck },
        sliders = { alphaSlider, scaleSlider }, buttons = { resetBtn } }) end
end)

InterfaceOptions_AddCategory(panel)
