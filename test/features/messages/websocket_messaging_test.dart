import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/messages/data/websocket_messaging_service.dart';

void main() {
  group('WebSocketMessagingService Tests', () {
    test('isAvailable returns false when client is null', () {
      final service = WebSocketMessagingService(client: null);
      expect(service.isAvailable, false);
    });

    test('watchTyping emits stream events correctly', () async {
      final service = WebSocketMessagingService(client: null);

      final stream = service.watchTyping('conv-1', 'user-1');
      expect(stream, isNotNull);

      // Verify channel unsubscribe cleanups
      service.unsubscribe('conv-1');
      service.dispose();
    });

    test('sendTyping without active channel completes safely without error', () async {
      final service = WebSocketMessagingService(client: null);

      await expectLater(
        service.sendTyping(
          conversationId: 'conv-999',
          senderId: 'user-1',
          isTyping: true,
        ),
        completes,
      );

      service.dispose();
    });
  });
}
