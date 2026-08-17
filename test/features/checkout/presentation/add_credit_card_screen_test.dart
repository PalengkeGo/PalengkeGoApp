import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:palengkego/features/checkout/domain/payment_selection.dart';
import 'package:palengkego/features/checkout/presentation/pages/add_credit_card_screen.dart';

void main() {
  testWidgets('renders all card fields without the obscured-field assertion', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddCreditCardScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Add Card'), findsOneWidget);
    expect(find.text('Card Number'), findsOneWidget);
    expect(find.text('Security code'), findsOneWidget);
    expect(find.text('Expiration date'), findsOneWidget);
    expect(find.text('Cardholder name'), findsOneWidget);
  });

  testWidgets('save shows validation errors when fields are empty', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: AddCreditCardScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Card number is required'), findsOneWidget);
    expect(find.text('Security code is required'), findsOneWidget);
    expect(find.text('Expiry date is required'), findsOneWidget);
    expect(find.text('Cardholder name is required'), findsOneWidget);
  });

  testWidgets('valid form pops with CardSelectionData', (tester) async {
    CardSelectionData? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                result = await Navigator.of(context).push<CardSelectionData>(
                  MaterialPageRoute(
                    builder: (_) => const AddCreditCardScreen(),
                  ),
                );
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Enter card number'),
      '4242424242424242',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'MM/YY'),
      '12/30',
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'CVV/CVC'), '123');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Juan Dela Cruz',
    );

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.last4, '4242');
    expect(result!.brand, 'Visa');
    expect(result!.expiry, '12/30');
    expect(result!.cardholderName, 'Juan Dela Cruz');
  });
}
