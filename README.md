# Katana Tempering (Project Zomboid B42)

Use a **blowtorch** on a katana (or any weapon you list) to temper it. While tempered, sharpness/condition wear is scaled down (default 0%) for 30 in-game minutes.
Reheating before heat stress has cooled risks cracking the blade (condition -> 0) and scorches it otherwise. The UI warns you first.

All state lives in server ModData; the client only requests actions. Everything is under Sandbox Options > Katana Tempering.

Known to verify in real MP: wear is applied by the client, so the server reconciles it every 5 ticks (`KT_Server.lua`). Animation is an optional separate mod (KatanaTemperingAnim), experimental and the spark projection are best-effort.

## Compatibility
Preventative Maintenance 2 (repair/sharpen overhaul) is supported: the mod wraps PM2's repair and sharpen functions so any item PM2 touches is re-baselined immediately, snapshots are dropped on unequip, and a PM2 repair-counter change also re-baselines. PM2's repairs, fumbles and sharpening damage are never refunded by the tempering guard.
