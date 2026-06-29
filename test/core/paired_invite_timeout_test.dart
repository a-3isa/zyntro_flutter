import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/constants/constants.dart';

void main() {
  test('invite window is long enough for the build-plan-after handshake', () {
    expect(pairedInviteTimeout, greaterThanOrEqualTo(const Duration(minutes: 5)));
  });
}
