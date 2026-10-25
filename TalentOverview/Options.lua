------------------------------------------------------------------------
-- TalentOverview: Options
-- Appears under  Game Menu > Interface > AddOns > TalentOverview
-- (also: /to config)
------------------------------------------------------------------------
local TO = TalentOverview

local panel = CreateFrame("Frame", "TalentOverviewOptions", UIParent)
panel.name = "TalentOverview"
TO.optionsPanel = panel

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -16)
title:SetText("TalentOverview")

local sub = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
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
    local h = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    h:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
    h:SetText(text)
    local line = panel:CreateTexture(nil, "ARTWORK")
    line:SetTexture("Interface\\Buttons\\WHITE8X8")
    line:SetVertexColor(1, 0.82, 0, 0.25)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -3)
    line:SetPoint("RIGHT", panel, "RIGHT", -16, 0)
    return h
end

local function Checkbox(name, label, y, set)
    local cb = CreateFrame("CheckButton", name, panel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y)
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
    local s = CreateFrame("Slider", name, panel, "OptionsSliderTemplate")
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
Header("Appearance", -62)
local bgCheck = Checkbox("TalentOverviewOptBg",
    "Show the talent tree pictures (off: plain parchment)", -82,
    function(v) db().specBg = v end)
local metalCheck = Checkbox("TalentOverviewOptMetal",
    "Use the metal window frame (default: the game's classic frame)", -110,
    function(v) db().metalFrame = v end)
local iconCheck = Checkbox("TalentOverviewOptClassIcon",
    "Show the class icon in the portrait ring (off: your character's face)", -138,
    function(v) db().classIcon = v end)
local elvCheck
local nextY = -166
if ElvUI then
    elvCheck = Checkbox("TalentOverviewOptElvUI",
        "Skin the window with ElvUI", -166,
        function(v) db().useElvUI = v end)
    nextY = -194
end

-- Window
Header("Window", nextY - 14)
local alphaCheck = Checkbox("TalentOverviewOptAlphaOn", "Enable transparency", nextY - 34,
    function(v) db().alphaEnabled = v end)
local alphaSlider = Slider("TalentOverviewOptAlpha", 0.25, 1, 0.05, "25%", "100%")
alphaSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 48, nextY - 78)
alphaSlider:SetScript("OnValueChanged", function(self, value)
    if not db() then return end
    _G["TalentOverviewOptAlphaText"]:SetText(format("Opacity: %d%%", value * 100 + 0.5))
    if panel.loading then return end
    db().alpha = value
    TO:ApplySettings()
end)

local scaleSlider = Slider("TalentOverviewOptScale", 0.4, 1.5, 0.05, "40%", "150%")
scaleSlider:SetPoint("TOPLEFT", panel, "TOPLEFT", 48, nextY - 136)
scaleSlider:SetScript("OnValueChanged", function(self, value)
    if not db() then return end
    _G["TalentOverviewOptScaleText"]:SetText(format("Window scale: %d%%", value * 100 + 0.5))
    if panel.loading then return end
    db().scale = value
    TO:ApplySettings()
end)

local resetBtn = CreateFrame("Button", "TalentOverviewOptReset", panel, "UIPanelButtonTemplate")
resetBtn:SetWidth(170)
resetBtn:SetHeight(22)
resetBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, nextY - 180)
resetBtn:SetText("Reset window position")
resetBtn:SetScript("OnClick", function() SlashCmdList["TALENTOVERVIEW"]("reset") panel.refresh() end)

-- Links (the game cannot open a browser: click the box, press Ctrl+C, paste into your browser)
Header("About", nextY - 222)
local function LinkRow(label, url, y, icon)
    local lead = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    if icon then
        local t = panel:CreateTexture(nil, "ARTWORK")
        t:SetTexture(TO.TEX .. icon)
        t:SetWidth(26)
        t:SetHeight(26)
        t:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, y + 2)
        lead:SetPoint("LEFT", t, "RIGHT", 6, 0)
    else
        lead:SetPoint("TOPLEFT", panel, "TOPLEFT", 52, y - 4)
    end
    lead:SetText(label)
    local eb = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    eb:SetAutoFocus(false)
    eb:SetWidth(280)
    eb:SetHeight(20)
    eb:SetPoint("TOPLEFT", panel, "TOPLEFT", 190, y - 2)
    eb:SetText(url)
    eb:SetCursorPosition(0)
    eb:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    eb:SetScript("OnTextChanged", function(self) if self:GetText() ~= url then self:SetText(url) end end)
    return eb
end
LinkRow("GitHub", "https://github.com/Stradios/TalentOverview", nextY - 244)
LinkRow("Buy me a coffee (Ko-fi)", "https://ko-fi.com/stradiostv", nextY - 278, "kofi")
local credit = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
credit:SetPoint("TOPLEFT", panel, "TOPLEFT", 20, nextY - 314)
credit:SetText("TalentOverview by Stradios.  Click a box and press Ctrl+C to copy the link.")

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
