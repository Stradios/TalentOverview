------------------------------------------------------------------------
-- TalentOverview: Chrome
-- The window border and portrait, in two styles (db.metalFrame picks one):
--   classic (default)  the game's own stone frame (as on the spellbook and glyph
--                      windows) with the player's face in the portrait ring
--   metal              retail-style metal frame with the class icon
-- With ElvUI loaded, Skins.lua hides both and skins the window instead.
--
-- Metal textures and coordinates come from DragonUI (MIT licence, see
-- LICENSE-DragonUI.txt): Textures\UI\uiframemetal*.blp and
-- Textures\ClassIcons\<CLASS>.blp.
--
-- Metal frame geometry (retail PortraitFrameTemplate):
--   top-left corner  75x75 at (-13, +16)   (has the portrait ring cut-out)
--   top-right corner 75x75 at (+4,  +16)
--   bottom corners   32x32 at (-13,-3) / (+4,-3)
--   edges are tiled strips between the corners
------------------------------------------------------------------------
local TO = TalentOverview
local f = TO.frame

-- The border and portrait live on their own frame, stacked above everything else in the
-- window (including the specialization chooser, which covers most of it).
local chrome = CreateFrame("Frame", nil, f)       -- the metal style
chrome:SetAllPoints(f)
chrome:SetFrameLevel(f:GetFrameLevel() + 40)
TO.chrome = chrome

local UI = TO.TEX .. "UI\\"
local SHEET   = UI .. "uiframemetal2x"
local SHEET_H = UI .. "uiframemetalhorizontal2x"
local SHEET_V = UI .. "uiframemetalvertical2x"

local W, H = TO.WIN_W, TO.WIN_H

local function Piece(file, w, h, point, x, y, l, r, t, b)
    local tex = chrome:CreateTexture(nil, "OVERLAY")
    tex:SetTexture(file)
    tex:SetWidth(w)
    tex:SetHeight(h)
    tex:SetPoint(point, f, point, x, y)
    tex:SetTexCoord(l, r, t, b)
    return tex
end

-- corners ---------------------------------------------------------------
Piece(SHEET, 75, 75, "TOPLEFT",     -13,  16, 0.00195312, 0.294922, 0.298828, 0.591797)   -- with portrait ring
Piece(SHEET, 75, 75, "TOPRIGHT",      4,  16, 0.298828,   0.591797, 0.00195312, 0.294922)
Piece(SHEET, 32, 32, "BOTTOMLEFT",  -13,  -3, 0.298828,   0.423828, 0.298828, 0.423828)
Piece(SHEET, 32, 32, "BOTTOMRIGHT",   4,  -3, 0.427734,   0.552734, 0.298828, 0.423828)

-- Tiled strips. Built from many fixed-size pieces instead of texture
-- tiling, which behaves differently from client to client.
-- vertical strip: y from y1 to y2 going down (positive numbers = distance from the top)
local function VStrip(file, xoff, w, y1, y2, tile, u1, u2)
    local y = y1
    while y < y2 - 0.01 do
        local h = math.min(tile, y2 - y)
        local tex = chrome:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(file)
        tex:SetWidth(w)
        tex:SetHeight(h)
        tex:SetPoint("TOPLEFT", f, "TOPLEFT", xoff, -y)
        tex:SetTexCoord(u1, u2, 0, h / tile)
        y = y + h
    end
end

-- top edge: between the two 75px corners (extended 4px under each)
do
    local x1 = -13 + 75 - 4
    local x2 = (W + 4 - 75) + 4
    local x = x1
    while x < x2 - 0.01 do
        local w = math.min(32, x2 - x)
        local tex = chrome:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(SHEET_H)
        tex:SetWidth(w)
        tex:SetHeight(75)
        tex:SetPoint("TOPLEFT", f, "TOPLEFT", x, 16)
        tex:SetTexCoord(0, w / 32, 0.00390625, 0.589844)
        x = x + w
    end
end

-- bottom edge: between the 32px bottom corners
do
    local x1 = -13 + 32
    local x2 = W + 4 - 32
    local x = x1
    while x < x2 - 0.01 do
        local w = math.min(16, x2 - x)
        local tex = chrome:CreateTexture(nil, "OVERLAY")
        tex:SetTexture(SHEET_H)
        tex:SetWidth(w)
        tex:SetHeight(32)
        tex:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", x, -3)
        tex:SetTexCoord(0, 0.5 * (w / 16), 0.597656, 0.847656)
        x = x + w
    end
end

-- left / right edges: between the 75px top corners and the 32px bottom corners
do
    local y1 = (75 - 16) - 4          -- bottom of the top corner, minus overlap
    local y2 = (H + 3 - 32) + 4       -- top of the bottom corner, plus overlap
    VStrip(SHEET_V, -13,        75, y1, y2, 16, 0.00195312, 0.294922)
    VStrip(SHEET_V, W + 4 - 75, 75, y1, y2, 16, 0.298828,   0.591797)
end

------------------------------------------------------------------------
-- Round class portrait inside the ring (ring centre = 25.7 right, 22.5 down
-- from the frame's top-left corner; ring inner diameter is about 55)
------------------------------------------------------------------------
local portrait = chrome:CreateTexture(nil, "ARTWORK")
portrait:SetWidth(51)
portrait:SetHeight(51)
portrait:SetPoint("CENTER", f, "TOPLEFT", 24.2, -21)   -- nudged up/left so no corner shows
TO.portrait = portrait

------------------------------------------------------------------------
-- Classic style: pieces cut from the game's own stone frame.
-- Top: Spellbook\UI-SpellbookPanel-TopLeft (256x256) / TopRight (128x256)
-- Bottom: TalentFrame\UI-TalentFrame-BotLeft (256x256) / BotRight (128x256)
-- Each piece is drawn 1:1; the long edges are narrow strips stretched to length.
-- Measured: in TopLeft the frame's outer edge is at x=12, top edge at y=14, the ring's
-- hole is centred on (39,35); in TopRight the outer edge is at x=95; in the bottom
-- pieces the bottom edge is at y=182 (BotLeft: left edge x=12, BotRight: right edge x=94).
------------------------------------------------------------------------
local classic = CreateFrame("Frame", nil, f)
classic:SetAllPoints(f)
classic:SetFrameLevel(f:GetFrameLevel() + 40)
classic:Hide()
TO.classicChrome = classic

local TOP_L = "Interface\\Spellbook\\UI-SpellbookPanel-TopLeft"
local TOP_R = "Interface\\Spellbook\\UI-SpellbookPanel-TopRight"
local RING  = TO.TEX .. "classicring"
local BOT_L = "Interface\\TalentFrame\\UI-TalentFrame-BotLeft"
local BOT_R = "Interface\\TalentFrame\\UI-TalentFrame-BotRight"

-- file, file width, then the picture area (x0,y0,x1,y1 in file pixels) drawn at window (x, y)
local function Cut(file, fw, fh, x0, y0, x1, y1, x, y, w, h)
    local t = classic:CreateTexture(nil, "OVERLAY")
    t:SetTexture(file)
    t:SetTexCoord(x0 / fw, x1 / fw, y0 / fh, y1 / fh)
    t:SetWidth(w or (x1 - x0))
    t:SetHeight(h or (y1 - y0))
    t:SetPoint("TOPLEFT", f, "TOPLEFT", x, -y)
end

local BAND = 10                                    -- height of the bottom edge pieces (rows 172-181; row 171 is a gold line)
local HEAD = 37                                    -- title bar rows of the top pieces (no stone band below it)
local RING_W, RING_H = 72, 70                      -- the portrait ring, with its bevel
local sideTop = RING_H - 14                        -- left edge starts under the ring
local rightTop = HEAD - 14
-- edges first, corners last, so the ring is drawn over the start of the left edge
Cut(TOP_L, 256, 256, 14,  100, 22,  240, 2,      sideTop,  8, H - BAND - sideTop)  -- left edge (stone only)
Cut(TOP_R, 128, 256, 88,  100, 96,  240, W - 7,  rightTop, 8, H - BAND - rightTop) -- right edge (stone only)
Cut(TOP_L, 256, 256, 78,  0,   200, HEAD, RING_W - 15, -14, W - 35 - (RING_W - 15), HEAD) -- title bar, stretched
Cut(BOT_L, 256, 256, 40,  172, 200, 182, 30,     H - BAND, W - 30 - 33, BAND)      -- bottom edge, stretched
Cut(BOT_L, 256, 256, 12,  172, 40,  182, 2,      H - BAND)                         -- bottom-left corner
Cut(BOT_R, 128, 256, 60,  172, 93,  182, W - 33, H - BAND)                         -- bottom-right corner
Cut(TOP_R, 128, 256, 60,  0,   96,  HEAD, W - 35, -14)                             -- top-right corner
Cut(RING,  128, 128, 0,   0,   RING_W, RING_H, -12, -14)                           -- the ring (own copy, round outline)

local face = classic:CreateTexture(nil, "ARTWORK")   -- below the ring, which is OVERLAY
face:SetWidth(54)
face:SetHeight(54)
face:SetPoint("CENTER", f, "TOPLEFT", 27, -21)

-- the ring shows the class icon (default) or the character's face (setting)
local function Fill(tex)
    local db = TalentOverviewDB
    local _, class = UnitClass("player")
    if db and db.classIcon == false then
        tex:SetTexCoord(0, 1, 0, 1)
        SetPortraitTexture(tex, "player")
    elseif class then
        tex:SetTexCoord(0, 1, 0, 1)
        tex:SetTexture(TO.TEX .. "ClassIcons\\" .. class)
    end
end

------------------------------------------------------------------------
-- Style switch
------------------------------------------------------------------------
function TO:UpdatePortrait()
    pcall(Fill, portrait)
    pcall(Fill, face)
end

-- The close button sits in the title bar: in the black square of the classic frame,
-- in the metal frame's top-right corner.
function TO:ApplyFrameStyle()
    local db = TalentOverviewDB
    if not db then return end
    local close = self.closeButton
    if self.skinned then                           -- ElvUI draws the window (see Skins.lua)
        chrome:Hide()
        classic:Hide()
        return
    end
    if db.metalFrame then
        classic:Hide()
        chrome:Show()
        if close then
            close:SetWidth(24)
            close:SetHeight(24)
            close:ClearAllPoints()
            close:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, 0)
        end
    else
        chrome:Hide()
        classic:Show()
        if close then
            close:SetWidth(22)
            close:SetHeight(22)
            close:ClearAllPoints()
            close:SetPoint("CENTER", f, "TOPRIGHT", -12, -12)
        end
    end
    self:UpdatePortrait()
end

f:HookScript("OnShow", function() TO:UpdatePortrait() end)
local portraitEvents = CreateFrame("Frame")
portraitEvents:RegisterEvent("UNIT_PORTRAIT_UPDATE")
portraitEvents:SetScript("OnEvent", function(_, _, unit)
    if unit == "player" and f:IsShown() then TO:UpdatePortrait() end
end)
