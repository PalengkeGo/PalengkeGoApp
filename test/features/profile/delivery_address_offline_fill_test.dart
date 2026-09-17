import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';
import 'package:palengkego/features/profile/presentation/widgets/delivery_address_form_sheet.dart';

/// Verifies the offline instant-fill behaviour of the delivery address form:
/// when the pin sits near a known Naga City place and the network is
/// unreachable, both fields populate immediately with the nearest place.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() {
    container.dispose();
  });

  testWidgets(
    'fields auto-fill with nearest known place when offline',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      // SM City Naga coordinates — should match the "SM City Naga" landmark.
      const smLat = 13.6218;
      const smLng = 123.1895;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Scaffold(
              body: DeliveryAddressFormSheet(
                scrollController: scrollController,
                initialLatitude: smLat,
                initialLongitude: smLng,
              ),
            ),
          ),
        ),
      );

      // Wait one frame so the postFrameCallback in
      // _reverseGeocodeInitialLocation fires (offline fallback).
      await tester.pump();

      // "PIN DROPPED NEAR" field (hint: 'Enter City/Landmark').
      final primaryField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Enter City/Landmark',
        ),
      );
      expect(
        primaryField.controller?.text,
        'Near SM City Naga, Naga City',
        reason: 'Primary field should fill from offline nearest-place lookup',
      );

      // "STREET ADDRESS" field (TextFormField builds an internal TextField
      // whose hint is 'Unit No., Building, Street Name').
      final streetField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Unit No., Building, Street Name',
        ),
      );
      expect(
        streetField.controller?.text,
        'SM City Naga, Naga City',
        reason: 'Street field should fill the landmark name',
      );
    },
  );

  /// Regression test for the editing flow: when the form is opened via route
  /// args with a saved DeliveryAddress, the initial reverse-geocode must NOT
  /// overwrite the user's saved primary / street fields.
  testWidgets(
    'editing existing address is not overwritten by initial reverse-geocode',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      const savedAddress = DeliveryAddress(
        label: 'Office',
        primaryAddress: 'Robinsons Place Naga, Naga City',
        streetAddress: 'East Diversion Road, Naga City',
        latitude: 13.6166,
        longitude: 123.1990,
      );

      // Build the form sheet as the initial route with a DeliveryAddress
      // argument so didChangeDependencies detects the editing path.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                // Push the form sheet as a route with arguments.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      settings: const RouteSettings(arguments: savedAddress),
                      builder: (_) => Scaffold(
                        body: DeliveryAddressFormSheet(
                          scrollController: scrollController,
                          initialLatitude: savedAddress.latitude,
                          initialLongitude: savedAddress.longitude,
                        ),
                      ),
                    ),
                  );
                });
                return const Scaffold();
              },
            ),
          ),
        ),
      );

      // Pump to let the push() complete and build the form sheet.
      await tester.pump();
      await tester.pump();

      // The form should now exist in the tree with route args.
      expect(find.byType(DeliveryAddressFormSheet), findsOneWidget);

      // "PIN DROPPED NEAR" field (hint: 'Enter City/Landmark').
      final primaryField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Enter City/Landmark',
        ),
      );

      // "STREET ADDRESS" field.
      final streetField = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.hintText == 'Unit No., Building, Street Name',
        ),
      );

      // The saved address fields must survive the initial reverse-geocode.
      expect(
        primaryField.controller?.text,
        'Robinsons Place Naga, Naga City',
        reason: 'Initial reverse-geocode must not overwrite the saved primary',
      );
      expect(
        streetField.controller?.text,
        'East Diversion Road, Naga City',
        reason: 'Initial reverse-geocode must not overwrite the saved street',
      );
    },
  );
}