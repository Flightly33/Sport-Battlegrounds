# Sports Battlegrounds: project memory

A Roblox PvP battlegrounds game with sport characters (Soccer, Basketball, Football, Baseball). It's a
Rojo project in Luau.

## Working rules (from the owner)
- After every finished change, rebuild `SportsBattlegrounds.rbxl` (`rojo build default.project.json -o SportsBattlegrounds.rbxl`) and send the file to the user.
- Don't write README text.
- Develop and push on branch `claude/elegant-goldberg-gq9v5k`. Don't open a PR unless asked.
- Push back when something isn't the best approach, and ask when an answer depends on details you don't have.
- Never invent Roblox asset or sound IDs.

## Open issues (fixed in code, not yet confirmed in Studio)
1. Characters stood stiff in Studio. Cause: current R15 avatars are jointed with AnimationConstraints, not Motor6Ds, and `Rig.FromCharacter` only read Motor6Ds. `Rig` now reads both, and the Animator warns `[Animator] ... has no R15 joints` when it finds neither.
2. Moves play full body clips. A clip's `Marks` (Plant, Contact, Release, Burst...) are the frames gameplay fires on, through `ctx:Until(track, mark)` (animation time, so they hold through hit-stop and slow-mo).
3. Dashes, lunges, leaps and slides did nothing: they pushed on a `RootAttachment` that current rigs lack. `src/client/Motion.luau` now drives them on its own `SB_Motion` attachment (speed curves, wall sliding, arena clamp). Tuning is in `Config.Dash` and `Config.Motion`.
4. The stadium is built at real-world size in Roblox's own units, `Layout.STUDS_PER_METER = 1 / 0.28` (Roblox: 1 stud = 0.28 m). The server logs each spawned character's height for calibration. `Layout.FIELD_SCALE` stretches only the pitch. `Layout.SCALE` is gone.
If any of these still fail in Studio, ask the user for the Output window's errors and warnings.

## Layout
- `src/shared`: Config, Remotes, AssetIds (manual asset IDs), AudioCatalog (audio search terms), Characters/ (move data), Anim/ (rig, poses, clips, locomotion styles), Stadium/ (Layout, Builder, CrowdLayout).
- `src/server`: CombatService (hits, stun, block, meters), MoveService (validates client moves and hits), CharacterService (spawns R15 from a description; CharacterAutoLoads is off), DummyService (training dummies plus a noob at centre field), MatchService, AudioService (`AssetService:SearchAudioAsync` at startup, publishes on `ReplicatedStorage.Audio`).
- `src/client`: Animator (procedural, plus hit-stop and slow-mo), MoveRunner plus Moves/ (per-class move scripts; Moves/Kit holds the shared M1 chain and the Contact / Climax beats), Motion (moves the local character), Controller (input, aim assist), FX/ (VFX built from parts and particles, plus optional Blender-pack hooks), CameraFX, Sound, Music, Crowd, StadiumFX, UI/.
- `map/Stadium.rbxm`: baked stadium. Rebake with `lune run tools/lune/bake_stadium.luau` after any Layout or Builder change.
- `blender/build_pack.py`: generates the OBJ meshes and PNG textures in `blender/out/`. Uploaded IDs go into AssetIds.

## Checks (run before every push)
- `tools/tc.sh`: Luau strict type check (luau-lsp, old solver). Empty output means clean.
- `lune run tests/consistency.luau`
- `rojo sourcemap default.project.json -o sourcemap.json && lune run tests/sim_smoke.luau [quick|Class,Class]`: boots the server and client in a deterministic simulator (`tools/sim`, virtual clock) and plays every move. Env vars: `SIM_ASSETS=1` fills every asset slot, `SIM_DIGEST=1` prints a per-frame state digest, `SIM_TRACE=1` adds tracing, `SIM_RIG=motor6d` builds legacy Motor6D rigs (the default is AnimationConstraint, like current avatars). It fails when a move doesn't animate the body, a mover doesn't move, or a dash misses its distance, cooldown or the arena wall.
- Tools: Lune 0.11; luau-lsp at /root/tools/luau-lsp; bpy venv at /root/tools/blendenv (renders with Cycles on CPU only, no GPU).
- The simulator only approximates Roblox. A passing sim doesn't prove the game works in Studio.

## Conventions
- Time comes from `workspace:GetServerTimeNow()` for combat and `os.clock()` for local timing.
- Pose conventions: +X swings a limb forward, a knee bends with -X, +Z abducts the right limb, Root +X leans back.
- Commit messages end with the Co-Authored-By and Claude-Session lines the session provides.
