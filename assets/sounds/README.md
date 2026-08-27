# Alarm sound files needed here

`AlarmSoundService` (lib/core/services/alarm_sound_service.dart) expects one
`.mp3` file per emergency type, at these exact paths:

```
assets/sounds/physical_violence.mp3
assets/sounds/domestic_violence.mp3
assets/sounds/threats.mp3
assets/sounds/minor_abuse.mp3
assets/sounds/other.mp3
```

These files are **not included** — I can't generate actual audio content.
You need to source or record real sound files yourself and drop them in
here with these exact names.

## What to look for
- Short (2–5 seconds is plenty — it doesn't need to loop forever, the app
  re-triggers it on each new alert anyway)
- Genuinely distinguishable from each other by ear alone — a tanod should
  be able to tell "this is different from that" without looking at the
  screen, since the whole point is recognizing urgency/type by sound
- Royalty-free / licensed for your use — freesound.org and pixabay.com/sound-effects
  both have usable alarm/siren SFX under permissive licenses; check the
  specific license on whichever one you pick

## After adding files
Run `flutter pub get` and rebuild — Flutter needs to re-scan the assets
folder to pick up new files, a hot reload alone won't do it.

## If a file is missing
`AlarmSoundService.play()` fails silently (logs a debug message, doesn't
crash and doesn't block the rest of the alert-handling flow) — so you can
test everything else in this feature before all five files exist, you just
won't hear anything for whichever type is missing its file yet.
