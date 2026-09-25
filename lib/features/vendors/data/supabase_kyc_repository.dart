import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:palengkego/features/vendors/domain/kyc_repository.dart';
import 'package:palengkego/features/vendors/domain/kyc_submission.dart';

class SupabaseKycRepository implements KycRepository {
  const SupabaseKycRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<KycSubmission?> getKycStatus(String stallId) async {
    try {
      final data = await _client
          .from('kyc_submissions')
          .select()
          .eq('stall_holder_id', stallId)
          .order('submitted_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;
      return KycSubmission.fromSupabase(data);
    } catch (e) {
      debugPrint('Error fetching KYC status from Supabase: $e');
      return null;
    }
  }

  @override
  Future<KycSubmission> submitKyc(KycSubmission submission) async {
    try {
      // 1. Ensure/update stall holder record in stall_holders table
      final stallPayload = {
        'stall_holder_id': submission.stallHolderId,
        'user_id': submission.stallHolderId,
        'stall_name': submission.stallName ?? 'My Stall',
        'stall_number': submission.stallNumber ?? '1',
        'floor_number': submission.floorNumber ?? '1',
        'category': submission.category ?? 'Vegetables',
        'kyc_status': 'pending',
        'is_kyc_approved': false,
        'is_open': false,
      };
      await _client.from('stall_holders').upsert(
            stallPayload,
            onConflict: 'stall_holder_id',
          );

      // 2. If phone number or owner name is provided, update users record
      if (submission.contactNumber != null || submission.ownerName != null) {
        final Map<String, dynamic> userUpdates = {};
        if (submission.contactNumber != null &&
            submission.contactNumber!.isNotEmpty) {
          userUpdates['phone_number'] = submission.contactNumber;
        }
        if (submission.ownerName != null &&
            submission.ownerName!.isNotEmpty) {
          userUpdates['full_name'] = submission.ownerName;
        }
        if (userUpdates.isNotEmpty) {
          userUpdates['updated_at'] = DateTime.now().toIso8601String();
          await _client
              .from('users')
              .update(userUpdates)
              .eq('user_id', submission.stallHolderId);
        }
      }

      // 3. Insert into kyc_submissions table
      final kycData = submission.toSupabase();
      final inserted = await _client
          .from('kyc_submissions')
          .insert(kycData)
          .select()
          .single();

      return KycSubmission.fromSupabase(inserted);
    } catch (e) {
      debugPrint('Error submitting KYC to Supabase: $e');
      rethrow;
    }
  }
}
