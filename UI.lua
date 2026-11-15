-- Angler's Rest: the fishing panel, in the FlareUI style.
-- Colours, fonts and art are FlareUI's own: bronze edge, warm dark ground, yellow titles, gold labels.
-- Every frame has a name: this client rejects a nameless CreateFrame, which left the panel empty.

local ADDON_NAME, ns = ...
local L = ns.L

local frame
local refreshing = false

local BRONZE       = { 0.65, 0.49, 0.27 }   -- FlareUI BORDER_COLOR
local EDGE_REST    = { 0.55, 0.42, 0.24 }   -- FlareUI EDGE_COLOR
local EDGE_HOVER   = { 0.98, 0.74, 0.36 }   -- FlareUI EDGE_HOVER
local TITLE_YELLOW = { 1, 0.82, 0 }         -- FlareUI TITLE_YELLOW
local GOLD         = { 0.91, 0.77, 0.42 }   -- FlareUI GOLD
local GREY         = { 0.62, 0.62, 0.62 }
local WHITE        = "Interface\\Buttons\\WHITE8X8"
local SPHERE       = "Interface\\Buttons\\UI-SphereButton-Static"
local BORDER_FILE  = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Borders\\FlareUI-Thin.tga"
local FONT_FACE    = "Fonts\\FRIZQT__.TTF"
if GetLocale and GetLocale() == "ruRU" then FONT_FACE = "Fonts\\FRIZQT___CYR.TTF" end

local WIDTH, PAD = 400, 18
local CONTENT = WIDTH - PAD * 2
local counter = 0

-- which text shows the value of which slider (kept outside the frames)
local SliderText = setmetatable({}, { __mode = "k" })

local function DB()
	return AnglersRestDB
end

-- a unique name for every frame
local function Name(what)
	counter = counter + 1
	return "AnglersRest" .. what .. counter
end

-- text -------------------------------------------------------------------------

local function MakeText(parent, name, size, color)
	local fs = parent:CreateFontString(name, "OVERLAY")
	fs:SetFont(FONT_FACE, size, "")
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	fs:SetJustifyH("LEFT")
	local c = color or { 1, 1, 1 }
	fs:SetTextColor(c[1], c[2], c[3])
	return fs
end

-- the bronze edge as a frame of its own, over the parent
local function EdgeFrame(parent, level)
	local edge = CreateFrame("Frame", Name("Edge"), parent, "BackdropTemplate")
	edge:SetAllPoints()
	edge:SetFrameLevel(level or (parent:GetFrameLevel() + 1))
	edge:SetBackdrop({ edgeFile = BORDER_FILE, edgeSize = 8 })
	edge:SetBackdropBorderColor(EDGE_REST[1], EDGE_REST[2], EDGE_REST[3], 1)
	return edge
end

-- FlareUI's window ground
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
	glow:SetHeight(150)
	glow:SetColorTexture(1, 1, 1)
	glow:SetGradient("VERTICAL", CreateColor(0.55, 0.41, 0.22, 0), CreateColor(0.55, 0.41, 0.22, 0.22))

	local shade = f:CreateTexture(Name("Shade"), "BACKGROUND", nil, 3)
	shade:SetPoint("BOTTOMLEFT", art)
	shade:SetPoint("BOTTOMRIGHT", art)
	shade:SetHeight(120)
	shade:SetColorTexture(1, 1, 1)
	shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.55), CreateColor(0, 0, 0, 0))
end

local function Divider(parent, y)
	local line = CreateFrame("Frame", Name("Divider"), parent, "BackdropTemplate")
	line:SetPoint("TOPLEFT", PAD, y)
	line:SetPoint("TOPRIGHT", -PAD, y)
	line:SetHeight(1)
	line:SetBackdrop({ bgFile = WHITE })
	line:SetBackdropColor(BRONZE[1], BRONZE[2], BRONZE[3], 0.45)
	return line
end

-- controls ---------------------------------------------------------------------

local function Slider(parent, width, minValue, maxValue, step, value, onChange)
	local s = CreateFrame("Frame", Name("Slider"), parent)
	s:SetSize(width, 14)
	s.minValue, s.maxValue, s.step = minValue, maxValue, step
	s.onChange = onChange

	local track = s:CreateTexture(Name("Track"), "BACKGROUND", nil, 1)
	track:SetTexture(SPHERE)
	track:SetPoint("TOPLEFT", 0, -3)
	track:SetPoint("BOTTOMRIGHT", 0, 3)
	track:SetVertexColor(0.10, 0.08, 0.06, 1)

	local fill = s:CreateTexture(Name("Fill"), "ARTWORK", nil, 1)
	fill:SetTexture(WHITE)
	fill:SetVertexColor(BRONZE[1], BRONZE[2], BRONZE[3], 0.75)
	fill:SetPoint("TOPLEFT", 2, -4)
	fill:SetPoint("BOTTOMLEFT", 2, 4)

	local knob = CreateFrame("Button", Name("Knob"), s)
	knob:SetSize(12, 12)
	knob:SetPoint("CENTER", s, "LEFT", 0, 0)
	knob:EnableMouse(true)
	local ring = knob:CreateTexture(Name("KnobRing"), "OVERLAY")
	ring:SetTexture(SPHERE)
	ring:SetAllPoints()
	ring:SetVertexColor(BRONZE[1], BRONZE[2], BRONZE[3], 1)
	local core = knob:CreateTexture(Name("KnobCore"), "BACKGROUND", nil, -1)
	core:SetTexture(SPHERE)
	core:SetPoint("TOPLEFT", 2, -2)
	core:SetPoint("BOTTOMRIGHT", -2, 2)
	core:SetVertexColor(0.14, 0.10, 0.06, 1)

	function s:SetValue(v, quiet)
		v = math.max(self.minValue, math.min(self.maxValue, v or self.minValue))
		if self.step > 0 then
			v = math.floor((v + self.step / 2) / self.step) * self.step
		end
		self.value = v
		local ratio = math.max(0, math.min(1, (v - self.minValue) / (self.maxValue - self.minValue)))
		knob:ClearAllPoints()
		knob:SetPoint("CENTER", self, "LEFT", ratio * width, 0)
		fill:SetWidth(math.max(2, ratio * width))
		local text = SliderText[self]
		if text then text:SetText("|cffffd100" .. math.floor(v) .. "%|r") end
		if not quiet and self.onChange then self.onChange(v) end
	end
	function s:GetValue()
		return self.value
	end

	local function FromCursor()
		local left, right = s:GetLeft(), s:GetRight()
		if not left or not right then return end
		local x = GetCursorPosition() / s:GetEffectiveScale()
		s:SetValue(s.minValue + math.max(0, math.min(1, (x - left) / (right - left))) * (s.maxValue - s.minValue))
	end

	knob:SetScript("OnMouseDown", function()
		s:SetScript("OnUpdate", FromCursor)
		FromCursor()
	end)
	knob:SetScript("OnMouseUp", function() s:SetScript("OnUpdate", nil) end)
	knob:HookScript("OnEnter", function() core:SetVertexColor(0.24, 0.17, 0.10, 1) end)
	knob:HookScript("OnLeave", function() core:SetVertexColor(0.14, 0.10, 0.06, 1) end)
	s:SetScript("OnMouseDown", function()
		FromCursor()
		s:SetScript("OnUpdate", FromCursor)
	end)
	s:SetScript("OnMouseUp", function() s:SetScript("OnUpdate", nil) end)
	s:SetScript("OnHide", function() s:SetScript("OnUpdate", nil) end)
	s:EnableMouse(true)

	s:SetValue(value, true)
	return s
end

local function Checkbox(parent, text, isChecked, onToggle, size)
	size = size or 20
	local f = CreateFrame("Button", Name("Check"), parent)
	f:SetSize(size, size)
	f:EnableMouse(true)

	local box = f:CreateTexture(Name("CheckBox"), "ARTWORK")
	box:SetPoint("CENTER", f, "LEFT", size / 2, 0)
	box:SetSize(size, size)

	local tick = f:CreateTexture(Name("Tick"), "OVERLAY")
	tick:SetPoint("CENTER", box)

	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("checkbox-minimal") then
		local bg = f:CreateTexture(Name("CheckBg"), "BACKGROUND")
		bg:SetAllPoints(box)
		bg:SetAtlas("checkbox-minimal", true)
		tick:SetAtlas("checkmark-minimal", true)
	else
		box:SetTexture(WHITE)
		box:SetVertexColor(0.18, 0.14, 0.09, 1)
		local rim = EdgeFrame(f)
		rim:SetPoint("CENTER", box)
		rim:SetSize(size + 2, size + 2)
		tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		tick:SetVertexColor(TITLE_YELLOW[1], TITLE_YELLOW[2], TITLE_YELLOW[3])
	end

	function f:SetChecked(checked)
		self.checked = checked and true or false
		tick:SetShown(self.checked)
	end
	function f:GetChecked()
		return self.checked
	end
	f:SetChecked(isChecked)

	if text then
		local label = MakeText(f, Name("CheckText"), 12, { 1, 1, 1 })
		label:SetPoint("LEFT", box, "RIGHT", 8, 0)
		label:SetText(text)
		f:HookScript("OnEnter", function() label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end)
		f:HookScript("OnLeave", function() label:SetTextColor(1, 1, 1) end)
	end

	f:SetScript("OnClick", function(self)
		self:SetChecked(not self:GetChecked())
		if onToggle then onToggle(self:GetChecked()) end
	end)
	return f
end

local function PillButton(parent, text, width, onClick)
	local b = CreateFrame("Button", Name("Button"), parent)
	b:SetSize(width, 24)
	b:EnableMouse(true)

	local plate = b:CreateTexture(Name("Plate"), "BACKGROUND", nil, 1)
	plate:SetTexture(WHITE)
	plate:SetPoint("TOPLEFT", 2, -2)
	plate:SetPoint("BOTTOMRIGHT", -2, 2)
	plate:SetVertexColor(0.13, 0.11, 0.09, 1)

	local edge = EdgeFrame(b)

	local label = MakeText(b, Name("ButtonText"), 12, TITLE_YELLOW)
	label:SetPoint("LEFT", 8, 0)
	label:SetPoint("RIGHT", -8, 0)
	label:SetJustifyH("CENTER")
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
	b:SetScript("OnClick", function()
		if onClick then onClick() end
	end)
	return b
end

local function Section(parent, text, y)
	local title = MakeText(parent, Name("Section"), 13, TITLE_YELLOW)
	title:SetPoint("TOPLEFT", PAD, y)
	title:SetText(text)
	local rule = CreateFrame("Frame", Name("Rule"), parent, "BackdropTemplate")
	rule:SetPoint("TOPLEFT", PAD, y - 18)
	rule:SetPoint("TOPRIGHT", -PAD, y - 18)
	rule:SetHeight(1)
	rule:SetBackdrop({ bgFile = WHITE })
	rule:SetBackdropColor(BRONZE[1], BRONZE[2], BRONZE[3], 0.35)
	return title
end

-- the name of a channel: the game's own word when it has one, the addon's table otherwise
local function ChannelName(key)
	local fromGame = ns.GameName and ns.GameName(key)
	if fromGame then return fromGame end
	local names = {
		master = L("CHANNEL_MASTER"),
		sfx = L("CHANNEL_SFX"),
		music = L("CHANNEL_MUSIC"),
		ambience = L("CHANNEL_AMBIENCE"),
		dialog = L("CHANNEL_DIALOG"),
		sfxOn = L("CHANNEL_SFX_ON"),
		musicOn = L("CHANNEL_MUSIC_ON"),
		ambientOn = L("CHANNEL_AMBIENCE_ON"),
		dialogOn = L("CHANNEL_DIALOG_ON"),
		allOn = L("CHANNEL_ALL_ON"),
	}
	return names[key] or key
end
AnglersRest_ChannelName = ChannelName

-- one sound channel: name, value text, slider and the off box at the right
local function ChannelRow(parent, entry, y)
	local db = DB()

	local label = MakeText(parent, Name("Channel"), 12, GOLD)
	label:SetPoint("TOPLEFT", PAD, y)
	label:SetText(AnglersRest_ChannelName(entry.key))

	local row = { entry = entry, label = label }

	local value = MakeText(parent, Name("ChannelValue"), 12, TITLE_YELLOW)
	value:SetPoint("TOPRIGHT", -PAD - 30, y)
	value:SetJustifyH("RIGHT")
	row.value = value

	if entry.kind == "percent" then
		local width = WIDTH - PAD * 2 - 30 - 60 - 150
		local slider = Slider(parent, width, 0, 100, 5, db[entry.key] or 100, function(v)
			AnglersRest_SetChannel(entry.key, v)
		end)
		SliderText[slider] = value
		slider:SetPoint("TOPLEFT", PAD + 150, y - 6)
		slider:SetValue(db[entry.key] or 100, true)
		row.slider = slider
	else
		value:SetText("")
	end

	local off = Checkbox(parent, nil, db.off[entry.key], function(v)
		AnglersRest_SetChannelOff(entry.key, v)
	end, 18)
	off:SetPoint("TOPRIGHT", -PAD, y + 4)
	row.off = off

	return row
end

-- the window -------------------------------------------------------------------

local function SavePosition()
	if not frame then return end
	local point, _, _, x, y = frame:GetPoint(1)
	local win = DB().window
	win.point, win.x, win.y = point, x or 0, y or 0
end

local function FitScale(wanted)
	local screenH = UIParent:GetHeight() or 768
	local needed = (frame:GetHeight() or 500) + 40
	-- 1 unless the window would not fit; it shrinks only as much as it has to
	local fit = math.min(1, (screenH * 0.96) / needed)
	return math.max(0.75, math.min(1.25, math.min(wanted or 1, fit)))
end

function AnglersRest_BuildUI()
	if frame then return frame end
	local db = DB()

	local f = CreateFrame("Frame", "AnglersRestFrame", UIParent, "BackdropTemplate")
	frame = f
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) self:StartMoving() end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		SavePosition()
	end)
	f:SetScript("OnMouseDown", function(_, button)
		if button == "LeftButton" then f:StartMoving() end
	end)
	f:SetScript("OnMouseUp", function()
		f:StopMovingOrSizing()
		SavePosition()
	end)
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, delta)
		if not IsShiftKeyDown() then return end
		local win = DB().window
		win.scale = math.max(0.7, math.min(1.25, (win.scale or 1) + (delta > 0 and 0.05 or -0.05)))
		AnglersRest_ApplyWindowPosition()
	end)

	EdgeFrame(f, f:GetFrameLevel() + 5)
	WindowGround(f)
	f:Hide()
	UISpecialFrames = type(UISpecialFrames) == "table" and UISpecialFrames or {}
	tinsert(UISpecialFrames, "AnglersRestFrame")

	-- header
	local title = MakeText(f, Name("Title"), 17, TITLE_YELLOW)
	title:SetPoint("TOPLEFT", PAD, -11)
	title:SetText(L("TITLE"))

	local close = CreateFrame("Button", Name("Close"), f)
	close:SetSize(18, 18)
	close:SetPoint("TOPRIGHT", -12, -11)
	close:EnableMouse(true)
	local closeText = MakeText(close, Name("CloseText"), 15, BRONZE)
	closeText:SetPoint("CENTER")
	closeText:SetText("|cffA67D45x|r")
	close:SetScript("OnClick", function() AnglersRest_ToggleWindow() end)
	close:HookScript("OnEnter", function() closeText:SetText("|cffffd770x|r") end)
	close:HookScript("OnLeave", function() closeText:SetText("|cffA67D45x|r") end)

	f.status = MakeText(f, Name("Status"), 11, GREY)
	f.status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	f.status:SetWidth(CONTENT)
	f.status:SetHeight(28)
	f.status:SetJustifyH("LEFT")
	f.status:SetJustifyV("TOP")

	-- sound: one line per channel this client has
	local y = -56
	Section(f, L("SOUND_SECTION"), y)

	y = y - 26
	f.rows = {}
	for _, entry in ipairs(AnglersRest_Channels()) do
		f.rows[#f.rows + 1] = ChannelRow(f, entry, y)
		y = y - 20
	end

	Divider(f, y - 2)
	y = y - 16

	-- the pole
	Section(f, L("POLE_SECTION"), y)
	y = y - 26

	local auto = Checkbox(f, L("AUTO_EQUIP"), db.autoEquip, function(v)
		AnglersRest_SetDB("autoEquip", v)
	end)
	auto:SetPoint("TOPLEFT", PAD - 6, y)
	f.autoEquipCheck = auto
	y = y - 26

	local poleButton = PillButton(f, L("EQUIP_NOW"), 110, function() AnglersRest_EquipPoleNow() end)
	poleButton:SetPoint("TOPLEFT", PAD, y)
	local backButton = PillButton(f, L("GIVE_BACK"), 130, function() AnglersRest_GiveWeaponBackNow() end)
	backButton:SetPoint("LEFT", poleButton, "RIGHT", 8, 0)
	y = y - 28

	Divider(f, y - 4)
	y = y - 20

	-- behaviour
	local catchCheck = Checkbox(f, L("RESTORE_ON_CATCH"), db.restoreOnCatch, function(v)
		AnglersRest_SetDB("restoreOnCatch", v)
	end)
	catchCheck:SetPoint("TOPLEFT", PAD - 6, y)
	f.catchCheck = catchCheck
	y = y - 24

	local clickCheck = Checkbox(f, L("DOUBLE_CLICK"), db.doubleClick, function(v)
		AnglersRest_SetDB("doubleClick", v)
	end)
	clickCheck:SetPoint("TOPLEFT", PAD - 6, y)
	f.doubleClickCheck = clickCheck
	y = y - 24

	local mapCheck = Checkbox(f, L("MINIMAP_ICON"), not db.minimap.hide, function(v)
		AnglersRest_SetMinimapShown(v)
	end)
	mapCheck:SetPoint("TOPLEFT", PAD - 6, y)
	f.minimapCheck = mapCheck
	y = y - 30

	-- footer
	local reset = PillButton(f, L("CENTRE"), 90, function() AnglersRest_ResetWindow() end)
	reset:SetPoint("BOTTOMLEFT", PAD, 12)

	local mode = PillButton(f, L("MODE_OFF"), 130, function() AnglersRest_Toggle() end)
	mode:SetPoint("BOTTOMRIGHT", -PAD, 12)
	f.modeLabel = mode.textLabel
	f.modeButton = mode

	local footer = MakeText(f, Name("Footer"), 10, GREY)
	footer:SetPoint("BOTTOMLEFT", reset, "TOPLEFT", 0, 5)
	footer:SetText(L("CREDIT"))

	f:SetHeight(math.abs(y) + 12 + 24 + 18)
	f:SetScript("OnShow", function() AnglersRest_Refresh() end)
	return f
end

function AnglersRest_ApplyWindowPosition()
	if not frame then return end
	local win = DB().window
	frame:ClearAllPoints()
	frame:SetPoint(win.point or "CENTER", UIParent, win.point or "CENTER", win.x or 0, win.y or 0)
	frame:SetScale(FitScale(win.scale))
end

function AnglersRest_Refresh()
	if not frame or refreshing then return end
	refreshing = true
	local db = DB()

	if frame.status then
		if db.enabled then
			frame.status:SetText("|cff7CE07C" .. L("STATUS_ON") .. "|r")
		else
			frame.status:SetText(L("STATUS_OFF"))
		end
	end
	if frame.modeLabel then
		frame.modeLabel:SetText(db.enabled and L("MODE_ON") or L("MODE_OFF"))
	end
	if frame.catchCheck then frame.catchCheck:SetChecked(db.restoreOnCatch) end
	if frame.doubleClickCheck then frame.doubleClickCheck:SetChecked(db.doubleClick) end
	if frame.minimapCheck then frame.minimapCheck:SetChecked(not db.minimap.hide) end
	if frame.autoEquipCheck then frame.autoEquipCheck:SetChecked(db.autoEquip) end

	for _, row in ipairs(frame.rows or {}) do
		local off = db.off[row.entry.key]
		row.off:SetChecked(off)
		if row.slider then
			row.slider:SetValue(db[row.entry.key] or 100, true)
			row.value:SetText("|cffffd100" .. math.floor(db[row.entry.key] or 100) .. "%|r")
			row.slider:SetAlpha(off and 0.45 or 1)
			row.label:SetAlpha(off and 0.55 or 1)
		end
	end

	refreshing = false
end

-- the weapon question after a catch ----------------------------------------------

function AnglersRest_ShowWeaponPrompt(itemID)
	if WeaponPromptFrame then WeaponPromptFrame:Hide() end
	local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(itemID) or GetItemInfo(itemID) or ""

	local box = CreateFrame("Frame", "WeaponPromptFrame", UIParent, "BackdropTemplate")
	box:SetSize(300, 120)
	box:SetPoint("CENTER")
	box:SetFrameStrata("DIALOG")
	box:SetToplevel(true)
	box:SetClampedToScreen(true)
	box:EnableMouse(true)
	box:SetMovable(true)
	box:RegisterForDrag("LeftButton")
	box:SetScript("OnDragStart", function(self) self:StartMoving() end)
	box:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
	box:SetBackdrop({ bgFile = WHITE, edgeFile = BORDER_FILE, edgeSize = 12 })
	box:SetBackdropColor(0.06, 0.055, 0.05, 0.97)
	box:SetBackdropBorderColor(EDGE_REST[1], EDGE_REST[2], EDGE_REST[3], 1)

	local title = MakeText(box, Name("PromptTitle"), 15, TITLE_YELLOW)
	title:SetPoint("TOPLEFT", 16, -12)
	title:SetText(L("TITLE"))

	local text = MakeText(box, Name("PromptText"), 12, { 1, 1, 1 })
	text:SetPoint("TOPLEFT", 16, -38)
	text:SetWidth(268)
	text:SetJustifyH("LEFT")
	text:SetText(L("PROMPT_WEAPON"):format(name))

	local yes = PillButton(box, L("YES"), 80, function()
		AnglersRest_GiveWeaponBackNow()
		box:Hide()
	end)
	yes:SetPoint("BOTTOMLEFT", 16, 12)
	local no = PillButton(box, L("NO"), 80, function() box:Hide() end)
	no:SetPoint("BOTTOMRIGHT", -16, 12)

	UISpecialFrames = type(UISpecialFrames) == "table" and UISpecialFrames or {}
	tinsert(UISpecialFrames, "WeaponPromptFrame")

	-- the mode's button shows the same state as the panel
	if frame and frame.modeLabel then frame.modeLabel:SetText(DB().enabled and L("MODE_ON") or L("MODE_OFF")) end
	box:Show()
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
end

function AnglersRest_ToggleWindow()
	if not frame then
		DB().window.closedByUser = nil
		AnglersRest_ShowWindow()
		return
	end
	if frame:IsShown() then
		frame:Hide()
		DB().window.closedByUser = true
	else
		DB().window.closedByUser = nil
		AnglersRest_ShowWindow()
	end
end

-- the panel opens with the game, unless it was closed on purpose
function AnglersRest_OpenOnLoad()
	AnglersRest_ShowWindow()
	if DB().window.closedByUser then frame:Hide() end
end
