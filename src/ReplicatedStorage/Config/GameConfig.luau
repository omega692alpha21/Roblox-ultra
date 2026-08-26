--!strict
-- Central tuning knobs. Change numbers here, not in service code.

return {
	-- Plots / bases
	PlotCount = 8,
	BaseSlots = 6, -- default character slots per base
	ExtraSlotsPass = 2, -- added by the +2 Slots game pass
	SlotsPerRebirth = 1, -- extra slot per rebirth...
	MaxRebirthSlots = 4, -- ...capped at this many

	-- Conveyor
	ConveyorSpawnInterval = 3.5, -- seconds between character spawns
	ConveyorTravelTime = 28, -- seconds to cross the map
	ConveyorMaxAlive = 12, -- max characters on the belt at once

	-- Income
	IncomeTickSeconds = 1,
	StarterCash = 250,

	-- Stealing
	CarrySpeedMultiplier = 0.6, -- thief walkspeed while carrying
	StealDepositRadius = 6,

	-- Locks
	JoinGraceLockSeconds = 30,
	BaseLockSeconds = 60,
	LockSecondsPerRebirth = 10,
	LockCooldownSeconds = 90,
	ExtendedLockPassBonus = 30,

	-- Offline earnings
	OfflineEarningsRate = 0.35, -- fraction of live income/s earned while away
	OfflineEarningsCapHours = 2,
	OfflineEarningsCapHours2x = 4, -- with 2x Cash pass

	-- Speed pass
	SpeedPassBonus = 6, -- added walkspeed
	SprintBonus = 8, -- extra walkspeed while holding sprint

	-- School RPG layer
	ClassBellIntervalSeconds = 300, -- time between class bells
	ClassOpenSeconds = 60, -- window to get into class
	QuizQuestionCount = 3,
	QuizCashReward = 500, -- scaled by rebirth multiplier
	QuizRepReward = 15,
	QuizLuckBuffSeconds = 120,
	QuizLuckBuffMultiplier = 1.5,

	-- Fighting
	PunchCooldownSeconds = 0.6,
	PunchRange = 8,
	PunchKnockback = 40,
	RepPerThiefHit = 2,
	RepPerSteal = 10,

	-- Event flags (set for special weekends, no code changes needed)
	EventLuckMultiplier = 1, -- e.g. 2 for a "2x Luck Weekend"
	EventCashMultiplier = 1, -- e.g. 2 for a "2x Cash Hour"

	-- Secret Rush: recurring in-server hype window with boosted odds
	SecretRushMinInterval = 1080, -- seconds between rushes (min)
	SecretRushMaxInterval = 1560, -- (max)
	SecretRushDuration = 75,
	SecretRushLuckMult = 5,

	-- Bounty: the richest player in the server wears a crown; robbing them pays extra
	BountyStealAuraBonus = 15,

	-- Rico the Bully (NPC rival)
	RivalRaidMinSeconds = 100,
	RivalRaidMaxSeconds = 180,
	RivalWalkSpeed = 11,
	RivalEscapeReturnSeconds = 15,
	RivalFoilAura = 3,

	-- Campus coin pickups
	CoinValueMin = 25,
	CoinValueMax = 75,
	CoinRespawnMin = 45,
	CoinRespawnMax = 90,

	-- Misc
	AutosaveSeconds = 60,
	LeaderboardPushSeconds = 120,
	LeaderboardSize = 50,
}
