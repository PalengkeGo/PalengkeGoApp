import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/infrastructure/supabase_storage_service.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/core/utils/image_picker_helper.dart';
import 'dart:io';

Future<List<String>> _uploadEvidence(WidgetRef ref, List<File> images) async {
  if (images.length > 5) throw ArgumentError('Attach up to 5 images.');
  final authUser = ref.read(firebaseAuthProvider)?.currentUser;
  final uid = authUser?.uid;
  if (uid == null) throw StateError('Sign in to attach report evidence.');
  final storage = ref.read(supabaseStorageServiceProvider);
  final stamp = DateTime.now().microsecondsSinceEpoch;
  final paths = <String>[];
  for (var i = 0; i < images.length; i++) {
    final image = images[i];
    final bytes = await ImagePickerHelper.readBytes(image);
    if (bytes.length > 5 * 1024 * 1024) {
      throw ArgumentError('Each evidence image must be 5 MB or smaller.');
    }
    final name = image.path.split('#').last.toLowerCase();
    final extension = name.endsWith('.png') ? 'png' : name.endsWith('.webp') ? 'webp' : 'jpg';
    final result = await storage.uploadFileDetailed(
      bucket: SupabaseStorageService.reportEvidenceBucket,
      path: '$uid/reports/${stamp}_$i.$extension',
      file: image,
    );
    paths.add(result.path);
  }
  return paths;
}

Future<String> submitVendorComplaint(
  WidgetRef ref, {
  required String stallId,
  required String reason,
  String? details,
  List<File> evidence = const [],
}) async {
  final client = ref.read(supabaseClientProvider);
  if (client == null) {
    throw StateError('Vendor reporting is unavailable while offline.');
  }
  final token = await ref
      .read(firebaseAuthProvider)
      ?.currentUser
      ?.getIdToken();
  if (token == null) throw StateError('Sign in to report a vendor.');

  final evidencePaths = await _uploadEvidence(ref, evidence);
  final response = await client.functions.invoke(
    'report-vendor',
    headers: {'Authorization': 'Bearer $token'},
    body: {
      'stallId': stallId,
      'reason': reason,
      if (details != null && details.trim().isNotEmpty)
        'details': details.trim(),
      'evidencePaths': evidencePaths,
    },
  );
  final result = response.data;
  if (result is! Map || result['complaintId'] is! String) {
    throw StateError('The report service returned an invalid response.');
  }
  return result['complaintId'] as String;
}

Future<String> submitSupportReport(
  WidgetRef ref, {
  required String topic,
  required String details,
  List<File> evidence = const [],
}) async {
  final client = ref.read(supabaseClientProvider);
  if (client == null) {
    throw StateError('Support reporting is unavailable while offline.');
  }
  final token = await ref
      .read(firebaseAuthProvider)
      ?.currentUser
      ?.getIdToken();
  if (token == null) throw StateError('Sign in to submit a support report.');

  final evidencePaths = await _uploadEvidence(ref, evidence);
  final response = await client.functions.invoke(
    'report-support-issue',
    headers: {'Authorization': 'Bearer $token'},
    body: {'topic': topic, 'details': details.trim(), 'evidencePaths': evidencePaths},
  );
  final result = response.data;
  if (result is! Map || result['complaintId'] is! String) {
    throw StateError('The support service returned an invalid response.');
  }
  return result['complaintId'] as String;
}
