import 'package:palengkego/core/infrastructure/supabase_service.dart';
import 'package:palengkego/core/infrastructure/firebase_service.dart';
import 'package:palengkego/core/services/app_services.dart';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:palengkego/core/services/preferences_provider.dart';
import 'package:palengkego/core/services/secure_storage_provider.dart';
import 'package:palengkego/features/auth/application/auth_provider.dart';
import 'package:palengkego/features/profile/domain/delivery_address.dart';

class CustomerPreferencesState {
  final DeliveryAddress? deliveryAddress;
  final List<DeliveryAddress> savedAddresses;
  final String paymentMethod;
  final String? cardLabel;
  final List<String> blockedStallIds;
  final Map<String, String> connectedPaymentAccounts;

  const CustomerPreferencesState({
    this.deliveryAddress,
    this.savedAddresses = const [],
    required this.paymentMethod,
    this.cardLabel,
    this.blockedStallIds = const [],
    this.connectedPaymentAccounts = const {},
  });

  bool isPaymentMethodConnected(String method) {
    if (method == 'cod' || method == 'cop') return true;
    return connectedPaymentAccounts.containsKey(method);
  }

  String? getPaymentMethodAccount(String method) =>
      connectedPaymentAccounts[method];

  CustomerPreferencesState copyWith({
    DeliveryAddress? deliveryAddress,
    bool clearDeliveryAddress = false,
    List<DeliveryAddress>? savedAddresses,
    String? paymentMethod,
    String? cardLabel,
    List<String>? blockedStallIds,
    Map<String, String>? connectedPaymentAccounts,
  }) {
    return CustomerPreferencesState(
      deliveryAddress: clearDeliveryAddress
          ? null
          : (deliveryAddress ?? this.deliveryAddress),
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
      case 'maya':
      case 'paymaya':
        return 'Maya';
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
        return 'Pay with GCash via PayMongo';
      case 'maya':
      case 'paymaya':
        return 'Pay with Maya via PayMongo';
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

  String _userKey(String baseKey, String? uid) {
    if (uid != null && uid.isNotEmpty) {
      return '${baseKey}_$uid';
    }
    return '${baseKey}_guest';
  }

  @override
  CustomerPreferencesState build() {
    final user = ref.watch(authProvider);
    final uid = user?.uid;
    final prefs = ref.watch(sharedPreferencesProvider);

    // Load payment method
    final payKey = _userKey(_kPaymentMethodKey, uid);
    final paymentMethod =
        prefs.getString(payKey) ??
        (uid != null && uid.isNotEmpty
            ? prefs.getString(_kPaymentMethodKey)
            : null) ??
        'cod';

    // Blocked stalls persist across restarts
    final blockedKey = _userKey(_kBlockedStallsKey, uid);
    final blockedStallIds =
        prefs.getStringList(blockedKey) ??
        (uid != null && uid.isNotEmpty
            ? prefs.getStringList(_kBlockedStallsKey)
            : null) ??
        [];

    // Load connected payment accounts
    Map<String, String> connectedPaymentAccounts = {};
    final connKey = _userKey(_kConnectedPaymentAccountsKey, uid);
    final connectedStr =
        prefs.getString(connKey) ??
        (uid != null && uid.isNotEmpty
            ? prefs.getString(_kConnectedPaymentAccountsKey)
            : null);
    if (connectedStr != null) {
      try {
        final decoded = jsonDecode(connectedStr) as Map<String, dynamic>;
        connectedPaymentAccounts = decoded.map(
          (k, v) => MapEntry(k, v.toString()),
        );
      } catch (_) {}
    }

    final initial = CustomerPreferencesState(
      deliveryAddress: null,
      savedAddresses: const [],
      paymentMethod: paymentMethod,
      blockedStallIds: blockedStallIds,
      connectedPaymentAccounts: connectedPaymentAccounts,
    );

    _mutationCount = 0;
    final countAtLoad = _mutationCount;
    _loadAddressesFromSecure(initial, uid).then((loaded) {
      if (loaded != null && ref.mounted && _mutationCount == countAtLoad) {
        WidgetsBinding? binding;
        try {
          binding = WidgetsBinding.instance;
        } catch (_) {
          binding = null;
        }
        if (binding != null) {
          binding.addPostFrameCallback((_) {
            if (ref.mounted && _mutationCount == countAtLoad) {
              state = loaded;
            }
          });
        } else {
          Future.microtask(() {
            if (ref.mounted && _mutationCount == countAtLoad) {
              state = loaded;
            }
          });
        }
      }
    });

    return initial;
  }

  Future<CustomerPreferencesState?> _loadAddressesFromSecure(
    CustomerPreferencesState baseState,
    String? uid,
  ) async {
    final client = ref.read(supabaseClientProvider);
    if (client != null && uid != null) {
      try {
        final token = await ref
            .read(firebaseAuthProvider)
            .currentUser
            ?.getIdToken();
        if (token == null) throw StateError('Sign in to load addresses.');
        final response = await client.functions.invoke(
          'save-address',
          headers: {'Authorization': 'Bearer $token'},
          body: {'read': true},
        );
        final addresses = (response.data['addresses'] as List)
            .map(
              (row) => DeliveryAddress.fromSupabase(
                Map<String, dynamic>.from(row as Map),
              ),
            )
            .toList();
        if (!ref.mounted || ref.read(authProvider)?.uid != uid) return null;
        return baseState.copyWith(
          savedAddresses: addresses,
          deliveryAddress:
              addresses.where((a) => a.isDefault).firstOrNull ??
              addresses.firstOrNull,
        );
      } catch (_) {
        AppServices.showError(
          'Unable to load saved addresses. Please try again.',
        );
        return null;
      }
    }
    final storage = ref.read(secureStorageProvider);
    final delivKey = _userKey(_kDeliveryAddressKey, uid);
    final savedKey = _userKey(_kSavedAddressesKey, uid);
    try {
      DeliveryAddress? currentAddress;
      var addressStr = await storage.read(key: delivKey);
      if (addressStr == null && uid != null && uid.isNotEmpty) {
        addressStr = await storage.read(key: _kDeliveryAddressKey);
        if (addressStr != null) {
          await storage.write(key: delivKey, value: addressStr);
        }
      }
      if (addressStr != null) {
        final Map<String, dynamic> data = Map<String, dynamic>.from(
          const JsonDecoder().convert(addressStr) as Map,
        );
        currentAddress = DeliveryAddress.fromFirestore(data);
      }

      List<DeliveryAddress> savedAddresses = [];
      var savedListStr = await storage.read(key: savedKey);
      if (savedListStr == null && uid != null && uid.isNotEmpty) {
        savedListStr = await storage.read(key: _kSavedAddressesKey);
        if (savedListStr != null) {
          await storage.write(key: savedKey, value: savedListStr);
        }
      }
      if (savedListStr != null) {
        final List<dynamic> decoded = const JsonDecoder().convert(savedListStr);
        for (final entry in decoded) {
          try {
            final Map<String, dynamic> data = entry is String
                ? Map<String, dynamic>.from(
                    const JsonDecoder().convert(entry) as Map,
                  )
                : Map<String, dynamic>.from(entry as Map);
            savedAddresses.add(DeliveryAddress.fromFirestore(data));
          } catch (_) {}
        }
      }

      if (currentAddress == null && savedAddresses.isEmpty) {
        return null;
      }
      return baseState.copyWith(
        deliveryAddress: currentAddress ?? baseState.deliveryAddress,
        savedAddresses: savedAddresses.isEmpty
            ? baseState.savedAddresses
            : savedAddresses,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _persistState(CustomerPreferencesState nextState) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final storage = ref.read(secureStorageProvider);
    final uid = ref.read(authProvider)?.uid;
    final delivKey = _userKey(_kDeliveryAddressKey, uid);
    final savedKey = _userKey(_kSavedAddressesKey, uid);
    final payKey = _userKey(_kPaymentMethodKey, uid);
    final blockedKey = _userKey(_kBlockedStallsKey, uid);
    final connKey = _userKey(_kConnectedPaymentAccountsKey, uid);

    try {
      if (nextState.deliveryAddress != null) {
        await storage.write(
          key: delivKey,
          value: const JsonEncoder().convert(
            nextState.deliveryAddress!.toFirestore(),
          ),
        );
      } else {
        await storage.delete(key: delivKey);
      }
      final savedListStr = nextState.savedAddresses
          .map((a) => const JsonEncoder().convert(a.toFirestore()))
          .toList();
      await storage.write(
        key: savedKey,
        value: const JsonEncoder().convert(savedListStr),
      );
    } catch (_) {
      // Address persistence is best-effort; in-memory state remains correct.
    }
    await prefs.setString(payKey, nextState.paymentMethod);
    await prefs.setStringList(blockedKey, nextState.blockedStallIds);
    await prefs.setString(
      connKey,
      jsonEncode(nextState.connectedPaymentAccounts),
    );
  }

  Future<bool> saveDeliveryAddress(DeliveryAddress address) async {
    _mutationCount++;
    final client = ref.read(supabaseClientProvider);
    final uid = ref.read(authProvider)?.uid;
    if (client != null && uid != null) {
      try {
        final token = await ref
            .read(firebaseAuthProvider)
            .currentUser
            ?.getIdToken();
        if (token == null) throw StateError('Sign in to save your address.');
        final response = await client.functions.invoke(
          'save-address',
          headers: {'Authorization': 'Bearer $token'},
          body: {'address': address.toFirestore()},
        );
        if (!ref.mounted || ref.read(authProvider)?.uid != uid) return false;
        address = DeliveryAddress.fromSupabase(
          Map<String, dynamic>.from(response.data['address'] as Map),
        );
      } catch (_) {
        AppServices.showError('Unable to save address. Please try again.');
        return false;
      }
    }
    final assignedId =
        address.addressId ?? 'addr_${DateTime.now().millisecondsSinceEpoch}';
    final normalized = address.copyWith(addressId: assignedId);

    final currentList = state.savedAddresses
        .map(
          (entry) =>
              normalized.isDefault ? entry.copyWith(isDefault: false) : entry,
        )
        .toList();
    int targetIndex = -1;

    if (address.addressId != null && address.addressId!.isNotEmpty) {
      targetIndex = currentList.indexWhere(
        (a) => a.addressId == address.addressId,
      );
    }

    if (targetIndex < 0) {
      targetIndex = currentList.indexWhere(
        (a) =>
            a.label.toLowerCase().trim() == address.label.toLowerCase().trim(),
      );
    }

    if (targetIndex >= 0) {
      currentList[targetIndex] = normalized;
    } else {
      currentList.add(normalized);
    }

    final next = state.copyWith(
      deliveryAddress: normalized,
      savedAddresses: currentList,
    );
    state = next;
    _persistState(next);
    return true;
  }

  Future<bool> removeDeliveryAddress(DeliveryAddress address) async {
    _mutationCount++;
    final client = ref.read(supabaseClientProvider);
    final uid = ref.read(authProvider)?.uid;
    if (client != null && uid != null) {
      try {
        final token = await ref
            .read(firebaseAuthProvider)
            .currentUser
            ?.getIdToken();
        if (token == null) throw StateError('Sign in to delete your address.');
        await client.functions.invoke(
          'save-address',
          headers: {'Authorization': 'Bearer $token'},
          body: {'address': address.toFirestore(), 'delete': true},
        );
        if (!ref.mounted || ref.read(authProvider)?.uid != uid) return false;
      } catch (_) {
        AppServices.showError('Unable to delete address. Please try again.');
        return false;
      }
    }
    final updatedList = state.savedAddresses
        .where(
          (addr) => (address.addressId != null && addr.addressId != null)
              ? addr.addressId != address.addressId
              : (addr.label.toLowerCase().trim() !=
                        address.label.toLowerCase().trim() ||
                    addr.streetAddress != address.streetAddress ||
                    addr.primaryAddress != address.primaryAddress),
        )
        .toList();

    // If the currently selected delivery address was removed, fallback to the first saved address
    DeliveryAddress? current = state.deliveryAddress;
    final isCurrentRemoved =
        current != null &&
        ((address.addressId != null && current.addressId != null)
            ? current.addressId == address.addressId
            : (current.label.toLowerCase().trim() ==
                      address.label.toLowerCase().trim() &&
                  current.streetAddress == address.streetAddress &&
                  current.primaryAddress == address.primaryAddress));

    if (isCurrentRemoved) {
      current = updatedList.isNotEmpty ? updatedList.first : null;
    }

    final next = state.copyWith(
      deliveryAddress: current,
      clearDeliveryAddress: current == null,
      savedAddresses: updatedList,
    );
    state = next;
    _persistState(next);
    return true;
  }

  void updateAddress({
    required String primaryAddress,
    String streetAddress = '',
    String notes = '',
    String label = 'Home',
    int? iconCodePoint,
    double? latitude,
    double? longitude,
  }) {
    final newAddress = DeliveryAddress(
      label: label,
      primaryAddress: primaryAddress,
      streetAddress: streetAddress,
      notes: notes,
      latitude: latitude,
      longitude: longitude,
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
    final fallbackMethod = state.paymentMethod == method
        ? 'cod'
        : state.paymentMethod;
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
