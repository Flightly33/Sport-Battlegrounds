--[[
	All animation clips, by class. Clips.All lists every clip (with the style it belongs to) for the
	offline previewer (tools/lune/preview_anim.luau).
]]

local Pose = require(script.Parent.Pose)

local Clips = {}

Clips.Common = require(script.Common)
Clips.Soccer = require(script.Soccer)
Clips.Basketball = require(script.Basketball)
Clips.Football = require(script.Football)
Clips.Baseball = require(script.Baseball)

export type Entry = { Style: string, Clip: Pose.Clip, Samples: number? }

Clips.All = {} :: { [string]: Entry }
for _, group in { "Common", "Soccer", "Basketball", "Football", "Baseball" } do
	local style = if group == "Common" then "Dummy" else group
	for name, clip in (Clips :: any)[group] :: { [string]: Pose.Clip } do
		if type(clip) == "table" and clip.Keys then
			Clips.All[group .. "." .. name] = { Style = style, Clip = clip, Samples = math.clamp(math.ceil(clip.Length / 0.07), 4, 12) }
		end
	end
end

return Clips
