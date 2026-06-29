import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';

void main() {
  test('invite window matches the paired-session expiry spec', () {
    expect(pairedInviteTimeout, const Duration(seconds: 30));
  });
}
