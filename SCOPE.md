# Katana Tempering – Scope (v0.2)

**In scope**
- Blowtorch "Temper Blade" action on eligible weapons (default `Base.Katana`, sandbox list).
- Tempered window (default 30 in-game min): wear scaled to `HardenedWearPercent` (default 0) for sharpness, condition, head condition.
- Optional global slowdown while untempered (`BaseWearPercent`).
- Heat stress + early reheat: confirm dialog, crack chance, scorch damage.
- Requirements: Mechanics 2, Maintenance 5, Welding 1 (defaults) + mask, torch fuel per use.
- Server authority: state in server ModData; server validates every request and reconciles wear every 5 ticks.
- Torch sound, sparks (visual), draggable HUD panel with saved position.

- Hattori Hanzo's Blade: a flagged Base.Katana (rare loot roll or admin menu): 150% damage, 200% condition, no sharpness wear, 2x tempering, half crack chance; all sandbox-tunable.

**Out of scope (v0.2)**: custom animation, other-mod compat/caps, repairing/sharpening, translations beyond EN, in-world spark particles.

**Ideas later**: oil/wrap to slow wear, flicker-free client prediction, per-weapon durations, glint effect, ModOptions for HUD lock/scale.
