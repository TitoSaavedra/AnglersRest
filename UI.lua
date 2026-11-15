-- Angler's Rest: the floating panel, drawn from scratch in the FlareUI style.
-- Values copied from FlareUI: bronze edge (FlareUI-Thin, 8 px), warm near-black ground, WoW-yellow
-- titles, bronze-gold labels, Friz Quadrata with a hard shadow, checkbox art by atlas, drawn slider.
-- One row per sound channel the client exposes, each with a value and its own off switch.

local ADDON_NAME = ...

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

-- the saved variables, created on the spot if the panel is built before they exist
local function DB()
	if type(AnglersRestDB) ~= "table" and AnglersRest_EnsureDB then AnglersRest_EnsureDB() end
	local db = AnglersRestDB or {}
	db.off = type(db.off) == "table" and db.off or {}
	db.minimap = type(db.minimap) == "table" and db.minimap or {}
	return db
end

-- helpers ---------------------------------------------------------------------

-- Every widget is made through this: on some clients CreateFrame does not take an empty name,
-- and a single failure there used to leave an empty panel behind.
local widgetCount = 0
local function NewFrame(kind, name, parent, template)
	widgetCount = widgetCount + 1
	local target = parent or UIParent
	local ok, frameObject = pcall(CreateFrame, kind, name, target, template)
	if ok and frameObject then return frameObject end
	-- Blizzard-like clients refuse nameless frames in some situations; a named one always works
	return CreateFrame(kind, "AnglersRestWidget" .. widgetCount, target, template)
end

local function MakeText(parent, size, color)
	local fs = parent:CreateFontString(nil, "OVERLAY")
	fs:SetFont(FONT_FACE, size, "")
	fs:SetShadowColor(0, 0, 0, 1)
	fs:SetShadowOffset(1, -1)
	fs:SetJustifyH("LEFT")
	local c = color or { 1, 1, 1 }
	fs:SetTextColor(c[1], c[2], c[3])
	return fs
end

local function EdgeFrame(parent, level)
	local edge = NewFrame("Frame", nil, parent, "BackdropTemplate")
	edge:SetAllPoints()
	edge:SetFrameLevel(level or (parent:GetFrameLevel() + 1))
	edge:SetBackdrop({ edgeFile = BORDER_FILE, edgeSize = 8 })
	edge:SetBackdropBorderColor(EDGE_REST[1], EDGE_REST[2], EDGE_REST[3], 1)
	return edge
end

local function WindowGround(f)
	local art = f:CreateTexture(nil, "BACKGROUND", nil, 1)
	art:SetPoint("TOPLEFT", 3, -3)
	art:SetPoint("BOTTOMRIGHT", -3, 3)
	art:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock", "REPEAT", "REPEAT")
	art:SetHorizTile(true)
	art:SetVertTile(true)
	art:SetDesaturated(true)
	art:SetVertexColor(0.85, 0.68, 0.47)

	local wash = f:CreateTexture(nil, "BACKGROUND", nil, 2)
	wash:SetAllPoints(art)
	wash:SetColorTexture(0.05, 0.038, 0.026, 0.62)

	local glow = f:CreateTexture(nil, "BACKGROUND", nil, 3)
	glow:SetPoint("TOPLEFT", art)
	glow:SetPoint("TOPRIGHT", art)
	glow:SetHeight(150)
	glow:SetColorTexture(1, 1, 1)
	glow:SetGradient("VERTICAL", CreateColor(0.55, 0.41, 0.22, 0), CreateColor(0.55, 0.41, 0.22, 0.22))

	local shade = f:CreateTexture(nil, "BACKGROUND", nil, 3)
	shade:SetPoint("BOTTOMLEFT", art)
	shade:SetPoint("BOTTOMRIGHT", art)
	shade:SetHeight(120)
	shade:SetColorTexture(1, 1, 1)
	shade:SetGradient("VERTICAL", CreateColor(0, 0, 0, 0.55), CreateColor(0, 0, 0, 0))
end

local function Divider(parent, y)
	local line = NewFrame("Frame", nil, parent, "BackdropTemplate")
	line:SetPoint("TOPLEFT", PAD, y)
	line:SetPoint("TOPRIGHT", -PAD, y)
	line:SetHeight(1)
	line:SetBackdrop({ bgFile = WHITE })
	line:SetBackdropColor(BRONZE[1], BRONZE[2], BRONZE[3], 0.45)
	return line
end

-- controls ----------------------------------------------------------------------

-- a slider drawn here: pill track, bronze fill, round knob. Values snap to the step.
local function Slider(parent, width, minValue, maxValue, step, value, onChange)
	local s = NewFrame("Frame", nil, parent)
	s:SetSize(width, 14)
	s.minValue, s.maxValue, s.step, s.onChange = minValue, maxValue, step, onChange

	local track = s:CreateTexture(nil, "BACKGROUND", nil, 1)
	track:SetTexture(SPHERE)
	track:SetPoint("TOPLEFT", 0, -3)
	track:SetPoint("BOTTOMRIGHT", 0, 3)
	track:SetVertexColor(0.10, 0.08, 0.06, 1)

	local fill = s:CreateTexture(nil, "ARTWORK", nil, 1)
	fill:SetTexture(WHITE)
	fill:SetVertexColor(BRONZE[1], BRONZE[2], BRONZE[3], 0.75)
	fill:SetPoint("TOPLEFT", 2, -4)
	fill:SetPoint("BOTTOMLEFT", 2, 4)
	s.fill = fill

	local knob = NewFrame("Button", nil, s)
	knob:SetSize(12, 12)
	knob:SetPoint("CENTER", s, "LEFT", 0, 0)
	local ring = knob:CreateTexture(nil, "OVERLAY")
	ring:SetTexture(SPHERE)
	ring:SetAllPoints()
	ring:SetVertexColor(BRONZE[1], BRONZE[2], BRONZE[3], 1)
	local core = knob:CreateTexture(nil, "BACKGROUND", nil, -1)
	core:SetTexture(SPHERE)
	core:SetPoint("TOPLEFT", 2, -2)
	core:SetPoint("BOTTOMRIGHT", -2, 2)
	core:SetVertexColor(0.14, 0.10, 0.06, 1)

	function s:SetValue(v, quiet)
		v = math.max(self.minValue, math.min(self.maxValue, v or self.minValue))
		if self.step and self.step > 0 then
			v = math.floor((v + self.step / 2) / self.step) * self.step
		end
		self.value = v
		local ratio = (v - self.minValue) / (self.maxValue - self.minValue)
		ratio = math.max(0, math.min(1, ratio))
		knob:ClearAllPoints()
		knob:SetPoint("CENTER", self, "LEFT", ratio * width, 0)
		fill:SetWidth(math.max(2, ratio * width))
		local text = rawget(self, "valueText")
		if text then text:SetText("|cffffd100" .. math.floor(v) .. "%|r") end
		if not quiet and self.onChange then self.onChange(v) end
	end
	function s:GetValue() return self.value end

	local function FromCursor()
		local left, right = s:GetLeft(), s:GetRight()
		if not left then return end
		local x = GetCursorPosition() / s:GetEffectiveScale()
		local ratio = (x - left) / math.max(1, right - left)
		s:SetValue(s.minValue + math.max(0, math.min(1, ratio)) * (s.maxValue - s.minValue))
	end
	knob:SetScript("OnMouseDown", function() s:SetScript("OnUpdate", FromCursor) FromCursor() end)
	knob:SetScript("OnMouseUp", function() s:SetScript("OnUpdate", nil) end)
	knob:HookScript("OnEnter", function() core:SetVertexColor(0.24, 0.17, 0.10, 1) end)
	knob:HookScript("OnLeave", function() core:SetVertexColor(0.14, 0.10, 0.06, 1) end)
	s:SetScript("OnMouseDown", function() FromCursor() s:SetScript("OnUpdate", FromCursor) end)
	s:SetScript("OnMouseUp", function() s:SetScript("OnUpdate", nil) end)
	s:SetScript("OnHide", function() s:SetScript("OnUpdate", nil) end)
	s:EnableMouse(true)
	s:SetValue(value, true)
	return s
end

-- FlareUI's toggle art by atlas; a drawn bronze box when the client has no atlas
local function Checkbox(parent, text, isChecked, onToggle, size)
	size = size or 20
	local f = NewFrame("Button", nil, parent)
	f:SetSize(size, size)
	local box = f:CreateTexture(nil, "ARTWORK")
	box:SetPoint("CENTER", f, "LEFT", size / 2, 0)
	box:SetSize(size, size)

	if C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("checkbox-minimal") then
		local bg = f:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints(box)
		bg:SetAtlas("checkbox-minimal", true)
		local tick = f:CreateTexture(nil, "OVERLAY")
		tick:SetAtlas("checkmark-minimal", true)
		tick:SetPoint("CENTER", box)
		f:SetCheckedTexture(tick)
	else
		box:SetTexture(WHITE)
		box:SetVertexColor(0.18, 0.14, 0.09, 1)
		local rim = EdgeFrame(f)
		rim:SetPoint("CENTER", box)
		rim:SetSize(size + 2, size + 2)
		local tick = f:CreateTexture(nil, "OVERLAY")
		tick:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
		tick:SetPoint("CENTER", box)
		tick:SetVertexColor(TITLE_YELLOW[1], TITLE_YELLOW[2], TITLE_YELLOW[3])
		f:SetCheckedTexture(tick)
		f:HookScript("OnEnter", function() rim:SetBackdropBorderColor(EDGE_HOVER[1], EDGE_HOVER[2], EDGE_HOVER[3], 1) end)
		f:HookScript("OnLeave", function() rim:SetBackdropBorderColor(EDGE_REST[1], EDGE_REST[2], EDGE_REST[3], 1) end)
	end

	if text then
		local label = MakeText(f, 12, { 1, 1, 1 })
		label:SetPoint("LEFT", box, "RIGHT", 8, 0)
		label:SetPoint("RIGHT", 0, 0)
		label:SetText(text)
		f.textLabel = label
		f:HookScript("OnEnter", function() label:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end)
		f:HookScript("OnLeave", function() label:SetTextColor(1, 1, 1) end)
	end

	f:SetScript("OnClick", function()
		local checked = not f:GetChecked()
		f:SetChecked(checked)
		if onToggle then onToggle(checked) end
	end)
	return f
end

local function PillButton(parent, text, width, onClick)
	local b = NewFrame("Button", nil, parent)
	b:SetSize(width, 24)

	local plate = b:CreateTexture(nil, "BACKGROUND", nil, 1)
	plate:SetTexture(WHITE)
	plate:SetPoint("TOPLEFT", 2, -2)
	plate:SetPoint("BOTTOMRIGHT", -2, 2)
	plate:SetVertexColor(0.13, 0.11, 0.09, 1)

	local edge = EdgeFrame(b)
	b.edge = edge

	local label = MakeText(b, 12, TITLE_YELLOW)
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
	b:SetScript("OnClick", function() if onClick then onClick() end end)
	return b
end

-- a section header: gold text with a bronze rule under it, the rule on its own frame (full width)
local function Section(parent, text, y)
	local title = MakeText(parent, 13, TITLE_YELLOW)
	title:SetPoint("TOPLEFT", PAD, y)
	title:SetText(text)
	local rule = NewFrame("Frame", nil, parent, "BackdropTemplate")
	rule:SetPoint("TOPLEFT", PAD, y - 18)
	rule:SetPoint("TOPRIGHT", -PAD, y - 18)
	rule:SetHeight(1)
	rule:SetBackdrop({ bgFile = WHITE })
	rule:SetBackdropColor(BRONZE[1], BRONZE[2], BRONZE[3], 0.35)
	return title
end

-- One channel on a single line: name, slider and value, and the off box at the far right.
-- A channel switch has no slider of its own (its box is the whole control).
local function ChannelRow(parent, entry, y)
	local label = MakeText(parent, 12, GOLD)
	label:SetPoint("TOPLEFT", PAD, y)
	label:SetText(entry.label)

	local width = WIDTH - PAD * 2 - 28 - 60 - 150 -- right box, value, the name column
	local slider
	local value = MakeText(parent, 12, TITLE_YELLOW)
	value:SetPoint("TOPRIGHT", -PAD - 28, y)
	value:SetJustifyH("RIGHT")

	if entry.kind == "percent" then
		slider = Slider(parent, width, 0, 100, 5, DB()[entry.key] or 100, function(v)
			AnglersRest_SetChannel(entry.key, v)
		end)
		slider:SetPoint("TOPLEFT", PAD + 150, y - 6)
		slider.valueText = value
		slider:SetValue(DB()[entry.key] or 100, true)
	else
		value:SetText("|cff808080switch|r")
	end

	local off = Checkbox(parent, nil, DB().off[entry.key], function(v)
		AnglersRest_SetChannelOff(entry.key, v)
	end, 18)
	off:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -PAD, y + 4)

	return { entry = entry, label = label, value = value, slider = slider, off = off }
end

-- the window -------------------------------------------------------------------

local function SavePosition()
	if not frame then return end
	local point, _, _, x, y = frame:GetPoint(1)
	local db = AnglersRestDB
	db.window = type(db.window) == "table" and db.window or {}
	db.window.point, db.window.x, db.window.y = point, tonumber(x) or 0, tonumber(y) or 0
end

function AnglersRest_BuildUI()
	if frame then return frame end

	local f = NewFrame("Frame", "AnglersRestFrame", UIParent, "BackdropTemplate")
	frame = f
	f:SetSize(WIDTH, 560)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetClampedToScreen(true)
	f:EnableMouse(true)
	f:SetMovable(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function() f:StartMoving() end)
	f:SetScript("OnDragStop", function() f:StopMovingOrSizing(); SavePosition() end)
	-- the gaps drag the window too
	f:SetScript("OnMouseDown", function(_, button) if button == "LeftButton" then f:StartMoving() end end)
	f:SetScript("OnMouseUp", function() f:StopMovingOrSizing(); SavePosition() end)
	-- shift + wheel over the window changes its scale, like FlareUI's own windows
	f:EnableMouseWheel(true)
	f:SetScript("OnMouseWheel", function(_, delta)
		if not IsShiftKeyDown() then return end
		local db = EnsureDB()
		local s = (db.window.scale or 1) + (delta > 0 and 0.05 or -0.05)
		s = math.max(0.6, math.min(1.4, s))
		db.window.scale = s
		AnglersRest_ApplyWindowPosition()
	end)

	EdgeFrame(f, f:GetFrameLevel() + 5)
	WindowGround(f)
	f:Hide()
	UISpecialFrames = type(UISpecialFrames) == "table" and UISpecialFrames or {}
	tinsert(UISpecialFrames, "AnglersRestFrame")

	-- header
	local title = MakeText(f, 17, TITLE_YELLOW)
	title:SetPoint("TOPLEFT", PAD, -11)
	title:SetText("Angler's Rest")

	local close = NewFrame("Button", nil, f)
	close:SetSize(18, 18)
	close:SetPoint("TOPRIGHT", -12, -11)
	local x = MakeText(close, 15, BRONZE)
	x:SetPoint("CENTER")
	x:SetText("|cffA67D45x|r")
	close:SetScript("OnClick", function() f:Hide() end)
	close:HookScript("OnEnter", function() x:SetText("|cffffd770x|r") end)
	close:HookScript("OnLeave", function() x:SetText("|cffA67D45x|r") end)

	f.status = MakeText(f, 11, GREY)
	f.status:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)
	f.status:SetWidth(CONTENT)

	-- sound: one compact line per channel
	local channels = AnglersRest_AvailableChannels and AnglersRest_AvailableChannels() or {}

	local y = -56
	Section(f, "Sound while fishing", y)
	local hint = MakeText(f, 10, GREY)
	hint:SetPoint("TOPRIGHT", -PAD, y + 1)
	hint:SetJustifyH("RIGHT")
	hint:SetText("the box on the right turns the channel off")

	y = y - 30
	f.rows = {}
	for _, entry in ipairs(channels) do
		local row = ChannelRow(f, entry, y)
		f.rows[#f.rows + 1] = row
		y = y - 20
	end

	Divider(f, y - 2)
	y = y - 16

	-- the pole
	local poleTitle = MakeText(f, 13, TITLE_YELLOW)
	poleTitle:SetPoint("TOPLEFT", PAD, y)
	poleTitle:SetText("The pole")
	y = y - 22

	local auto = Checkbox(f, "Put my fishing pole on, and hand back what was in my hand", DB().autoEquip, function(v)
		AnglersRest_SetDB("autoEquip", v)
	end)
	auto:SetPoint("TOPLEFT", PAD - 6, y)
	auto:SetPoint("RIGHT", -PAD, 0)
	f.autoEquipCheck = auto
	y = y - 26

	local poleButton = PillButton(f, "Equip pole now", 118, function() AnglersRest_EquipPoleNow() end)
	poleButton:SetPoint("TOPLEFT", PAD, y)
	local backButton = PillButton(f, "Give my weapon back", 140, function() AnglersRest_GiveWeaponBackNow() end)
	backButton:SetPoint("LEFT", poleButton, "RIGHT", 8, 0)
	y = y - 28

	-- behaviour
	local catchCheck = Checkbox(f, "Sound and weapon back when the line comes in", DB().restoreOnCatch, function(v)
		AnglersRest_SetDB("restoreOnCatch", v)
	end)
	catchCheck:SetPoint("TOPLEFT", PAD - 6, y)
	catchCheck:SetPoint("RIGHT", -PAD, 0)
	f.catchCheck = catchCheck
	y = y - 24

	local clickCheck = Checkbox(f, "Double right-click the world to cast", DB().doubleClick, function(v)
		AnglersRest_SetDB("doubleClick", v)
	end)
	clickCheck:SetPoint("TOPLEFT", PAD - 6, y)
	clickCheck:SetPoint("RIGHT", -PAD, 0)
	f.doubleClickCheck = clickCheck
	y = y - 24

	local mapCheck = Checkbox(f, "Icon on the minimap", not (DB().minimap and DB().minimap.hide), function(v)
		AnglersRest_SetMinimapShown(v)
	end)
	mapCheck:SetPoint("TOPLEFT", PAD - 6, y)
	mapCheck:SetPoint("RIGHT", -PAD, 0)
	f.minimapCheck = mapCheck
	y = y - 30

	-- footer buttons
	local reset = PillButton(f, "Centre window", 108, function() AnglersRest_ResetWindow() end)
	reset:SetPoint("BOTTOMLEFT", PAD, 12)

	local mode = PillButton(f, "Fishing mode: off", 150, function() AnglersRest_Toggle() end)
	mode:SetPoint("BOTTOMRIGHT", -PAD, 12)
	f.modeButton = mode
	f.modeLabel = mode.textLabel

	f.footer = MakeText(f, 10, GREY)
	f.footer:SetPoint("BOTTOMLEFT", reset, "TOPLEFT", 0, 5)
	f.footer:SetText("Bronze skin after FlareUI")

	f:SetHeight(math.abs(y) + 12 + 24 + 18)
	f.height = math.abs(y) + 12 + 24 + 18
	f:SetScript("OnShow", function() AnglersRest_Refresh() end)
	return f
end

-- The window fits the screen: it shrinks only when it would not fit, and never past 0.7
local function FitScale(wanted)
	local okH, screenH = pcall(function() return UIParent:GetHeight() end)
	if not okH or type(screenH) ~= "number" or screenH <= 0 then screenH = 768 end
	local okW, needed = pcall(function() return frame:GetHeight() end)
	if not okW or type(needed) ~= "number" or needed <= 0 then needed = frame.height or 500 end
	local fit = math.min(1, (screenH * 0.94) / (needed + 30))
	local scale = math.max(0.7, math.min(1.25, math.min(tonumber(wanted) or 1, fit)))
	return scale
end

function AnglersRest_ApplyWindowPosition()
	if not frame then return end
	local win = type(AnglersRestDB) == "table" and AnglersRestDB.window or nil
	win = type(win) == "table" and win or { point = "CENTER", x = 0, y = 0 }
	frame:ClearAllPoints()
	frame:SetPoint(win.point or "CENTER", UIParent, win.point or "CENTER", tonumber(win.x) or 0, tonumber(win.y) or 0)
	frame:SetScale(FitScale(win.scale))
end

function AnglersRest_Refresh()
	if not frame or refreshing then return end
	refreshing = true
	local db = AnglersRestDB

	if frame.status then
		if db.enabled then
			frame.status:SetText("|cff7CE07CFishing mode is on|r " .. "\226\128\148" .. " your own settings wait to come back.")
		else
			frame.status:SetText("Fishing mode is off. Left click the minimap icon to start it.")
		end
	end
	if frame.modeButton and frame.modeLabel then
		frame.modeLabel:SetText(db.enabled and "Fishing mode: on" or "Fishing mode: off")
	end
	if frame.catchCheck then frame.catchCheck:SetChecked(db.restoreOnCatch and true or false) end
	if frame.doubleClickCheck then frame.doubleClickCheck:SetChecked(db.doubleClick and true or false) end
	if frame.minimapCheck then frame.minimapCheck:SetChecked(not (db.minimap and db.minimap.hide)) end
	if frame.autoEquipCheck then frame.autoEquipCheck:SetChecked(db.autoEquip and true or false) end

	for _, row in ipairs(frame.rows or {}) do
		local entry = row.entry
		local off = db.off and db.off[entry.key]
		row.off:SetChecked(off and true or false)
		if row.slider then
			row.slider:SetValue(db[entry.key] or 100, true)
			row.value:SetText("|cffffd100" .. math.floor(db[entry.key] or 100) .. "%|r")
			row.slider:SetAlpha(off and 0.45 or 1)
			row.label:SetAlpha(off and 0.55 or 1)
		end
	end

	refreshing = false
end
-- Boxed, like the larger Blizzard and FlareUI windows (12 px edge, grey face).
function AnglersRest_DialogBox(parent, width, height)
	local box = NewFrame("Frame", nil, parent, "BackdropTemplate")
	box:SetSize(width, height)
	box:SetFrameStrata("DIALOG")
	box:SetToplevel(true)
	box:SetClampedToScreen(true)
	box:EnableMouse(true)
	box:SetMovable(true)
	box:RegisterForDrag("LeftButton")
	box:SetScript("OnDragStart", function() box:StartMoving() end)
	box:SetScript("OnDragStop", function() box:StopMovingOrSizing() end)
	box:SetBackdrop({ bgFile = WHITE, edgeFile = BORDER_FILE, edgeSize = 12 })
	box:SetBackdropColor(0.06, 0.055, 0.05, 0.97)
	box:SetBackdropBorderColor(EDGE_REST[1], EDGE_REST[2], EDGE_REST[3], 1)
	return box
end

function AnglersRest_ShowWeaponPrompt(itemID)
	AnglersRest_HideWeaponPrompt()
	local name = (GetItemInfo and select(1, GetItemInfo(itemID))) or "your weapon"

	local box = AnglersRest_DialogBox(UIParent, 340, 140)
	box:SetPoint("CENTER")
	WeaponPromptFrame = box

	local title = MakeText(box, 15, TITLE_YELLOW)
	title:SetPoint("TOPLEFT", 16, -14)
	title:SetText("Angler's Rest")

	local text = MakeText(box, 12, { 1, 1, 1 })
	text:SetPoint("TOPLEFT", 16, -42)
	text:SetWidth(320)
	text:SetJustifyH("LEFT")
	text:SetText("Put your " .. name .. " back on? The fishing line is in.")

	local yes = PillButton(box, "Yes", 90, function()
		AnglersRest_GiveWeaponBackNow()
		box:Hide()
	end)
	yes:SetPoint("BOTTOMLEFT", 16, 14)
	local no = PillButton(box, "No", 90, function() box:Hide() end)
	no:SetPoint("BOTTOMRIGHT", -16, 14)

	UISpecialFrames = type(UISpecialFrames) == "table" and UISpecialFrames or {}
	tinsert(UISpecialFrames, "WeaponPromptFrame")
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

-- The window must look right from the first frame, so the layout is applied at load too: the
-- panel used to sit at its default size until something else asked for its position.
AnglersRest_BuildUI()
AnglersRest_ApplyWindowPosition()

function AnglersRest_ToggleWindow()
	if frame and frame:IsShown() then
		frame:Hide()
	else
		AnglersRest_ShowWindow()
	end
end
