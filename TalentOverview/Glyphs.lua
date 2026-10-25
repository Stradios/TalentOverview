------------------------------------------------------------------------
-- TalentOverview: Glyphs
-- Bottom-right of the window: big circles = major glyphs, small = minor.
-- (This is where the modern PvP-talent slots sit in the reference image.)
--
-- 3.3.5 workflow: use a glyph item from your bags (the cursor turns into a
-- targeting cursor), then click an empty socket.
-- Shift + right click on a filled socket removes the glyph.
------------------------------------------------------------------------
local TO = TalentOverview

TO.glyphs = {}

local MAJOR, MINOR = 1, 2
local BIG, SMALL = 54, 34

-- The game's own glyph pictures (Interface\\Spellbook): one atlas with rings, glow rings and
-- the stone disc, a separate locked ring, and the rune symbols the sockets report as icons.
local ATLAS  = "Interface\\Spellbook\\UI-GlyphFrame"
local LOCKED = "Interface\\Spellbook\\UI-GlyphFrame-Locked"
local function UV(x, y, w, h)                      -- pixel box in the 512x512 atlas
    return (x - 2) / 512, (x + w + 2) / 512, (y - 2) / 512, (y + h + 2) / 512
end
local PIECE = {
    ring = { [MAJOR] = { UV(394, 166, 80, 81) },  [MINOR] = { UV(404, 18, 61, 61) } },
    glow = { [MAJOR] = { UV(382, 251, 104, 104) }, [MINOR] = { UV(394, 81, 80, 80) } },
    disc = { UV(402, 360, 62, 62) },                  -- empty socket: plain stone disc
    -- filled sockets: the six discs along the bottom of the atlas (orange = major, silver = minor)
    ball = {
        [MAJOR] = { { UV(2, 448, 62, 62) }, { UV(271, 448, 62, 62) }, { UV(338, 448, 62, 62) } },
        [MINOR] = { { UV(69, 448, 62, 62) }, { UV(136, 448, 62, 62) }, { UV(204, 448, 62, 62) } },
    },
}
-- The rune pictures are grey; the game colours them: dark orange-brown on major glyphs,
-- dark blue on minor glyphs (measured from the default glyph window).
local RUNE_TINT = { [MAJOR] = { 1.0, 0.35, 0.06 }, [MINOR] = { 0.05, 0.35, 1.0 } }
local RING_PX  = { [MAJOR] = 80, [MINOR] = 61 }      -- ring size in the atlas
local GLOW_PX  = { [MAJOR] = 104, [MINOR] = 80 }
local DISC_FIT = { [MAJOR] = 62 / 80, [MINOR] = 1 }  -- disc size relative to the ring

local function Place(tex, parent, size, ...)
    tex:SetWidth(size)
    tex:SetHeight(size)
    tex:SetPoint("CENTER", parent, "CENTER", 0, 0)
    if ... then tex:SetTexCoord(...) end
end

local function CreateSocket(parent, size, gtype, index)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(size)
    b:SetHeight(size)
    b.gtype = gtype
    local balls = PIECE.ball[gtype]
    b.ballUV = balls[(index - 1) % #balls + 1]

    local discSize = size * DISC_FIT[gtype]
    b.disc = b:CreateTexture(nil, "BACKGROUND")
    b.disc:SetTexture(ATLAS)
    Place(b.disc, b, discSize, unpack(PIECE.disc))

    b.rune = b:CreateTexture(nil, "ARTWORK")
    Place(b.rune, b, discSize * 0.9)

    b.ring = b:CreateTexture(nil, "OVERLAY")
    b.ring:SetTexture(ATLAS)
    Place(b.ring, b, size, unpack(PIECE.ring[gtype]))

    b.locked = b:CreateTexture(nil, "OVERLAY")
    b.locked:SetTexture(LOCKED)
    Place(b.locked, b, size * 128 / 92)
    b.locked:Hide()

    b.glow = b:CreateTexture(nil, "OVERLAY")
    b.glow:SetTexture(ATLAS)
    Place(b.glow, b, size * GLOW_PX[gtype] / RING_PX[gtype], unpack(PIECE.glow[gtype]))
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()

    b.plus = b:CreateFontString(nil, "OVERLAY")
    b.plus:SetFont("Fonts\\FRIZQT__.TTF", (gtype == MINOR) and 16 or 24, "OUTLINE")
    b.plus:SetPoint("CENTER", b, "CENTER", 0, 1)
    b.plus:SetTextColor(0.9, 0.75, 0.25)
    return b
end

function TO:BuildGlyphs()
    if self.glyphsBuilt then return end
    local num = GetNumGlyphSockets and GetNumGlyphSockets() or 0
    if num == 0 then return end

    local f = self.frame
    local gf = CreateFrame("Frame", nil, f)
    gf:SetFrameLevel(f:GetFrameLevel() + 10)
    gf:SetWidth(320)
    gf:SetHeight(92)
    gf:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -34, 6)
    self.glyphFrame = gf

    local label = gf:CreateFontString(nil, "OVERLAY")
    label:SetFont("Fonts\\FRIZQT__.TTF", 13, "OUTLINE")
    label:SetPoint("TOP", gf, "TOP", 0, -2)
    label:SetTextColor(1, 0.82, 0)
    label:SetText("Glyphs")

    local group = GetActiveTalentGroup() or 1
    local nMajor, nMinor = 0, 0

    for id = 1, num do
        local _, gtype = GetGlyphSocketInfo(id, group)
        gtype = (gtype == MINOR) and MINOR or MAJOR
        local x, index
        if gtype == MINOR then
            nMinor = nMinor + 1
            index = nMinor
            x = 3 * 60 + 16 + (nMinor - 1) * 42
        else
            nMajor = nMajor + 1
            index = nMajor
            x = 4 + (nMajor - 1) * 60
        end
        local b = CreateSocket(gf, (gtype == MINOR) and SMALL or BIG, gtype, index)
        b:SetPoint("LEFT", gf, "LEFT", x, -8)

        b.socket = id
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:SetScript("OnEnter", function(self)
            self.hover = true
            TO:UpdateGlyphs()
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetGlyph(self.socket, GetActiveTalentGroup() or 1)
        end)
        b:SetScript("OnLeave", function(self)
            self.hover = false
            TO:UpdateGlyphs()
            GameTooltip:Hide()
        end)
        b:SetScript("OnClick", function(self, btn)
            local grp = GetActiveTalentGroup() or 1
            if IsModifiedClick("CHATLINK") then
                local ok, link = pcall(GetGlyphLink, self.socket, grp)
                if ok and link then ChatEdit_InsertLink(link) end
            elseif btn == "RightButton" then
                if IsShiftKeyDown() and self.filled then
                    RemoveGlyphFromSocket(self.socket)
                end
            elseif SpellCanTargetGlyph and SpellCanTargetGlyph() then
                PlaceGlyphInSocket(self.socket)
            else
                DEFAULT_CHAT_FRAME:AddMessage(
                    "|cffffd100TalentOverview:|r use a glyph item from your bags first, then click a socket.")
            end
        end)

        self.glyphs[id] = b
    end

    -- while a glyph item is on the cursor, the open sockets glow
    local timer = 0
    gf:SetScript("OnUpdate", function(_, dt)
        timer = timer + dt
        if timer < 0.2 then return end
        timer = 0
        local targeting = SpellCanTargetGlyph and SpellCanTargetGlyph() and true or false
        if targeting ~= TO.glyphTargeting then
            TO.glyphTargeting = targeting
            TO:UpdateGlyphs()
        end
    end)

    self.glyphsBuilt = true
end

function TO:UpdateGlyphs()
    if not self.glyphsBuilt then return end
    local group = GetActiveTalentGroup() or 1

    for id, b in pairs(self.glyphs) do
        local enabled, _, spellID, icon = GetGlyphSocketInfo(id, group)
        b.filled = (enabled and spellID ~= nil and icon ~= nil) and true or false

        if not enabled then
            b.disc:SetTexCoord(unpack(PIECE.disc))
            b.disc:SetVertexColor(0.3, 0.3, 0.3)
            b.rune:Hide()
            b.ring:Hide()
            b.locked:Show()
            b.plus:SetText("")
        else
            b.disc:SetVertexColor(1, 1, 1)
            b.locked:Hide()
            b.ring:Show()
            if b.filled then
                b.disc:SetTexCoord(unpack(b.ballUV))
                b.rune:SetTexCoord(0, 1, 0, 1)
                if tostring(icon):lower():find("glyph%-rune") then
                    local c = RUNE_TINT[b.gtype]
                    b.rune:SetTexture(icon)                      -- the game's rune symbol
                    b.rune:SetVertexColor(c[1], c[2], c[3])
                else
                    self:SetRoundTexture(b.rune, icon)           -- a spell icon: clip to a circle
                    b.rune:SetVertexColor(1, 1, 1)
                end
                b.rune:Show()
                b.plus:SetText("")
            else
                b.disc:SetTexCoord(unpack(PIECE.disc))
                b.rune:Hide()
                b.plus:SetText("+")
            end
        end

        if enabled and (b.hover or (self.glyphTargeting and not b.filled)) then
            b.glow:Show()
        else
            b.glow:Hide()
        end
    end
end
