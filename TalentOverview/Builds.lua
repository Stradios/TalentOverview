------------------------------------------------------------------------
-- TalentOverview: Builds
-- Build codes + the sidebar on the right side of the window.
--
-- Code format:  TO1:<tree1>-<tree2>-<tree3>
--   each tree is one digit (the rank) per talent in the game's own talent
--   order, trailing zeros trimmed, e.g.  TO1:05301-5000230-
--   The "TO1:" prefix is optional, so a bare  0530-500-  style string works too.
--
-- Wrath has no loadouts: points can only be ADDED, never moved, without a
-- respec. "Load" therefore fills your free points toward the build, in the
-- right order (tier by tier), as a preview. You still press Apply Changes.
------------------------------------------------------------------------
local TO = TalentOverview

local ROWS = 10
local ROW_H = 20

------------------------------------------------------------------------
-- Code handling
------------------------------------------------------------------------
function TO:ExportCode()
    local parts = {}
    for tab = 1, (GetNumTalentTabs() or 0) do
        local digits = {}
        for i = 1, GetNumTalents(tab) do
            local _, _, _, _, rank, _, _, _, prank = GetTalentInfo(tab, i)
            digits[i] = tostring(prank or rank or 0)
        end
        parts[tab] = (table.concat(digits):gsub("0+$", ""))
    end
    return "TO1:" .. table.concat(parts, "-")
end

-- returns targets[tab][index] = rank, or nil, "error text"
function TO:ParseCode(code)
    local s = (code or ""):gsub("%s", "")
    s = s:gsub("^[Tt][Oo]%d*:", "")
    if s == "" then return nil, "The code is empty." end

    local numTabs = GetNumTalentTabs() or 0
    local parts = {}
    for p in (s .. "-"):gmatch("([^-]*)-") do parts[#parts + 1] = p end
    if #parts > numTabs then
        return nil, "Too many trees in the code (this class has " .. numTabs .. ")."
    end

    local targets = {}
    for tab = 1, numTabs do
        targets[tab] = {}
        local digits = parts[tab] or ""
        if not digits:match("^%d*$") then
            return nil, "Tree " .. tab .. " contains characters that are not digits."
        end
        local n = GetNumTalents(tab)
        if #digits > n then
            return nil, "Tree " .. tab .. " has too many entries. Is this build for another class?"
        end
        for i = 1, #digits do
            local want = tonumber(digits:sub(i, i))
            local _, _, _, _, _, maxRank = GetTalentInfo(tab, i)
            if want > maxRank then
                return nil, "Tree " .. tab .. ", talent " .. i ..
                    ": rank " .. want .. " is above the maximum (" .. maxRank .. "). Wrong class?"
            end
            targets[tab][i] = want
        end
    end
    return targets
end

local function TreeTotals(targets)
    local t = {}
    for tab, ranks in ipairs(targets) do
        local sum = 0
        for _, r in pairs(ranks) do sum = sum + r end
        t[tab] = sum
    end
    return t
end

-- Add preview points toward the build. Returns added, stillMissing, conflicts.
function TO:ApplyBuild(targets)
    local group = GetActiveTalentGroup() or 1
    if ResetGroupPreviewTalentPoints then ResetGroupPreviewTalentPoints(false, group) end

    local order, conflicts = {}, 0
    for tab = 1, (GetNumTalentTabs() or 0) do
        for i = 1, GetNumTalents(tab) do
            local _, _, tier, _, rank = GetTalentInfo(tab, i)
            if (rank or 0) > ((targets[tab] and targets[tab][i]) or 0) then
                conflicts = conflicts + 1
            end
            order[#order + 1] = { tab = tab, i = i, tier = tier }
        end
    end
    -- lower tiers first: higher tiers need points already spent in the tree
    table.sort(order, function(a, b)
        if a.tier ~= b.tier then return a.tier < b.tier end
        if a.tab ~= b.tab then return a.tab < b.tab end
        return a.i < b.i
    end)

    self.suspend = true     -- don't redraw the whole UI after every single point
    local added, progress, guard = 0, true, 0
    while progress and guard < 100 do
        progress, guard = false, guard + 1
        for _, o in ipairs(order) do
            local want = (targets[o.tab] and targets[o.tab][o.i]) or 0
            local _, _, _, _, rank, _, _, _, prank = GetTalentInfo(o.tab, o.i)
            local cur = prank or rank or 0
            while cur < want do
                AddPreviewTalentPoints(o.tab, o.i, 1)
                local _, _, _, _, r2, _, _, _, p2 = GetTalentInfo(o.tab, o.i)
                local new = p2 or r2 or 0
                if new > cur then
                    cur, added, progress = new, added + 1, true
                else
                    break       -- no free points, or prerequisites not met yet
                end
            end
        end
    end
    self.suspend = false

    local missing = 0
    for tab, ranks in ipairs(targets) do
        for i, want in pairs(ranks) do
            local _, _, _, _, rank, _, _, _, prank = GetTalentInfo(tab, i)
            local cur = prank or rank or 0
            if cur < want then missing = missing + (want - cur) end
        end
    end
    return added, missing, conflicts
end

------------------------------------------------------------------------
-- Build list (premade + saved)
------------------------------------------------------------------------
local function PlayerClass()
    local _, class = UnitClass("player")
    return class
end

function TO:GetBuildList()
    local class = PlayerClass()
    local list = {}
    for _, b in ipairs((self.PREMADE and self.PREMADE[class]) or {}) do
        list[#list + 1] = { name = b.name, code = b.code, premade = true }
    end
    local saved = TalentOverviewDB and TalentOverviewDB.builds and TalentOverviewDB.builds[class]
    for i, b in ipairs(saved or {}) do
        list[#list + 1] = { name = b.name, code = b.code, savedIndex = i }
    end
    return list
end

function TO:SaveBuild(name, code)
    local class = PlayerClass()
    local all = TalentOverviewDB.builds
    all[class] = all[class] or {}
    for _, b in ipairs(all[class]) do
        if b.name == name then b.code = code; return end    -- overwrite same name
    end
    all[class][#all[class] + 1] = { name = name, code = code }
end

------------------------------------------------------------------------
-- Sidebar UI
------------------------------------------------------------------------
function TO:SetStatus(text, r, g, b)
    if self.sidebar then
        self.sidebar.status:SetText(text or "")
        self.sidebar.status:SetTextColor(r or 1, g or 1, b or 1)
    end
end

-- The builds tools live in their own movable window, opened with the Builds
-- button (or /to builds).
local BW = 230          -- width of the content panel
local BH = 532          -- height of the content panel

function TO:BuildBuilds()
    if self.sidebar then return end
    local f = self.frame
    local W = BW

    -- outer window ----------------------------------------------------------
    local win = CreateFrame("Frame", "TalentOverviewBuildsFrame", UIParent)
    self.buildsWindow = win
    win:SetFrameStrata("HIGH")
    win:SetWidth(W + 24)
    win:SetHeight(BH + 54)
    win:SetPoint("TOPLEFT", f, "TOPRIGHT", 12, 0)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", function(self) self:StartMoving() end)
    win:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    win:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    win:Hide()
    tinsert(UISpecialFrames, "TalentOverviewBuildsFrame")
    win:SetScript("OnShow", function()
        if TO.SkinBuilds then TO:SkinBuilds() end
        TO:UpdateBuilds()
    end)

    local wtitle = win:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    wtitle:SetPoint("TOP", win, "TOP", 0, -16)
    wtitle:SetText("Talent Builds")
    local wclose = CreateFrame("Button", nil, win, "UIPanelCloseButton")
    wclose:SetPoint("TOPRIGHT", win, "TOPRIGHT", -4, -4)

    -- content panel ---------------------------------------------------------
    local sb = CreateFrame("Frame", nil, win)
    self.sidebar = sb
    sb:SetWidth(W)
    sb:SetHeight(BH)
    sb:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -42)
    sb:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = false, edgeSize = 12,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    sb:SetBackdropColor(0.04, 0.04, 0.06, 1)
    sb:SetBackdropBorderColor(0.45, 0.45, 0.5, 1)
    sb.offset = 0

    local header = sb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header:SetPoint("TOPLEFT", sb, "TOPLEFT", 10, -9)
    header:SetText("Builds")

    local count = sb:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    count:SetPoint("TOPRIGHT", sb, "TOPRIGHT", -10, -10)
    sb.count = count

    -- list ---------------------------------------------------------------
    local list = CreateFrame("Frame", nil, sb)
    list:SetPoint("TOPLEFT", sb, "TOPLEFT", 8, -28)
    list:SetWidth(W - 16)
    list:SetHeight(ROWS * ROW_H)
    list:EnableMouseWheel(true)
    list:SetScript("OnMouseWheel", function(_, delta)
        sb.offset = math.max(0, sb.offset - delta)
        TO:UpdateBuilds()
    end)
    sb.rows = {}
    for r = 1, ROWS do
        local row = CreateFrame("Button", nil, list)
        row:SetWidth(W - 16)
        row:SetHeight(ROW_H)
        row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -(r - 1) * ROW_H)
        row.sel = row:CreateTexture(nil, "BACKGROUND")
        row.sel:SetAllPoints(row)
        row.sel:SetTexture("Interface\\Buttons\\WHITE8X8")
        row.sel:SetVertexColor(1, 0.82, 0, 0.22)
        row.sel:Hide()
        row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
        row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row.text:SetPoint("LEFT", row, "LEFT", 4, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.text:SetJustifyH("LEFT")
        row:SetScript("OnClick", function(self)
            if not self.entry then return end
            sb.selected = self.index
            sb.code:SetText(self.entry.code or "")
            sb.code:SetCursorPosition(0)
            TO:SetStatus("")
            TO:UpdateBuilds()
        end)
        sb.rows[r] = row
    end

    -- detail + buttons ---------------------------------------------------
    local detail = sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 2, -8)
    detail:SetWidth(W - 20)
    detail:SetHeight(30)
    detail:SetJustifyH("LEFT")
    detail:SetJustifyV("TOP")
    sb.detail = detail

    local load = CreateFrame("Button", nil, sb, "UIPanelButtonTemplate")
    load:SetWidth(100)
    load:SetHeight(22)
    load:SetPoint("TOPLEFT", detail, "BOTTOMLEFT", -2, -4)
    load:SetText("Load build")
    load:SetScript("OnClick", function()
        local e = sb.selected and TO:GetBuildList()[sb.selected]
        if not e then return end
        local targets, err = TO:ParseCode(e.code)
        if not targets then TO:SetStatus(err, 1, 0.3, 0.3) return end
        local added, missing, conflicts = TO:ApplyBuild(targets)
        TO:Refresh()
        local msg = "Added " .. added .. " point(s) to the preview. Press Apply Changes to learn them."
        local r, g, b = 0.4, 1, 0.4
        if missing > 0 then
            msg = msg .. "\n" .. missing .. " point(s) could not be added (not enough free points, " ..
                "or talents you already have are in the way)."
            r, g, b = 1, 0.82, 0
        end
        if conflicts > 0 then
            msg = msg .. "\n" .. conflicts .. " of your learned talents differ from this build; " ..
                "a respec is needed to match it fully."
            r, g, b = 1, 0.82, 0
        end
        if added == 0 and missing > 0 then
            msg = "Nothing could be added. You need free talent points (or a respec first)."
            r, g, b = 1, 0.3, 0.3
        end
        TO:SetStatus(msg, r, g, b)
    end)
    sb.loadBtn = load

    local del = CreateFrame("Button", nil, sb, "UIPanelButtonTemplate")
    del:SetWidth(100)
    del:SetHeight(22)
    del:SetPoint("LEFT", load, "RIGHT", 6, 0)
    del:SetText("Delete")
    del:SetScript("OnClick", function()
        local e = sb.selected and TO:GetBuildList()[sb.selected]
        if e and e.savedIndex then
            table.remove(TalentOverviewDB.builds[PlayerClass()], e.savedIndex)
            sb.selected = nil
            TO:SetStatus("Deleted.")
            TO:UpdateBuilds()
        end
    end)
    sb.delBtn = del

    -- code box -----------------------------------------------------------
    local codeLabel = sb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    codeLabel:SetPoint("TOPLEFT", load, "BOTTOMLEFT", 2, -14)
    codeLabel:SetText("Build code (copy / paste here)")

    local code = CreateFrame("EditBox", "TalentOverviewCodeBox", sb, "InputBoxTemplate")
    code:SetWidth(W - 28)
    code:SetHeight(20)
    code:SetPoint("TOPLEFT", codeLabel, "BOTTOMLEFT", 6, -4)
    code:SetAutoFocus(false)
    code:SetMaxLetters(600)
    code:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    code:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    sb.code = code

    local nameLabel = sb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOPLEFT", code, "BOTTOMLEFT", -6, -10)
    nameLabel:SetText("Name (for Save / Import)")

    local name = CreateFrame("EditBox", "TalentOverviewNameBox", sb, "InputBoxTemplate")
    name:SetWidth(W - 28)
    name:SetHeight(20)
    name:SetPoint("TOPLEFT", nameLabel, "BOTTOMLEFT", 6, -4)
    name:SetAutoFocus(false)
    name:SetMaxLetters(30)
    name:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    name:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    sb.name = name

    local function NameOrDefault(prefix)
        local n = strtrim(name:GetText() or "")
        if n == "" then
            n = prefix .. " " .. (#TO:GetBuildList() + 1)
        end
        return n
    end

    local export = CreateFrame("Button", nil, sb, "UIPanelButtonTemplate")
    export:SetWidth(100)
    export:SetHeight(22)
    export:SetPoint("TOPLEFT", name, "BOTTOMLEFT", -6, -8)
    export:SetText("Export current")
    export:SetScript("OnClick", function()
        code:SetText(TO:ExportCode())
        code:SetFocus()
        code:HighlightText()
        TO:SetStatus("Your current talents are in the box. Press Ctrl+C to copy.")
    end)

    local import = CreateFrame("Button", nil, sb, "UIPanelButtonTemplate")
    import:SetWidth(100)
    import:SetHeight(22)
    import:SetPoint("LEFT", export, "RIGHT", 6, 0)
    import:SetText("Import code")
    import:SetScript("OnClick", function()
        local text = code:GetText() or ""
        local targets, err = TO:ParseCode(text)
        if not targets then TO:SetStatus(err, 1, 0.3, 0.3) return end
        local n = NameOrDefault("Imported")
        TO:SaveBuild(n, text)
        for i, e in ipairs(TO:GetBuildList()) do
            if e.savedIndex and e.name == n then sb.selected = i end
        end
        TO:SetStatus("Imported as \"" .. n .. "\". Select it and press Load build.", 0.4, 1, 0.4)
        TO:UpdateBuilds()
    end)

    local save = CreateFrame("Button", nil, sb, "UIPanelButtonTemplate")
    save:SetWidth(206)
    save:SetHeight(22)
    save:SetPoint("TOPLEFT", export, "BOTTOMLEFT", 0, -6)
    save:SetText("Save current talents as build")
    save:SetScript("OnClick", function()
        local n = NameOrDefault("Build")
        TO:SaveBuild(n, TO:ExportCode())
        TO:SetStatus("Saved \"" .. n .. "\".", 0.4, 1, 0.4)
        TO:UpdateBuilds()
    end)

    local status = sb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("TOPLEFT", save, "BOTTOMLEFT", 2, -10)
    status:SetWidth(W - 20)
    status:SetJustifyH("LEFT")
    status:SetJustifyV("TOP")
    sb.status = status

    -- widgets that Skins.lua restyles when ElvUI is loaded
    self.buildsWidgets = { window = win, panel = sb, close = wclose,
        buttons = { load, del, export, import, save }, edits = { code, name } }
end

function TO:UpdateBuilds()
    local sb = self.sidebar
    if not sb then return end
    local list = self:GetBuildList()

    local maxOffset = math.max(0, #list - ROWS)
    if sb.offset > maxOffset then sb.offset = maxOffset end
    if sb.selected and not list[sb.selected] then sb.selected = nil end

    for r = 1, ROWS do
        local row = sb.rows[r]
        local idx = sb.offset + r
        local e = list[idx]
        row.entry, row.index = e, idx
        if e then
            local tag = e.premade and "|cff66ccff[Premade]|r " or ""
            row.text:SetText(tag .. e.name)
            row:Show()
            if sb.selected == idx then row.sel:Show() else row.sel:Hide() end
        else
            row.text:SetText("")
            row.sel:Hide()
            row:Hide()
        end
    end
    sb.count:SetText(#list > 0 and (#list .. " builds") or "")

    local e = sb.selected and list[sb.selected]
    if e then
        local targets, err = self:ParseCode(e.code)
        if targets then
            local t = TreeTotals(targets)
            sb.detail:SetText(e.name .. "\n|cffffffff" ..
                table.concat(t, " / ") .. "|r points per tree")
        else
            sb.detail:SetText(e.name .. "\n|cffff5555" .. err .. "|r")
        end
        sb.loadBtn:Enable()
        if e.savedIndex then sb.delBtn:Enable() else sb.delBtn:Disable() end
    else
        sb.detail:SetText(#list == 0
            and "No builds yet. Save your talents or import a code below."
            or "Select a build to load it.")
        sb.loadBtn:Disable()
        sb.delBtn:Disable()
    end
end

function TO:ToggleBuilds()
    self:BuildBuilds()
    local win = self.buildsWindow
    if win:IsShown() then win:Hide() else win:Show() end
end
