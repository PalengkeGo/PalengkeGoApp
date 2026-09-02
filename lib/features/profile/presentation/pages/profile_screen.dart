import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/navigation/app_routes.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/profile/application/favorites_provider.dart';
import 'package:palengkego/features/profile/application/profile_provider.dart';
import 'package:palengkego/features/home/presentation/widgets/location_selection_sheet.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_profile_screen.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_onboarding_screen.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_dashboard_screen.dart';
import 'package:palengkego/features/auth/application/has_vendor_stall_provider.dart';
import 'edit_profile_screen.dart';
import 'security_settings_screen.dart';
import 'saved_stalls_screen.dart';
import 'help_support_screen.dart';
import 'package:palengkego/features/checkout/presentation/pages/payment_methods_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsyncValue = ref.watch(currentProfileProvider);
    final favoriteVendors = ref.watch(favoriteVendorsProvider);
    final user = ref.watch(authProvider);
    final isVendor = user?.isVendor ?? false;
    final hasVendorStall = ref.watch(hasVendorStallProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.maybePop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppTheme.surfaceContainerLow,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: SvgPicture.asset(
                        'assets/icons/back button icon.svg',
                        width: 16,
                        height: 16,
                        colorFilter: const ColorFilter.mode(
                          AppTheme.primaryGreen,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ],
              ),
            ),

            // Profile Info Section
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: profileAsyncValue.when(
                  data: (profile) {
                    if (profile == null) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 24),
                          Center(
                            child: Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primaryGreen,
                                  width: 2,
                                ),
                              ),
                              child: ClipOval(child: _fallbackAvatar()),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Center(
                            child: Text(
                              'Guest User',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryGreen,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Center(
                            child: Text(
                              'Log in to view your profile and orders',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 48),
                          _buildMenuItem(
                            iconData: Icons.login_rounded,
                            title: 'Log In',
                            onTap: () {
                              Navigator.of(context).pushNamed(AppRoutes.login);
                            },
                          ),
                          _buildMenuItem(
                            iconData: Icons.person_add_alt_1_rounded,
                            title: 'Create an Account',
                            onTap: () {
                              Navigator.of(
                                context,
                              ).pushNamed(AppRoutes.registration);
                            },
                          ),
                          _buildMenuItem(
                            iconData: Icons.help_outline_rounded,
                            title: 'Help & Support',
                            onTap: () {
                              Navigator.of(context).push(
                                PageTransitions.slideFromRight(
                                  const CustomerHelpSupportScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        // ── Avatar ────────────────────────────────────────
                        Center(
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.primaryGreen,
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: AdaptiveImage(
                                profile.avatarUrl,
                                fit: BoxFit.cover,
                                placeholder: _fallbackAvatar(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            profile.displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryGreen,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Center(
                          child: Text(
                            profile.email,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // ── Favorites Section ─────────────────────────────
                        favoriteVendors.maybeWhen(
                          data: (vendors) {
                            if (vendors.isEmpty) return const SizedBox.shrink();
                            return Column(
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'My Favorites',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryGreen,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F5E9),
                                        borderRadius: BorderRadius.circular(
                                          999,
                                        ),
                                      ),
                                      child: Text(
                                        '${vendors.length}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryGreen,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 100,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: vendors.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(width: 12),
                                    itemBuilder: (context, index) {
                                      final vendor = vendors[index];
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            PageTransitions.slideFromRight(
                                              VendorProfileScreen(
                                                vendorId: vendor.id,
                                              ),
                                            ),
                                          );
                                        },
                                        child: Container(
                                          width: 80,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            color: Colors.white,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.05,
                                                ),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Column(
                                            children: [
                                              Expanded(
                                                child: ClipRRect(
                                                  borderRadius:
                                                      const BorderRadius.vertical(
                                                        top: Radius.circular(
                                                          12,
                                                        ),
                                                      ),
                                                  child: AdaptiveImage(
                                                    vendor.imageUrl,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    placeholder: Container(
                                                      color: const Color(
                                                        0xFFE8F5E9,
                                                      ),
                                                      child: const Icon(
                                                        Icons
                                                            .storefront_outlined,
                                                        color: AppTheme
                                                            .accentGreen,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  6,
                                                ),
                                                child: Text(
                                                  vendor.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                  style: const TextStyle(
                                                    fontFamily:
                                                        'PlusJakartaSans',
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppTheme.primaryGreen,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(height: 28),
                              ],
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        ),

                        // ── Menu Items ────────────────────────────────────
                        _buildMenuItem(
                          iconPath: 'assets/icons/profile icon.svg',
                          title: 'Edit Profile',
                          onTap: () {
                            Navigator.of(context).push(
                              PageTransitions.slideFromRight(
                                const EditProfileScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          iconData: Icons.location_on_outlined,
                          title: 'My Addresses',
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              isScrollControlled: true,
                              builder: (context) =>
                                  const LocationSelectionSheet(),
                            );
                          },
                        ),
                        _buildMenuItem(
                          iconData: Icons.account_balance_wallet_outlined,
                          title: 'Payment Methods',
                          onTap: () {
                            Navigator.of(context).push(
                              PageTransitions.slideFromRight(
                                const PaymentMethodsScreen(isManageMode: true),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          iconData: Icons.bookmark_border_rounded,
                          title: 'Saved Stalls',
                          onTap: () {
                            Navigator.of(context).push(
                              PageTransitions.slideFromRight(
                                const SavedStallsScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          iconPath: 'assets/icons/Security Icon.svg',
                          title: 'Security',
                          onTap: () {
                            Navigator.of(context).push(
                              PageTransitions.slideFromRight(
                                const SecuritySettingsScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          iconData: Icons.help_outline_rounded,
                          title: 'Help & Support',
                          onTap: () {
                            Navigator.of(context).push(
                              PageTransitions.slideFromRight(
                                const CustomerHelpSupportScreen(),
                              ),
                            );
                          },
                        ),
                        _buildMenuItem(
                          iconPath: isVendor
                              ? null
                              : (hasVendorStall
                                    ? null
                                    : 'assets/icons/start selling icon.svg'),
                          iconData: isVendor
                              ? Icons.storefront_rounded
                              : (hasVendorStall
                                    ? Icons.storefront_rounded
                                    : null),
                          title: isVendor
                              ? 'Manage Stall Holder Stall'
                              : (hasVendorStall
                                    ? 'Manage Stall Holder Stall'
                                    : 'Start Selling'),
                          onTap: () async {
                            if (isVendor || hasVendorStall) {
                              final entered = await ref
                                  .read(authProvider.notifier)
                                  .enterVendorMode();
                              if (!entered) {
                                if (context.mounted) {
                                  AppServices.showError(
                                    'Only stall holders can manage a stall.',
                                  );
                                }
                                return;
                              }
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  PageTransitions.slideFromRight(
                                    const VendorDashboardScreen(),
                                  ),
                                  (route) => false,
                                );
                              }
                            } else {
                              Navigator.of(context).push(
                                PageTransitions.slideFromRight(
                                  const VendorOnboardingScreen(),
                                ),
                              );
                            }
                          },
                        ),
                        _buildMenuItem(
                          iconPath: 'assets/icons/logout icon.svg',
                          title: 'Logout',
                          onTap: () => _showLogoutDialog(context, ref),
                          isLogout: true,
                        ),
                        const SizedBox(height: 32),
                      ],
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                  error: (error, stack) =>
                      AsyncErrorView(message: 'Error: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: const Color(0xFFE8F5E9),
      child: const Icon(
        Icons.person_rounded,
        size: 48,
        color: AppTheme.primaryGreen,
      ),
    );
  }

  Widget _buildMenuItem({
    String? iconPath,
    IconData? iconData,
    required String title,
    required VoidCallback onTap,
    bool isLogout = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: isLogout ? Border.all(color: const Color(0xFFEF4444)) : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          children: [
            if (iconPath != null)
              SvgPicture.asset(
                iconPath,
                width: 22,
                height: 22,
                colorFilter: ColorFilter.mode(
                  isLogout ? const Color(0xFFEF4444) : AppTheme.primaryGreen,
                  BlendMode.srcIn,
                ),
              )
            else if (iconData != null)
              Icon(
                iconData,
                size: 22,
                color: isLogout
                    ? const Color(0xFFEF4444)
                    : AppTheme.primaryGreen,
              ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isLogout
                      ? const Color(0xFFEF4444)
                      : AppTheme.textPrimary,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isLogout
                  ? const Color(0xFFEF4444)
                  : AppTheme.muted,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(context, rootNavigator: true);
              Navigator.of(context).pop();
              await ref.read(authProvider.notifier).logout();
              nav.pushNamedAndRemoveUntil(AppRoutes.login, (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
