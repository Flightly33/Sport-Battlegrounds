--[[
	AudioService: finds sound effects and music in Roblox's audio library when the server starts.

	For every sound slot that has no id in Shared/AssetIds, it searches the library with the terms in
	Shared/AudioCatalog and publishes what it found as attributes on ReplicatedStorage.Audio; the
	client's Sound and Music modules pick them up (and fall back to built-in sounds for anything that
	is missing or fails to load). The picks are printed as a table: paste it into Shared/AssetIds to
	keep them, since search results can change from one server to the next.
]]

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local AssetIds = require(Shared.AssetIds)
local AudioCatalog = require(Shared.AudioCatalog)

local AudioService = {}

type Found = { Id: number, Title: string }

local SEARCH_GAP = 0.2 -- seconds between requests, to stay well inside the rate limit

local folder: Folder

-- Search results are plain tables; read them defensively in case field names change.
local function readItem(item: any): Found?
	if type(item) ~= "table" then
		return nil
	end
	local id = tonumber(item.Id or item.AssetId or item.id)
	if not id or id <= 0 then
		return nil
	end
	local title = item.Title or item.Name or item.title
	return { Id = id, Title = if type(title) == "string" then title else "?" }
end

local function search(keyword: string, subType: Enum.AudioSubType, minDuration: number?, maxDuration: number?): ({ Found }, string?)
	local params = Instance.new("AudioSearchParams")
	params.SearchKeyword = keyword
	params.AudioSubType = subType
	if minDuration then
		params.MinDuration = math.floor(minDuration)
	end
	if maxDuration then
		params.MaxDuration = math.ceil(maxDuration)
	end
	local ok, result = pcall(function()
		return AssetService:SearchAudioAsync(params)
	end)
	params:Destroy()
	if not ok then
		return {}, tostring(result)
	end
	local okPage, page = pcall(function()
		return (result :: AudioPages):GetCurrentPage()
	end)
	if not okPage or type(page) ~= "table" then
		return {}, "no results page"
	end
	-- Endorsed (Roblox-curated) sounds first, otherwise keep the search order
	local endorsed: { Found } = {}
	local rest: { Found } = {}
	for _, item in page :: { any } do
		local found = readItem(item)
		if found then
			table.insert(if type(item) == "table" and item.IsEndorsed == true then endorsed else rest, found)
		end
	end
	table.move(rest, 1, #rest, #endorsed + 1, endorsed)
	return endorsed, nil
end

local function idList(found: { Found }): string
	local parts = {}
	for _, f in found do
		table.insert(parts, "rbxassetid://" .. f.Id)
	end
	return table.concat(parts, ",")
end

local function findEffects(report: { string }): number
	local names = {}
	for name in AudioCatalog.Effects do
		table.insert(names, name)
	end
	table.sort(names)
	local count = 0
	for _, name in names do
		local manual = (AssetIds.Sounds :: any)[name]
		if type(manual) == "string" and manual ~= "" then
			continue
		end
		local spec = AudioCatalog.Effects[name]
		for _, keyword in spec.Keywords do
			local found, err = search(keyword, Enum.AudioSubType.SoundEffect, spec.MinDuration, spec.MaxDuration)
			task.wait(SEARCH_GAP)
			if err then
				warn(string.format("[AudioService] search failed (%s): %s", keyword, err))
				return count -- the service is unavailable (Studio not published, outage...); stop trying
			end
			if #found > 0 then
				local keep = table.move(found, 1, math.min(#found, spec.Pick or 1), 1, {})
				folder:SetAttribute(name, idList(keep))
				count += 1
				local ids = {}
				for _, f in keep do
					table.insert(ids, tostring(f.Id))
				end
				table.insert(report, string.format('\t%s = "%s", -- %s', name, table.concat(ids, ","), keep[1].Title))
				break
			end
		end
	end
	return count
end

local function findMusic(report: { string }): number
	local spec = AudioCatalog.Music
	local seen: { [number]: boolean } = {}
	local tracks: { Found } = {}
	for _, keyword in spec.Keywords do
		if #tracks >= spec.MaxTracks then
			break
		end
		local found, err = search(keyword, Enum.AudioSubType.Music, spec.MinDuration, spec.MaxDuration)
		task.wait(SEARCH_GAP)
		if err then
			warn(string.format("[AudioService] music search failed (%s): %s", keyword, err))
			break
		end
		local taken = 0
		for _, f in found do
			if taken >= spec.PerKeyword or #tracks >= spec.MaxTracks then
				break
			end
			if not seen[f.Id] then
				seen[f.Id] = true
				table.insert(tracks, f)
				taken += 1
			end
		end
	end
	if #tracks > 0 then
		folder:SetAttribute("Music", idList(tracks))
		for _, f in tracks do
			table.insert(report, string.format('\t"%d", -- %s', f.Id, f.Title))
		end
	end
	return #tracks
end

function AudioService.Init()
	folder = Instance.new("Folder")
	folder.Name = "Audio"
	folder.Parent = ReplicatedStorage
	if not Config.Audio.Search then
		folder:SetAttribute("Ready", true)
		return
	end
	task.spawn(function()
		local effectLines: { string } = {}
		local musicLines: { string } = {}
		local effects = findEffects(effectLines)
		local music = if #AssetIds.Music > 0 then 0 else findMusic(musicLines)
		folder:SetAttribute("Ready", true)
		print(string.format("[AudioService] found %d sound effect(s) and %d music track(s) in the audio library", effects, music))
		if RunService:IsStudio() and (#effectLines > 0 or #musicLines > 0) then
			print("[AudioService] to keep these picks, paste into Shared/AssetIds.luau:\n"
				.. "AssetIds.Sounds = {\n" .. table.concat(effectLines, "\n") .. "\n}\n"
				.. "AssetIds.Music = {\n" .. table.concat(musicLines, "\n") .. "\n}")
		end
	end)
end

return AudioService
