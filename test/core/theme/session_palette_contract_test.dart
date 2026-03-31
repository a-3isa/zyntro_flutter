import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/theme/app_theme.dart';

void main() {
  test('session palette matches approved figma colors', () {
    expect(AppColors.sessionNavy900, const Color(0xFF0A0E27));
    expect(AppColors.sessionNavy800, const Color(0xFF151B3D));
    expect(AppColors.sessionNavy700, const Color(0xFF1E2749));
    expect(AppColors.sessionNeonGreen, const Color(0xFF39FF14));
    expect(AppColors.sessionNeonGreenHover, const Color(0xFF2EE00F));
    expect(AppColors.sessionGray400, const Color(0xFF8B8B98));
    expect(AppColors.sessionMutedText, const Color(0xFFA0A0AC));
  });
}
