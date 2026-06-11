import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/cart_item.dart';

class CartService extends ChangeNotifier {
  CartService._();
  static final CartService instance = CartService._();

  final List<CartItem> _items = [];
  bool _authBound = false;

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);

  void bindAuth() {
    if (_authBound) return;
    _authBound = true;
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) {
        _items.clear();
        notifyListeners();
        return;
      }
      await loadFromUser(user.uid);
    });
  }

  Future<void> loadFromUser(String uid) async {
    try {
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final raw = snap.data()?['cart'];
      _items.clear();
      if (raw is List) {
        for (final entry in raw) {
          if (entry is Map) {
            _items.add(CartItem.fromMap(Map<String, dynamic>.from(entry)));
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Cart load failed: $e');
    }
  }

  Future<void> _persist() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'cart': _items.map((e) => e.toMap()).toList(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Cart save failed: $e');
    }
  }

  Future<void> addItem(CartItem item) async {
    final index = _items.indexWhere((e) => e.cartKey == item.cartKey);
    if (index >= 0) {
      _items[index] = _items[index].copyWith(quantity: _items[index].quantity + item.quantity);
    } else {
      _items.add(item);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> updateQuantity(String cartKey, int quantity) async {
    final index = _items.indexWhere((e) => e.cartKey == cartKey);
    if (index < 0) return;
    if (quantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: quantity);
    }
    notifyListeners();
    await _persist();
  }

  Future<void> removeItem(String cartKey) async {
    _items.removeWhere((e) => e.cartKey == cartKey);
    notifyListeners();
    await _persist();
  }

  Future<void> clear() async {
    _items.clear();
    notifyListeners();
    await _persist();
  }
}
