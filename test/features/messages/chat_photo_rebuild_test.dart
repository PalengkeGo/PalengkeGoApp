import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/messages/domain/chat_message.dart';
import 'package:palengkego/features/messages/presentation/widgets/chat_bubble.dart';

void main() {
  testWidgets('photo bytes stay identical across bubble and receipt rebuilds', (tester) async {
    final time = DateTime(2026);
    Widget build(bool read) => MaterialApp(home: Scaffold(body: ChatBubble(
      key: const ValueKey('photo'),
      message: ChatMessage(id: 'photo', conversationId: 'thread', senderId: 'user',
        senderName: 'User', senderRole: 'vendor', text: '', timestamp: time, isRead: read,
        attachmentUrl: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aD1sAAAAASUVORK5CYII=',
        attachmentType: 'image'),
      isOutgoing: true)));
    await tester.pumpWidget(build(false));
    final before = tester.widget<Image>(find.byType(Image)).image as MemoryImage;
    await tester.pumpWidget(build(true));
    final image = tester.widget<Image>(find.byType(Image));
    final after = image.image as MemoryImage;
    expect(identical(before.bytes, after.bytes), isTrue);
    expect(image.gaplessPlayback, isTrue);
    expect(tester.takeException(), isNull);
  });
}
