--!strict
-- Sound effects. The rbxasset:// entries ship with the Roblox client (always work,
-- no upload needed). To upgrade any of them, upload audio on the Creator Dashboard
-- and replace the string with "rbxassetid://YOUR_ID".

return {
	Collect = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.6, speed = 1.2 },
	Recruit = { id = "rbxasset://sounds/snap.mp3", volume = 0.7, speed = 1 },
	StealGrab = { id = "rbxasset://sounds/unsheath.wav", volume = 0.8, speed = 0.9 },
	StealDone = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.8, speed = 0.7 },
	Caught = { id = "rbxasset://sounds/splat.mp3", volume = 0.8, speed = 1 },
	Punch = { id = "rbxasset://sounds/swordslash.mp3", volume = 0.6, speed = 1.1 },
	QuizWin = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.7, speed = 0.8 },
	Announce = { id = "rbxasset://sounds/snap.mp3", volume = 0.8, speed = 0.6 },
	UIClick = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.25, speed = 1.7 },
	-- action feedback: a swing you hear, a hit you feel
	PunchHit = { id = "rbxasset://sounds/splat.mp3", volume = 0.9, speed = 1.15 },
	Throw = { id = "rbxasset://sounds/unsheath.wav", volume = 0.5, speed = 1.7 },
	Impact = { id = "rbxasset://sounds/splat.mp3", volume = 0.7, speed = 1.4 },
	Bang = { id = "rbxasset://sounds/snap.mp3", volume = 1, speed = 0.45 },
}
