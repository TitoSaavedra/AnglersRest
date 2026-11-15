-- Angler's Rest: fishing audio mode + a fishing panel in the FlareUI style.
-- The minimap icon is drawn by LibDBIcon when another addon ships it, otherwise by this addon.

local ADDON_NAME = ...

local FISHING_SPELL_ID = 7620
local FISHING_SPELL_NAME = (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(FISHING_SPELL_ID)) or "Fishing"
local ICON_TEXTURE = 135123 -- Interface\Icons\Trade_Fishing
local MAINHAND = (INVSLOT_MAINHAND and rawget(_G, "INVSLOT_MAINHAND")) or 16

-- Every sound channel the game exposes, with the CVar that really holds the value in this client.
-- Whichever of the two names the client has is read; the value found is written back on restore.
-- Every sound channel this client really has. A channel that is not in its CVar list is left out
-- instead of showing a switch that would do nothing.
local AUDIO = {
	{ key = "master",   label = "General",       cvar = { "Sound_MasterVolume" },       kind = "percent" },
	{ key = "sfx",      label = "Effects",       cvar = { "Sound_SFXVolume" },          kind = "percent" },
	{ key = "music",    label = "Music",         cvar = { "Sound_MusicVolume" },        kind = "percent" },
	{ key = "ambience", label = "Ambience",      cvar = { "Sound_AmbienceVolume" },     kind = "percent" },
	{ key = "dialog",   label = "Dialogue",      cvar = { "Sound_DialogVolume" },       kind = "percent" },
	{ key = "sfxOn",    label = "Effects on",    cvar = { "Sound_EnableSFX" },          kind = "switch" },
	{ key = "musicOn",  label = "Music on",      cvar = { "Sound_EnableMusic" },        kind = "switch", optional = true },
	{ key = "ambientOn",label = "Ambience on",   cvar = { "Sound_EnableAmbience" },     kind = "switch", optional = true },
	{ key = "dialogOn", label = "Dialogue on",   cvar = { "Sound_EnableDialog" },       kind = "switch", optional = true },
	{ key = "allOn",    label = "All sound",     cvar = { "Sound_EnableAllSound" },     kind = "switch", optional = true },
}

-- The channels this client actually has (an optional one is skipped when its CVar is missing)
local function AvailableAudio()
	local list = {}
	for _, entry in ipairs(AUDIO) do
		local present = C_CVar and C_CVar.GetCVar and C_CVar.GetCVar(entry.cvar[1]) or nil
		if not entry.optional or present ~= nil then
			list[#list + 1] = entry
		end
	end
	return list
end

local defaults = {
	enabled       = false,
	-- the value each channel takes while fishing
	volume        = 100,
	sfx           = 100,
	music         = 100,
	ambience      = 100,
	dialog        = 100,
	-- per-channel off switches while fishing: percent channels read 0, the others a channel switch
	off           = { music = false, ambience = true, dialog = true },
	restoreOnCatch = true,
	doubleClick   = true,
	-- the pole: put it on when fishing starts, give the old weapon back when it ends
	autoEquip     = true,
	weaponToRestore = nil,   -- itemID kept only if we took the pole off again ourselves
	weaponLocked  = false,   -- the player changed weapons by hand: don't fight them
	minimap       = { hide = false, angle = 220 },
	window        = { point = "CENTER", x = 0, y = 0 },
}

local resumeAfterCombat, resumeQuiet = false, false
local intervalTimer, idleTimer
local minimapButton, buttonMode = nil, "custom"

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
	for _, name in ipairs(entry.cvar) do
		if GetCVar1(name) ~= nil then return name end
	end
	return entry.cvar[1]
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
	return AvailableAudio()
end
AnglersRest_AvailableChannels = AnglersRest_Channels

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
local equipAfterSwap = false

function AnglersRest_Cast()
	-- nothing at all while the mode is off: no cast, no message
	if not EnsureDB().enabled then return end
	local now = GetTime()
	if now - lastCast < 0.4 then return end
	if InCombatLockdown and InCombatLockdown() then return end
	if IsCastingFishing() then return end
	if not PoleInHand() then
		-- no pole in hand: put yours on first (if the option is on) and cast once it is there
		if EquipPole(true) and not PoleInHand() then
			equipAfterSwap = true
			lastCast = now
			return
		end
		if not PoleInHand() then
			Announce("No fishing pole in your bags.")
			return
		end
	end
	lastCast = now
	CastSpellByID(FISHING_SPELL_ID)
end

-- The pole: swap it in on the main hand, swap the old weapon back after ----------------------
-- On this client the fishing pole can be equipped from addon code (a normal item, not a weapon a
-- warrior or rogue must be holding through combat), so no secure button is needed.

local poleSeen = nil      -- itemID of the pole currently known to be worn

-- Frames with a name: this client does not take a nameless CreateFrame.
local function LearnPole()
	local id = MainHandID()
	if id and ItemIsFishingPole(id) then
		poleSeen = id
	end
	return poleSeen
end

-- The first pole found in the bags.
local function FindPoleInBags()
	local bags = (NUM_BAG_SLOTS or 4) + (NUM_BANKBAGSLOTS or 0)
	for bag = 0, bags do
		local size = (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag))
			or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
		for slot = 1, size do
			local id
			if C_Container and C_Container.GetContainerItemID then
				id = C_Container.GetContainerItemID(bag, slot)
			elseif GetContainerItemID then
				id = GetContainerItemID(bag, slot)
			end
			if id and ItemIsFishingPole(id) then return id end
		end
	end
	return nil
end

-- The old weapon comes back when the line comes in, the mode goes off, or the game closes.
function AnglersRest_GiveWeaponBack(quiet)
	local db = EnsureDB()
	local oldID = db.weaponToRestore
	db.weaponToRestore = nil
	db.weaponLocked = false
	if not oldID then return end
	if InCombatLockdown and InCombatLockdown() then
		db.weaponToRestore = oldID -- try again after the fight
		return
	end
	if not PoleInHand() then return end -- the player already changed their main hand
	EquipItemByName(oldID)
	if not quiet then
		local name = GetItemInfo and select(1, GetItemInfo(oldID))
		Announce("Your " .. (name or "weapon") .. " is back on.")
	end
end

local function EquipPole(quiet)
	local db = EnsureDB()
	if not db.autoEquip then return false end
	if InCombatLockdown and InCombatLockdown() then
		if not quiet then Announce("Can't change weapons in combat.") end
		return false
	end
	if PoleInHand() then LearnPole(); return true end
	local pole = LearnPole() or FindPoleInBags()
	if not pole then
		if not quiet then Announce("No fishing pole in your bags.") end
		return false
	end
	local oldID = MainHandID()
	if oldID and oldID ~= pole and not ItemIsFishingPole(oldID) then
		db.weaponToRestore = oldID
	end
	db.weaponLocked = false
	EquipItemByName(pole)
	if not quiet then
		local name = GetItemInfo and select(1, GetItemInfo(pole))
		Announce("Equipped your " .. (name or "fishing pole") .. ".")
	end
	return true
end

-- audio -----------------------------------------------------------------------

local function ReadAudio()
	local saved = { values = {}, at = time and time() or 0 }
	for _, entry in ipairs(AvailableAudio()) do
		local name = CvarFor(entry)
		saved.values[entry.key] = { cvar = name, value = Number(GetCVar1(name)) }
	end
	return saved
end

local function RestoreAudio(saved)
	if type(saved) ~= "table" or type(saved.values) ~= "table" then return end
	for _, entry in ipairs(AvailableAudio()) do
		local rec = saved.values[entry.key]
		if type(rec) == "table" and rec.cvar and rec.value ~= nil then
			SetCVar1(rec.cvar, rec.value)
		end
	end
end

local function StopTimers()
	if intervalTimer then intervalTimer:Cancel(); intervalTimer = nil end
	if idleTimer then idleTimer:Cancel(); idleTimer = nil end
end

local function ApplyAudio(db)
	local offline = db.off or {}
	for _, entry in ipairs(AvailableAudio()) do
		local name = CvarFor(entry)
		local off = offline[entry.key]
		if entry.kind == "switch" then
			SetCVar1(name, off and 0 or 1)
		elseif entry.key == "master" then
			-- the master is never silenced from the panel: restoring it is its whole point
			SetCVar1(name, (off and 0 or (db.volume or 100)) / 100)
		else
			local value = db[entry.key] or 100
			if entry.key == "music" and not off then
				-- WoW often ignores a music slider raised in one go from a saved low value:
				-- drop it to 0 and bring it up a moment later
				SetCVar1(name, 0)
				if C_Timer and C_Timer.After then
					C_Timer.After(0.1, function()
						if EnsureDB().enabled then SetCVar1(name, value / 100) end
					end)
				else
					SetCVar1(name, value / 100)
				end
			else
				SetCVar1(name, off and 0 or value / 100)
			end
		end
	end
end

function AnglersRest_Activate(silent)
	local db = EnsureDB()
	if InCombatLockdown and InCombatLockdown() then
		resumeAfterCombat, resumeQuiet = true, silent
		if not silent then Announce("Can't touch the sound in combat. Switching when the fight ends.") end
		return
	end
	if not db.snapshot then
		db.snapshot = ReadAudio()
	end
	db.enabled = true
	ApplyAudio(db)
	EquipPole(silent)

	AnglersRest_ApplyIconState()
	AnglersRest_RefreshPanel()
	if not silent then
		Announce("|cff7CE07CFishing mode on|r - " .. describeAudio(db) .. ".")
	end
end

function describeAudio(db)
	local parts = { "general " .. (db.volume or 100) .. "%", "effects " .. (db.sfx or 100) .. "%", "music " .. (db.music or 100) .. "%" }
	local muted = {}
	for _, entry in ipairs(AvailableAudio()) do
		if db.off[entry.key] and entry.key ~= "master" then muted[#muted + 1] = string.lower(entry.label) end
	end
	if #muted > 0 then parts[#parts + 1] = "off: " .. table.concat(muted, ", ") end
	return table.concat(parts, ", ")
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
		Announce("|cffff9a6aFishing mode off|r - your own sound settings are back.")
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
	ApplyAudio(db)
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

function AnglersRest_SetChannel(key, value)
	local db = EnsureDB()
	db[key] = value
	if db.enabled and db.snapshot then ApplyAudio(db) end
	AnglersRest_RefreshPanel()
end

function AnglersRest_SetChannelOff(key, off)
	local db = EnsureDB()
	db.off[key] = off and true or false
	if db.enabled and db.snapshot then ApplyAudio(db) end
	AnglersRest_RefreshPanel()
end

function AnglersRest_GetAudioSnapshot()
	return EnsureDB().snapshot
end

function AnglersRest_SetMinimapShown(shown)
	local db = EnsureDB()
	db.minimap.hide = not shown
	if minimapButton then
		if buttonMode == "lib" then
			local lib = LibStub and LibStub("LibDBIcon-1.0", true)
			if lib then
				if shown then lib:Show(ADDON_NAME) else lib:Hide(ADDON_NAME) end
			end
		else
			minimapButton:SetShown(shown)
		end
	end
	AnglersRest_RefreshPanel()
end

function AnglersRest_ResetWindow()
	local db = EnsureDB()
	db.window.point, db.window.x, db.window.y = "CENTER", 0, 0
	-- the scale is left as it is: forgetting it would make the window jump back to full size
	if AnglersRest_ApplyWindowPosition then AnglersRest_ApplyWindowPosition() end
end

function AnglersRest_EquipPoleNow()
	EquipPole(false)
	AnglersRest_RefreshPanel()
end

function AnglersRest_GiveWeaponBackNow()
	AnglersRest_GiveWeaponBack(false)
	AnglersRest_RefreshPanel()
end

-- minimap icon ----------------------------------------------------------------

local function BuildMinimapIcon(parent)
	local border = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Borders\\FlareUI-Thin.tga"
	local btn = CreateFrame("Button", "AnglersRestMinimapButton", parent or Minimap, "BackdropTemplate")
	btn:SetSize(30, 30)
	btn:SetFrameStrata("MEDIUM")
	btn:SetFrameLevel(8)
	btn:SetClampedToScreen(true)
	btn:EnableMouse(true)
	btn:RegisterForDrag("LeftButton")
	btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local edge = CreateFrame("Frame", "AnglersRestMinimapEdge", btn, "BackdropTemplate")
	edge:SetAllPoints()
	edge:SetFrameLevel(btn:GetFrameLevel() + 1)
	edge:SetBackdrop({ edgeFile = border, edgeSize = 8 })
	edge:SetBackdropBorderColor(0.55, 0.42, 0.24, 1)
	btn.edge = edge

	local icon = btn:CreateTexture(nil, "ARTWORK")
	icon:SetTexture(ICON_TEXTURE)
	icon:SetPoint("TOPLEFT", 5, -5)
	icon:SetPoint("BOTTOMRIGHT", -5, 5)
	btn.iconTexture = icon
	return btn
end

local function IconTooltip(parent)
	GameTooltip:SetOwner(parent, "ANCHOR_LEFT")
	GameTooltip:AddLine("|cffA67D45Angler's Rest|r")
	GameTooltip:AddLine(EnsureDB().enabled and "|cff7CE07CFishing mode is on|r" or "Fishing mode is off", 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("|cffA67D45Left click|r sound on / off", 1, 1, 1)
	GameTooltip:AddLine("|cffA67D45Right click|r the panel", 1, 1, 1)
	GameTooltip:AddLine("|cffA67D45Drag|r move it around the minimap", 1, 1, 1)
	GameTooltip:Show()
end

local function CreateMinimapButton()
	local db = EnsureDB()

	local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
	local iconLib = LibStub and LibStub("LibDBIcon-1.0", true)
	if ldb and iconLib then
		local data = ldb:NewDataObject(ADDON_NAME, {
			type = "launcher",
			icon = ICON_TEXTURE,
			label = "Angler's Rest",
			OnClick = function(_, button)
				if button == "LeftButton" then
					AnglersRest_Toggle()
				else
					AnglersRest_ToggleWindow()
				end
			end,
			OnTooltipShow = function(tip)
				tip:AddLine("|cffA67D45Angler's Rest|r")
				tip:AddLine(EnsureDB().enabled and "|cff7CE07CFishing mode is on|r" or "Fishing mode is off")
			end,
		})
		iconLib:Register(ADDON_NAME, data, db.minimap)
		buttonMode = "lib"
		return
	end

	local btn = BuildMinimapIcon(Minimap)
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
		EnsureDB().minimap.angle = PositionFromCursor()
	end)
	btn:SetScript("OnClick", function(_, button)
		if btn.dragging then return end
		if button == "LeftButton" then
			AnglersRest_Toggle()
		else
			AnglersRest_ToggleWindow()
		end
	end)
	btn:SetScript("OnEnter", function(self) IconTooltip(self) end)
	btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

	local angle = db.minimap.angle or 220
	btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(math.rad(angle)) * 80, math.sin(math.rad(angle)) * 80)
	btn:SetShown(not db.minimap.hide)
end

local function PaintIcon()
	if buttonMode ~= "custom" or not minimapButton then return end
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
-- slash commands ----------------------------------------------------------------

SLASH_ANGLERSREST1 = "/anglersrest"
SLASH_ANGLERSREST2 = "/ar"
SlashCmdList["ANGLERSREST"] = function(msg)
	msg = (msg or ""):lower():gsub("%s+", "")
	if msg == "on" then
		AnglersRest_Activate()
	elseif msg == "off" then
		AnglersRest_Deactivate()
	elseif msg == "cast" then
		AnglersRest_Cast()
	elseif msg == "ui" or msg == "window" then
		AnglersRest_ToggleWindow()
	elseif msg == "reset" then
		AnglersRest_ResetWindow()
	elseif msg == "pole" then
		AnglersRest_EquipPoleNow()
	else
		AnglersRest_Toggle()
	end
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
				-- a cast that was waiting for the pole to be on: go
				if equipAfterSwap then
					equipAfterSwap = false
					C_Timer.After(0.1, function() AnglersRest_Cast() end)
				end
			elseif db.weaponToRestore and id and id ~= db.weaponToRestore then
				-- the player chose another weapon by hand: leave their choice alone
				db.weaponToRestore = nil
				db.weaponLocked = true
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
			Announce("Your sound settings from the last fishing session are back.")
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
