#!/usr/bin/env python3
import json, sys, os

profile_path = sys.argv[1]
if not os.path.exists(profile_path):
    print(f"FEHLER: Profil nicht gefunden: {profile_path}", file=sys.stderr)
    sys.exit(1)

DLC_IDS = [
    "1829580","1829581","1829582","1829583","1829584","1829585","1829586","1829587",
    "1829590","1829591","1829592","1829593","1829594","1829595","1829596",
    "1829600","1829601","1829602","1829603","1829604","1829605",
    "1843460","2184790","2184791","2475260","2828470","2973650",
    "3110360","3254350","3711140","3957470","4097630","4328240","4542910","4621250"
]

with open(profile_path) as f:
    p = json.load(f)
p["Extensions"]["entP"] = DLC_IDS
with open(profile_path, "w") as f:
    json.dump(p, f)
print(f"OK: {len(DLC_IDS)} DLC-IDs gesetzt")
