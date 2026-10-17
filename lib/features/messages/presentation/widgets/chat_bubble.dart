import 'dart:convert';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/messages/domain/chat_message.dart';

class ChatBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOutgoing;

  const ChatBubble({
    super.key,
    required this.message,
    required this.isOutgoing,
  });

  Widget _errorPlaceholder() {
    return Container(
      width: 180,
      height: 120,
      color: Colors.black12,
      child: const Center(
        child: Icon(
          Icons.broken_image_rounded,
          color: AppTheme.muted,
          size: 32,
        ),
      ),
    );
  }

  void _openFullScreenImage(BuildContext context, String url) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          Widget img;
          if (url.startsWith('data:image')) {
            try {
              final commaIndex = url.indexOf(',');
              final base64String =
                  commaIndex != -1 ? url.substring(commaIndex + 1) : url;
              img = Image.memory(base64Decode(base64String));
            } catch (_) {
              img = const Icon(
                Icons.broken_image_rounded,
                color: Colors.white70,
                size: 64,
              );
            }
          } else if (url.startsWith('http://') || url.startsWith('https://')) {
            img = CachedNetworkImage(
              imageUrl: url,
              errorWidget: (context, url, error) => const Icon(
                Icons.broken_image_rounded,
                color: Colors.white70,
                size: 64,
              ),
            );
          } else {
            final f = File(url);
            img = f.existsSync()
                ? Image.file(f)
                : const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white70,
                    size: 64,
                  );
          }

          return Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: img,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildAttachment(BuildContext context) {
    final url = message.attachmentUrl!;
    Widget imageWidget;

    if (url.startsWith('data:image')) {
      try {
        final commaIndex = url.indexOf(',');
        final base64String =
            commaIndex != -1 ? url.substring(commaIndex + 1) : url;
        final bytes = base64Decode(base64String);
        imageWidget = Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
        );
      } catch (_) {
        imageWidget = _errorPlaceholder();
      }
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      imageWidget = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.black12,
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (context, url, error) => _errorPlaceholder(),
      );
    } else {
      final file = File(url);
      if (file.existsSync()) {
        imageWidget = Image.file(
          file,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _errorPlaceholder(),
        );
      } else {
        imageWidget = _errorPlaceholder();
      }
    }

    return GestureDetector(
      onTap: () => _openFullScreenImage(context, url),
      child: Container(
        margin: EdgeInsets.only(bottom: message.text.isNotEmpty ? 6 : 4),
        constraints: const BoxConstraints(
          maxHeight: 220,
          minHeight: 120,
          minWidth: 160,
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.black.withValues(alpha: 0.05),
        ),
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.passthrough,
          children: [
            imageWidget,
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.zoom_in_rounded,
                  color: Colors.white,
                  size: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('h:mm a').format(message.timestamp);

    return Align(
      alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isOutgoing
                ? AppTheme.primaryGreen
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isOutgoing ? 16 : 4),
              bottomRight: Radius.circular(isOutgoing ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: isOutgoing
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Photo Attachment if present
              if (message.hasAttachment) ...[
                _buildAttachment(context),
              ],
              // Text Content if present
              if (message.text.isNotEmpty) ...[
                Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: isOutgoing
                        ? Colors.white
                        : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isOutgoing
                          ? Colors.white.withValues(alpha: 0.7)
                          : AppTheme.muted,
                    ),
                  ),
                  if (isOutgoing) ...[
                    const SizedBox(width: 4),
                    Icon(
                      message.isRead
                          ? Icons.done_all_rounded
                          : Icons.done_rounded,
                      size: 13,
                      color: message.isRead
                          ? const Color(0xFF6EE7B7)
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
