import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/utils/image_picker_helper.dart';

class ChatComposer extends StatefulWidget {
  final Future<void> Function(String text, [String? attachmentUrl]) onSend;
  final bool isSending;

  const ChatComposer({
    super.key,
    required this.onSend,
    this.isSending = false,
  });

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  late final TextEditingController _controller;
  bool _canSend = false;
  File? _selectedImageFile;
  String? _selectedImageDataUri;
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    final hasAttachment = _selectedImageDataUri != null || _selectedImageFile != null;
    final canSend = (hasText || hasAttachment) && !widget.isSending && !_isPicking;
    if (canSend != _canSend) {
      setState(() => _canSend = canSend);
    }
  }

  @override
  void didUpdateWidget(covariant ChatComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSending != widget.isSending) {
      _onTextChanged();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _showSourceSelectionSheet() async {
    if (widget.isSending || _isPicking) return;

    final source = await showModalBottomSheet<AttachmentSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Attach Photo',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 20),
              // Option 1: Camera
              _AttachSourceTile(
                icon: Icons.camera_alt_rounded,
                label: 'Take Photo (Camera)',
                subtitle: 'Capture a photo with your device camera',
                onTap: () => Navigator.pop(ctx, AttachmentSource.camera),
              ),
              const SizedBox(height: 12),
              // Option 2: Gallery
              _AttachSourceTile(
                icon: Icons.photo_library_rounded,
                label: 'Choose from Gallery (Photos)',
                subtitle: 'Select an existing image from your library',
                onTap: () => Navigator.pop(ctx, AttachmentSource.gallery),
              ),
              const SizedBox(height: 16),
              // Cancel
              _AttachSourceTile(
                icon: Icons.close_rounded,
                label: 'Cancel',
                isDestructive: true,
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;

    setState(() => _isPicking = true);
    try {
      final file = await ImagePickerHelper.pickImageFromSource(source);
      if (file != null && mounted) {
        final dataUri = await ImagePickerHelper.fileToDataUri(file);
        setState(() {
          _selectedImageFile = file;
          _selectedImageDataUri = dataUri ?? file.path;
        });
        _onTextChanged();
      }
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
        _onTextChanged();
      }
    }
  }

  void _removeAttachment() {
    setState(() {
      _selectedImageFile = null;
      _selectedImageDataUri = null;
    });
    _onTextChanged();
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    final attachment = _selectedImageDataUri;
    if ((text.isEmpty && attachment == null) || widget.isSending || _isPicking) {
      return;
    }

    _controller.clear();
    setState(() {
      _selectedImageFile = null;
      _selectedImageDataUri = null;
      _canSend = false;
    });

    await widget.onSend(text, attachment);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppTheme.border,
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Attachment Preview
          if (_selectedImageFile != null || _selectedImageDataUri != null) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 8, left: 4),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      color: const Color(0xFFF1F5F9),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _selectedImageFile != null && !kIsWeb
                        ? Image.file(
                            _selectedImageFile!,
                            fit: BoxFit.cover,
                          )
                        : const Center(
                            child: Icon(
                              Icons.image_rounded,
                              color: AppTheme.primaryGreen,
                              size: 32,
                            ),
                          ),
                  ),
                  Positioned(
                    top: -6,
                    right: -6,
                    child: GestureDetector(
                      onTap: _removeAttachment,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Composer Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Attachment Action Button
              Container(
                margin: const EdgeInsets.only(right: 6, bottom: 2),
                child: IconButton(
                  key: const Key('chat_attachment_button'),
                  tooltip: 'Attach photo',
                  onPressed: widget.isSending || _isPicking
                      ? null
                      : _showSourceSelectionSheet,
                  icon: _isPicking
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.primaryGreen,
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.attach_file_rounded,
                          color: AppTheme.primaryGreen,
                          size: 24,
                        ),
                  splashRadius: 22,
                ),
              ),
              // Text Field Container
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: TextField(
                    controller: _controller,
                    keyboardType: TextInputType.multiline,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: (_selectedImageFile != null ||
                              _selectedImageDataUri != null)
                          ? 'Add a caption...'
                          : 'Type a message...',
                      hintStyle: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF94A3B8),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _handleSend(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Send Button
              GestureDetector(
                key: const Key('chat_send_button'),
                onTap: _canSend ? _handleSend : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _canSend
                        ? AppTheme.primaryGreen
                        : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: widget.isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(
                          Icons.send_rounded,
                          size: 18,
                          color: _canSend
                              ? Colors.white
                              : const Color(0xFF94A3B8),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AttachSourceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _AttachSourceTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive
        ? const Color(0xFFEF4444)
        : AppTheme.primaryGreen;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDestructive
              ? const Color(0xFFFEF2F2)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDestructive
                ? const Color(0xFFFECACA)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDestructive
                    ? const Color(0xFFFEE2E2)
                    : AppTheme.primaryGreen.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDestructive
                          ? const Color(0xFFEF4444)
                          : const Color(0xFF1E293B),
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
