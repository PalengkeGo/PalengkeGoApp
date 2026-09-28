import 'dart:io';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/config/categories.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/widgets/app_screen_header.dart';
import 'package:palengkego/core/infrastructure/supabase_storage_service.dart';
import 'package:palengkego/core/widgets/async_view.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/features/vendors/domain/day_schedule.dart';
import 'package:palengkego/core/utils/image_picker_helper.dart';
import 'package:palengkego/features/vendors/domain/vendor_stall.dart';
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
  bool _userHasEdited = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _locationController = TextEditingController();

    _nameController.addListener(() => _userHasEdited = true);
    _descriptionController.addListener(() => _userHasEdited = true);
    _locationController.addListener(() => _userHasEdited = true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _populateFromStall(ref.read(vendorStallProvider));
    });
  }

  void _populateFromStall(VendorStall stall) {
    if (_nameController.text.isEmpty || !_userHasEdited) {
      _nameController.text = stall.name;
    }
    if (_descriptionController.text.isEmpty || !_userHasEdited) {
      _descriptionController.text = stall.description;
    }
    if (_locationController.text.isEmpty || !_userHasEdited) {
      _locationController.text = stall.location;
    }
    if (!_userHasEdited) {
      _selectedCategory = stall.category;
      _bannerImage = stall.bannerImage;
      _avatarImage = stall.avatarImage;
      _thumbnailImage = stall.thumbnailImage;
      if (stall.schedule.isNotEmpty) {
        _schedules.clear();
        _schedules.addAll(stall.schedule);
      }
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _applyDayToAll(int sourceIndex) {
    _userHasEdited = true;
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

  Future<String?> _ensureUploaded(String? pathOrUrl, String type) async {
    if (pathOrUrl == null || pathOrUrl.isEmpty) return pathOrUrl;
    if (pathOrUrl.startsWith('http://') ||
        pathOrUrl.startsWith('https://') ||
        pathOrUrl.startsWith('data:') ||
        pathOrUrl.startsWith('assets/')) {
      return pathOrUrl;
    }
    try {
      final clean = pathOrUrl.replaceFirst('file://', '');
      final file = File(clean);
      if (file.existsSync()) {
        final vendorId = ref.read(currentVendorIdProvider) ?? 'v1';
        final storage = ref.read(supabaseStorageServiceProvider);
        final url = await storage.uploadFile(
          bucket: SupabaseStorageService.stallsBucket,
          path: '$vendorId/${SupabaseStorageService.objectName(type, file)}',
          file: file,
        );
        if (url != null && url.isNotEmpty) {
          return url;
        }
        final dataUri = await ImagePickerHelper.fileToDataUri(file);
        if (dataUri != null && dataUri.isNotEmpty) {
          return dataUri;
        }
      }
    } catch (e) {
      debugPrint('Failed to upload $type before save: $e');
      try {
        final clean = pathOrUrl.replaceFirst('file://', '');
        final file = File(clean);
        if (file.existsSync()) {
          final dataUri = await ImagePickerHelper.fileToDataUri(file);
          if (dataUri != null && dataUri.isNotEmpty) {
            return dataUri;
          }
        }
      } catch (_) {}
    }
    return pathOrUrl;
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AsyncLoadingView(),
    );

    final bannerUploaded = await _ensureUploaded(_bannerImage, 'banner');
    final avatarUploaded = await _ensureUploaded(_avatarImage, 'avatar');
    final thumbUploaded = await _ensureUploaded(_thumbnailImage, 'thumbnail');

    await ref
        .read(vendorStallProvider.notifier)
        .updateStall(
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          category: _selectedCategory,
          bannerImage: bannerUploaded,
          avatarImage: avatarUploaded,
          thumbnailImage: thumbUploaded,
          schedule: List.from(_schedules),
        );

    if (!mounted) return;
    Navigator.pop(context); // Close loading dialog

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

  @override
  Widget build(BuildContext context) {
    ref.listen<VendorStall>(vendorStallProvider, (prev, next) {
      if (!_userHasEdited) {
        _populateFromStall(next);
      }
    });

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
                          onBannerChanged: (url) {
                            _userHasEdited = true;
                            setState(() => _bannerImage = url);
                          },
                          onAvatarChanged: (url) {
                            _userHasEdited = true;
                            setState(() => _avatarImage = url);
                          },
                          onThumbnailChanged: (url) {
                            _userHasEdited = true;
                            setState(() => _thumbnailImage = url);
                          },
                        ),
                        const SizedBox(height: 24),
                        StallInfoForm(
                          nameController: _nameController,
                          descriptionController: _descriptionController,
                          locationController: _locationController,
                          selectedCategory: _selectedCategory,
                          categories: _categories,
                          onCategoryChanged: (category) {
                            _userHasEdited = true;
                            setState(() => _selectedCategory = category);
                          },
                        ),
                        const SizedBox(height: 32),
                        OperatingHoursEditor(
                          schedules: _schedules,
                          onApplyDayToAll: _applyDayToAll,
                          onChanged: () {
                            _userHasEdited = true;
                            setState(() {});
                          },
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
