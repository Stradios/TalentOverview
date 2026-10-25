------------------------------------------------------------------------
-- TalentOverview: Specializations
--
-- 3.3.5 has no real "choose a specialization" step: you may spend points in
-- any tree. This module adds the modern-style choice as a layer on top:
--   * the first time you open the window at level 10+ (or on your second
--     talent group) you pick a specialization,
--   * that choice is stored per talent group and shown as the name in the dropdown,
--   * it does NOT restrict where you can spend talent points.
-- Characters that already have points are assigned the tree they invested
-- most in, without asking.
------------------------------------------------------------------------
local TO = TalentOverview

-- tree order is the 3.3.5 tab order of each class
TO.ROLES = {
    PALADIN     = { "Healer", "Tank", "Damage" },
    WARRIOR     = { "Damage", "Damage", "Tank" },
    MAGE        = { "Damage", "Damage", "Damage" },
    PRIEST      = { "Healer", "Healer", "Damage" },
    SHAMAN      = { "Damage", "Damage", "Healer" },
    HUNTER      = { "Damage", "Damage", "Damage" },
    ROGUE       = { "Damage", "Damage", "Damage" },
    DRUID       = { "Damage", "Tank / Damage", "Healer" },
    WARLOCK     = { "Damage", "Damage", "Damage" },
    DEATHKNIGHT = { "Tank / Damage", "Damage", "Damage" },
}

local function PlayerClass()
    local _, class = UnitClass("player")
    return class
end

------------------------------------------------------------------------
-- Storage: TalentOverviewDB.chars["Name-Realm"].spec[talentGroup] = tab
------------------------------------------------------------------------
function TO:GetSpecStore()
    local db = TalentOverviewDB
    db.chars = db.chars or {}
    local key = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    db.chars[key] = db.chars[key] or { spec = {} }
    return db.chars[key]
end

function TO:GetSpec(group)
    return self:GetSpecStore().spec[group or GetActiveTalentGroup() or 1]
end

function TO:SetSpec(tab, group)
    self:GetSpecStore().spec[group or GetActiveTalentGroup() or 1] = tab
end

-- name of the chosen specialization of a talent group (used by the dropdown)
function TO:GroupSpecName(group)
    local tab = TalentOverviewDB and self:GetSpec(group)
    if tab then
        local name = GetTalentTabInfo(tab)
        if name then return name end
    end
    return "Specialization " .. group
end

-- tree with the most points in the given talent group, or nil when none are spent
function TO:DetectSpec(group)
    local best, bestPts, total = nil, 0, 0
    local isActive = (group == (GetActiveTalentGroup() or 1))
    for tab = 1, (GetNumTalentTabs() or 0) do
        local _, _, spent, _, prev = GetTalentTabInfo(tab, false, false, group)
        spent = (spent or 0) + (isActive and (prev or 0) or 0)
        total = total + spent
        if spent > bestPts then best, bestPts = tab, spent end
    end
    if total > 0 then return best end
end

------------------------------------------------------------------------
-- Chooser overlay (full window, picture of the hovered specialization behind it)
------------------------------------------------------------------------
TO.chooserSkipped = {}

function TO:BuildChooser()
    if self.chooser then return true end
    if not self.treesBuilt then return false end

    local f = self.frame
    local W, H = self.WIN_W, self.WIN_H - self.ART_TOP

    local ch = CreateFrame("Frame", nil, f)
    self.chooser = ch
    ch:SetFrameLevel(f:GetFrameLevel() + 30)
    ch:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -self.ART_TOP)
    ch:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
    ch:EnableMouse(true)           -- swallow clicks meant for the trees underneath
    ch:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ch:SetBackdropColor(0.08, 0.06, 0.05, 1)
    ch:Hide()

    -- colour field: the edge colours of the hovered specialization's picture, stretched
    -- over the whole screen (the same colours that surround its tree in the window)
    ch.field = self:CreateEdgeStrips(ch, "BACKGROUND", 0, 0, W, H, "left", 1, 1)

    ch.shade = ch:CreateTexture(nil, "BORDER")
    ch.shade:SetAllPoints(ch)
    ch.shade:SetTexture("Interface\\Buttons\\WHITE8X8")
    ch.shade:SetVertexColor(0, 0, 0, 0.55)

    local title = ch:CreateFontString(nil, "OVERLAY")
    title:SetFont("Fonts\\FRIZQT__.TTF", 28, "OUTLINE")
    title:SetPoint("TOP", ch, "TOP", 0, -34)
    title:SetTextColor(1, 0.82, 0)
    title:SetText("Choose your specialization")

    local sub = ch:CreateFontString(nil, "OVERLAY")
    sub:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -10)
    sub:SetWidth(W - 200)
    ch.sub = sub

    local skip = CreateFrame("Button", nil, ch, "UIPanelButtonTemplate")
    skip:SetWidth(120)
    skip:SetHeight(24)
    skip:SetPoint("BOTTOM", ch, "BOTTOM", 0, 22)
    skip:SetText("Decide later")
    ch.skip = skip
    skip:SetScript("OnClick", function()
        TO.chooserSkipped[ch.group or 1] = true
        ch:Hide()
    end)

    local numTabs = GetNumTalentTabs() or 3
    local cw, chh, gap = 300, 330, 40
    local x0 = (W - (numTabs * cw + (numTabs - 1) * gap)) / 2
    ch.cards = {}

    for tab = 1, numTabs do
        local name, icon = GetTalentTabInfo(tab)
        local card = CreateFrame("Button", nil, ch)
        card:SetWidth(cw)
        card:SetHeight(chh)
        card:SetPoint("TOPLEFT", ch, "TOPLEFT", x0 + (tab - 1) * (cw + gap), -150)
        card:SetBackdrop({
            bgFile   = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = false, edgeSize = 14,
            insets = { left = 3, right = 3, top = 3, bottom = 3 },
        })
        card:SetBackdropColor(0, 0, 0, 1)
        card:SetBackdropBorderColor(0.6, 0.55, 0.4, 1)
        card.tab = tab

        -- the specialization's own picture fills the card, underneath everything else on it
        local scale = math.min((cw - 8) / self.PIC_W, (chh - 8) / self.PIC_H)
        card.pic = self:CreatePicture(card, "ARTWORK", (cw - self.PIC_W * scale) / 2,
            (chh - self.PIC_H * scale) / 2, scale, false)

        local round = self:CreateRoundButton(card, 72)
        round:SetPoint("TOP", card, "TOP", 0, -34)
        self:SetRoundTexture(round.icon, icon)
        round:EnableMouse(false)
        self:SetState(round, "open")
        card.round = round

        card.name = card:CreateFontString(nil, "OVERLAY")
        card.name:SetFont("Fonts\\FRIZQT__.TTF", 22, "OUTLINE")
        card.name:SetPoint("TOP", round, "BOTTOM", 0, -22)
        card.name:SetTextColor(1, 0.82, 0)
        card.name:SetText(name)

        card.role = card:CreateFontString(nil, "OVERLAY")
        card.role:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        card.role:SetPoint("TOP", card.name, "BOTTOM", 0, -10)

        card.pts = card:CreateFontString(nil, "OVERLAY")
        card.pts:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
        card.pts:SetPoint("TOP", card.role, "BOTTOM", 0, -8)
        card.pts:SetTextColor(0.8, 0.8, 0.8)

        local choose = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
        choose:SetWidth(130)
        choose:SetHeight(26)
        choose:SetPoint("BOTTOM", card, "BOTTOM", 0, 26)
        choose:SetText("Choose")
        choose:SetScript("OnClick", function() card:Click() end)
        card.choose = choose

        card:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(1, 0.82, 0, 1)
            TO:ShowChooserField(self.tab)
        end)
        card:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(0.6, 0.55, 0.4, 1)
        end)
        card:SetScript("OnClick", function(self)
            TO:SetSpec(self.tab, ch.group)
            ch:Hide()
            TO:Refresh()
        end)

        ch.cards[tab] = card
    end
    return true
end

-- the background of the chooser takes the colours of the card under the mouse
function TO:ShowChooserField(tab)
    local ch = self.chooser
    if ch then ch.field:SetBase(self:TabPictureBase(tab)) end
end

function TO:ShowChooser(group)
    if not self:BuildChooser() then return end
    local ch = self.chooser
    group = group or GetActiveTalentGroup() or 1
    ch.group = group

    local numGroups = GetNumTalentGroups() or 1
    local text = "Your choice sets the background. You can still spend points in any tree."
    if numGroups >= 2 then
        text = "Talent specialization " .. group .. " of " .. numGroups .. ".  " .. text
    end
    ch.sub:SetText(text)

    local roles = self.ROLES[PlayerClass()] or {}
    for tab, card in ipairs(ch.cards) do
        card.pic:SetBase(self:TabPictureBase(tab))
        card.role:SetText(roles[tab] or "")
        local _, _, spent = GetTalentTabInfo(tab, false, false, group)
        card.pts:SetText((spent or 0) .. " points spent")
    end
    self:ShowChooserField(self:GetSpec(group) or 1)
    if self.SkinChooser then self:SkinChooser() end
    ch:Show()
end

function TO:HideChooser()
    if self.chooser then self.chooser:Hide() end
end

-- Called after every refresh: decides whether the chooser is due.
function TO:CheckChooser()
    if not self.treesBuilt or not TalentOverviewDB then return end
    if UnitLevel("player") < 10 then return end
    if self.chooser and self.chooser:IsShown() then return end

    local active = GetActiveTalentGroup() or 1
    local store = self:GetSpecStore()

    -- characters that already invested points: pick the main tree silently
    for group = 1, (GetNumTalentGroups() or 1) do
        if store.spec[group] == nil then
            local detected = self:DetectSpec(group)
            if detected then store.spec[group] = detected end
        end
    end

    if store.spec[active] == nil and not self.chooserSkipped[active] then
        self:ShowChooser(active)
        return
    end

    -- just learned Dual Talent Specialization: ask for the second one right away
    if (GetNumTalentGroups() or 1) >= 2 and store.spec[3 - active] == nil
        and not self.chooserSkipped[3 - active] then
        self:ShowChooser(3 - active)
    end
end

function TO:UpdateTitle()
    local spec = self:GetSpec()
    if spec then
        local name = GetTalentTabInfo(spec)
        self.title:SetText("Talents |cffffd100- " .. (name or "") .. "|r")
    else
        self.title:SetText("Talents")
    end
end
