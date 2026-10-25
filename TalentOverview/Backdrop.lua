------------------------------------------------------------------------
-- TalentOverview: Backdrop
-- The window background: the game's own background picture of the specialization
-- that is active, centred behind its tree and stretched over the full height of the
-- window. Its sides fade out into the dark window colour.
--
-- The game stores a tree background as four tiles. The files are 256x256, 64x256,
-- 256x128 and 64x128, but the art only fills part of the two narrow / short ones:
-- exactly 300x331 pixels in total (256+44 across, 256+75 down; measured from the
-- tiles' transparency, the same for every class).
-- <base> is "Interface\TalentFrame\<Name>-".
--
-- Shared helpers (used by the chooser and /to arttest too):
--     TO:TabPictureBase(tab)                       -> base path or nil
--     TO:CreatePicture(frame, layer, x, y, scale, fade) -> pic, pic:SetBase(base)
--     TO:CreateEdgeStrips(frame, layer, x, y, w, h, side, a0, a1) -> strips, strips:SetBase(base)
------------------------------------------------------------------------
local TO = TalentOverview
local f = TO.frame

local BASE  = { 0.055, 0.05, 0.045 }      -- window fill behind and between the pictures
local PIC_W, PIC_H = 300, 331             -- the part of the four tiles that holds the art
local RAMP  = 85                          -- picture pixels over which the picture fades out sideways
local PANEL_TOP = TO.ART_TOP
local PANEL_H   = TO.WIN_H - TO.ART_TOP
local SCALE = PANEL_H / PIC_H             -- one scale for both directions: no distortion
local PW    = PIC_W * SCALE               -- width of the picture on screen
local FLAT  = "Interface\\Buttons\\WHITE8X8"

-- name, x, y in the picture, used width and height, file width and height
local TILES = {
    { "TopLeft",     0,   0,   256, 256, 256, 256 },
    { "TopRight",    256, 0,   44,  256, 64,  256 },
    { "BottomLeft",  0,   256, 256, 75,  256, 128 },
    { "BottomRight", 256, 256, 44,  75,  64,  128 },
}
TO.PIC_W, TO.PIC_H = PIC_W, PIC_H

f:SetBackdrop({ bgFile = FLAT })
f:SetBackdropColor(BASE[1], BASE[2], BASE[3], 1)

-- "MageFire", "Interface\TalentFrame\MageFire" or "...MageFire-" all give the same base
function TO:TabPictureBase(tab)
    local _, _, _, bg = GetTalentTabInfo(tab)
    if type(bg) ~= "string" or bg == "" then return nil end
    if not bg:find("\\", 1, true) then bg = "Interface\\TalentFrame\\" .. bg end
    if bg:sub(-1) ~= "-" then bg = bg .. "-" end
    return bg
end

local function Ramp(x)                    -- opacity of a fading picture at picture-pixel x
    return math.max(0, math.min(1, x / RAMP, (PIC_W - x) / RAMP))
end

------------------------------------------------------------------------
-- A whole 320x384 picture built from its four tiles. With `fade`, the tiles are
-- cut at the fade zones and each piece gets a sideways opacity gradient.
------------------------------------------------------------------------
function TO:CreatePicture(frame, layer, x, y, scale, fade)
    local pic = { pieces = {} }
    for _, t in ipairs(TILES) do
        local part, tx, ty, tw, th, fw, fh = t[1], t[2], t[3], t[4], t[5], t[6], t[7]
        local cuts = { 0, tw }
        if fade then
            for _, c in ipairs({ RAMP, PIC_W - RAMP }) do
                local at = c - tx
                if at > 0 and at < tw then cuts[#cuts + 1] = at end
            end
            table.sort(cuts)
        end
        for i = 1, #cuts - 1 do
            local a, b = cuts[i], cuts[i + 1]
            local tex = frame:CreateTexture(nil, layer)
            tex:SetWidth((b - a) * scale)
            tex:SetHeight(th * scale)
            tex:SetPoint("TOPLEFT", frame, "TOPLEFT", x + (tx + a) * scale, -(y + ty * scale))
            tex:SetTexCoord(a / fw, b / fw, 0, th / fh)
            if fade then
                tex:SetGradientAlpha("HORIZONTAL", 1, 1, 1, Ramp(tx + a), 1, 1, 1, Ramp(tx + b))
            end
            tex.part = part
            tex:Hide()
            pic.pieces[#pic.pieces + 1] = tex
        end
    end
    function pic:SetBase(base)
        if self.base == base then return end
        self.base = base
        for _, tex in ipairs(self.pieces) do
            if base then
                tex:SetTexture(base .. tex.part)
                tex:Show()
            else
                tex:Hide()
            end
        end
    end
    return pic
end

------------------------------------------------------------------------
-- The picture's left or right edge (one pixel column of the top and bottom tile),
-- stretched to a w x h area. a0 / a1 are the opacity at the left / right end.
------------------------------------------------------------------------
function TO:CreateEdgeStrips(frame, layer, x, y, w, h, side, a0, a1)
    local strips = { pieces = {} }
    local right = (side == "right")
    local rows = {                       -- tile, top (picture pixels), used height
        { right and "TopRight" or "TopLeft",       0,   256 },
        { right and "BottomRight" or "BottomLeft", 256, 75 },
    }
    for _, r in ipairs(rows) do
        local tex = frame:CreateTexture(nil, layer)
        tex:SetWidth(w)
        tex:SetHeight(h * r[3] / PIC_H)
        tex:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -(y + h * r[2] / PIC_H))
        local fw = right and 64 or 256
        local fh = (r[2] == 0) and 256 or 128
        local col = right and 44 or 1    -- right edge: last used column of the narrow tile
        if right then
            tex:SetTexCoord((col - 1) / fw, col / fw, 0, r[3] / fh)
        else
            tex:SetTexCoord(0, 1 / fw, 0, r[3] / fh)
        end
        tex:SetGradientAlpha("HORIZONTAL", 1, 1, 1, a0, 1, 1, 1, a1)
        tex.part = r[1]
        tex:Hide()
        strips.pieces[#strips.pieces + 1] = tex
    end
    function strips:SetBase(base)
        if self.base == base then return end
        self.base = base
        for _, tex in ipairs(self.pieces) do
            if base then
                tex:SetTexture(base .. tex.part)
                tex:Show()
            else
                tex:Hide()
            end
        end
    end
    return strips
end

local function LayerFrame(offset)
    local fr = CreateFrame("Frame", nil, f)
    fr:SetAllPoints(f)
    fr:SetFrameLevel(f:GetFrameLevel() + offset)
    return fr
end

------------------------------------------------------------------------
-- The window: one picture per tree position, only the active one is shown
------------------------------------------------------------------------
local art = LayerFrame(1)
local shade = art:CreateTexture(nil, "ARTWORK")      -- keeps icons and text readable
shade:SetTexture(FLAT)
shade:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -PANEL_TOP)
shade:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
shade:SetVertexColor(0, 0, 0, 0.22)
shade:Hide()

local slots = {}
for i = 1, 3 do
    local centre = TO.TREE_X0 + TO.TREE_W / 2 + (i - 1) * (TO.TREE_W + TO.TREE_GAP)
    slots[i] = TO:CreatePicture(art, "BORDER", centre - PW / 2, PANEL_TOP, SCALE, true)
end

-- plain mode (artwork off): the game's own parchment (512x256, the shape of the window)
local plain = LayerFrame(1)
plain:Hide()
local paper = plain:CreateTexture(nil, "BACKGROUND")
paper:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
paper:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -PANEL_TOP)
paper:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)

-- tree whose picture is shown: the chosen specialization of the active talent group
function TO:ActiveTree()
    local spec = self.GetSpec and self:GetSpec()
    if not spec and self.DetectSpec then spec = self:DetectSpec(GetActiveTalentGroup() or 1) end
    local n = GetNumTalentTabs() or 3
    if not spec or spec > n then spec = 1 end
    return spec
end

function TO:UpdateBackground()
    local db = TalentOverviewDB
    if not db then return end
    local pictures = db.specBg ~= false
    local active = self:ActiveTree()
    for i, slot in ipairs(slots) do
        local base = (pictures and i == active) and self:TabPictureBase(i) or nil
        slot:SetBase(base)
    end
    if pictures then
        shade:Show()
        plain:Hide()
    else
        shade:Hide()
        plain:Show()
    end
end
