#!/usr/bin/env python3
"""Writes a realistic savegame.json (relative to now) into the folder given as argv[1].
Used ONLY by CI to take screenshots; never touches a real player's save."""
import json, sys, uuid, os
from datetime import datetime, timedelta, timezone

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
now = datetime.now(timezone.utc)
iso = lambda d: d.strftime("%Y-%m-%dT%H:%M:%SZ")
b = lambda t, x, y, blk=0: {"id": str(uuid.uuid4()).upper(), "type": t, "gridX": x, "gridY": y, "placedAtFocusBlocks": blk}

buildings = [
    b("townHall", 3, 3), b("cottage", 2, 4), b("cottage", 4, 4), b("road", 3, 2), b("road", 3, 4),
    b("road", 3, 5), b("garden", 2, 2), b("park", 4, 2),
    b("cottage", 5, 3, 3), b("cottage", 5, 5, 5), b("cottage", 2, 6, 6), b("cottage", 6, 4, 8),
    b("garden", 1, 3, 2), b("garden", 5, 2, 4), b("fountain", 4, 5, 7), b("windmill", 6, 2, 9),
    b("library", 6, 6, 10), b("workshop", 1, 5, 11), b("road", 4, 3, 3), b("road", 5, 4, 5),
    b("park", 9, 2, 12), b("park", 10, 3, 12), b("cottage", 9, 5, 13),
]
sessions = []
for day in range(6, -1, -1):
    for k in range(1 + (day % 3)):
        end = (now - timedelta(days=day)).replace(hour=9 + 3 * k, minute=25, second=0, microsecond=0)
        if end > now: end = now - timedelta(minutes=5)
        sessions.append({"id": str(uuid.uuid4()).upper(), "type": "focus", "startTime": iso(end - timedelta(minutes=25)),
                         "endTime": iso(end), "durationSeconds": 1500})
sessions.sort(key=lambda s: s["endTime"], reverse=True)
focus_seconds = 14 * 1500 + 720
state = {
    "version": 1, "resources": {"wood": 11, "stone": 7, "metal": 3}, "buildings": buildings,
    "completedFocusSeconds": focus_seconds, "completedFocusBlocks": 14,
    "totalLifetimeFocusSeconds": 6.5 * 3600, "sessionHistory": sessions,
    "currentStreakDays": 6, "bestStreakDays": 9,
    "lastFocusDate": datetime.now().strftime("%Y-%m-%d"), "milestonesUnlocked": [3],
    "settings": {"focusDurationMinutes": 25, "breakDurationMinutes": 5, "eveningReminderEnabled": True,
                 "eveningReminderHour": 20, "eveningReminderMinute": 0, "soundEnabled": True},
}
with open(os.path.join(out, "savegame.json"), "w") as f:
    json.dump(state, f, indent=1)
print("demo save written to", out)
