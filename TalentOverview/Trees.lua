------------------------------------------------------------------------
-- TalentOverview: Trees
-- Draws every talent tree of the player's class side by side, directly on the
-- window background (no panels or borders).
-- Left click = +1 preview point, right click = -1 preview point.
-- Nothing is spent until "Apply Changes" (LearnPreviewTalents).
------------------------------------------------------------------------
local TO = TalentOverview

TO.trees = {}
TO.searchText = ""

local LINE = "Interface\\Buttons\\WHITE8X8"
local LINE_W = 4        -- coloured line
local OUTLINE_W = 7     -- dark outline behind it, so lines read on any background

local ACTIVE   = { 1.00, 0.82, 0.10 }
local INACTIVE = { 0.50, 0.46, 0.40 }

-- axis-aligned line segment in grid coordinates (x right, y down = negative)
local function Segment(grid, x1, y1, x2, y2, w, layer)
    local t = grid:CreateTexture(nil, layer)
    t:SetTexture(LINE)
    if x1 == x2 then
        t:SetWidth(w)
        t:SetHeight(math.abs(y2 - y1) + w)
        t:SetPoint("TOPLEFT", grid, "TOPLEFT", x1 - w / 2, math.max(y1, y2) + w / 2)
    else
        t:SetHeight(w)
        t:SetWidth(math.abs(x2 - x1) + w)
        t:SetPoint("TOPLEFT", grid, "TOPLEFT", math.min(x1, x2) - w / 2, y1 + w / 2)
    end
    return t
end

local function Center(btn)
    local half = TO.ICON / 2
    return (btn.col - 1) * TO.STEP + half, -((btn.tier - 1) * TO.STEP + half)
end

-- connect a prerequisite talent (src) to the talent that needs it (dst)
local function AddPrereqLine(grid, src, dst)
    local sx, sy = Center(src)
    local dx, dy = Center(dst)
    local pts = {}
    if sx == dx or sy == dy then
        pts[1] = { sx, sy, dx, dy }
    else
        -- not straight: go sideways on the prereq's row, then down
        pts[1] = { sx, sy, dx, sy }
        pts[2] = { dx, sy, dx, dy }
    end
    local segs = {}
    for _, p in ipairs(pts) do
        local o = Segment(grid, p[1], p[2], p[3], p[4], OUTLINE_W, "BACKGROUND")
        o:SetVertexColor(0, 0, 0, 0.55)
        segs[#segs + 1] = Segment(grid, p[1], p[2], p[3], p[4], LINE_W, "BORDER")
    end
    dst.lines = dst.lines or {}
    dst.lines[#dst.lines + 1] = { src = src, segs = segs }
end

------------------------------------------------------------------------
function TO:BuildTrees()
    if self.treesBuilt then return end
    local numTabs = GetNumTalentTabs()
    if not numTabs or numTabs == 0 then return end

    local f = self.frame

    for tab = 1, numTabs do
        local tabName = GetTalentTabInfo(tab)

        local holder = CreateFrame("Frame", nil, f)
        holder:SetFrameLevel(f:GetFrameLevel() + 10)    -- above the background pictures
        holder:SetWidth(self.TREE_W)
        holder:SetHeight(self.TREE_H + 24)
        holder:SetPoint("TOPLEFT", f, "TOPLEFT",
            self.TREE_X0 + (tab - 1) * (self.TREE_W + self.TREE_GAP), -(self.TREE_TOP - 24))

        local hText = holder:CreateFontString(nil, "OVERLAY")
        hText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        hText:SetPoint("TOP", holder, "TOP", 0, -2)

        local grid = CreateFrame("Frame", nil, holder)
        grid:SetWidth(self.TREE_W)
        grid:SetHeight(self.TREE_H)
        grid:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -24)

        local T = { holder = holder, grid = grid, header = hText, buttons = {} }
        local byPos = {}

        for i = 1, GetNumTalents(tab) do
            local tname, ticon, tier, col, _, maxRank = GetTalentInfo(tab, i)
            local b = self:CreateRoundButton(grid, self.ICON)
            b:SetPoint("TOPLEFT", grid, "TOPLEFT", (col - 1) * self.STEP, -(tier - 1) * self.STEP)
            self:SetRoundTexture(b.icon, ticon)
            b.tab, b.index, b.tier, b.col = tab, i, tier, col
            b.tname, b.maxRank = tname, maxRank
            b.rank = 0

            b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
            b:SetScript("OnClick", function(self, btn)
                if btn == "RightButton" then
                    AddPreviewTalentPoints(self.tab, self.index, -1)
                elseif IsModifiedClick("CHATLINK") and GetTalentLink then
                    local link = GetTalentLink(self.tab, self.index)
                    if link then ChatEdit_InsertLink(link) end
                else
                    AddPreviewTalentPoints(self.tab, self.index, 1)
                end
            end)
            b:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetTalent(self.tab, self.index)
            end)
            b:SetScript("OnLeave", function() GameTooltip:Hide() end)

            T.buttons[i] = b
            byPos[tier .. "," .. col] = b
        end

        -- prerequisite lines. 3.3.5 talents have at most one prerequisite:
        -- GetTalentPrereqs returns tier, column, isLearnable. Be defensive about
        -- the shape (some clients/servers differ) and never error on it.
        for i, b in ipairs(T.buttons) do
            local pt, pc2 = GetTalentPrereqs(tab, i)
            if type(pt) == "number" and type(pc2) == "number" then
                local src = byPos[pt .. "," .. pc2]
                if src and src ~= b then AddPrereqLine(grid, src, b) end
            end
        end

        self.trees[tab] = T
    end

    self.treesBuilt = true
end

------------------------------------------------------------------------
function TO:UpdateTrees()
    if not self.treesBuilt then return end
    local unspent = self:GetUnspent()
    local search = self.searchText or ""

    for tab, T in ipairs(self.trees) do
        local tabName, _, spent, _, prev = GetTalentTabInfo(tab)
        local total = (spent or 0) + (prev or 0)

        local extra = ""
        if (prev or 0) > 0 then extra = " |cff33ff33(+" .. prev .. ")|r" end
        T.header:SetText("|cffffd100" .. tabName .. "|r  |cffffffff" .. total .. "|r" .. extra)

        for i, b in ipairs(T.buttons) do
            local _, _, tier, _, rank, maxRank, _, avail, prank, pavail = GetTalentInfo(tab, i)
            local r = prank or rank or 0
            local meets = avail
            if pavail ~= nil then meets = pavail end

            local tierOK  = ((tier - 1) * 5) <= total
            local canLearn = tierOK and meets and unspent > 0 and r < maxRank

            b.rank = r
            if r >= maxRank then
                self:SetState(b, "max")
                b.count:SetTextColor(0.2, 1, 0.2)
            elseif r > 0 or canLearn then
                self:SetState(b, "open")
                b.count:SetTextColor(1, 0.82, 0)
            else
                self:SetState(b, "locked")
            end

            if r > 0 or canLearn then
                b.count:SetText(r)
            else
                b.count:SetText("")
            end

            if search ~= "" then
                local hit = strfind(strlower(b.tname or ""), search, 1, true)
                b:SetAlpha(hit and 1 or 0.25)
            else
                b:SetAlpha(1)
            end
        end

        -- prerequisite lines: gold once the prerequisite talent is maxed
        for _, b in ipairs(T.buttons) do
            if b.lines then
                for _, line in ipairs(b.lines) do
                    local done = line.src.rank >= line.src.maxRank
                    local c = done and ACTIVE or INACTIVE
                    for _, seg in ipairs(line.segs) do
                        seg:SetVertexColor(c[1], c[2], c[3])
                    end
                end
            end
        end
    end
end
