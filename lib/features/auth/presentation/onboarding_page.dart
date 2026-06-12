import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/constants.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/username_service.dart';
import '../auth_providers.dart';
import 'providers/auth_controller.dart';

/// Streamlined onboarding: Profile → Workout (2 steps, no separate done screen).
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

/// Live state of the username availability check.
enum _UsernameStatus { idle, checking, available, taken, invalid }

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  int _step = 0; // 0 = profile, 1 = workout preference
  bool _isFinishing = false;

  // Profile: name
  final TextEditingController _nameController = TextEditingController();
  bool _prefilledName = false;

  // Profile: username
  final TextEditingController _usernameController = TextEditingController();
  _UsernameStatus _usernameStatus = _UsernameStatus.idle;
  String? _usernameMessage;
  bool _claimingUsername = false;
  Timer? _usernameDebounce;
  int _usernameCheckSeq = 0;

  // Profile: accent color — all neon shades. This becomes the user's app color.
  final List<Color> _avatarColors = const [
    Color(0xFFC8FF00), // acid lime (default)
    Color(0xFF39FF14), // neon green
    Color(0xFF00FFC6), // neon teal
    Color(0xFF00E5FF), // neon cyan
    Color(0xFF2979FF), // neon blue
    Color(0xFFB026FF), // neon purple
    Color(0xFFFF2EC4), // neon magenta
    Color(0xFFFF6D00), // neon orange
  ];
  int _selectedColorIndex = 0;

  // Training: workout preference
  WorkoutType _selectedWorkoutType = WorkoutType.gym;

  // Training: days per week
  final int _selectedDays = 4;

  @override
  void initState() {
    super.initState();
    // Prefill name for users who already have a profile (e.g. Google/Facebook
    // sign-ups) so they only need to add a username.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final profile = await ref.read(authUserProfileProvider.future);
        if (!mounted || _prefilledName) return;
        final existing = profile?.displayName.trim() ?? '';
        if (existing.isNotEmpty && _nameController.text.trim().isEmpty) {
          setState(() {
            _nameController.text = existing;
            _prefilledName = true;
          });
        }
      } catch (_) {
        // Non-fatal — user can type their name manually.
      }
    });
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _nameController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  void _nextStep() {
    HapticFeedback.lightImpact();
    setState(() => _step++);
  }

  // ── Username logic ─────────────────────────────────────────────────────────

  void _onUsernameChanged(String raw) {
    _usernameDebounce?.cancel();
    final service = ref.read(usernameServiceProvider);
    final error = service.validationError(raw);

    if (error != null) {
      setState(() {
        _usernameStatus = raw.trim().isEmpty
            ? _UsernameStatus.idle
            : _UsernameStatus.invalid;
        _usernameMessage = raw.trim().isEmpty ? null : error;
      });
      return;
    }

    setState(() {
      _usernameStatus = _UsernameStatus.checking;
      _usernameMessage = null;
    });

    final seq = ++_usernameCheckSeq;
    _usernameDebounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final uid = ref.read(authSessionProvider).valueOrNull?.id;
        final available = await service.isAvailable(raw, currentUserId: uid);
        if (!mounted || seq != _usernameCheckSeq) return;
        setState(() {
          _usernameStatus = available
              ? _UsernameStatus.available
              : _UsernameStatus.taken;
          _usernameMessage = available ? null : 'That username is taken.';
        });
      } catch (_) {
        if (!mounted || seq != _usernameCheckSeq) return;
        setState(() {
          _usernameStatus = _UsernameStatus.invalid;
          _usernameMessage = 'Could not check availability. Try again.';
        });
      }
    });
  }

  /// Claim the username, then advance to the Training step.
  Future<void> _claimUsernameAndContinue() async {
    if (_claimingUsername) return;
    final uid = ref.read(authSessionProvider).valueOrNull?.id;
    if (uid == null) return;

    setState(() => _claimingUsername = true);
    final result = await ref
        .read(usernameServiceProvider)
        .claim(userId: uid, raw: _usernameController.text);
    if (!mounted) return;
    setState(() => _claimingUsername = false);

    switch (result) {
      case UsernameClaimResult.success:
        _nextStep();
      case UsernameClaimResult.taken:
        setState(() {
          _usernameStatus = _UsernameStatus.taken;
          _usernameMessage = 'That username was just taken. Try another.';
        });
      case UsernameClaimResult.invalid:
        setState(() {
          _usernameStatus = _UsernameStatus.invalid;
          _usernameMessage = 'Please choose a valid username.';
        });
      case UsernameClaimResult.error:
        setState(() {
          _usernameMessage = 'Something went wrong. Please try again.';
        });
    }
  }

  Future<void> _finishOnboarding() async {
    if (_isFinishing) return;
    HapticFeedback.heavyImpact();
    final uid = ref.read(authSessionProvider).valueOrNull?.id;
    if (uid == null) return;

    setState(() => _isFinishing = true);

    // The picked neon color becomes the user's app accent (stored in
    // avatarConfig as an 8-digit ARGB hex string).
    final accentHex = _avatarColors[_selectedColorIndex]
        .toARGB32()
        .toRadixString(16)
        .padLeft(8, '0');

    await ref
        .read(authControllerProvider)
        .createUserProfile(
          userId: uid,
          displayName: _nameController.text.trim(),
          workoutPreference: _selectedWorkoutType,
          beginnerFlag: false,
          avatarConfig: accentHex,
          trainingDaysPerWeek: _selectedDays,
        );

    // Mark onboarding as finished — this single flag is what gates routing.
    await ref
        .read(authControllerProvider)
        .updateUserProfile(userId: uid, data: {'onboardingCompleted': true});

    if (!mounted) return;
    setState(() => _isFinishing = false);
    // Refresh the routing gate so the user is taken into the app.
    ref.invalidate(authProfileCompletionProvider);
    ref.invalidate(authUserProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    // Block back navigation — first-time users must finish setup.
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundV2,
        body: SafeArea(child: _buildCurrentStep()),
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 0:
        return _StepProfile(
          nameController: _nameController,
          usernameController: _usernameController,
          usernameStatus: _usernameStatus,
          usernameMessage: _usernameMessage,
          isClaiming: _claimingUsername,
          colors: _avatarColors,
          selectedColorIndex: _selectedColorIndex,
          onUsernameChanged: _onUsernameChanged,
          onColorSelected: (i) => setState(() => _selectedColorIndex = i),
          onContinue: _claimUsernameAndContinue,
        );
      case 1:
        return _StepWorkoutPreference(
          selectedType: _selectedWorkoutType,
          onSelected: (t) => setState(() => _selectedWorkoutType = t),
          onContinue: _isFinishing ? null : _finishOnboarding,
          isSubmitting: _isFinishing,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Progress dots
// ---------------------------------------------------------------------------

class _ProgressDots extends StatelessWidget {
  final int currentStep; // 0-indexed
  final int total;
  const _ProgressDots({required this.currentStep, this.total = 2});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isPast = i < currentStep;
        final isActive = i == currentStep;
        final width = isActive ? 20.0 : 6.0;
        final color = (isActive || isPast)
            ? AppColors.userAccent
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
// Shared styles
// ---------------------------------------------------------------------------

TextStyle _headingStyle() => AppTextStyles.h2.copyWith(
  fontSize: 34,
  fontWeight: FontWeight.w700,
  color: AppColors.textV2Primary,
  letterSpacing: -1.2,
  height: 1.05,
);

TextStyle _subStyle() =>
    AppTextStyles.body.copyWith(color: AppColors.textV2Secondary);

TextStyle _bodyStyle() =>
    AppTextStyles.body.copyWith(color: AppColors.textV2Secondary);

TextStyle _sectionLabelStyle() => AppTextStyles.caption.copyWith(
  fontSize: 11,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.4,
  color: AppColors.textV2Tertiary,
);

// ---------------------------------------------------------------------------
// Shared bottom Continue button
// ---------------------------------------------------------------------------

class _ContinueButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _ContinueButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  State<_ContinueButton> createState() => _ContinueButtonState();
}

class _ContinueButtonState extends State<_ContinueButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.isLoading;
    return GestureDetector(
      onTap: enabled ? widget.onPressed : null,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: enabled ? () => setState(() => _pressed = false) : null,
      child: AnimatedScale(
        scale: _pressed ? AppAnimations.buttonPressScale : 1.0,
        duration: AppDurations.fast,
        curve: AppCurves.press,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 54,
          decoration: BoxDecoration(
            color: (enabled || widget.isLoading)
                ? AppColors.userAccent
                : AppColors.surfaceV2Elevated,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.label,
                    style: AppTextStyles.h5.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? AppColors.backgroundV2
                          : AppColors.textV2Secondary,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 1: Profile (name + username + avatar color)
// ---------------------------------------------------------------------------

class _StepProfile extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController usernameController;
  final _UsernameStatus usernameStatus;
  final String? usernameMessage;
  final bool isClaiming;
  final List<Color> colors;
  final int selectedColorIndex;
  final ValueChanged<String> onUsernameChanged;
  final ValueChanged<int> onColorSelected;
  final VoidCallback onContinue;

  const _StepProfile({
    required this.nameController,
    required this.usernameController,
    required this.usernameStatus,
    required this.usernameMessage,
    required this.isClaiming,
    required this.colors,
    required this.selectedColorIndex,
    required this.onUsernameChanged,
    required this.onColorSelected,
    required this.onContinue,
  });

  @override
  State<_StepProfile> createState() => _StepProfileState();
}

class _StepProfileState extends State<_StepProfile> {
  @override
  void initState() {
    super.initState();
    widget.nameController.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.nameController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  bool get _nameValid => widget.nameController.text.trim().length > 1;

  bool get _canContinue =>
      _nameValid &&
      widget.usernameStatus == _UsernameStatus.available &&
      !widget.isClaiming;

  Widget? _usernameSuffix() {
    switch (widget.usernameStatus) {
      case _UsernameStatus.checking:
        return const Padding(
          padding: EdgeInsets.all(14),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.textV2Tertiary,
            ),
          ),
        );
      case _UsernameStatus.available:
        return Icon(
          Icons.check_circle_rounded,
          color: AppColors.userAccent,
          size: 22,
        );
      case _UsernameStatus.taken:
      case _UsernameStatus.invalid:
        return const Icon(
          Icons.error_outline_rounded,
          color: Color(0xFFFF6B6B),
          size: 22,
        );
      case _UsernameStatus.idle:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = widget.colors[widget.selectedColorIndex];
    final nameText = widget.nameController.text.trim();
    final initial = nameText.isNotEmpty ? nameText[0].toUpperCase() : 'Z';

    final bool usernameError =
        widget.usernameStatus == _UsernameStatus.taken ||
        widget.usernameStatus == _UsernameStatus.invalid;
    final Color usernameBorder = usernameError
        ? const Color(0xFFFF6B6B).withValues(alpha: 0.5)
        : (widget.usernameStatus == _UsernameStatus.available
              ? AppColors.userAccent.withValues(alpha: 0.4)
              : AppColors.surfaceV2Elevated);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ProgressDots(currentStep: 0, total: 2),
                const SizedBox(height: 14),
                Text("Create your\nprofile.", style: _headingStyle()),
                const SizedBox(height: 8),
                Text(
                  "Your name and a unique @username so buddies can find you.",
                  style: _subStyle(),
                ),
                const SizedBox(height: 14),

                // Avatar preview
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.surfaceV2,
                      border: Border.all(color: selectedColor, width: 2.5),
                    ),
                    child: Center(
                      child: Text(
                        initial,
                        style: AppTextStyles.h2.copyWith(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: selectedColor,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Name field
                Text('YOUR NAME', style: _sectionLabelStyle()),
                const SizedBox(height: 6),
                _NameInput(controller: widget.nameController),
                const SizedBox(height: 12),

                // Username field
                Text('USERNAME', style: _sectionLabelStyle()),
                const SizedBox(height: 6),
                TextField(
                  controller: widget.usernameController,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(20),
                    TextInputFormatter.withFunction(
                      (oldValue, newValue) =>
                          newValue.copyWith(text: newValue.text.toLowerCase()),
                    ),
                    FilteringTextInputFormatter.allow(RegExp(r'[a-z0-9_]')),
                  ],
                  onChanged: widget.onUsernameChanged,
                  style: AppTextStyles.h3.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Primary,
                    letterSpacing: -0.5,
                  ),
                  cursorColor: AppColors.userAccent,
                  decoration: InputDecoration(
                    prefixText: '@',
                    prefixStyle: AppTextStyles.h3.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textV2Tertiary,
                      letterSpacing: -0.5,
                    ),
                    hintText: 'username',
                    hintStyle: AppTextStyles.h3.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textV2Tertiary,
                      letterSpacing: -0.5,
                    ),
                    suffixIcon: _usernameSuffix(),
                    filled: true,
                    fillColor: AppColors.surfaceV2,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 13,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: usernameBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: usernameBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: usernameBorder, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.usernameMessage ??
                      'Letters, numbers and underscores. 3–20 characters.',
                  style: AppTextStyles.caption.copyWith(
                    color: usernameError
                        ? const Color(0xFFFF6B6B)
                        : AppColors.textV2Tertiary,
                  ),
                ),
                const SizedBox(height: 12),

                // Color picker — compact circles
                Text('PICK A COLOR', style: _sectionLabelStyle()),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: List.generate(widget.colors.length, (i) {
                    final isSelected = i == widget.selectedColorIndex;
                    final color = widget.colors[i];
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onColorSelected(i);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? color.withValues(alpha: 0.15)
                              : AppColors.surfaceV2,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? color
                                : AppColors.surfaceV2Elevated,
                            width: isSelected ? 2.5 : 1.5,
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
          child: _ContinueButton(
            label: widget.isClaiming ? 'Reserving…' : 'Continue',
            onPressed: _canContinue ? widget.onContinue : null,
          ),
        ),
      ],
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
          style: AppTextStyles.h3.copyWith(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textV2Primary,
            letterSpacing: -0.5,
          ),
          cursorColor: AppColors.userAccent,
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: AppTextStyles.h3.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textV2Tertiary,
              letterSpacing: -0.5,
            ),
            filled: true,
            fillColor: AppColors.surfaceV2,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 13,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasText
                    ? AppColors.userAccent.withValues(alpha: 0.27)
                    : AppColors.surfaceV2Elevated,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasText
                    ? AppColors.userAccent.withValues(alpha: 0.27)
                    : AppColors.surfaceV2Elevated,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: hasText
                    ? AppColors.userAccent.withValues(alpha: 0.27)
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
// Step 2: Training (goal + days per week)
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

// ignore: unused_element
class _StepTraining extends StatelessWidget {
  final List<_GoalOption> goals;
  final int selectedGoalIndex;
  final int selectedDays;
  final ValueChanged<int> onGoalSelected;
  final ValueChanged<int> onDaysSelected;
  final VoidCallback onContinue;

  const _StepTraining({
    required this.goals,
    required this.selectedGoalIndex,
    required this.selectedDays,
    required this.onGoalSelected,
    required this.onDaysSelected,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 60, 28, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ProgressDots(currentStep: 1),
                const SizedBox(height: 28),
                Text("Your\ntraining.", style: _headingStyle()),
                const SizedBox(height: 12),
                Text("Tailor your goal and weekly target.", style: _subStyle()),
                const SizedBox(height: 28),

                // Goal cards
                Text('MAIN GOAL', style: _sectionLabelStyle()),
                const SizedBox(height: 12),
                ...List.generate(goals.length, (i) {
                  final isSelected = i == selectedGoalIndex;
                  final goal = goals[i];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: i < goals.length - 1 ? 8 : 0,
                    ),
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
                                ? AppColors.userAccent.withValues(alpha: 0.27)
                                : Colors.transparent,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              goal.emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    goal.label,
                                    style: AppTextStyles.h5.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textV2Primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    goal.desc,
                                    style: AppTextStyles.caption.copyWith(
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
                                decoration: BoxDecoration(
                                  color: AppColors.userAccent,
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

                const SizedBox(height: 28),

                // Days per week
                Text('DAYS PER WEEK', style: _sectionLabelStyle()),
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    '$selectedDays',
                    style: AppTextStyles.display.copyWith(
                      fontSize: 56,
                      fontWeight: FontWeight.w700,
                      color: AppColors.userAccent,
                      letterSpacing: -2,
                    ),
                  ),
                ),
                Center(child: Text('days / week', style: _bodyStyle())),
                const SizedBox(height: 20),
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
                                ? AppColors.userAccent
                                : AppColors.surfaceV2,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: AppColors.userAccent.withValues(
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
                              style: AppTextStyles.h5.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
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
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
          child: _ContinueButton(label: 'Continue', onPressed: onContinue),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2: Workout preference (category → sub-type)
// ---------------------------------------------------------------------------

class _WorkoutCategory {
  final String key;
  final String name;
  final String emoji;
  final String description;
  const _WorkoutCategory({
    required this.key,
    required this.name,
    required this.emoji,
    required this.description,
  });
}

class _StepWorkoutPreference extends StatefulWidget {
  final WorkoutType selectedType;
  final ValueChanged<WorkoutType> onSelected;
  final VoidCallback? onContinue;
  final bool isSubmitting;

  const _StepWorkoutPreference({
    required this.selectedType,
    required this.onSelected,
    required this.onContinue,
    this.isSubmitting = false,
  });

  @override
  State<_StepWorkoutPreference> createState() => _StepWorkoutPreferenceState();
}

class _StepWorkoutPreferenceState extends State<_StepWorkoutPreference> {
  late String _selectedCategory;

  static const List<_WorkoutCategory> _categories = [
    _WorkoutCategory(
      key: 'strength',
      name: 'Strength',
      emoji: '💪',
      description: 'Build muscle & lift heavier',
    ),
    _WorkoutCategory(
      key: 'cardio',
      name: 'Cardio',
      emoji: '🏃',
      description: 'Endurance & heart health',
    ),
    _WorkoutCategory(
      key: 'flexibility',
      name: 'Flexibility',
      emoji: '🧘',
      description: 'Mobility & mindfulness',
    ),
    _WorkoutCategory(
      key: 'mixed',
      name: 'Mixed',
      emoji: '⚡',
      description: 'High intensity & sports',
    ),
  ];

  static IconData _iconFor(WorkoutType type) {
    switch (type) {
      case WorkoutType.gym:
        return Icons.fitness_center;
      case WorkoutType.running:
        return Icons.directions_run;
      case WorkoutType.cycling:
        return Icons.directions_bike;
      case WorkoutType.swimming:
        return Icons.pool;
      case WorkoutType.yoga:
        return Icons.self_improvement;
      case WorkoutType.hiit:
        return Icons.timer;
      case WorkoutType.walking:
        return Icons.directions_walk;
      case WorkoutType.sports:
        return Icons.sports_soccer;
      case WorkoutType.other:
        return Icons.category;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedType.category;
  }

  List<WorkoutType> get _subtypes =>
      WorkoutType.values.where((t) => t.category == _selectedCategory).toList();

  void _selectCategory(String category) {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
    final first = WorkoutType.values.firstWhere(
      (t) => t.category == category,
      orElse: () => WorkoutType.other,
    );
    widget.onSelected(first);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _ProgressDots(currentStep: 1, total: 2),
                const SizedBox(height: 14),
                Text("What's your\nworkout?", style: _headingStyle()),
                const SizedBox(height: 8),
                Text(
                  "Choose a category, then pick your specific style.",
                  style: _subStyle(),
                ),
                const SizedBox(height: 20),

                // ── Category grid ──────────────────────────────────────────
                Text('TRAINING CATEGORY', style: _sectionLabelStyle()),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 2.1,
                  children: _categories.map((cat) {
                    final isSelected = cat.key == _selectedCategory;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _selectCategory(cat.key);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.surfaceV2Elevated
                              : AppColors.surfaceV2,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.userAccent.withValues(alpha: 0.45)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Text(
                                  cat.emoji,
                                  style: const TextStyle(fontSize: 18),
                                ),
                                const Spacer(),
                                if (isSelected)
                                  Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: AppColors.userAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.check,
                                      size: 9,
                                      color: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cat.name,
                                  style: AppTextStyles.h5.copyWith(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppColors.textV2Primary
                                        : AppColors.textV2Secondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  cat.description,
                                  style: AppTextStyles.caption.copyWith(
                                    fontSize: 10,
                                    color: AppColors.textV2Tertiary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // ── Sub-type pills ─────────────────────────────────────────
                Text('SPECIFIC WORKOUT', style: _sectionLabelStyle()),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _subtypes.map((type) {
                    final isSelected = type == widget.selectedType;
                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        widget.onSelected(type);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.userAccent
                              : AppColors.surfaceV2,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.userAccent
                                : AppColors.surfaceV2Elevated,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _iconFor(type),
                              size: 16,
                              color: isSelected
                                  ? AppColors.backgroundV2
                                  : AppColors.textV2Secondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              type.displayName,
                              style: AppTextStyles.body.copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: isSelected
                                    ? AppColors.backgroundV2
                                    : AppColors.textV2Secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
          child: _ContinueButton(
            label: 'Start training',
            onPressed: widget.onContinue,
            isLoading: widget.isSubmitting,
          ),
        ),
      ],
    );
  }
}
