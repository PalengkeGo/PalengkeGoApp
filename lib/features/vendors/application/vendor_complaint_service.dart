import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';

Future<String> submitVendorComplaint(
  WidgetRef ref, {
  required String stallId,
  required String reason,
  String? details,
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

  final response = await client.functions.invoke(
    'report-vendor',
    headers: {'Authorization': 'Bearer $token'},
    body: {
      'stallId': stallId,
      'reason': reason,
      if (details != null && details.trim().isNotEmpty)
        'details': details.trim(),
    },
  );
  final result = response.data;
  if (result is! Map || result['complaintId'] is! String) {
    throw StateError('The report service returned an invalid response.');
  }
  return result['complaintId'] as String;
}
