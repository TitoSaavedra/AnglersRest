-- Angler's Rest: fishing audio mode and its panel.
-- No libraries: the minimap icon is drawn here.

local ADDON_NAME, ns = ...
local L = ns.L

local FISHING_SPELL_ID = 7620
local FISHING_SPELL_NAME = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(FISHING_SPELL_ID)) or "Fishing"
local ICON_TEXTURE = 135123 -- Interface\Icons\Trade_Fishing
local MAINHAND = (INVSLOT_MAINHAND and rawget(_G, "INVSLOT_MAINHAND")) or 16

-- The sound channels WoW: Forever actually has (checked against Config.wtf and its logs).
-- While fishing: general and effects at 100 %, everything else silenced. On exit every value returns.
local AUDIO = {
	{ key = "volume",   cvar = "Sound_MasterVolume",   percent = 100 },
	{ key = "sfx",      cvar = "Sound_SFXVolume",      percent = 100 },
	{ key = "music",    cvar = "Sound_MusicVolume",    percent = 0 },
	{ key = "ambience", cvar = "Sound_AmbienceVolume", percent = 0 },
	{ key = "dialog",   cvar = "Sound_DialogVolume",   percent = 0 },
	{ key = "dialogOn", cvar = "Sound_EnableDialog",   percent = 0 },
}

local defaults = {
	enabled        = false,
	restoreOnCatch = true,
	doubleClick    = true,
	autoEquip      = true,
	weaponToRestore = nil,   -- the weapon we took off, to give back afterwards
	map            = { hide = false, angle = 220 },
	window         = { closedByUser = false },
}

local resumeAfterCombat, resumeQuiet = false, false
local intervalTimer, idleTimer
local minimapButton = nil

AnglersRest_ApplyIconState = function() end
AnglersRest_RefreshPanel = function() end

-- utilities -------------------------------------------------------------------

local function GetCVar1(name)
	return C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(name)
end

local function SetCVar1(name, value)
	if C_CVar and C_CVar.SetCVar then
		C_CVar.SetCVar(name, tostring(value))
	end
end

-- The client can hand back a "secret" value: reading is fine, arithmetic is not. Non-numbers become nil.
local function Number(v, fallback)
	local t = type(v)
	if t ~= "number" and t ~= "string" then return fallback end
	local ok, n = pcall(tonumber, v)
	if not ok or n == nil then return fallback end
	return n
end

local function CvarFor(entry)
	return entry.cvar
end

local function Announce(msg)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffA67D45Angler's Rest|r: " .. tostring(msg))
	end
end

function AnglersRest_EnsureDB()
	AnglersRestDB = AnglersRestDB or {}
	local db = AnglersRestDB
	for k, v in pairs(defaults) do
		if type(v) ~= "table" then
			if db[k] == nil then db[k] = v end
		else
			db[k] = db[k] or {}
			for k2, v2 in pairs(v) do
				if db[k][k2] == nil then db[k][k2] = v2 end
			end
		end
	end
	return db
end
local EnsureDB = AnglersRest_EnsureDB

function AnglersRest_Channels()
	return AUDIO
end
AnglersRest_AvailableChannels = AnglersRest_Channels

-- the name of a channel, in the client's language (UI.lua supplies the words)
function AnglersRest_ChannelLabel(entry)
	return entry.cvar
end

-- fishing ---------------------------------------------------------------------

local function IsCastingFishing()
	if C_Spell and C_Spell.IsCurrentSpell then
		return C_Spell.IsCurrentSpell(FISHING_SPELL_ID)
	end
	local name = UnitChannelInfo("player") or UnitCastingInfo("player")
	return name == FISHING_SPELL_NAME
end

local function ItemIsFishingPole(itemID)
	if not itemID or not C_Item or not C_Item.GetItemInfoInstant then return false end
	local ok, _, _, _, _, _, classID, subclassID = pcall(C_Item.GetItemInfoInstant, itemID)
	if not ok then return false end
	if classID == nil then return true end -- unknown data: don't block the cast
	return classID == 2 and subclassID == 20 -- Weapon / Fishing pole
end

local function MainHandID()
	local id = GetInventoryItemID and GetInventoryItemID("player", MAINHAND)
	if id then return id end
	local link = GetInventoryItemLink and GetInventoryItemLink("player", MAINHAND)
	return link and tonumber(link:match("item:(%d+)")) or nil
end

local function PoleInHand()
	return ItemIsFishingPole(MainHandID())
end

local lastCast = 0
local poleSeen = nil

function AnglersRest_Cast()
	-- nothing at all while the mode is off: no cast, no message
	if not EnsureDB().enabled then return end
	local now = GetTime()
	if now - lastCast < 0.4 then return end
	if InCombatLockdown() then return end
	if IsCastingFishing() then return end
	if not PoleInHand() then
		EquipPole(true)
		if not PoleInHand() then
			Announce(L("NO_POLE"))
			return
		end
	end
	lastCast = now
	CastSpellByID(FISHING_SPELL_ID)
end

-- The pole goes on the main hand when the mode starts; the old weapon comes back after --------

local function LearnPole()
	if PoleInHand() then poleSeen = MainHandID() end
end

-- The first pole found in the bags: bag 0 first, then the bag slots the client reports.
local function FindPoleInBags()
	local bags = NUM_BAG_SLOTS or 4
	for bag = 0, bags do
		local size = C_Container.GetContainerNumSlots(bag)
		for slot = 1, size do
			local id = C_Container.GetContainerItemID(bag, slot)
			if id and ItemIsFishingPole(id) then return id end
		end
	end
end

-- The old weapon comes back when the line comes in or the mode goes off.
function AnglersRest_GiveWeaponBack(quiet)
	local db = EnsureDB()
	local oldID = db.weaponToRestore
	db.weaponToRestore = nil
	if not oldID then return end
	if InCombatLockdown() then
		db.weaponToRestore = oldID -- after the fight
		return
	end
	EquipItemByName(oldID)
	if not quiet then
		Announce(L("EQUIPPED"):format(C_Item.GetItemNameByID(oldID)))
	end
end

local function EquipPole(quiet)
	local db = EnsureDB()
	if InCombatLockdown() then
		if not quiet then Announce(L("IN_COMBAT")) end
		return
	end
	if PoleInHand() then return end

	local pole = FindPoleInBags()
	if not pole then
		if not quiet then Announce(L("NO_POLE")) end
		return
	end

	local oldID = MainHandID()
	if oldID and not ItemIsFishingPole(oldID) then
		db.weaponToRestore = oldID
	end
	EquipItemByName(pole)
	if not quiet then
		Announce(L("EQUIPPED"):format(C_Item.GetItemNameByID(pole)))
	end
end
-- audio -----------------------------------------------------------------------

-- every channel the client has, saved as "cvar -> value" right before touching anything
local function ReadAudio()
	local saved = {}
	for _, entry in ipairs(AUDIO) do
		saved[entry.cvar] = Number(GetCVar1(entry.cvar))
	end
	return saved
end

local function RestoreAudio(saved)
	if type(saved) ~= "table" then return end
	for name, value in pairs(saved) do
		if value ~= nil then SetCVar1(name, value) end
	end
end

local function StopTimers()
	if intervalTimer then intervalTimer:Cancel(); intervalTimer = nil end
	if idleTimer then idleTimer:Cancel(); idleTimer = nil end
end

local function ApplyAudio()
	for _, entry in ipairs(AUDIO) do
		local value = entry.percent / 100
		if entry.key == "music" and value > 0 then
			-- music raised in one go from 0 often stays silent: drop it and bring it up after
			SetCVar1(entry.cvar, 0)
			C_Timer.After(0.1, function()
				if EnsureDB().enabled then SetCVar1(entry.cvar, value) end
			end)
		else
			SetCVar1(entry.cvar, value)
		end
	end
end
function AnglersRest_Activate(silent)
	local db = EnsureDB()
	if InCombatLockdown and InCombatLockdown() then
		resumeAfterCombat, resumeQuiet = true, silent
		if not silent then Announce(L("IN_COMBAT")) end
		return
	end
	if not db.snapshot then
		db.snapshot = ReadAudio()
	end
	db.enabled = true
	ApplyAudio()
	EquipPole(silent)

	AnglersRest_ApplyIconState()
	AnglersRest_RefreshPanel()
	if not silent then
		Announce("|cff7CE07C" .. L("MODE_ON") .. "|r")
	end
end

function AnglersRest_Deactivate(silent)
	local db = EnsureDB()
	StopTimers()
	if db.snapshot then
		RestoreAudio(db.snapshot)
		db.snapshot = nil
	end
	db.enabled = false
	AnglersRest_GiveWeaponBack(true)
	AnglersRest_ApplyIconState()
	AnglersRest_RefreshPanel()
	if not silent then
		Announce("|cffff9a6a" .. L("MODE_OFF") .. "|r")
	end
end

function AnglersRest_Toggle()
	if EnsureDB().enabled then
		AnglersRest_Deactivate()
	else
		AnglersRest_Activate()
	end
end

local function KeepHeld()
	local db = EnsureDB()
	if not db.enabled or not db.snapshot then return end
	ApplyAudio()
end

function AnglersRest_Catch()
	local db = EnsureDB()
	if not db.enabled or not db.restoreOnCatch then return end
	-- quiet, like the switch itself: the sound and the weapon just come back
	AnglersRest_Deactivate(true)
	-- the weapon waits for your answer: a pop-up, so it never grabs your hand mid-fight
	if db.weaponToRestore and AnglersRest_ShowWeaponPrompt then
		AnglersRest_ShowWeaponPrompt(db.weaponToRestore)
	end
end

local function StartIdleTimer()
	if idleTimer then idleTimer:Cancel() end
	idleTimer = C_Timer.NewTimer(30, function()
		idleTimer = nil
		AnglersRest_Deactivate(true)
	end)
end

-- panel hooks -----------------------------------------------------------------

function AnglersRest_SetDB(key, value)
	EnsureDB()[key] = value
	AnglersRest_RefreshPanel()
end

function AnglersRest_GetAudioSnapshot()
	return EnsureDB().snapshot
end

function AnglersRest_SetMinimapShown(shown)
	EnsureDB().map.hide = not shown
	minimapButton:SetShown(shown)
	AnglersRest_RefreshPanel()
end

-- double right-click on the world -------------------------------------------------



-- minimap icon ----------------------------------------------------------------

local function CreateMinimapButton()
	local db = EnsureDB()

	local btn = CreateFrame("Button", "AnglersRestMinimapButton", Minimap, "BackdropTemplate")
	btn:SetSize(30, 30)
	btn:SetFrameStrata("MEDIUM")
	btn:SetClampedToScreen(true)
	btn:EnableMouse(true)
	btn:RegisterForDrag("LeftButton")
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local edge = CreateFrame("Frame", "AnglersRestMinimapEdge", btn, "BackdropTemplate")
	edge:SetAllPoints()
	edge:SetBackdrop({ edgeFile = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Borders\\FlareUI-Thin.tga", edgeSize = 8 })
	edge:SetBackdropBorderColor(0.55, 0.42, 0.24, 1)
	btn.edge = edge

	local icon = btn:CreateTexture("AnglersRestMinimapIcon", "ARTWORK")
	icon:SetTexture(ICON_TEXTURE)
	icon:SetPoint("TOPLEFT", 5, -5)
	icon:SetPoint("BOTTOMRIGHT", -5, 5)
	btn.iconTexture = icon
	minimapButton = btn

	local function PositionFromCursor()
		local mx, my = Minimap:GetCenter()
		if not mx then return end
		local px, py = GetCursorPosition()
		local scale = Minimap:GetEffectiveScale()
		px, py = px / scale, py / scale
		local angle = math.deg(math.atan2(py - my, px - mx))
		local radius = 80
		btn:ClearAllPoints()
		btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(math.rad(angle)) * radius, math.sin(math.rad(angle)) * radius)
		return angle
	end

	btn:SetScript("OnDragStart", function()
		btn.dragging = true
		btn:SetScript("OnUpdate", PositionFromCursor)
	end)
	btn:SetScript("OnDragStop", function()
		btn.dragging = nil
		btn:SetScript("OnUpdate", nil)
		EnsureDB().map.angle = PositionFromCursor()
	end)
	btn:SetScript("OnClick", function(_, button)
		if btn.dragging then return end
		if button == "LeftButton" then
			AnglersRest_Toggle()
		else
			AnglersRest_ToggleWindow()
		end
	end)
	btn:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:AddLine("|cffA67D45" .. L("TITLE") .. "|r")
		GameTooltip:AddLine(EnsureDB().enabled and ("|cff7CE07C" .. L("MODE_ON") .. "|r") or L("MODE_OFF"), 1, 1, 1)
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(L("HOVER_LEFT"), 1, 1, 1)
		GameTooltip:AddLine(L("HOVER_RIGHT"), 1, 1, 1)
		GameTooltip:Show()
	end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local angle = db.map.angle or 220
	btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(math.rad(angle)) * 80, math.sin(math.rad(angle)) * 80)
	btn:SetShown(not db.map.hide)
end

local function PaintIcon()
	if not minimapButton then return end
	local on = EnsureDB().enabled
	local c = on and { 1, 0.84, 0.5 } or { 0.55, 0.42, 0.24 }
	minimapButton.edge:SetBackdropBorderColor(c[1], c[2], c[3], 1)
	minimapButton.iconTexture:SetDesaturated(not on)
end
AnglersRest_ApplyIconState = PaintIcon

-- Double right-click on the world -------------------------------------------------
-- One right click is only counted when nothing turns the camera (a short click that barely moves);
-- two of those within 0.25 s cast. A right click the game uses for the camera, or a click this addon
-- answers, never casts anything nor says a word.

local CLICK_QUICK, CLICK_TRAVEL = 0.25, 12
local press, lastTap = nil, 0
local function CursorOnWorld()
	local foci = GetMouseFoci and GetMouseFoci()
	if foci then
		for _, focus in ipairs(foci) do
			if focus ~= WorldFrame then return false end
		end
		return true
	end
	local focus = GetMouseFocus and GetMouseFocus()
	return focus == nil or focus == WorldFrame
end

-- The mouse events can hand the button as its name or as a number (1, 2, 3 for left, right, middle).
local function IsRight(btn)
	return btn == "RightButton" or btn == 2 or tostring(btn) == "2"
end

local function OnMouseDown(btn)
	if not IsRight(btn) then press = nil; return end
	press = nil
	-- off: the mouse is not watched at all
	if not EnsureDB().enabled then return end
	if not EnsureDB().doubleClick then return end
	if InCombatLockdown and InCombatLockdown() then return end
	if IsModifierKeyDown and IsModifierKeyDown() then return end
	if not CursorOnWorld() or UnitExists("mouseover") then return end
	local x, y = GetCursorPosition()
	press = { at = GetTime(), x = x, y = y }
end

local function OnMouseUp(btn)
	if not IsRight(btn) then return end
	local p = press
	press = nil
	if not p or GetTime() - p.at > CLICK_QUICK then return end
	local x, y = GetCursorPosition()
	if (x - p.x) ^ 2 + (y - p.y) ^ 2 > CLICK_TRAVEL ^ 2 then return end

	local now = GetTime()
	lastTap = now
	AnglersRest_Cast()
end
-- slash command ------------------------------------------------------------------
-- One command, for what the mouse cannot reach: the window is under the right click on the icon.

SLASH_ANGLERSREST1 = "/ar"
SlashCmdList["ANGLERSREST"] = function()
	AnglersRest_ToggleWindow()
end

-- events --------------------------------------------------------------------------

local events = CreateFrame("Frame", "AnglersRestEvents")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
events:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
events:RegisterEvent("GLOBAL_MOUSE_DOWN")
events:RegisterEvent("GLOBAL_MOUSE_UP")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, arg1, arg2, spellID)
	if event == "GLOBAL_MOUSE_DOWN" then
		OnMouseDown(arg1)
		return
	elseif event == "GLOBAL_MOUSE_UP" then
		OnMouseUp(arg1)
		return
	elseif event == "PLAYER_REGEN_DISABLED" then
		press = nil
		return
	elseif event == "PLAYER_REGEN_ENABLED" then
		local db = EnsureDB()
		-- in OFF the addon lets go of everything it took, without a word
		if db.weaponToRestore then AnglersRest_GiveWeaponBack(true) end
		if resumeAfterCombat then
			resumeAfterCombat = false
			AnglersRest_Activate(resumeQuiet)
		end
		return
	elseif event == "PLAYER_EQUIPMENT_CHANGED" then
		local db = EnsureDB()
		if arg1 == MAINHAND then
			local id = MainHandID()
			if id and ItemIsFishingPole(id) then
				poleSeen = id
			elseif db.weaponToRestore and id ~= db.weaponToRestore then
				-- the player chose another weapon by hand: leave their choice alone
				db.weaponToRestore = nil
			end
		end
		return
	end

	-- the line
	local name = spellID and C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(spellID)
	local isFishing = name == FISHING_SPELL_NAME or spellID == FISHING_SPELL_ID
	if not isFishing then return end

	if event == "UNIT_SPELLCAST_CHANNEL_START" then
		-- the mode only follows the line while it is on: in OFF this addon does nothing at all
		if EnsureDB().enabled then
			if idleTimer then idleTimer:Cancel(); idleTimer = nil end
			if not intervalTimer and C_Timer and C_Timer.NewTicker then
				intervalTimer = C_Timer.NewTicker(0.5, KeepHeld)
			end
		end
	elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
		if intervalTimer then intervalTimer:Cancel(); intervalTimer = nil end
		if IsCastingFishing() then return end
		AnglersRest_Catch()
		if EnsureDB().enabled then StartIdleTimer() end
	end
end)

-- load ----------------------------------------------------------------------------

local loader = CreateFrame("Frame", "AnglersRestLoader")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:RegisterEvent("PLAYER_LOGOUT")
loader:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == ADDON_NAME then
			EnsureDB()
			if AnglersRest_BuildUI then AnglersRest_BuildUI() end
		end
	elseif event == "PLAYER_LOGIN" then
		local db = EnsureDB()
		if db.snapshot then
			-- closed the game mid-session: give back what we took before anything else
			RestoreAudio(db.snapshot)
			db.snapshot = nil
			db.enabled = false
			Announce(L("RESTORED_LOGIN"))
		end
		LearnPole()
		CreateMinimapButton()
		AnglersRest_ApplyIconState()
		if AnglersRest_ApplyWindowPosition then AnglersRest_ApplyWindowPosition() end
		AnglersRest_RefreshPanel()
		-- the panel opens with the game, on or off, unless it was closed on purpose
		if AnglersRest_OpenOnLoad then AnglersRest_OpenOnLoad() end
	elseif event == "PLAYER_LOGOUT" then
		local db = AnglersRestDB
		if db and db.snapshot then
			-- the settings go back (by default); the weapon is left alone at logout
			RestoreAudio(db.snapshot)
			db.snapshot = nil
			db.enabled = false
		end
	end
end)
