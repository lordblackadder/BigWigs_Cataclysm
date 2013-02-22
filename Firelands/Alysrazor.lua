--------------------------------------------------------------------------------
-- Module Declaration
--

local mod, CL = BigWigs:NewBoss("Alysrazor", 800, 194)
if not mod then return end
mod:RegisterEnableMob(52530, 53898, 54015, 53089) --Alysrazor, Voracious Hatchling, Majordomo Staghelm, Molten Feather

local woundTargets = mod:NewTargetList()
local meteorCount, moltCount, burnCount, initiateCount = 0, 0, 0, 0
local initiateTimes = {31, 31, 21, 21, 21}

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.claw_message = "%2$dx Claw on %1$s"
	L.fullpower_soon_message = "Full power soon!"
	L.halfpower_soon_message = "Stage 4 soon!"
	L.encounter_restart = "Here we go again..."
	L.no_stacks_message = "Dunno if you care, but you have no feathers"
	L.moonkin_message = "Stop pretending and get some real feathers"
	L.molt_bar = "Molt"

	L.meteor = "Meteor"
	L.meteor_desc = "Warn when a Molten Meteor is summoned."
	L.meteor_icon = 100761
	L.meteor_message = "Meteor!"

	L.stage_message = "Stage %d"
	L.kill_message = "It's now or never - Kill her!"
	L.engage_message = "Alysrazor engaged - Stage 2 in ~%d min"

	L.worm_emote = "Fiery Lava Worms erupt from the ground!"
	L.phase2_soon_emote = "Alysrazor begins to fly in a rapid circle!"

	L.flight = "Flight Assist"
	L.flight_desc = "Show a bar with the duration of 'Wings of Flame' on you, ideally used with the Super Emphasize feature."
	L.flight_icon = 98619

	L.initiate = "Initiate Spawn"
	L.initiate_desc = "Show timer bars for initiate spawns."
	L.initiate_icon = 97062
	L.initiate_both = "Both Initiates"
	L.initiate_west = "West Initiate"
	L.initiate_east = "East Initiate"

	L.eggs, L.eggs_desc = EJ_GetSectionInfo(2836)
	L.eggs_icon = "inv_trinket_firelands_02"
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions()
	return {
		99362, 100024, 97128, 99464, "flight", "initiate", "eggs",
		99816,
		99432,
		99844, 99925,
		{100744, "FLASH"}, "meteor",
		"bosskill"
	}, {
		[99362] = -2820, --Stage 1: Flight
		[99816] = -2821, --Stage 2: Tornadoes
		[99432] = -2822, --Stage 3: Burnout
		[99844] = -2823, --Stage 4: Re-Ignite
		[100744] = "heroic",
		bosskill = "general"
	}
end

function mod:OnBossEnable()
	-- General
	self:Log("SPELL_AURA_APPLIED", "Molting", 99464, 99465)
	self:Log("SPELL_AURA_APPLIED_DOSE", "BlazingClaw", 99844)
	self:Log("SPELL_AURA_APPLIED", "StartFlying", 98619)
	self:Log("SPELL_AURA_REMOVED", "StopFlying", 98619)

	-- Stage 1: Flight
	self:Log("SPELL_AURA_APPLIED", "Wound", 100024, 99308)
	self:Log("SPELL_AURA_APPLIED", "Tantrum", 99362)

	self:Emote("BuffCheck", L["worm_emote"])

	-- Stage 2: Tornadoes
	self:Emote("FieryTornado", L["phase2_soon_emote"])

	-- Stage 3: Burnout
	self:Log("SPELL_AURA_APPLIED", "Burnout", 99432)

	-- Stage 4: Re-Ignite
	self:Log("SPELL_AURA_REMOVED", "ReIgnite", 99432)

	-- Heroic only
	self:Log("SPELL_CAST_START", "Meteor", 100761, 102111)
	self:Log("SPELL_CAST_START", "Firestorm", 100744)
	self:Log("SPELL_AURA_REMOVED", "FirestormOver", 100744)

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")
	self:RegisterEvent("CHAT_MSG_MONSTER_YELL", "Initiates")

	self:Death("Win", 52530)
end

function mod:OnEngage()
	meteorCount, moltCount, burnCount, initiateCount = 0, 0, 0, 0
	wipe(initiateTimes)
	if self:Heroic() then
		initiateTimes = {22, 63, 21, 21, 40}
		self:Message(99816, L["engage_message"]:format(4), "Attention", "inv_misc_pheonixpet_01")
		self:Bar(99816, L["stage_message"]:format(2), 250, 99816)
		self:Bar(100744, 100744, 95, 100744) -- Firestorm
		self:Bar("meteor", "~"..L["meteor"], 30, 100761)
		self:Bar("eggs", "~"..self:SpellName(58542), 42, L["eggs_icon"]) -- Hatch Eggs
		self:DelayedMessage("eggs", 41.5, 58542, "Positive", L["eggs_icon"]) -- Hatch Eggs
	else
		initiateTimes = {31, 31, 21, 21, 21}
		self:Message(99816, L["engage_message"]:format(3), "Attention", "inv_misc_pheonixpet_01")
		self:Bar(99816, L["stage_message"]:format(2), 188.5, 99816)
		self:Bar(99464, L["molt_bar"], 12.5, 99464)
		--self:Bar("eggs", "~"..self:SpellName(58542), 42, L["eggs_icon"]) -- Hatch Eggs
		--self:DelayedMessage("eggs", 41.5, 58542, "Positive", L["eggs_icon"]) -- Hatch Eggs
	end
	self:Bar("initiate", L["initiate_both"], 27, 97062)
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do
	local flying = mod:SpellName(98619)
	local lastCheck = 0
	function mod:FlightCheck(unit)
		local _, _, _, _, _, _, expires = UnitBuff(unit, flying)
		if expires ~= lastCheck then
			lastCheck = expires
			self:Bar("flight", flying, expires-GetTime(), 98619)
		end
	end
	function mod:StartFlying(args)
		if UnitIsUnit(args.destName, "player") then
			self:Bar("flight", flying, 30, 98619)
			self:RegisterUnitEvent("UNIT_AURA", "FlightCheck", "player")
		end
	end
	function mod:StopFlying(args)
		if UnitIsUnit(args.destName, "player") then
			self:UnregisterUnitEvent("UNIT_AURA", "player")
		end
	end
end

do
	local initiateLocation = {L["initiate_both"], L["initiate_east"], L["initiate_west"], L["initiate_east"], L["initiate_west"]}
	local initiate = EJ_GetSectionInfo(2834)
	function mod:Initiates(_, _, unit)
		if unit == initiate then
			initiateCount = initiateCount + 1
			if initiateCount > 5 then return end
			self:Bar("initiate", initiateLocation[initiateCount], initiateTimes[initiateCount], 97062) --Night Elf head
		end
	end
end

do
	local feather = mod:SpellName(97128)
	local moonkin = mod:SpellName(24858)
	function mod:BuffCheck()
		local name = UnitBuff("player", feather)
		if not name then
			if UnitBuff("player", moonkin) then
				self:Message(97128, L["moonkin_message"], "Personal", 97128)
			else
				self:Message(97128, L["no_stacks_message"], "Personal", 97128)
			end
		end
	end
end

do
	local scheduled = nil
	local function woundWarn(spellName)
		mod:TargetMessage(100024, spellName, woundTargets, "Personal", 100024)
		scheduled = nil
	end
	function mod:Wound(args)
		if not UnitIsPlayer(args.destName) then return end --Avoid those shadowfiends
		woundTargets[#woundTargets + 1] = args.destName
		if not scheduled then
			scheduled = true
			self:ScheduleTimer(woundWarn, 0.5, args.spellName)
		end
	end
end

function mod:Tantrum(args)
	local target = UnitGUID("target")
	if not target or args.sourceGUID ~= target then return end
	-- Just warn for the tank
	self:Message(args.spellId, args.spellName, "Important", args.spellId)
end

-- don't need molting warning for heroic because molting happens at every firestorm
function mod:Molting(args)
	if not self:Heroic() then
		moltCount = moltCount + 1
		self:Message(99464, args.spellName, "Positive", args.spellId)
		if moltCount < 3 then
			self:Bar(99464, L["molt_bar"], 60, args.spellId)
		end
	end
end

function mod:Firestorm(args)
	self:Flash(args.spellId)
	self:Message(args.spellId, args.spellName, "Urgent", args.spellId, "Alert")
	self:Bar(args.spellId, CL["cast"]:format(args.spellName), 10, args.spellId)
end

function mod:FirestormOver(args)
	-- Only show a bar for next if we have seen less than 3 meteors
	if meteorCount < 3 then
		self:Bar(args.spellId, "~"..args.spellName, 72, args.spellId)
	end
	self:Bar("meteor", L["meteor"], meteorCount == 2 and 11.5 or 21.5, 100761)
	self:Bar("eggs", "~"..self:SpellName(58542), 22.5, L["eggs_icon"]) -- Hatch Eggs
	self:DelayedMessage("eggs", 22, 58542, "Positive", L["eggs_icon"]) -- Hatch Eggs
end

function mod:Meteor(args)
	self:Message("meteor", L["meteor_message"], "Attention", args.spellId, "Alarm")
	-- Only show a bar if this is the first or third meteor this phase
	meteorCount = meteorCount + 1
	if meteorCount == 1 or meteorCount == 3 then
		self:Bar("meteor", L["meteor"], 32, args.spellId)
	end
end

function mod:FieryTornado()
	self:BuffCheck()
	self:StopBar(100744) -- Firestorm
	local fieryTornado = self:SpellName(99816)
	self:Bar(99816, fieryTornado, 35, 99816)
	self:Message(99816, (L["stage_message"]:format(2))..": "..fieryTornado, "Important", 99816, "Alarm")
end

function mod:BlazingClaw(args)
	if args.amount > 4 then -- 50% extra fire and physical damage taken on tank
		self:TargetMessage(args.spellId, L["claw_message"], args.destName, "Urgent", args.spellId, "Info", args.amount)
	end
end

do
	local halfWarned = false
	local fullWarned = false

	-- Alysrazor crashes to the ground
	function mod:Burnout(args)
		self:Message(args.spellId, (L["stage_message"]:format(3))..": "..args.spellName, "Positive", args.spellId, "Alert")
		self:Bar(args.spellId, "~"..args.spellName, 33, args.spellId)
		halfWarned, fullWarned = false, false
		burnCount = burnCount + 1
		if burnCount < 3 then
			self:RegisterUnitEvent("UNIT_POWER_FREQUENT", nil, "boss1")
		end
	end

	function mod:UNIT_POWER_FREQUENT(unit)
		local power = UnitPower(unit, 0)
		if power > 40 and not halfWarned then
			self:Message(99925, L["halfpower_soon_message"], "Urgent", 99925)
			halfWarned = true
		elseif power > 80 and not fullWarned then
			self:Message(99925, L["fullpower_soon_message"], "Attention", 99925)
			fullWarned = true
		elseif power == 100 then
			self:Message(99925, (L["stage_message"]:format(1))..": "..(L["encounter_restart"]), "Positive", 99925, "Alert")
			self:UnregisterUnitEvent("UNIT_POWER_FREQUENT", unit)
			initiateCount = 0
			self:Bar("initiate", L["initiate_both"], 13.5, 97062)
			if self:Heroic() then
				meteorCount = 0
				self:Bar("meteor", L["meteor"], 19, 100761)
				self:Bar(100744, 100744, 72, 100744) -- Firestorm
				self:Bar(99816, L["stage_message"]:format(2), 225, 99816) -- Just adding 60s like OnEngage
				self:Bar("eggs", "~"..self:SpellName(58542), 30, L["eggs_icon"]) -- Hatch Eggs
				self:DelayedMessage("eggs", 29.5, 58542, "Positive", L["eggs_icon"]) -- Hatch Eggs
			else
				self:Bar(99816, L["stage_message"]:format(2), 165, 99816)
				moltCount = 1
				self:Bar(99464, L["molt_bar"], 55, 99464)
				--self:Bar("eggs", "~"..self:SpellName(58542), 22.5, L["eggs_icon"]) -- Hatch Eggs
				--self:DelayedMessage("eggs", 22, 58542, "Positive", L["eggs_icon"]) -- Hatch Eggs
			end
		end
	end

	function mod:ReIgnite()
		if burnCount < 3 then
			self:Message(99925, (L["stage_message"]:format(4))..": "..self:SpellName(99922), "Positive", 99922, "Alert")
			self:Bar(99925, 99925, 25, 99925) -- Full Power
		else
			self:Message(99925, L["kill_message"], "Positive", 99922, "Alert")
		end
		self:StopBar("~"..self:SpellName(99432))
	end
end

