import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme/app_text_styles.dart';
import '../core/theme/app_theme.dart';

class CelebrationOverlay extends StatefulWidget {
  final String title;
  final String subtitle;
  final String emoji;
  final VoidCallback onDismiss;

  const CelebrationOverlay({
    super.key,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.onDismiss,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late ConfettiController _confetti;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnim;
  Timer? _autoDismiss;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3))..play();
    HapticFeedback.heavyImpact();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: AppCurves.spring));
    _slideController.forward();

    _autoDismiss = Timer(const Duration(seconds: 4), widget.onDismiss);
  }

  @override
  void dispose() {
    _confetti.dispose();
    _slideController.dispose();
    _autoDismiss?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onDismiss,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // Dim background
          Container(color: Colors.black.withValues(alpha: 0.6)),

          // Confetti
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            colors: [AppColors.signal, AppColors.warnV2, Colors.white],
            numberOfParticles: 30,
            maxBlastForce: 20,
            minBlastForce: 8,
          ),

          // Achievement card slides up from bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SlideTransition(
              position: _slideAnim,
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surfaceV2Elevated,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.surfaceV2Active),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.emoji,
                      style: const TextStyle(fontSize: 56),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.title,
                      style: AppTextStyles.h2.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textV2Primary,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.subtitle,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontSize: 15,
                        color: AppColors.textV2Secondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Tap anywhere to continue',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textV2Tertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Show the celebration overlay as a full-screen dialog.
Future<void> showCelebration(
  BuildContext context, {
  required String title,
  required String subtitle,
  required String emoji,
}) {
  return showDialog(
    context: context,
    barrierColor: Colors.transparent,
    barrierDismissible: true,
    builder: (_) => CelebrationOverlay(
      title: title,
      subtitle: subtitle,
      emoji: emoji,
      onDismiss: () => Navigator.of(context, rootNavigator: true).pop(),
    ),
  );
}
