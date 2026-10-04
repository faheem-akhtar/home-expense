import 'package:flutter/material.dart';

enum PaymentMethod {
  cash('Cash', Icons.payments_outlined),
  primaryCard('Primary Card', Icons.credit_card),
  prepaidCard('Prepaid Card', Icons.card_giftcard);

  const PaymentMethod(this.label, this.icon);
  final String label;
  final IconData icon;

  static PaymentMethod parse(String? name) =>
      PaymentMethod.values.firstWhere((m) => m.name == name, orElse: () => PaymentMethod.cash);
}
