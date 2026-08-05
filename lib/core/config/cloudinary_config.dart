/// TEMPORARY — demo-purposes swap-in for evidence file storage while
/// Firebase Storage is blocked on the Blaze plan (needs a card on file).
///
/// Paste your real values from cloudinary.com below (Dashboard → Cloud name,
/// Settings → Upload → your unsigned preset name).
///
/// TO SWITCH BACK TO FIREBASE STORAGE LATER (once Blaze is sorted):
/// just revert report_repository.dart's createReport() evidence-upload loop
/// back to using FirebaseStorage directly — nothing else in the app needs to
/// change, since Firestore only ever stores the resulting URL string in
/// evidenceFiles, not which service produced it.
class CloudinaryConfig {
  CloudinaryConfig._();

  static const cloudName = 'gcbcw5nf';
  static const uploadPreset = 'bantay_nuevo_evidence';

  static Uri get uploadUrl => Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/upload');
}
