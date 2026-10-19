import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/presentation/widgets/adaptive_image.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/utils/page_transitions.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/messages/application/messaging_provider.dart';
import 'package:palengkego/features/messages/domain/chat_conversation.dart';
import 'package:palengkego/features/messages/presentation/pages/chat_screen.dart';
import 'package:palengkego/features/messages/presentation/widgets/conversation_card.dart';
import 'package:palengkego/features/messages/presentation/widgets/messages_filter_chips.dart';
import 'package:palengkego/features/notifications/application/notification_provider.dart';
import 'package:palengkego/features/notifications/presentation/pages/notifications_screen.dart';
import 'package:palengkego/features/vendors/application/vendor_stall_provider.dart';
import 'package:palengkego/features/vendors/presentation/pages/vendor_notifications_screen.dart';

class MessagesInboxScreen extends ConsumerStatefulWidget {
  final bool isEmbeddedInTab;

  const MessagesInboxScreen({
    super.key,
    this.isEmbeddedInTab = true,
  });

  @override
  ConsumerState<MessagesInboxScreen> createState() => _MessagesInboxScreenState();
}

class _MessagesInboxScreenState extends ConsumerState<MessagesInboxScreen> {
  MessageFilter _selectedFilter = MessageFilter.all;
  String _searchQuery = '';
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider);
    final isVendor = user?.isVendor ?? true;
    final stall = ref.watch(vendorStallProvider);

    final conversationsAsync = isVendor
        ? ref.watch(vendorConversationsProvider)
        : ref.watch(customerConversationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header Bar matching reference image
            _buildHeader(context, ref, isVendor, stall.avatarImage),
            // Search Bar
            _buildSearchBar(),
            // Content
            Expanded(
              child: conversationsAsync.when(
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
                          size: 40,
                          color: Color(0xFFEF4444),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Error loading messages: $error',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (allConversations) {
                  return _buildConversationContent(
                    context,
                    allConversations,
                    isVendor,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    bool isVendor,
    String? stallAvatar,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          if (!widget.isEmbeddedInTab) ...[
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 36,
                height: 36,
                margin: const EdgeInsets.only(right: 12),
                decoration: const BoxDecoration(
                  color: AppTheme.scaffoldBackground,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: AppTheme.primaryGreen,
                ),
              ),
            ),
          ],
          // Left: Stall icon/avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              image: (stallAvatar != null &&
                      stallAvatar.isNotEmpty &&
                      adaptiveImageProvider(stallAvatar) != null)
                  ? DecorationImage(
                      image: adaptiveImageProvider(stallAvatar)!,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: (stallAvatar == null || stallAvatar.isEmpty)
                ? const Icon(
                    Icons.storefront_outlined,
                    color: Colors.white,
                    size: 20,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          // Subtitle + Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVendor ? 'PalengkeGo Stall Holder' : 'PalengkeGo Customer',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.muted,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
          // Notification Bell
          Consumer(
            builder: (context, ref, _) {
              final notifService = ref.read(notificationServiceProvider);
              return ListenableBuilder(
                listenable: notifService,
                builder: (context, _) {
                  final unread = isVendor
                      ? notifService.vendorUnreadCount
                      : notifService.customerUnreadCount;

                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        PageTransitions.slideFromRight(
                          isVendor
                              ? const VendorNotificationsScreen()
                              : const NotificationsScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppTheme.scaffoldBackground,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Stack(
                        children: [
                          const Center(
                            child: Icon(
                              Icons.notifications_outlined,
                              color: AppTheme.primaryGreen,
                              size: 20,
                            ),
                          ),
                          if (unread > 0)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            const Icon(
              Icons.search_rounded,
              color: Color(0xFF64748B),
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                ),
                decoration: const InputDecoration(
                  hintText: 'Search messages, customers, or orders...',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF94A3B8),
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: const Icon(
                  Icons.close_rounded,
                  color: Color(0xFF94A3B8),
                  size: 18,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationContent(
    BuildContext context,
    List<ChatConversation> allConversations,
    bool isVendor,
  ) {
    // Filter by tab
    final unreadList = allConversations.where((c) {
      final unread = isVendor ? c.vendorUnreadCount : c.customerUnreadCount;
      return unread > 0;
    }).toList();

    final ordersList = allConversations.where((c) {
      return c.inquiryType == 'order' || c.relatedOrderId != null;
    }).toList();

    List<ChatConversation> filteredList;
    switch (_selectedFilter) {
      case MessageFilter.all:
        filteredList = allConversations;
        break;
      case MessageFilter.unread:
        filteredList = unreadList;
        break;
      case MessageFilter.orders:
        filteredList = ordersList;
        break;
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      filteredList = filteredList.where((c) {
        final name = (isVendor ? c.customerName : c.stallName).toLowerCase();
        final text = c.lastMessageText.toLowerCase();
        final orderId = c.relatedOrderId?.toLowerCase() ?? '';
        return name.contains(query) ||
            text.contains(query) ||
            orderId.contains(query);
      }).toList();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter Chips Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: MessagesFilterChips(
            selectedFilter: _selectedFilter,
            onSelected: (filter) => setState(() => _selectedFilter = filter),
            allCount: allConversations.length,
            unreadCount: unreadList.length,
            ordersCount: ordersList.length,
          ),
        ),
        const SizedBox(height: 14),
        // Conversation List
        Expanded(
          child: filteredList.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 96),
                  itemCount: filteredList.length,
                  itemBuilder: (context, index) {
                    final conv = filteredList[index];
                    return ConversationCard(
                      conversation: conv,
                      isVendorView: isVendor,
                      onTap: () {
                        Navigator.of(context).push(
                          PageTransitions.slideFromRight(
                            ChatScreen(
                              conversationId: conv.id,
                              displayName: isVendor
                                  ? conv.customerName
                                  : conv.stallName,
                              isVendorView: isVendor,
                              inquiryType: conv.inquiryType,
                              relatedOrderId: conv.relatedOrderId,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    String title;
    String subtitle;
    IconData icon;

    if (_searchQuery.isNotEmpty) {
      title = 'No results found';
      subtitle = 'No conversations match "$_searchQuery"';
      icon = Icons.search_off_rounded;
    } else if (_selectedFilter == MessageFilter.unread) {
      title = 'No unread messages';
      subtitle = 'You are all caught up on your conversations.';
      icon = Icons.mark_chat_read_outlined;
    } else if (_selectedFilter == MessageFilter.orders) {
      title = 'No order messages';
      subtitle = 'No conversations linked to customer orders.';
      icon = Icons.receipt_long_outlined;
    } else {
      title = 'No messages yet';
      subtitle = 'Customer questions and order updates will appear here.';
      icon = Icons.chat_bubble_outline_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primaryGreen, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
