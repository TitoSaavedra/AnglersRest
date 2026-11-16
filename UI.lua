-- Angler's Rest: the panel, in the FlareUI style.
-- Four things only: the mode, the pole, the double click and the minimap icon.
-- The audio itself is fixed: general and effects at 100 %, the rest silent, everything back on exit.

local ADDON_NAME, ns = ...
local L = ns.L

local frame
local refreshing = false

local BRONZE       = { 0.65, 0.49, 0.27 }
local EDGE_REST    = { 0.55, 0.42, 0.24 }
local EDGE_HOVER   = { 0.98, 0.74, 0.36 }
local TITLE_YELLOW = { 1, 0.82, 0 }
local GOLD         = { 0.91, 0.77, 0.42 }
local GREY         = { 0.62, 0.62, 0.62 }
local WHITE        = "Interface\\Buttons\\WHITE8X8"
local BORDER_FILE  = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Borders\\FlareUI-Thin.tga"
local FONT_FACE    = GetLocale() == "ruRU" and "Fonts\\FRIZQT___CYR.TTF" or "Fonts\\FRIZQT__.TTF"

local WIDTH, PAD = 340, 18
local counter = 0

local function DB() return AnglersRestDB end

local function Name(what)
	counter = counter + 1
	return "AnglersRest" .. what .. counter
end

local function MakeText(parent, size, color, justify)
	local fs = parent:CreateFontString(Name("Text"), "OVERLAY")
	fs:SetFont(FONT_FACE, size, "")
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	fs:SetJustifyH(justify or "LEFT")
	fs:SetTextColor(color[1], color[2], color[3])
	return fs
end

local function EdgeFrame(parent, level)
	local edge = CreateFrame("Frame", Name("Edge"), parent, "BackdropTemplate")
	edge:SetAllPoints()
	edge:SetFrameLevel(level)
	edge:SetBackdrop({ edgeFile = BORDER_FILE, edgeSize = 8 })
	edge:SetBackdropBorderColor(EDGE_REST[1], EDGE_REST[2], EDGE_REST[3], 1)
	return edge
end

-- FlareUI's ground: the game's rock in warm dark bronze, a glow under the header, a shade below
local function WindowGround(f)
	local art = f:CreateTexture(Name("Ground"), "BACKGROUND", nil, 1)
	art:SetPoint("TOPLEFT", 3, -3)
	art:SetPoint("BOTTOMRIGHT", -3, 3)
	art:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
	art:SetHorizTile(true)
	art:SetVertTile(true)
	art:SetDesaturated(true)
	art:SetVertexColor(0.85, 0.68, 0.47)

	local wash = f:CreateTexture(Name("Wash"), "BACKGROUND", nil, 2)
	wash:SetAllPoints(art)
	wash:SetColorTexture(0.05, 0.038, 0.026, 0.62)

	local glow = f:CreateTexture(Name("Glow"), "BACKGROUND", nil, 3)
	glow:SetPoint("TOPLEFT", art)
	glow:SetPoint("TOPRIGHT", art)
	glow:SetHeight(120)
	glow:SetColorTexture(1, 1, 1)
	glow:SetGradient("VERTICAL", CreateColor(0.55, 0.41, 0.22, 0), CreateColor(0.55, 0.41, 0.22, 0.22))
end

local function Checkbox(parent, text, checked, onClick)
	local f = CreateFrame("Button", Name("Check"), parent)
	f:SetSize(WIDTH - PAD * 2, 22)
	f:EnableMouse(true)

	local box = f:CreateTexture(Name("Box"), "ARTWORK")
	box:SetSize(18, 18)
	box:SetPoint("LEFT", 0, 0)
	box:SetTexture(WHITE)
	box:SetVertexColor(0.18, 0.14, 0.09, 1)

	local rim = CreateFrame("Frame", Name("BoxRim"), f, "BackdropTemplate")
	rim:SetPoint("CENTER", box)
	rim:SetSize(20, 20)
	rim:SetFrameLevel(f:GetFrameLevel() + 1)
	rim:SetBackdrop({ edgeFile = BORDER_FILE, edgeSize = 8 })
	rim:SetBackdropBorderColor(EDGE_REST[1], EDGE_REST[2], EDGE_REST[3], 1)

	local tick = f:CreateTexture(Name("Tick"), "OVERLAY")
	tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
	tick:SetPoint("CENTER", box)
	tick:SetVertexColor(TITLE_YELLOW[1], TITLE_YELLOW[2], TITLE_YELLOW[3])

	local label = MakeText(f, 12, { 1, 1, 1 })
	label:SetPoint("LEFT", box, "RIGHT", 10, 0)
	label:SetText(text)

	function f:SetChecked(value)
		self.checked = value and true or false
		tick:SetShown(self.checked)
	end
	function f:GetChecked() return self.checked end
	f:SetChecked(checked)

	f:HookScript("OnEnter", function()
		label:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
		rim:SetBackdropBorderColor(EDGE_HOVER[1], EDGE_HOVER[2], EDGE_HOVER[3], 1)
	end)
	f:HookScript("OnLeave", function()
		label:SetTextColor(1, 1, 1)
		rim:SetBackdropBorderColor(EDGE_REST[1], EDGE_REST[2], EDGE_REST[3], 1)
	end)
	f:SetScript("OnClick", function(self)
		self:SetChecked(not self:GetChecked())
		onClick(self:GetChecked())
	end)
	return f
end

-- the big button: grey plate, bronze rim, gold text
local function PlateButton(parent, text, width, onClick)
	local b = CreateFrame("Button", Name("Button"), parent)
	b:SetSize(width, 26)
	b:EnableMouse(true)

	local plate = b:CreateTexture(Name("Plate"), "BACKGROUND", nil, 1)
	plate:SetTexture(WHITE)
	plate:SetPoint("TOPLEFT", 2, -2)
	plate:SetPoint("BOTTOMRIGHT", -2, 2)
	plate:SetVertexColor(0.13, 0.11, 0.09, 1)

	local edge = EdgeFrame(b, b:GetFrameLevel() + 1)

	local label = MakeText(b, 12, TITLE_YELLOW, "CENTER")
	label:SetPoint("LEFT", 8, 0)
	label:SetPoint("RIGHT", -8, 0)
	label:SetText(text)
	b.textLabel = label

	b:HookScript("OnEnter", function()
		edge:SetBackdropBorderColor(EDGE_HOVER[1], EDGE_HOVER[2], EDGE_HOVER[3], 1)
		plate:SetVertexColor(0.22, 0.18, 0.14, 1)
	end)
	b:HookScript("OnLeave", function()
		edge:SetBackdropBorderColor(EDGE_REST[1], EDGE_REST[2], EDGE_REST[3], 1)
		plate:SetVertexColor(0.13, 0.11, 0.09, 1)
	end)
	b:SetScript("OnClick", onClick)
	return b
end

function AnglersRest_BuildUI()
	if frame then return frame end
	local db = DB()

	local f = CreateFrame("Frame", "AnglersRestFrame", UIParent, "BackdropTemplate")
	frame = f
	f:SetSize(WIDTH, 210)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

	EdgeFrame(f, f:GetFrameLevel() + 5)
	WindowGround(f)
	f:Hide()
	tinsert(UISpecialFrames, "AnglersRestFrame")

	local title = MakeText(f, 17, TITLE_YELLOW)
	title:SetPoint("TOPLEFT", PAD, -12)
	title:SetText(L("TITLE"))

	local close = CreateFrame("Button", Name("Close"), f)
	close:SetSize(18, 18)
	close:SetPoint("TOPRIGHT", -12, -12)
	close:EnableMouse(true)
	local x = MakeText(close, 15, BRONZE, "CENTER")
	x:SetPoint("CENTER")
	x:SetText("|cffA67D45x|r")
	close:SetScript("OnClick", function() AnglersRest_ToggleWindow() end)
	close:HookScript("OnEnter", function() x:SetText("|cffffd770x|r") end)
	close:HookScript("OnLeave", function() x:SetText("|cffA67D45x|r") end)

	local status = MakeText(f, 11, GREY)
	status:SetPoint("TOPLEFT", PAD, -36)
	f.status = status

	local y = -60

	local auto = Checkbox(f, L("AUTO_EQUIP"), db.autoEquip, function(v)
		AnglersRest_SetDB("autoEquip", v)
	end)
	auto:SetPoint("TOPLEFT", PAD, y)
	f.autoEquipCheck = auto
	y = y - 28

	local click = Checkbox(f, L("DOUBLE_CLICK"), db.doubleClick, function(v)
		AnglersRest_SetDB("doubleClick", v)
	end)
	click:SetPoint("TOPLEFT", PAD, y)
	f.doubleClickCheck = click
	y = y - 28

	local map = Checkbox(f, L("MINIMAP_ICON"), not db.map.hide, function(v)
		AnglersRest_SetMinimapShown(v)
	end)
	map:SetPoint("TOPLEFT", PAD, y)
	f.mapCheck = map
	y = y - 36

	local mode = PlateButton(f, L("MODE_OFF"), WIDTH - PAD * 2, function()
		AnglersRest_Toggle()
	end)
	mode:SetPoint("TOPLEFT", PAD, y)
	f.modeLabel = mode.textLabel

	local footer = MakeText(f, 10, GREY)
	footer:SetPoint("BOTTOMLEFT", PAD, 10)
	footer:SetText(L("CREDIT"))

	f:SetHeight(-y + 26 + 34)
	f:SetScript("OnShow", function() AnglersRest_Refresh() end)
	return f
end

-- always in the middle of the screen, at a size that fits it
function AnglersRest_ApplyWindowPosition()
	if not frame then return end
	local scale = 1
	local needH = frame:GetHeight() + 40
	local needW = frame:GetWidth() + 40
	local screenH, screenW = UIParent:GetHeight(), UIParent:GetWidth()
	if needH > screenH or needW > screenW then
		scale = math.min(screenH / needH, screenW / needW)
	end
	frame:SetScale(scale)
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
end

function AnglersRest_Refresh()
	if not frame or refreshing then return end
	refreshing = true
	local db = DB()

	if db.enabled then
		frame.status:SetText("|cff7CE07C" .. L("STATUS_ON") .. "|r")
	else
		frame.status:SetText(L("STATUS_OFF"))
	end
	frame.modeLabel:SetText(db.enabled and L("MODE_ON") or L("MODE_OFF"))
	frame.autoEquipCheck:SetChecked(db.autoEquip)
	frame.doubleClickCheck:SetChecked(db.doubleClick)
	frame.mapCheck:SetChecked(not db.map.hide)

	refreshing = false
end

-- the weapon question, made once and reused ------------------------------------

function AnglersRest_ShowWeaponPrompt(itemID)
	local name = C_Item.GetItemNameByID(itemID)

	if not WeaponPromptFrame then
		local box = CreateFrame("Frame", "WeaponPromptFrame", UIParent, "BackdropTemplate")
		WeaponPromptFrame = box
		box:SetSize(300, 120)
		box:SetPoint("CENTER")
		box:SetFrameStrata("DIALOG")
		box:SetToplevel(true)
		box:SetClampedToScreen(true)
		box:EnableMouse(true)
		box:SetBackdrop({ bgFile = WHITE, edgeFile = BORDER_FILE, edgeSize = 12 })
		box:SetBackdropColor(0.06, 0.055, 0.05, 0.97)
		box:SetBackdropBorderColor(EDGE_REST[1], EDGE_REST[2], EDGE_REST[3], 1)

		local title = MakeText(box, 15, TITLE_YELLOW)
		title:SetPoint("TOPLEFT", 16, -12)
		title:SetText(L("TITLE"))

		box.promptText = MakeText(box, 12, { 1, 1, 1 })
		box.promptText:SetPoint("TOPLEFT", 16, -38)
		box.promptText:SetWidth(268)
		box.promptText:SetJustifyH("LEFT")

		local yes = PlateButton(box, L("YES"), 80, function()
			AnglersRest_GiveWeaponBack(false)
			box:Hide()
		end)
		yes:SetPoint("BOTTOMLEFT", 16, 12)
		local no = PlateButton(box, L("NO"), 80, function() box:Hide() end)
		no:SetPoint("BOTTOMRIGHT", -16, 12)

		tinsert(UISpecialFrames, "WeaponPromptFrame")
	end

	WeaponPromptFrame.promptText:SetText(L("PROMPT_WEAPON"):format(name))
	WeaponPromptFrame:Show()
end

function AnglersRest_HideWeaponPrompt()
	if WeaponPromptFrame then WeaponPromptFrame:Hide() end
end

AnglersRest_RefreshPanel = AnglersRest_Refresh

function AnglersRest_ShowWindow()
	AnglersRest_BuildUI()
	AnglersRest_ApplyWindowPosition()
	AnglersRest_Refresh()
	frame:Show()
	DB().window.closedByUser = false
end

function AnglersRest_ToggleWindow()
	if frame and frame:IsShown() then
		frame:Hide()
		DB().window.closedByUser = true
	else
		AnglersRest_ShowWindow()
	end
end

function AnglersRest_OpenOnLoad()
	if DB().window.closedByUser then return end
	AnglersRest_ShowWindow()
end
