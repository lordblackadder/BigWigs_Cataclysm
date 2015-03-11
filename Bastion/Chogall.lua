--------------------------------------------------------------------------------
-- Module Declaration
--

local mod = BigWigs:NewBoss("Cho'gall", 758, 167)
if not mod then return end
mod:RegisterEnableMob(43324)

--------------------------------------------------------------------------------
-- Locals
--

local worshipTargets = mod:NewTargetList()
local worshipCooldown = 24
local firstFury = 0
local counter = 1
local bigcount = 1
local oozecount = 1

--------------------------------------------------------------------------------
-- Localization
--

local L = mod:NewLocale("enUS", true)
if L then
	L.orders = "Stance changes"
	L.orders_desc = "Warning for when Cho'gall changes between Shadow/Flame Orders stances."

	L.worship_cooldown = "~Worship"

	L.adherent_bar = "Big add #%d"
	L.adherent_message = "Add %d incoming!"
	L.ooze_bar = "Ooze swarm %d"
	L.ooze_message = "Ooze swarm %d incoming!"

	L.tentacles_bar = "Tentacles spawn"
	L.tentacles_message = "Tentacle disco party!"

	L.sickness_message = "You feel terrible!"
	L.blaze_message = "Fire under YOU!"
	L.crash_say = "Crash"

	L.fury_message = "Fury!"
	L.first_fury_soon = "Fury Soon!"
	L.first_fury_message = "85% - Fury Begins!"

	L.unleashed_shadows = "Pulsing Shadow"

	L.phase2_message = "Phase 2!"
	L.phase2_soon = "Phase 2 soon!"
end
L = mod:GetLocale()

--------------------------------------------------------------------------------
-- Initialization
--

function mod:GetOptions(CL)
	return {
		91303, {81538, "FLASH"}, {81685, "FLASH", "ICON", "SAY"}, 81571, 82524, 81628, 82299,
		82630, 82414,
		"orders", {82235, "FLASH", "PROXIMITY"}, "berserk"
	}, {
		[91303] = CL.phase:format(1),
		[82630] = CL.phase:format(2),
		orders = "general",
	}
end

function mod:OnBossEnable()
	--normal
	self:Log("SPELL_CAST_SUCCESS", "Orders", 81171, 81556)
	self:Log("SPELL_AURA_APPLIED", "Worship", 91317)
	self:Log("SPELL_CAST_START", "SummonCorruptingAdherent", 81628)
	self:Log("SPELL_CAST_START", "FuryOfChogall", 82524)
	self:Log("SPELL_CAST_START", "FesterBlood", 82299)
	self:Log("SPELL_CAST_SUCCESS", "LastPhase", 82630)
	self:Log("SPELL_CAST_SUCCESS", "DarkenedCreations", 82414)
	self:Log("SPELL_CAST_SUCCESS", "CorruptingCrash", 81685)

	self:Log("SPELL_DAMAGE", "Blaze", 81538)
	self:Log("SPELL_MISSED", "Blaze", 81538)

	self:RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "CheckBossStatus")

	self:Death("Win", 43324)
end

function mod:OnEngage()
	bigcount = 1
	oozecount = 1
	self:Bar(91303, 11, L["worship_cooldown"])
	self:Berserk(600)
	worshipCooldown = 24 -- its not 40 sec till the 1st add
	firstFury = 0
	counter = 1

	self:RegisterUnitEvent("UNIT_AURA", "SicknessCheck", "player")
	self:RegisterUnitEvent("UNIT_HEALTH_FREQUENT", nil, "boss1")
end

--------------------------------------------------------------------------------
-- Event Handlers
--

do
	local last = 0
	function mod:Blaze(args)
		local time = GetTime()
		if (time - last) > 2 then
			last = time
			if self:Me(args.destGUID) then
				self:Message(args.spellId, "Personal", "Info", L["blaze_message"])
				self:Flash(args.spellId)
			end
		end
	end
end

do
	local function checkTarget(sGUID, spellId)
		local mobId = mod:GetUnitIdByGUID(sGUID)
		if mobId then
			local player = UnitName(mobId.."target")
			if not player then return end
			if UnitIsUnit("player", player) then
				mod:Say(spellId, L["crash_say"])
				mod:Flash(spellId)
			end
			mod:TargetMessage(spellId, player, "Urgent", "Long") -- Corrupting Crash
			if counter == 1 then
				mod:PrimaryIcon(spellId, player)
			else
				mod:SecondaryIcon(spellId, player)
			end
			if mod:Difficulty() == 6 then counter = counter + 1 end
		end
		if counter > 2 then counter = 1 end
	end
	function mod:CorruptingCrash(args)
		self:ScheduleTimer(checkTarget, 0.2, args.sourceGUID, args.spellId)
	end
end

do
	local sickness = mod:SpellName(82235)
	local prev = 0
	function mod:SicknessCheck(unit)
		local t = GetTime()
		if (t - prev) > 7 then
			local sick = UnitDebuff(unit, sickness)
			if sick then
				prev = t
				self:Message(82235, "Personal", "Long", L["sickness_message"], 81831)
				self:OpenProximity(82235, 5)
				self:Flash(82235)
			end
		end
	end
end

function mod:FuryOfChogall(args)
	if firstFury == 1 then
		self:Message(args.spellId, "Attention", nil, L["first_fury_message"])
		self:Bar(91303, 10, L["worship_cooldown"])
		worshipCooldown = 40
		firstFury = 2
	else
		self:Message(args.spellId, "Attention", nil, L["fury_message"])
	end
	self:Bar(args.spellId, 47)
end

function mod:Orders(args)
	self:Message("orders", "Urgent", nil, args.spellId)
	if args.spellId == 81556 then
		if self:Heroic() then
			self:Bar(81571, 24, L["unleashed_shadows"]) -- verified for 25man heroic
		else
			self:Bar(81571, 15, L["unleashed_shadows"]) -- verified for 10man normal
		end
	end
end

do
	local function nextAdd(spellId)
		mod:Bar(spellId, 50, L["adherent_bar"]:format(bigcount))
	end
	function mod:SummonCorruptingAdherent(args)
		self:Message(args.spellId, "Important", nil, L["adherent_message"]:format(bigcount))
		bigcount = bigcount + 1
		self:ScheduleTimer(nextAdd, 41, args.spellId)

		-- I assume its 40 sec from summon and the timer is not between two casts of Fester Blood
		self:Bar(82299, 40, L["ooze_bar"]:format(oozecount))
	end
end

function mod:FesterBlood(args)
	self:Message(args.spellId, "Attention", "Alert", L["ooze_message"]:format(oozecount))
	oozecount = oozecount + 1
end

function mod:UNIT_HEALTH_FREQUENT(unit)
	local hp = UnitHealth(unit) / UnitHealthMax(unit) * 100
	if firstFury == 0 and hp > 86 and hp < 89 then
		self:Message(82524, "Attention", nil, L["first_fury_soon"])
		firstFury = 1
	elseif hp < 30 then
		self:Message(82630, "Attention", "Info", L["phase2_soon"], false)
		self:UnregisterUnitEvent("UNIT_HEALTH_FREQUENT", unit)
	end
end

function mod:LastPhase(args)
	self:StopBar(L["adherent_bar"])
	self:StopBar(L["ooze_bar"])
	self:StopBar(L["worship_cooldown"])
	self:Message(args.spellId, "Positive", nil, L["phase2_message"])
	self:Bar(82414, 6, L["tentacles_bar"])
end

function mod:DarkenedCreations(args)
	self:Message(args.spellId, "Urgent", nil, L["tentacles_message"])
	self:Bar(args.spellId, 30, L["tentacles_bar"])
end

do
	local scheduled = nil
	local function worshipWarn(spellName)
		mod:TargetMessage(91303, worshipTargets, "Important", "Alarm", spellName, 91303, true)
		scheduled = nil
	end
	function mod:Worship(args)
		worshipTargets[#worshipTargets + 1] = args.destName
		if not scheduled then
			scheduled = true
			self:Bar(91303, worshipCooldown, L["worship_cooldown"])
			self:ScheduleTimer(worshipWarn, 0.3, args.spellName)
		end
	end
end

