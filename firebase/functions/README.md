# Cloud Functions — setup & testing

## You can test this WITHOUT the Blaze plan / a card

Cloud Functions only need billing enabled to **deploy live**. Running them
locally through the Firebase Emulator Suite is completely free, no card
required, and is honestly the better way to test `onSosCreated` anyway since
you can watch the logs directly instead of digging through the real console.

### One-time setup
```
npm install -g firebase-tools
cd firebase
firebase login
firebase init emulators   # pick Functions + Firestore emulators
cd functions
npm install
```

### Running the emulator
```
firebase emulators:start --only functions,firestore
```
This spins up a local Firestore + Functions environment. Point your Flutter
app at it temporarily by adding, near the top of `main()` in `lib/main.dart`
(only while testing — remove/comment out before building for real use):
```dart
FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
FirebaseFunctions.instance.useFunctionsEmulator('localhost', 5001);
```
Then trigger an SOS from the app as normal — you'll see `onSosCreated` fire
in the emulator's terminal output in real time, including any Semaphore SMS
errors (which will fail without a real API key, that's expected locally —
you're testing the *logic*, not actually sending texts, unless you set real
secrets below).

### Testing Semaphore for real (optional, needs their free trial credits — no card needed for that either)
```
firebase functions:secrets:set SEMAPHORE_API_KEY
firebase functions:secrets:set SEMAPHORE_SENDER_NAME
```
Semaphore's free trial gives you enough credits to test real SMS sends
without paying anything — separate from Firebase's own billing.

## Known gap: push notifications currently no-op

`onSosCreated` and `onReportCreated` both try to push via FCM, but no screen
in the app yet saves a device's `fcmToken` to `users/{uid}` — that gets
added when the Notifications feature (Prompt 6) registers each device with
Firebase Messaging. Until then, the push step silently does nothing (logged,
not an error) — the SMS backup still fires either way, so this doesn't block
testing the SOS flow end-to-end.

## Deploying for real (needs Blaze — hold off until your card situation is sorted)
```
firebase deploy --only functions
```
