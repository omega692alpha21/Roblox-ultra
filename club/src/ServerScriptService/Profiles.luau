--!strict
-- Member profiles: interests + looking-for tags, and the member directory.
-- The network is the product; this is its social graph.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Club.ClubConfig)
local Remotes = require(ReplicatedStorage.Club.ClubRemotes)
local Membership = require(script.Parent.Membership)

local Profiles = {}

export type Profile = { interests: { string }, lookingFor: { string } }

local cache: { [number]: Profile } = {}
local nameCache: { [number]: string } = {}

local function store(): DataStore?
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore("ClubProfiles")
	end)
	return ok and ds or nil
end

local function sanitizeTags(input: unknown, allowed: { string }): { string }
	local out: { string } = {}
	if typeof(input) ~= "table" then
		return out
	end
	for _, tag in input :: { any } do
		if typeof(tag) == "string" and table.find(allowed, tag) and not table.find(out, tag) and #out < 5 then
			table.insert(out, tag)
		end
	end
	return out
end

local function load(userId: number): Profile
	if cache[userId] then
		return cache[userId]
	end
	local profile: Profile = { interests = {}, lookingFor = {} }
	local ds = store()
	if ds then
		pcall(function()
			local saved = ds:GetAsync("u_" .. userId)
			if typeof(saved) == "table" then
				profile.interests = sanitizeTags((saved :: any).interests, Config.Interests)
				profile.lookingFor = sanitizeTags((saved :: any).lookingFor, Config.LookingFor)
			end
		end)
	end
	cache[userId] = profile
	return profile
end

local function displayName(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local name = "Member"
	pcall(function()
		name = Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = name
	return name
end

function Profiles.Init()
	Remotes.Get("SetProfile").OnServerEvent:Connect(function(player, interests, lookingFor)
		if not Membership.IsMember(player) then
			return
		end
		local profile: Profile = {
			interests = sanitizeTags(interests, Config.Interests),
			lookingFor = sanitizeTags(lookingFor, Config.LookingFor),
		}
		cache[player.UserId] = profile
		local ds = store()
		if ds then
			task.spawn(function()
				pcall(function()
					ds:SetAsync("u_" .. player.UserId, profile)
				end)
			end)
		end
		Remotes.Get("Notify"):FireClient(player, "Profile updated.", "good")
	end)

	Remotes.GetFunction("GetMyProfile").OnServerInvoke = function(player)
		return load(player.UserId)
	end

	Remotes.GetFunction("GetDirectory").OnServerInvoke = function(player)
		if not Membership.IsMember(player) then
			return {}
		end
		local out = {}
		for _, userId in Membership.Roster() do
			local profile = load(userId)
			table.insert(out, {
				userId = userId,
				name = displayName(userId),
				interests = profile.interests,
				lookingFor = profile.lookingFor,
			})
		end
		return out
	end
end

return Profiles
