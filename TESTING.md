# Test checklist
SP first, then host-and-join, then dedicated server (2 clients).
1. Mod loads, Sandbox page "Katana Tempering" present, no Lua errors in console.txt.
2. Katana context menu shows Temper; disabled + tooltip reasons: no torch / empty torch / Mechanics<2 / Maintenance<5 / mask (if enabled).
3. Action plays sound + sparks; cancelling (walk) stops sound; torch loses 1 unit only on completion.
4. Tempered: swing at zombies 20+ times -> sharpness/condition unchanged (HardenedWear=0). After 30 in-game min wear resumes.
5. HUD shows time left + heat bar, drags, position survives relog; hidden with other weapon.
6. Re-temper while heat stress > 0: confirm dialog shows crack %; test with chance 0 (damage only) and 100 (always cracks -> condition 0).
7. Sandbox: duration, wear %, ProtectCondition off (only sharpness protected), BaseWear 40, Items list with a second weapon.
8. MP: second client sees sparks/sound within 25 tiles; forged `temper` command without `fx` is denied; relog keeps tempered state; wear flicker acceptable?
9. Repair/sharpen a tempered blade: values are not rolled back upward/downward incorrectly.
10. Verify anim `BlowTorch` exists; if not, pick a vanilla welding anim.
11. Throw/drop/pick up katana: item ID stable and tempering retained.
