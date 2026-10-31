import 'package:palengkego/core/config/app_config.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/core/services/support_chat_client.dart';
import 'package:palengkego/core/theme/app_theme.dart';
import 'package:palengkego/core/utils/image_picker_helper.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/auth/domain/app_user.dart';
import 'package:palengkego/features/auth/presentation/pages/auth_guard.dart';
import 'package:palengkego/features/messages/domain/chat_message.dart';
import 'package:palengkego/features/messages/presentation/widgets/chat_bubble.dart';

final supportChatProvider = Provider.autoDispose<SupportChatClient>((ref) {
  ref.watch(authProvider.select((user) => user?.uid));
  final backend = ref.watch(supabaseClientProvider);
  final auth = ref.watch(firebaseAuthProvider);
  if (backend == null || auth == null) {
    throw StateError('Sign in to message Market Admin.');
  }
  final config = ref.watch(appConfigProvider);
  final api = SupportChatClient(
    backend,
    auth,
    url: config.supabaseUrl,
    anonKey: config.supabaseAnonKey,
  );
  ref.onDispose(api.dispose);
  return api;
});
final supportThreadsProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>(
      (ref) => ref.watch(supportChatProvider).watch('conversations'),
    );
final supportMessagesProvider = StreamProvider.autoDispose
    .family<List<Map<String, dynamic>>, String>(
      (ref, id) => ref.watch(supportChatProvider).watch(id),
    );

class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});
  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  String? _id;
  String? _image;
  String? _error;
  bool _sending = false;
  bool _loadingOlder = false;
  bool _reading = false;
  String? _latest;
  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(String id) async {
    setState(() {
      _id = id;
      _error = null;
      _latest = null;
      _text.clear();
      _image = null;
    });
  }

  Future<void> _read(String id) async {
    if (_reading) return;
    _reading = true;
    try {
      await ref.read(supportChatProvider).markRead(id);
    } catch (error) {
      if (mounted) {
        setState(() => _error = 'Could not mark messages as read. $error');
      }
    } finally {
      _reading = false;
    }
  }

  Future<void> _send() async {
    if (_sending || (_text.text.trim().isEmpty && _image == null)) return;
    final text = _text.text.trim();
    final image = _image;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final api = ref.read(supportChatProvider);
      if (_id == null) {
        if (text.isEmpty) {
          throw StateError(
            'Write your first message before attaching a photo.',
          );
        }
        final response = await api.request('start-conversation', {
          'subject': 'Market administration',
          'message': text,
        });
        final id = (response['conversation'] as Map)['id'].toString();
        if (!mounted) return;
        setState(() {
          _id = id;
          _text.clear();
        });
        // The initial text is already committed. Keep a failed photo in the draft.
        if (image != null) await api.send(id, '', image: image);
        api.refresh('conversations');
      } else {
        await api.send(_id!, text, image: image);
      }
      if (mounted) {
        setState(() {
          _text.clear();
          _image = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _pick() async {
    if (_sending) return;
    final image = await ImagePickerHelper.pickImage(context);
    if (image == null) return;
    final data = await ImagePickerHelper.fileToDataUri(image);
    if (mounted) setState(() => _image = data);
  }

  Future<void> _older() async {
    if (_loadingOlder || _id == null) return;
    setState(() => _loadingOlder = true);
    final extent = _scroll.hasClients ? _scroll.position.maxScrollExtent : 0.0;
    final offset = _scroll.hasClients ? _scroll.offset : 0.0;
    try {
      await ref.read(supportChatProvider).loadOlder(_id!);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.jumpTo(offset + _scroll.position.maxScrollExtent - extent);
        }
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Widget _threads() => ref
      .watch(supportThreadsProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text('$error', textAlign: TextAlign.center),
              ),
              TextButton(
                onPressed: () => ref.invalidate(supportThreadsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (rows) => ListView(
          children: [
            const ListTile(
              title: Text('Market Admin'),
              subtitle: Text(
                'Questions about your stall, permits, or market operations.',
              ),
            ),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Start a conversation using the message box below.',
                ),
              ),
            for (final row in rows)
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE8F5E9),
                  child: Icon(
                    Icons.support_agent,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                title: Text(row['subject'].toString()),
                subtitle: Text(
                  row['last_message'].toString(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: (row['user_unread_count'] as num) > 0
                    ? Badge(label: Text('${row['user_unread_count']}'))
                    : const Icon(Icons.chevron_right),
                onTap: () => _open(row['id'].toString()),
              ),
            if (ref.read(supportChatProvider).hasOlder('conversations'))
              TextButton(
                onPressed: () async {
                  try {
                    await ref
                        .read(supportChatProvider)
                        .loadOlder('conversations');
                  } catch (error) {
                    if (mounted) setState(() => _error = error.toString());
                  }
                },
                child: const Text('Load more conversations'),
              ),
          ],
        ),
      );
  Widget _messages() => ref
      .watch(supportMessagesProvider(_id!))
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$error'),
              TextButton(
                onPressed: () => ref.invalidate(supportMessagesProvider(_id!)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (rows) {
          if (rows.any(
            (row) => row['sender_role'] == 'admin' && row['read_at'] == null,
          )) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _id != null) unawaited(_read(_id!));
            });
          }
          final latest = rows.isEmpty ? null : rows.last['id'].toString();
          if (latest != _latest) {
            final first = _latest == null;
            final nearBottom =
                !_scroll.hasClients || _scroll.position.extentAfter < 120;
            _latest = latest;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scroll.hasClients && (first || nearBottom)) {
                _scroll.jumpTo(_scroll.position.maxScrollExtent);
              }
            });
          }
          return ListView(
            controller: _scroll,
            padding: const EdgeInsets.all(14),
            children: [
              if (ref.read(supportChatProvider).hasOlder(_id!))
                TextButton(
                  onPressed: _loadingOlder ? null : _older,
                  child: Text(
                    _loadingOlder ? 'Loading…' : 'Load older messages',
                  ),
                ),
              for (final row in rows)
                ChatBubble(
                  message: ChatMessage(
                    id: row['id'].toString(),
                    conversationId: _id!,
                    senderId: row['sender_user_id'].toString(),
                    senderName: row['sender_role'] == 'admin'
                        ? 'Market Admin'
                        : 'You',
                    senderRole: row['sender_role'].toString(),
                    text: row['body'].toString(),
                    timestamp: DateTime.parse(
                      row['created_at'].toString(),
                    ).toLocal(),
                    isRead: row['read_at'] != null,
                    attachmentUrl: row['attachment_url'] as String?,
                    attachmentType: row['attachment_url'] == null
                        ? null
                        : 'image',
                  ),
                  isOutgoing: row['sender_role'] == 'vendor',
                ),
            ],
          );
        },
      );
  @override
  Widget build(BuildContext context) => AuthGuard(
    allowedRoles: {UserRole.vendor},
    child: Scaffold(
      backgroundColor: AppTheme.surface,
      appBar: AppBar(
        title: const Text('Market Admin'),
        actions: [
          if (_id != null)
            IconButton(
              tooltip: 'Conversations',
              icon: const Icon(Icons.forum_outlined),
              onPressed: _sending
                  ? null
                  : () => setState(() {
                      _id = null;
                      _latest = null;
                      _text.clear();
                      _image = null;
                    }),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _id == null ? _threads() : _messages()),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          if (_image != null)
            ListTile(
              title: const Text('Photo attached (maximum 2 MB)'),
              trailing: IconButton(
                onPressed: _sending
                    ? null
                    : () => setState(() => _image = null),
                icon: const Icon(Icons.close),
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Attach photo',
                    onPressed: _sending ? null : _pick,
                    icon: const Icon(Icons.attach_file),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      enabled: !_sending,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 4000,
                      decoration: InputDecoration(
                        hintText: _id == null
                            ? 'Start a conversation…'
                            : 'Message Market Admin…',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Send message',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send, color: AppTheme.primaryGreen),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
