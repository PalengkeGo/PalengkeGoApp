import 'dart:io';
import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/utils/image_url_resolver.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/messages/application/messaging_provider.dart';
import 'package:palengkego/features/messages/domain/chat_message.dart';
import 'package:palengkego/features/messages/presentation/widgets/chat_bubble.dart';
import 'package:palengkego/features/messages/presentation/widgets/chat_composer.dart';
import 'package:palengkego/features/vendors/application/vendor_provider.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String displayName;
  final bool isVendorView;
  final String? stallId;
  final String? avatarUrl;
  final String? inquiryType;
  final String? relatedOrderId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.displayName,
    required this.isVendorView,
    this.stallId,
    this.avatarUrl,
    this.inquiryType,
    this.relatedOrderId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  String? _sendError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markRead();
    });
  }

  Future<void> _markRead() async {
    try {
      await ref
          .read(messagingActionsProvider)
          .markAsRead(
            conversationId: widget.conversationId,
            readerRole: widget.isVendorView ? 'vendor' : 'customer',
          );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not update read receipts. Please try again.'),
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _handleSend(String text, [String? attachmentUrl]) async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _sendError = null;
    });

    try {
      final user = ref.read(authProvider);
      final stall = ref.read(vendorStallProvider);

      final senderId = widget.isVendorView
          ? (stall.stallId.isNotEmpty ? stall.stallId : 'v1')
          : (user?.uid ?? 'customer-001');

      final senderName = widget.isVendorView
          ? (stall.name.isNotEmpty ? stall.name : "Mer's Mayao Fruit Stand")
          : (user?.displayName ?? 'Customer');

      final senderRole = widget.isVendorView ? 'vendor' : 'customer';

      String? resolvedAttachmentUrl = attachmentUrl;
      final chatClient = ref.read(messagingClientProvider);
      if (attachmentUrl != null && chatClient != null) {
        if (user == null) throw StateError('Sign in to attach photos.');
        final isData = attachmentUrl.startsWith('data:');
        final mime = isData
            ? UriData.parse(attachmentUrl).mimeType
            : (attachmentUrl.toLowerCase().endsWith('.png')
                  ? 'image/png'
                  : attachmentUrl.toLowerCase().endsWith('.webp')
                  ? 'image/webp'
                  : 'image/jpeg');
        final bytes = isData
            ? base64Decode(
                attachmentUrl.substring(attachmentUrl.indexOf(',') + 1),
              )
            : await File(attachmentUrl).readAsBytes();
        final path =
            '${widget.conversationId}/${user.uid}/${DateTime.now().microsecondsSinceEpoch}';
        await chatClient.storage
            .from('chat-attachments')
            .uploadBinary(
              path,
              bytes,
              fileOptions: FileOptions(contentType: mime),
            );
        resolvedAttachmentUrl = 'chat-attachments/$path';
      }

      await ref
          .read(messagingActionsProvider)
          .sendMessage(
            conversationId: widget.conversationId,
            senderId: senderId,
            senderName: senderName,
            senderRole: senderRole,
            text: text,
            attachmentUrl: resolvedAttachmentUrl,
          );

      _scrollToBottom();
    } catch (e) {
      setState(() {
        _sendError = 'Message failed to send. Tap to retry.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _handleTypingChanged(bool isTyping) {
    try {
      final user = ref.read(authProvider);
      final stall = ref.read(vendorStallProvider);
      final senderId = widget.isVendorView
          ? (stall.stallId.isNotEmpty ? stall.stallId : 'v1')
          : (user?.uid ?? 'customer-001');

      ref
          .read(messagingActionsProvider)
          .sendTyping(
            conversationId: widget.conversationId,
            senderId: senderId,
            isTyping: isTyping,
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      conversationMessagesProvider(widget.conversationId),
    );
    final isTyping =
        ref.watch(conversationTypingProvider(widget.conversationId)).value ??
        false;

    String? effectiveAvatarUrl = widget.avatarUrl;
    if (!widget.isVendorView) {
      final stallLookupKey =
          (widget.stallId != null && widget.stallId!.trim().isNotEmpty)
          ? widget.stallId!.trim()
          : widget.displayName.trim();
      if (stallLookupKey.isNotEmpty) {
        final vendorProfile = ref
            .watch(vendorProfileProvider(stallLookupKey))
            .asData
            ?.value;
        if (vendorProfile != null) {
          final profileAvatar = vendorProfile.avatarUrl.trim().isNotEmpty
              ? vendorProfile.avatarUrl.trim()
              : vendorProfile.imageUrl.trim();
          if (profileAvatar.isNotEmpty) {
            effectiveAvatarUrl = profileAvatar;
          }
        }
      }
    }
    if (effectiveAvatarUrl != null && effectiveAvatarUrl.trim().isNotEmpty) {
      effectiveAvatarUrl =
          resolveImageUrl(
            effectiveAvatarUrl.trim(),
            client: ref.watch(supabaseClientProvider),
          ) ??
          effectiveAvatarUrl.trim();
    }

    // Listen to messages change to auto-scroll and mark read
    ref.listen(conversationMessagesProvider(widget.conversationId), (
      previous,
      next,
    ) {
      if (next.hasValue) {
        _scrollToBottom();
        _markRead();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: _buildAppBar(context, effectiveAvatarUrl),
      body: Column(
        children: [
          // Optional Inquiry Banner
          if (widget.relatedOrderId != null ||
              (widget.inquiryType != null &&
                  widget.inquiryType != 'general')) ...[
            _buildInquiryBanner(),
          ],
          // Message List
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryGreen),
              ),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Color(0xFFEF4444),
                        size: 36,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Could not load messages: $error',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(
                          conversationMessagesProvider(widget.conversationId),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10,
                          ),
                          minimumSize: Size.zero,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (messages) {
                if (messages.isEmpty) {
                  return _buildEmptyChat();
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isOutgoing = widget.isVendorView
                        ? message.senderRole == 'vendor'
                        : message.senderRole == 'customer';
                    final showDateHeader = _shouldShowDateHeader(
                      messages,
                      index,
                    );

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showDateHeader) _buildDateHeader(message.timestamp),
                        ChatBubble(message: message, isOutgoing: isOutgoing),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          if (_sendError != null)
            GestureDetector(
              onTap: () {
                // Retry banner
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please re-enter your message and send.'),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 6,
                  horizontal: 16,
                ),
                color: const Color(0xFFFEF2F2),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: Color(0xFFEF4444),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _sendError!,
                        style: const TextStyle(
                          color: Color(0xFFB91C1C),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (isTyping)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${widget.displayName} is typing...',
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          // Composer
          ChatComposer(
            onSend: _handleSend,
            isSending: _isSending,
            onTypingChanged: _handleTypingChanged,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String? avatarUrl) {
    final fallbackAvatar = Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(0xFFE8F5E9),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        widget.displayName.trim().isNotEmpty
            ? widget.displayName.trim()[0].toUpperCase()
            : 'P',
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: AppTheme.primaryGreen,
        ),
      ),
    );

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      leading: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.of(context).pop(),
        child: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppTheme.primaryGreen,
          size: 18,
        ),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
            SizedBox(
              width: 36,
              height: 36,
              child: ClipOval(
                child: AdaptiveImage(
                  avatarUrl,
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  placeholder: fallbackAvatar,
                ),
              ),
            )
          else
            fallbackAvatar,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryGreen,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  widget.isVendorView ? 'Customer' : 'Stall Holder',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInquiryBanner() {
    String label;
    IconData icon;
    Color color;

    if (widget.relatedOrderId != null || widget.inquiryType == 'order') {
      label = widget.relatedOrderId != null
          ? 'Related to Order #${widget.relatedOrderId}'
          : 'Order Inquiry';
      icon = Icons.receipt_long_outlined;
      color = const Color(0xFF166534);
    } else if (widget.inquiryType == 'delivery') {
      label = 'Delivery Inquiry';
      icon = Icons.local_shipping_outlined;
      color = const Color(0xFFB45309);
    } else {
      label = 'Product Inquiry';
      icon = Icons.shopping_cart_outlined;
      color = const Color(0xFF4338CA);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDateHeader(List<ChatMessage> messages, int index) {
    if (index == 0) return true;
    final current = messages[index].timestamp.toLocal();
    final previous = messages[index - 1].timestamp.toLocal();

    final isDifferentDay =
        current.year != previous.year ||
        current.month != previous.month ||
        current.day != previous.day;
    if (isDifferentDay) return true;

    return current.difference(previous).inMinutes.abs() >= 15;
  }

  String _formatMessengerTimestamp(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(local.year, local.month, local.day);
    final diffDays = today.difference(messageDate).inDays;
    final timePart = DateFormat('h:mm a').format(local);

    if (diffDays == 0) {
      return 'TODAY, ${DateFormat('MMM d').format(local).toUpperCase()} AT $timePart';
    } else if (diffDays == 1) {
      return 'YESTERDAY, ${DateFormat('MMM d').format(local).toUpperCase()} AT $timePart';
    } else if (local.year == now.year) {
      return '${DateFormat('EEE, MMM d').format(local).toUpperCase()} AT $timePart';
    } else {
      return '${DateFormat('MMM d, yyyy').format(local).toUpperCase()} AT $timePart';
    }
  }

  Widget _buildDateHeader(DateTime timestamp) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            _formatMessengerTimestamp(timestamp),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyChat() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                color: AppTheme.primaryGreen,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No messages yet',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Send a message to start the conversation.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
