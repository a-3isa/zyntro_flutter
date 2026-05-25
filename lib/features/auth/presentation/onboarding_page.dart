import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import '../../../services/storage_service.dart';

/// Multi-step onboarding profile setup screen (5 steps).
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _step = 0; // 0–4

  // Step 1: Name
  final TextEditingController _nameController = TextEditingController();

  // Step 2: Avatar color
  final List<Color> _avatarColors = const [
    Color(0xFFC8FF00),
    Color(0xFF38BDF8),
    Color(0xFFFF6B6B),
    Color(0xFFFF8C00),
    Color(0xFFA78BFA),
    Color(0xFF34D399),
    Color(0xFFF472B6),
    Color(0xFF60A5FA),
  ];
  int _selectedColorIndex = 0;

  // Step 3: Goal
  final List<_GoalOption> _goals = const [
    _GoalOption(emoji: '💪', label: 'Build Strength', desc: 'Grow muscle, lift heavier, get stronger'),
    _GoalOption(emoji: '🏃', label: 'Improve Cardio', desc: 'Build endurance and stamina'),
    _GoalOption(emoji: '🔥', label: 'Body Composition', desc: 'Burn fat, tone up, transform'),
    _GoalOption(emoji: '🏆', label: 'Compete', desc: 'Train for performance and competition'),
  ];
  int _selectedGoalIndex = 0;

  // Step 4: Days per week
  int _selectedDays = 4;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    setState(() => _step++);
  }

  void _finishOnboarding() {
    HapticFeedback.heavyImpact();
    ref.read(storageServiceProvider).setHasSeenOnboarding(true);
    context.go(AppRoutes.signUp);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: SafeArea(
        child: _buildCurrentStep(),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _StepName(
          controller: _nameController,
          onContinue: _nextStep,
        );
      case 1:
        return _StepAvatarColor(
          colors: _avatarColors,
          selectedIndex: _selectedColorIndex,
          name: _nameController.text.trim(),
          onColorSelected: (i) => setState(() => _selectedColorIndex = i),
          onContinue: _nextStep,
        );
      case 2:
        return _StepGoal(
          goals: _goals,
          selectedIndex: _selectedGoalIndex,
          onGoalSelected: (i) => setState(() => _selectedGoalIndex = i),
          onContinue: _nextStep,
        );
      case 3:
        return _StepDays(
          selectedDays: _selectedDays,
          onDaysSelected: (d) => setState(() => _selectedDays = d),
          onContinue: _nextStep,
        );
      case 4:
        return _StepDone(
          name: _nameController.text.trim(),
          days: _selectedDays,
          onStart: _finishOnboarding,
          onExplore: _finishOnboarding,
        );
      default:
        return _StepName(
          controller: _nameController,
          onContinue: _nextStep,
        );
    }
  }
}

// ---------------------------------------------------------------------------
// Progress dots (steps 0–3, i.e. steps 1–4 in 1-indexed spec)
// ---------------------------------------------------------------------------

class _ProgressDots extends StatelessWidget {
  final int currentStep; // 0-indexed, max 3
  const _ProgressDots({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        final isPast = i < currentStep;
        final isActive = i == currentStep;
        final width = isActive ? 20.0 : 6.0;
        final color = (isActive || isPast)
            ? AppColors.accentLime
            : AppColors.surfaceV2Elevated;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: width,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        );
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared heading builder
// ---------------------------------------------------------------------------

TextStyle _headingStyle() => GoogleFonts.syne(
      fontWeight: FontWeight.w800,
      fontSize: 34,
      color: AppColors.textV2Primary,
      letterSpacing: -1.2,
      height: 1.05,
    );

TextStyle _subStyle() => GoogleFonts.outfit(
      fontSize: 14,
      color: AppColors.textV2Secondary,
    );

TextStyle _bodyStyle() => GoogleFonts.outfit(
      fontSize: 14,
      color: AppColors.textV2Secondary,
    );

// ---------------------------------------------------------------------------
// Shared bottom Continue button
// ---------------------------------------------------------------------------

class _ContinueButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? leftIcon;

  const _ContinueButton({
    required this.label,
    required this.onPressed,
    this.leftIcon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return GestureDetector(
      onTap: onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 54,
        decoration: BoxDecoration(
          color: enabled ? AppColors.accentLime : AppColors.surfaceV2Elevated,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leftIcon != null) ...[
              leftIcon!,
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: GoogleFonts.syne(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: enabled
                    ? AppColors.backgroundV2
                    : AppColors.textV2Secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1: Name
// ---------------------------------------------------------------------------

class _StepName extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onContinue;

  const _StepName({required this.controller, required this.onContinue});

  @override
  State<_StepName> createState() => _StepNameState();
}

class _StepNameState extends State<_StepName> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  bool get _canContinue => widget.controller.text.trim().length > 1;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProgressDots(currentStep: 0),
          const SizedBox(height: 32),
          Text("What's your\nname?", style: _headingStyle()),
          const SizedBox(height: 12),
          Text("We'll use this on the leaderboard.", style: _subStyle()),
          const SizedBox(height: 32),
          _NameInput(controller: widget.controller),
          const Spacer(),
          _ContinueButton(
            label: 'Continue',
            onPressed: _canContinue ? widget.onContinue : null,
          ),
        ],
      ),
    );
  }
}

class _NameInput extends StatelessWidget {
  final TextEditingController controller;
  const _NameInput({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final hasText = value.text.trim().length > 1;
        return TextField(
          controller: controller,
          textCapitalization: TextCapitalization.words,
          style: GoogleFonts.syne(
            fontWeight: FontWeight.w700,
            fontSize: 22,
            color: AppColors.textV2Primary,
            letterSpacing: -0.5,
          ),
          cursorColor: AppColors.accentLime,
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: GoogleFonts.syne(
              fontWeight: FontWeight.w700,
              fontSize: 22,
              color: AppColors.textV2Tertiary,
              letterSpacing: -0.5,
            ),
            filled: true,
            fillColor: AppColors.surfaceV2,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasText
                    ? AppColors.accentLime.withValues(alpha: 0.27)
                    : AppColors.surfaceV2Elevated,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasText
                    ? AppColors.accentLime.withValues(alpha: 0.27)
                    : AppColors.surfaceV2Elevated,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasText
                    ? AppColors.accentLime.withValues(alpha: 0.27)
                    : AppColors.surfaceV2Elevated,
                width: 1.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2: Avatar color
// ---------------------------------------------------------------------------

class _StepAvatarColor extends StatelessWidget {
  final List<Color> colors;
  final int selectedIndex;
  final String name;
  final ValueChanged<int> onColorSelected;
  final VoidCallback onContinue;

  const _StepAvatarColor({
    required this.colors,
    required this.selectedIndex,
    required this.name,
    required this.onColorSelected,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final selectedColor = colors[selectedIndex];
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'Z';

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProgressDots(currentStep: 1),
          const SizedBox(height: 32),
          Text("Pick your\ncolor.", style: _headingStyle()),
          const SizedBox(height: 32),

          // Avatar preview
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceV2,
                border: Border.all(color: selectedColor, width: 3),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.syne(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    color: selectedColor,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // 4x2 color grid
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: List.generate(colors.length, (i) {
              final isSelected = i == selectedIndex;
              final color = colors[i];
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onColorSelected(i);
                },
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceV2,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          const Spacer(),
          _ContinueButton(label: 'Continue', onPressed: onContinue),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3: Goal
// ---------------------------------------------------------------------------

class _GoalOption {
  final String emoji;
  final String label;
  final String desc;
  const _GoalOption({
    required this.emoji,
    required this.label,
    required this.desc,
  });
}

class _StepGoal extends StatelessWidget {
  final List<_GoalOption> goals;
  final int selectedIndex;
  final ValueChanged<int> onGoalSelected;
  final VoidCallback onContinue;

  const _StepGoal({
    required this.goals,
    required this.selectedIndex,
    required this.onGoalSelected,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProgressDots(currentStep: 2),
          const SizedBox(height: 32),
          Text("What's your\nmain goal?", style: _headingStyle()),
          const SizedBox(height: 12),
          Text("Tailor your experience.", style: _subStyle()),
          const SizedBox(height: 32),

          // Goal cards
          ...List.generate(goals.length, (i) {
            final isSelected = i == selectedIndex;
            final goal = goals[i];
            return Padding(
              padding: EdgeInsets.only(bottom: i < goals.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onGoalSelected(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.surfaceV2Elevated
                        : AppColors.surfaceV2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.accentLime.withValues(alpha: 0.27)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(goal.emoji,
                          style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              goal.label,
                              style: GoogleFonts.syne(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.textV2Primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              goal.desc,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: AppColors.textV2Secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 12),
                        Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                            color: AppColors.accentLime,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            size: 12,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          const Spacer(),
          _ContinueButton(label: 'Continue', onPressed: onContinue),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 4: Days per week
// ---------------------------------------------------------------------------

class _StepDays extends StatelessWidget {
  final int selectedDays;
  final ValueChanged<int> onDaysSelected;
  final VoidCallback onContinue;

  const _StepDays({
    required this.selectedDays,
    required this.onDaysSelected,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProgressDots(currentStep: 3),
          const SizedBox(height: 32),
          Text("How often\ndo you train?", style: _headingStyle()),
          const SizedBox(height: 12),
          Text("Days per week — we'll set your goal.", style: _subStyle()),
          const SizedBox(height: 48),

          // Big number
          Center(
            child: Text(
              '$selectedDays',
              style: GoogleFonts.syne(
                fontWeight: FontWeight.w800,
                fontSize: 72,
                color: AppColors.accentLime,
                letterSpacing: -3,
              ),
            ),
          ),
          Center(
            child: Text('days / week', style: _bodyStyle()),
          ),

          const SizedBox(height: 40),

          // Day selector row (2–7)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              final day = i + 2;
              final isSelected = day == selectedDays;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onDaysSelected(day);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.accentLime
                          : AppColors.surfaceV2,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.accentLime.withValues(
                                  alpha: 0.35,
                                ),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: GoogleFonts.syne(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          color: isSelected
                              ? AppColors.backgroundV2
                              : AppColors.textV2Secondary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),

          const Spacer(),
          _ContinueButton(label: 'Continue', onPressed: onContinue),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 5: Done
// ---------------------------------------------------------------------------

class _StepDone extends StatelessWidget {
  final String name;
  final int days;
  final VoidCallback onStart;
  final VoidCallback onExplore;

  const _StepDone({
    required this.name,
    required this.days,
    required this.onStart,
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name.isNotEmpty ? name : 'there';

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Check circle
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.accentLime,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accentLime.withValues(alpha: 0.4),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),

          const SizedBox(height: 28),

          Text(
            "You're in.",
            style: GoogleFonts.syne(
              fontWeight: FontWeight.w800,
              fontSize: 42,
              color: AppColors.textV2Primary,
              letterSpacing: -2,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            "Welcome, $displayName. Training $days days/week. Let's go.",
            style: _bodyStyle(),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 40),

          // CTA card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceV2,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.accentLime.withValues(alpha: 0.13),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'READY TO START?',
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                    color: AppColors.textV2Tertiary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Kick off your first session',
                  style: GoogleFonts.syne(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: AppColors.textV2Primary,
                  ),
                ),
                const SizedBox(height: 16),
                _ContinueButton(
                  label: 'Start First Session',
                  leftIcon: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.backgroundV2,
                    size: 20,
                  ),
                  onPressed: onStart,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: onExplore,
            child: Text(
              'Explore first →',
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: AppColors.textV2Tertiary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
