import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
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

  runApp(const BantayNuevoApp());
}
