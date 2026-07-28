# Bantay Nuevo — Prompt 0 output

This is the hand-written output of Prompt 0 from `PROMPTS.md`, matching the
folder structure and design system in `AGENTS.md`. Built without running the
Flutter CLI (not available in the sandbox this was generated in), so you need
to do a few one-time local steps before it runs.

## What's here
- `pubspec.yaml` — all packages for Prompts 0–8 pre-added
- `android/app/src/main/AndroidManifest.xml` — every permission Prompts 3, 4, 7, 8 need, each commented with which feature uses it
- `lib/core/theme/` — colors, typography, spacing tokens + assembled `ThemeData`, all matching AGENTS.md §4 exactly
- `lib/core/widgets/` — AppButton, StatusBadge, AppCard, SectionTitle, ListItemTile, ToggleRow, NetBanner
- `lib/app.dart` — a scaffold showcase screen so you can see the theme + widgets rendering correctly before any real screens exist
- `lib/firebase_options.dart` — placeholder, see instructions inside
- Empty folders with `.gitkeep` for everything Prompts 1–8 will fill in (`features/auth`, `features/resident`, `features/tanod`, `features/police`, `features/resources`, `models`, `core/router`, `core/utils`, `firebase/functions`)

## One-time local setup

1. **Install Flutter** if you haven't: https://docs.flutter.dev/get-started/install
2. **Turn this into a runnable project.** Since this was hand-written (no `flutter create` was run), do this once:
   ```
   flutter create --org com.baranggaycaminonuevo --project-name bantay_nuevo .
   ```
   Run this *inside* this folder — it'll fill in the missing native scaffolding (iOS folder, Android Gradle files, etc.) without touching the files already here, since `flutter create` only adds files that don't exist yet.
3. **Get packages:**
   ```
   flutter pub get
   ```
4. **Connect Firebase:**
   ```
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   Follow the prompts, select/create your Firebase project, enable Auth, Firestore, Storage, and Cloud Messaging in the Firebase console first. This overwrites `lib/firebase_options.dart` and drops `android/app/google-services.json` for you.
5. **Google Maps key** (needed later for the police map screen): paste it into `android/app/src/main/AndroidManifest.xml` where marked `PASTE_GOOGLE_MAPS_API_KEY_HERE`.
6. **Run it:**
   ```
   flutter run
   ```
   You should see the "Bantay Nuevo — scaffold check" screen: buttons, status badges, a card with sample report list items, a toggle row, and the color palette swatches. If that renders correctly, the theme and shared widgets are wired up right and you're ready for Prompt 1 (auth).

## Next step
Move on to **Prompt 1 — Auth & role-based routing** from `PROMPTS.md`.
