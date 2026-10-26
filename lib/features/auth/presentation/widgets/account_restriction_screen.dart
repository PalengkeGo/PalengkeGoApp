import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';

class AccountRestrictionScreen extends ConsumerWidget {
  const AccountRestrictionScreen({
    super.key,
    required this.user,
    this.transparentBackground = false,
  });

  final AppUser user;
  final bool transparentBackground;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blocked = user.isBlocked;
    final until = user.suspendedUntil;
    final notifications = ref.watch(notificationServiceProvider);
    return ListenableBuilder(
      listenable: notifications,
      builder: (context, _) {
        final notice = notifications.all
            .where(
              (item) => const {
                'account blocked',
                'account suspension',
                'account restored',
                'suspension lifted',
              }.contains(item.title.trim().toLowerCase()),
            )
            .firstOrNull;
        return Scaffold(
          backgroundColor: transparentBackground
              ? Colors.transparent
              : AppTheme.scaffoldBackground,
          body: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: transparentBackground ? const EdgeInsets.all(22) : null,
                  decoration: transparentBackground
                      ? BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 28,
                              offset: Offset(0, 12),
                            ),
                          ],
                        )
                      : null,
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      blocked
                          ? Icons.block_rounded
                          : Icons.hourglass_top_rounded,
                      size: 64,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      blocked
                          ? 'Account Blocked'
                          : 'Account Temporarily Suspended',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w700,
                        color: Colors.redAccent,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      blocked
                          ? 'Your account has been blocked by Market Administration. You can’t place or manage orders, make payments, chat, or use other account services. Contact MEPO office for help.'
                          : 'Your account is temporarily suspended by Market Administration. Account services, including orders, payments, and chat, are unavailable during the suspension.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (!blocked && until != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Scheduled to end ${DateFormat('MMM d, yyyy · h:mm a').format(until.toLocal())}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                        ),
                      ),
                    ],
                    if (notice != null) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              notice.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(notice.body),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => ref.read(authProvider.notifier).logout(),
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Sign out'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
