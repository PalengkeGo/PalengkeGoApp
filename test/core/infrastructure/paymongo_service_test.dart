import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/core/infrastructure/paymongo_service.dart';

void main() {
  group('PayMongoService.mapMethodToType', () {
    test('maps app payment ids to PayMongo types', () {
      expect(PayMongoService.mapMethodToType('gcash'), 'gcash');
      expect(PayMongoService.mapMethodToType('paymaya'), 'maya');
      expect(PayMongoService.mapMethodToType('maya'), 'maya');
    });

    test('returns null for cash methods and unknown ids', () {
      expect(PayMongoService.mapMethodToType('cod'), isNull);
      expect(PayMongoService.mapMethodToType('cop'), isNull);
      expect(PayMongoService.mapMethodToType('card'), isNull); // needs details
      expect(PayMongoService.mapMethodToType('bitcoin'), isNull);
    });
  });

  group('PayMongoService.redirectUrlFromAttachResponse', () {
    test('extracts the e-wallet redirect url', () {
      const body = {
        'data': {
          'id': 'int_123',
          'attributes': {
            'status': 'awaiting_next_action',
            'next_action': {
              'redirect': {
                'url': 'https://test-paymongo.net/redirect/id_abc',
                'type': 'gcash',
              },
            },
          },
        },
      };
      expect(
        PayMongoService.redirectUrlFromAttachResponse(body),
        'https://test-paymongo.net/redirect/id_abc',
      );
    });

    test('returns null when no redirect is required', () {
      const body = {
        'data': {
          'id': 'int_123',
          'attributes': {'status': 'processing'},
        },
      };
      expect(PayMongoService.redirectUrlFromAttachResponse(body), isNull);
    });

    test('returns null for malformed bodies', () {
      expect(PayMongoService.redirectUrlFromAttachResponse({}), isNull);
      expect(
        PayMongoService.redirectUrlFromAttachResponse({
          'data': {'attributes': null},
        }),
        isNull,
      );
      expect(
        PayMongoService.redirectUrlFromAttachResponse({
          'data': {
            'attributes': {
              'next_action': {
                'redirect': {'url': ''},
              },
            },
          },
        }),
        isNull,
      );
    });
  });

  test('CardPaymentUnsupportedError explains the limitation', () {
    expect(
      CardPaymentUnsupportedError().toString(),
      contains('GCash/Maya'),
    );
  });
}
