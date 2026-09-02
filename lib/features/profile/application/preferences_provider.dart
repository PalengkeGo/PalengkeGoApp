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
  final Map<String, String> connectedPaymentAccounts;

  const CustomerPreferencesState({
    required this.deliveryAddress,
    this.savedAddresses = const [],
    required this.paymentMethod,
    this.cardLabel,
    this.blockedStallIds = const [],
    this.connectedPaymentAccounts = const {'gcash': '0912 345 6789'},
  });

  bool isPaymentMethodConnected(String method) {
    if (method == 'cod' || method == 'cop') return true;
    return connectedPaymentAccounts.containsKey(method);
  }

  String? getPaymentMethodAccount(String method) =>
      connectedPaymentAccounts[method];

  CustomerPreferencesState copyWith({
    DeliveryAddress? deliveryAddress,
    List<DeliveryAddress>? savedAddresses,
    String? paymentMethod,
    String? cardLabel,
    List<String>? blockedStallIds,
    Map<String, String>? connectedPaymentAccounts,
  }) {
    return CustomerPreferencesState(
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      savedAddresses: savedAddresses ?? this.savedAddresses,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      cardLabel: cardLabel ?? this.cardLabel,
      blockedStallIds: blockedStallIds ?? this.blockedStallIds,
      connectedPaymentAccounts:
          connectedPaymentAccounts ?? this.connectedPaymentAccounts,
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
const _kBlockedStallsKey = 'pref_blocked_stalls';
const _kConnectedPaymentAccountsKey = 'pref_connected_payment_accounts';

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

    // Blocked stalls persist across restarts (best-effort — an empty or
    // missing list simply starts clean).
    final blockedStallIds = prefs.getStringList(_kBlockedStallsKey) ?? [];

    // Load connected payment accounts
    Map<String, String> connectedPaymentAccounts = {'gcash': '0912 345 6789'};
    final connectedStr = prefs.getString(_kConnectedPaymentAccountsKey);
    if (connectedStr != null) {
      try {
        final decoded = jsonDecode(connectedStr) as Map<String, dynamic>;
        connectedPaymentAccounts = decoded.map(
          (k, v) => MapEntry(k, v.toString()),
        );
      } catch (_) {}
    }

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
      blockedStallIds: blockedStallIds,
      connectedPaymentAccounts: connectedPaymentAccounts,
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
    await prefs.setStringList(_kBlockedStallsKey, nextState.blockedStallIds);
    await prefs.setString(
      _kConnectedPaymentAccountsKey,
      jsonEncode(nextState.connectedPaymentAccounts),
    );
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

  void removeDeliveryAddress(DeliveryAddress address) {
    _mutationCount++;
    final updatedList = state.savedAddresses
        .where(
          (addr) =>
              (address.addressId != null && addr.addressId != null)
                  ? addr.addressId != address.addressId
                  : (addr.label.toLowerCase().trim() !=
                          address.label.toLowerCase().trim() ||
                      addr.streetAddress != address.streetAddress ||
                      addr.primaryAddress != address.primaryAddress),
        )
        .toList();

    // If the currently selected delivery address was removed, fallback to the first saved address
    DeliveryAddress current = state.deliveryAddress;
    final isCurrentRemoved = (address.addressId != null &&
            current.addressId != null)
        ? current.addressId == address.addressId
        : (current.label.toLowerCase().trim() ==
                address.label.toLowerCase().trim() &&
            current.streetAddress == address.streetAddress &&
            current.primaryAddress == address.primaryAddress);

    if (isCurrentRemoved) {
      current = updatedList.isNotEmpty
          ? updatedList.first
          : const DeliveryAddress(
              label: 'Home',
              primaryAddress: 'Magsaysay Ave, Naga City',
              streetAddress: '123 Magsaysay Avenue',
            );
    }

    final next = state.copyWith(
      deliveryAddress: current,
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

  void connectPaymentAccount(String method, String accountDetail) {
    _mutationCount++;
    final updated = Map<String, String>.from(state.connectedPaymentAccounts)
      ..[method] = accountDetail;
    final next = state.copyWith(
      connectedPaymentAccounts: updated,
      paymentMethod: method,
    );
    state = next;
    _persistState(next);
  }

  void disconnectPaymentAccount(String method) {
    _mutationCount++;
    final updated = Map<String, String>.from(state.connectedPaymentAccounts)
      ..remove(method);
    // If the disconnected method was currently selected, reset to 'cod'
    final fallbackMethod = state.paymentMethod == method ? 'cod' : state.paymentMethod;
    final next = state.copyWith(
      connectedPaymentAccounts: updated,
      paymentMethod: fallbackMethod,
    );
    state = next;
    _persistState(next);
  }

  void blockStall(String stallNameOrId) {
    _mutationCount++;
    if (!state.blockedStallIds.contains(stallNameOrId)) {
      final next = state.copyWith(
        blockedStallIds: [...state.blockedStallIds, stallNameOrId],
      );
      state = next;
      _persistState(next);
    }
  }
}

final preferencesProvider =
    NotifierProvider<CustomerPreferencesNotifier, CustomerPreferencesState>(
      CustomerPreferencesNotifier.new,
    );
