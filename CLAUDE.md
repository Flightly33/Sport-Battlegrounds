# Sports Battlegrounds: project memory

A Roblox PvP battlegrounds game with sport characters (Soccer, Basketball, Football, Baseball). It's a
Rojo project in Luau.

## Working rules (from the owner)
- After every finished change, rebuild `SportsBattlegrounds.rbxl` (`rojo build default.project.json -o SportsBattlegrounds.rbxl`) and send the file to the user.
- Don't write README text.
- Develop and push on branch `claude/elegant-goldberg-gq9v5k`. Don't open a PR unless asked.
- Push back when something isn't the best approach, and ask when an answer depends on details you don't have.
- Never invent Roblox asset or sound IDs.

## Open issues (latest feedback, not yet fixed)
1. In real Studio, the procedural animations don't show (characters stand stiff). The simulator doesn't reproduce this. Asked the user for Studio Output errors; none received yet.
2. Moves should visibly play body animations (e.g. Soccer kicks show the kick) instead of the player standing still.
3. Q dash doesn't actually move the player in real Roblox.
4. Make the stadium accurate to player size. The arena was just doubled (`Layout.SCALE = 2`); seats, rows and props may need rescaling to R15 proportions.
Items 1 to 3 likely share a root cause: client movement and Motor6D posing behave differently in real Roblox than in the simulator. Check `src/client/Animator.luau` (writes Motor6D.Transform in PreSimulation), `src/server/CharacterService.luau` (deletes Animate and Animator), and the movement helpers in `src/client/MoveRunner.luau` (`ctx:Forward`, `Teleport`, velocities).

## Layout
- `src/shared`: Config, Remotes, AssetIds (manual asset IDs), AudioCatalog (audio search terms), Characters/ (move data), Anim/ (rig, poses, clips, locomotion styles), Stadium/ (Layout, Builder, CrowdLayout).
- `src/server`: CombatService (hits, stun, block, meters), MoveService (validates client moves and hits), CharacterService (spawns R15 from a description; CharacterAutoLoads is off), DummyService (training dummies plus a noob at centre field), MatchService, AudioService (`AssetService:SearchAudioAsync` at startup, publishes on `ReplicatedStorage.Audio`).
- `src/client`: Animator (procedural), MoveRunner plus Moves/ (per-class move scripts), Controller (input, aim assist), FX/ (VFX built from parts and particles, plus optional Blender-pack hooks), CameraFX, Sound, Music, Crowd, StadiumFX, UI/.
- `map/Stadium.rbxm`: baked stadium. Rebake with `lune run tools/lune/bake_stadium.luau` after any Layout or Builder change.
- `blender/build_pack.py`: generates the OBJ meshes and PNG textures in `blender/out/`. Uploaded IDs go into AssetIds.

## Checks (run before every push)
- `tools/tc.sh`: Luau strict type check (luau-lsp, old solver). Empty output means clean.
- `lune run tests/consistency.luau`
- `rojo sourcemap default.project.json -o sourcemap.json && lune run tests/sim_smoke.luau [quick|Class,Class]`: boots the server and client in a deterministic simulator (`tools/sim`, virtual clock) and plays every move. Env vars: `SIM_ASSETS=1` fills every asset slot, `SIM_DIGEST=1` prints a per-frame state digest, `SIM_TRACE=1` adds tracing.
- Tools: Lune 0.11; luau-lsp at /root/tools/luau-lsp; bpy venv at /root/tools/blendenv (renders with Cycles on CPU only, no GPU).
- The simulator only approximates Roblox. A passing sim doesn't prove the game works in Studio.

## Conventions
- Time comes from `workspace:GetServerTimeNow()` for combat and `os.clock()` for local timing.
- Pose conventions: +X swings a limb forward, a knee bends with -X, +Z abducts the right limb, Root +X leans back.
- Commit messages end with the Co-Authored-By and Claude-Session lines the session provides.
