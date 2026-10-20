import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/reports/domain/user_report.dart';

void main() {
  group('UserReport Domain Model', () {
    test('serializes to and from Supabase snake_case JSON correctly', () {
      final now = DateTime.utc(2026, 10, 18, 10, 30);
      final report = UserReport(
        id: 'RPT-12345',
        userId: 'user-abc',
        type: 'Customer',
        accountIssue: 'Fresh Fish Stall',
        category: 'Inappropriate Content',
        submittedBy: 'Maria Santos',
        reason: 'Inappropriate Content',
        description: 'Vendor sold rotten tilapia.',
        reporterEmail: 'maria@example.com',
        phone: '09171234567',
        vendorName: 'Fresh Fish Stall',
        owner: 'Mang Juan',
        stallNumber: 'Stall #12',
        previousViolations: 1,
        status: 'pending',
        priority: 'high',
        notes: '',
        createdAt: now,
      );

      final json = report.toJson();
      expect(json['id'], 'RPT-12345');
      expect(json['user_id'], 'user-abc');
      expect(json['account_issue'], 'Fresh Fish Stall');
      expect(json['submitted_by'], 'Maria Santos');
      expect(json['status'], 'pending');
      expect(json['priority'], 'high');

      final deserialized = UserReport.fromJson(json);
      expect(deserialized.id, report.id);
      expect(deserialized.userId, report.userId);
      expect(deserialized.accountIssue, report.accountIssue);
      expect(deserialized.description, report.description);
      expect(deserialized.isPending, isTrue);
      expect(deserialized.isResolved, isFalse);
    });

    test('handles admin resolution note and status correctly', () {
      final now = DateTime.utc(2026, 10, 18, 10, 30);
      final resolvedTime = DateTime.utc(2026, 10, 18, 11, 0);
      final report = UserReport(
        id: 'RPT-999',
        userId: 'user-123',
        accountIssue: 'Payment Problem',
        submittedBy: 'Pedro',
        reason: 'Payment Problem',
        description: 'Double charged on GCash',
        createdAt: now,
      );

      expect(report.isResolved, isFalse);

      final resolved = report.copyWith(
        status: 'resolved',
        decision: 'Refund Issued',
        actionTaken: 'Payment Refunded',
        resolutionNote: 'We investigated your report and refunded ₱150 to your GCash wallet.',
        resolvedAt: resolvedTime,
        resolvedBy: 'ADM-001',
      );

      expect(resolved.isResolved, isTrue);
      expect(resolved.decision, 'Refund Issued');
      expect(resolved.resolutionNote, contains('refunded ₱150'));
      expect(resolved.resolvedBy, 'ADM-001');

      final json = resolved.toJson();
      expect(json['status'], 'resolved');
      expect(json['decision'], 'Refund Issued');
      expect(json['resolution_note'], contains('refunded ₱150'));

      final fromJson = UserReport.fromJson(json);
      expect(fromJson.isResolved, isTrue);
      expect(fromJson.resolutionNote, resolved.resolutionNote);
    });
  });
}
