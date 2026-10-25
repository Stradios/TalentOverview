------------------------------------------------------------------------
-- TalentOverview: Skins
-- ElvUI (ElvUI-WotLK) support. When ElvUI is loaded and its Blizzard skinning is on
-- (and the player has not turned it off in our options), the main window, builds
-- window, settings and specialization chooser are drawn with ElvUI's templates:
-- ElvUI backdrop instead of our frame, ElvUI buttons / edit boxes / dropdown / checkboxes.
-- The talent icons and glyph sockets keep their own look.
--
-- Every ElvUI call is wrapped in pcall: a change in ElvUI can never break the window.
-- Skinning happens when a window is first shown, after ElvUI has finished loading.
------------------------------------------------------------------------
local TO = TalentOverview

local function Elv()
    local db = TalentOverviewDB
    if not db or db.useElvUI == false or type(ElvUI) ~= "table" then return end
    local E = ElvUI[1]
    if type(E) ~= "table" or not E.private or not E.private.skins then return end
    if not (E.private.skins.blizzard and E.private.skins.blizzard.enable) then return end
    local ok, S = pcall(E.GetModule, E, "Skins", true)
    if ok and S then return E, S end
end

local function Try(fn, ...)
    local ok = pcall(fn, ...)
    return ok
end

local function Buttons(S, list)
    for _, b in ipairs(list) do
        if b and not b.elvSkinned then
            if Try(S.HandleButton, S, b) then b.elvSkinned = true end
        end
    end
end

-- main window ---------------------------------------------------------------
function TO:TrySkin()
    if self.skinned then return end
    local E, S = Elv()
    if not E then return end
    local f = self.frame
    self.skinned = true

    Try(f.SetTemplate, f, "Transparent")
    if self.closeButton then
        self.closeButton:ClearAllPoints()
        self.closeButton:SetPoint("TOPRIGHT", f, "TOPRIGHT", -4, -4)
        self.closeButton:SetWidth(24)
        self.closeButton:SetHeight(24)
        Try(S.HandleCloseButton, S, self.closeButton)
    end
    Buttons(S, { TalentOverviewApply, TalentOverviewReset, TalentOverviewBuildsButton })
    if TalentOverviewSearch then Try(S.HandleEditBox, S, TalentOverviewSearch) end
    if TalentOverviewSpecDrop then Try(S.HandleDropDownBox, S, TalentOverviewSpecDrop, 150) end

    -- no title bar or portrait ring any more: move the header texts to the corner
    if self.title then
        self.title:ClearAllPoints()
        self.title:SetPoint("TOP", f, "TOP", 0, -10)
    end
    if self.pointsText then
        self.pointsText:ClearAllPoints()
        self.pointsText:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -36)
    end
    self:ApplyFrameStyle()
end

-- specialization chooser ----------------------------------------------------
function TO:SkinChooser()
    local ch = self.chooser
    if not (self.skinned and ch and not ch.elvSkinned) then return end
    local _, S = Elv()
    if not S then return end
    ch.elvSkinned = true
    local list = { ch.skip }
    for _, card in ipairs(ch.cards) do list[#list + 1] = card.choose end
    Buttons(S, list)
end

-- builds window -------------------------------------------------------------
function TO:SkinBuilds()
    local w = self.buildsWidgets
    if not (w and not w.elvSkinned) then return end
    local _, S = Elv()
    if not S then return end
    w.elvSkinned = true
    Try(w.window.SetTemplate, w.window, "Transparent")
    Try(w.panel.SetTemplate, w.panel, "Default")
    Try(S.HandleCloseButton, S, w.close, w.window)
    Buttons(S, w.buttons)
    for _, e in ipairs(w.edits) do Try(S.HandleEditBox, S, e) end
end

-- settings panel --------------------------------------------------------------
function TO:SkinOptions(c)
    if c.done or self.optionsSkinned then return end
    local _, S = Elv()
    if not S then return end
    self.optionsSkinned = true
    for _, cb in pairs({ c.checks[1], c.checks[2], c.checks[3], c.checks[4], c.checks[5] }) do
        if cb then Try(S.HandleCheckBox, S, cb) end
    end
    for _, sl in ipairs(c.sliders) do Try(S.HandleSliderFrame, S, sl) end
    Buttons(S, c.buttons)
end
