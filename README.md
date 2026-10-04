# Katana Tempering (Project Zomboid B42)

Use a **blowtorch** on a katana (or any weapon you list) to temper it. While tempered, sharpness/condition wear is scaled down (default 0%) for 30 in-game minutes.
Reheating before heat stress has cooled risks cracking the blade (condition -> 0) and scorches it otherwise. The UI warns you first.

All state lives in server ModData; the client only requests actions. Everything is under Sandbox Options > Katana Tempering.

Known to verify in real MP: wear is applied by the client, so the server reconciles it every 5 ticks (`KT_Server.lua`). Anim name `BlowTorch` and the spark projection are best-effort.
