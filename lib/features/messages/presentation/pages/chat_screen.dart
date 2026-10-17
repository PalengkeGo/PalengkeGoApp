import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/messages/application/messaging_provider.dart';
import 'package:palengkego/features/messages/presentation/widgets/chat_bubble.dart';
import 'package:palengkego/features/messages/presentation/widgets/chat_composer.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final String displayName;
  final bool isVendorView;
  final String? inquiryType;
  final String? relatedOrderId;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.displayName,
    required this.isVendorView,
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

  void _markRead() {
    ref.read(messagingActionsProvider).markAsRead(
          conversationId: widget.conversationId,
          readerRole: widget.isVendorView ? 'vendor' : 'customer',
        );
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

      await ref.read(messagingActionsProvider).sendMessage(
            conversationId: widget.conversationId,
            senderId: senderId,
            senderName: senderName,
            senderRole: senderRole,
            text: text,
            attachmentUrl: attachmentUrl,
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

  @override
  Widget build(BuildContext context) {
    final messagesAsync =
        ref.watch(conversationMessagesProvider(widget.conversationId));

    // Listen to messages change to auto-scroll and mark read
    ref.listen(conversationMessagesProvider(widget.conversationId),
        (previous, next) {
      if (next.hasValue) {
        _scrollToBottom();
        _markRead();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: _buildAppBar(context),
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
                child: CircularProgressIndicator(
                  color: AppTheme.primaryGreen,
                ),
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

                    return ChatBubble(
                      message: message,
                      isOutgoing: isOutgoing,
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
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
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
          // Composer
          ChatComposer(
            onSend: _handleSend,
            isSending: _isSending,
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
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
          Container(
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
          ),
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
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
