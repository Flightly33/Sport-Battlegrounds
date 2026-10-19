--[[
	All RemoteEvents in one place. The server creates them, the client waits for them.

	Client -> Server
		MoveRequest(token, moveId, aim, variant)      start a move (the client already started it locally)
		HitRequest(token, hitName, targets, position)  your hitbox / projectile touched these fighters
		BlockRequest(holding)
		SelectCharacter(classId)
		ClientReady()

	Server -> Client
		MoveStarted(character, moveId, token, startTime, aim, variant)   everyone but the attacker
		MoveRejected(token, moveId, reason)                              the attacker only
		MoveCancelled(character, token)                                  interrupted by a stun
		HitConfirmed(hit)                                                everyone (see CombatService)
		Knockback(velocity, duration, knockdown)                         the victim only
		Follow(attackerRoot, offset, duration)                           the victim only (grabs)
		Cooldown(moveId, seconds)                                        resync a cooldown after a rejection
		KillFeed(killer, victim, killerClass, victimClass)
		Announce(text, color)                                            big banner (awakenings, streaks)
		Notify(text)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- NOTE: the folder must NOT sit next to this ModuleScript under the same name ("Remotes"),
-- otherwise the client's WaitForChild finds this script instead of the folder and hangs forever.
local FOLDER_NAME = "GameRemotes"

local EVENTS = {
	"MoveRequest",
	"HitRequest",
	"BlockRequest",
	"SelectCharacter",
	"ClientReady",
	"MoveStarted",
	"MoveRejected",
	"MoveCancelled",
	"HitConfirmed",
	"Knockback",
	"Follow",
	"Cooldown",
	"KillFeed",
	"Announce",
	"Notify",
}

local Remotes = {}

local folder: Folder
if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
end

function Remotes.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
