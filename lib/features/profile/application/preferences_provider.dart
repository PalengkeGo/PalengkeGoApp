import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/core/services/secure_storage_provider.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

class CustomerPreferencesState {
  final DeliveryAddress deliveryAddress;
  final List<DeliveryAddress> savedAddresses;
  final String paymentMethod;
  final String? cardLabel;
  final List<String> blockedStallIds;

  const CustomerPreferencesState({
    required this.deliveryAddress,
    this.savedAddresses = const [],
    required this.paymentMethod,
    this.cardLabel,
    this.blockedStallIds = const [],
  });

  CustomerPreferencesState copyWith({
    DeliveryAddress? deliveryAddress,
    List<DeliveryAddress>? savedAddresses,
    String? paymentMethod,
    String? cardLabel,
    List<String>? blockedStallIds,
  }) {
    return CustomerPreferencesState(
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      savedAddresses: savedAddresses ?? this.savedAddresses,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cardLabel: cardLabel ?? this.cardLabel,
      blockedStallIds: blockedStallIds ?? this.blockedStallIds,
    );
  }

  String get paymentTitle {
    switch (paymentMethod) {
      case 'gcash':
        return 'GCash';
      case 'paymaya':
        return 'PayMaya';
      case 'card':
        return cardLabel ?? 'Saved Card';
      case 'cop':
        return 'Cash on Pickup';
      default:
        return 'Cash on Delivery';
    }
  }

  String get paymentSubtitle {
    switch (paymentMethod) {
      case 'gcash':
        return 'Pay with GCash via Paymongo';
      case 'paymaya':
        return 'Pay with PayMaya via Paymongo';
      case 'card':
        return 'Pay with your saved debit or credit card';
      default:
        return 'Pay when you receive your order';
    }
  }
}

const _kDeliveryAddressKey = 'pref_delivery_address';
const _kSavedAddressesKey = 'pref_saved_addresses';
const _kPaymentMethodKey = 'pref_payment_method';

/// Addresses are PII: persisted in keychain-backed secure storage, while the
/// non-sensitive payment-method choice stays in SharedPreferences.
class CustomerPreferencesNotifier extends Notifier<CustomerPreferencesState> {
  /// Bumped on every user mutation. The async secure-storage load started in
  /// [build] only applies its result when no mutation happened in the meantime,
  /// so a slow load can never overwrite a change the user just made.
  int _mutationCount = 0;

  @override
  CustomerPreferencesState build() {
    final prefs = ref.watch(sharedPreferencesProvider);

    // Load payment method
    final paymentMethod = prefs.getString(_kPaymentMethodKey) ?? 'cod';

    const defaultAddress = DeliveryAddress(
      label: 'Home',
      primaryAddress: 'Magsaysay Ave, Naga City',
      streetAddress: '123 Magsaysay Avenue',
    );

    const defaultSavedAddresses = [
      defaultAddress,
      DeliveryAddress(
        label: 'School',
        primaryAddress: 'Ateneo de Naga University',
        streetAddress: 'Ateneo Avenue',
      ),
    ];

    final initial = CustomerPreferencesState(
      deliveryAddress: defaultAddress,
      savedAddresses: defaultSavedAddresses,
      paymentMethod: paymentMethod,
      blockedStallIds: [],
    );

    _mutationCount = 0;
    final countAtLoad = _mutationCount;
    _loadAddressesFromSecure().then((loaded) {
      if (loaded != null &&
          ref.mounted &&
          _mutationCount == countAtLoad) {
        state = loaded;
      }
    });

    return initial;
  }

  Future<CustomerPreferencesState?> _loadAddressesFromSecure() async {
    final storage = ref.read(secureStorageProvider);
    try {
      DeliveryAddress? currentAddress;
      final addressStr = await storage.read(key: _kDeliveryAddressKey);
      if (addressStr != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          const JsonDecoder().convert(addressStr) as Map,
        );
        currentAddress = DeliveryAddress.fromFirestore(data);
      }

      List<DeliveryAddress> savedAddresses = [];
      final savedListStr = await storage.read(key: _kSavedAddressesKey);
      if (savedListStr != null) {
        final List<dynamic> decoded = const JsonDecoder().convert(savedListStr);
        for (final entry in decoded) {
          try {
            final Map<String, dynamic> data = Map<String, dynamic>.from(
              entry as Map,
            );
            savedAddresses.add(DeliveryAddress.fromFirestore(data));
          } catch (_) {}
        }
      }

      if (currentAddress == null && savedAddresses.isEmpty) {
        return null;
      }
      return state.copyWith(
        deliveryAddress: currentAddress ?? state.deliveryAddress,
        savedAddresses: savedAddresses.isEmpty
            ? state.savedAddresses
            : savedAddresses,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistState(CustomerPreferencesState nextState) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final storage = ref.read(secureStorageProvider);
    try {
      await storage.write(
        key: _kDeliveryAddressKey,
        value: const JsonEncoder().convert(
          nextState.deliveryAddress.toFirestore(),
        ),
      );
      final savedListStr = nextState.savedAddresses
          .map((a) => const JsonEncoder().convert(a.toFirestore()))
          .toList();
      await storage.write(
        key: _kSavedAddressesKey,
        value: const JsonEncoder().convert(savedListStr),
      );
    } catch (_) {
      // Address persistence is best-effort; in-memory state remains correct.
    }
    await prefs.setString(_kPaymentMethodKey, nextState.paymentMethod);
  }

  void saveDeliveryAddress(DeliveryAddress address) {
    _mutationCount++;
    final updatedList =
        state.savedAddresses
            .where(
              (addr) =>
                  addr.label.toLowerCase().trim() !=
                  address.label.toLowerCase().trim(),
            )
            .toList()
          ..add(address);

    final next = state.copyWith(
      deliveryAddress: address,
      savedAddresses: updatedList,
    );
    state = next;
    _persistState(next);
  }

  void updateAddress({
    required String primaryAddress,
    String streetAddress = '',
    String notes = '',
    String label = 'Home',
    int? iconCodePoint,
  }) {
    final newAddress = DeliveryAddress(
      label: label,
      primaryAddress: primaryAddress,
      streetAddress: streetAddress,
      notes: notes,
      iconCodePoint: iconCodePoint,
    );
    saveDeliveryAddress(newAddress);
  }

  void selectAddress(DeliveryAddress address) {
    _mutationCount++;
    final next = state.copyWith(deliveryAddress: address);
    state = next;
    _persistState(next);
  }

  void updatePaymentMethod(String method, {String? cardLabel}) {
    _mutationCount++;
    final next = state.copyWith(paymentMethod: method, cardLabel: cardLabel);
    state = next;
    _persistState(next);
  }

  void blockStall(String stallNameOrId) {
    _mutationCount++;
    if (!state.blockedStallIds.contains(stallNameOrId)) {
      state = state.copyWith(
        blockedStallIds: [...state.blockedStallIds, stallNameOrId],
      );
    }
  }
}

final preferencesProvider =
    NotifierProvider<CustomerPreferencesNotifier, CustomerPreferencesState>(
      CustomerPreferencesNotifier.new,
    );
