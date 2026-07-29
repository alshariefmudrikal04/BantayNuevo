import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/user_model.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Streams the logged-in resident's UserModel (name, purok, uid, role),
/// or null when signed out. Any screen needing "who's logged in" should
/// watch this instead of touching AuthRepository directly.
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});
