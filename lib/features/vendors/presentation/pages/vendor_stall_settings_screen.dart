import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/config/categories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/widgets/app_screen_header.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/features/vendors/domain/day_schedule.dart';
import 'package:palengkego/features/vendors/presentation/widgets/stall_photo_editor.dart';
import 'package:palengkego/features/vendors/presentation/widgets/stall_info_form.dart';
import 'package:palengkego/features/vendors/presentation/widgets/operating_hours_editor.dart';
import 'package:palengkego/features/vendors/presentation/widgets/stall_settings_save_button.dart';

class VendorStallSettingsScreen extends ConsumerStatefulWidget {
  const VendorStallSettingsScreen({super.key});

  @override
  ConsumerState<VendorStallSettingsScreen> createState() =>
      _VendorStallSettingsScreenState();
}

class _VendorStallSettingsScreenState
    extends ConsumerState<VendorStallSettingsScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _locationController;

  String _selectedCategory = 'Fresh Fish';
  final List<String> _categories = AppCategories.stall;

  final List<DaySchedule> _schedules = [
    const DaySchedule(name: 'Monday'),
    const DaySchedule(name: 'Tuesday'),
    const DaySchedule(name: 'Wednesday'),
    const DaySchedule(name: 'Thursday'),
    const DaySchedule(name: 'Friday'),
    const DaySchedule(name: 'Saturday'),
    const DaySchedule(name: 'Sunday'),
  ];

  String? _bannerImage;
  String? _avatarImage;
  String? _thumbnailImage;

  @override
  void initState() {
    super.initState();
    // Initialize with empty strings first (late controllers must be assigned before use)
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();
    // Populate from provider state — ref is available in ConsumerState after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stall = ref.read(vendorStallProvider);
      _nameController.text = stall.name;
      _descriptionController.text = stall.description;
      _locationController.text = stall.location;
      setState(() {
        _selectedCategory = stall.category;
        _bannerImage = stall.bannerImage;
        _avatarImage = stall.avatarImage;
        _thumbnailImage = stall.thumbnailImage;
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _applyDayToAll(int sourceIndex) {
    final source = _schedules[sourceIndex];
    setState(() {
      for (int i = 0; i < _schedules.length; i++) {
        if (i == sourceIndex) continue;
        _schedules[i] = _schedules[i].copyWith(
          isOpen: source.isOpen,
          openTime: source.openTime,
          closeTime: source.closeTime,
        );
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.primaryGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        content: Text(
          "Applied ${source.name}'s hours to all days",
          style: const TextStyle(fontSize: 13, color: Colors.white),
        ),
      ),
    );
  }

  void _saveChanges() {
    if (_formKey.currentState!.validate()) {
      ref
          .read(vendorStallProvider.notifier)
          .updateStall(
            name: _nameController.text.trim(),
            description: _descriptionController.text.trim(),
            category: _selectedCategory,
            bannerImage: _bannerImage ?? '',
            avatarImage: _avatarImage ?? '',
            thumbnailImage: _thumbnailImage ?? '',
            schedule: List.from(_schedules),
          );

      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: const Text(
            'Stall settings and operating hours saved!',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthGuard(
      allowedRoles: {UserRole.vendor},
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              const AppScreenHeader(title: 'Stall Settings'),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StallPhotoEditor(
                          bannerImage: _bannerImage,
                          avatarImage: _avatarImage,
                          thumbnailImage: _thumbnailImage,
                          onBannerChanged: (url) =>
                              setState(() => _bannerImage = url),
                          onAvatarChanged: (url) =>
                              setState(() => _avatarImage = url),
                          onThumbnailChanged: (url) =>
                              setState(() => _thumbnailImage = url),
                        ),
                        const SizedBox(height: 24),
                        StallInfoForm(
                          nameController: _nameController,
                          descriptionController: _descriptionController,
                          locationController: _locationController,
                          selectedCategory: _selectedCategory,
                          categories: _categories,
                          onCategoryChanged: (category) =>
                              setState(() => _selectedCategory = category),
                        ),
                        const SizedBox(height: 32),
                        OperatingHoursEditor(
                          schedules: _schedules,
                          onApplyDayToAll: _applyDayToAll,
                          onChanged: () => setState(() {}),
                        ),
                        const SizedBox(height: 32),
                        StallSettingsSaveButton(onSave: _saveChanges),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
