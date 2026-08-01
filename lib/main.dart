import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: this will throw until you run `flutterfire configure` — see the
  // instructions at the top of lib/firebase_options.dart. That's expected
  // for now; comment out the line below if you want to preview the UI
  // scaffold before your Firebase project is set up.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // TEMPORARY — connects to the local Firebase emulator instead of live
  // production Firestore, so you can test onSosCreated without the Blaze
  // plan. Only active in debug builds. Remove/comment out once you're done
  // testing against the emulator and want to hit real Firestore again.
  // Requires `adb reverse tcp:8080 tcp:8080` if testing on a USB-connected
  // physical phone — see firebase/functions/README.md.
  if (kDebugMode) {
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
  }

  runApp(const BantayNuevoApp());
}
