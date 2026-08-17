import 'package:palengkego/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'package:palengkego/features/vendors/presentation/widgets/block_vendor_dialog.dart';
import 'package:palengkego/features/vendors/presentation/widgets/report_vendor_dialog.dart';

class VendorProfileTopBar extends StatelessWidget {
  const VendorProfileTopBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SizedBox(
        height: 32,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _circleButton(
                icon: Icons.arrow_back_ios_new_rounded,
                onTap: () => Navigator.pop(context),
              ),
            ),
            const Text(
              'Stall Holder Profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.primaryGreen,
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: Colors.white,
                onSelected: (value) async {
                  if (value == 'flag') {
                    final reason = await ReportVendorDialog.show(
                      context,
                      'this stall holder',
                    );
                    if (reason != null && reason.isNotEmpty) {
                      AppServices.showSnackBar(
                        'Stall Holder reported successfully.',
                      );
                    }
                  } else if (value == 'block') {
                    final confirmed = await BlockVendorDialog.show(
                      context,
                      vendorName: 'this stall holder',
                    );
                    if (confirmed == true) {
                      AppServices.showSnackBar(
                        'Stall Holder blocked successfully.',
                      );
                    }
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  const PopupMenuItem<String>(
                    value: 'flag',
                    child: Row(
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          color: Colors.redAccent,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text('Report Stall Holder'),
                      ],
                    ),
                  ),
                  const PopupMenuItem<String>(
                    value: 'block',
                    child: Row(
                      children: [
                        Icon(Icons.block, color: Colors.black54, size: 20),
                        SizedBox(width: 8),
                        Text('Block Stall Holder'),
                      ],
                    ),
                  ),
                ],
                child: _circleButton(icon: Icons.more_vert_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AppTheme.scaffoldBackground,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: AppTheme.primaryGreen),
      ),
    );
  }
}
