import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/app_theme.dart';
import '../../../app/navigation/app_router.dart';
import '../../../services/facebook_link_service.dart';
import '../../../widgets/circuit_breaker_status_widget.dart';
import '../../auth/presentation/providers/auth_controller.dart';
import '../../auth/auth_providers.dart';
import '../../social/presentation/providers/facebook_friends_provider.dart';

/// Settings page — v2 design (true-black + acid-lime palette).
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // ── Notification toggles ──────────────────────────────────────────────────
  bool _sessionInvites = true;
  bool _workoutLikes = true;
  bool _newFollowers = true;
  bool _buddyActivity = false;

  // ── Training prefs ────────────────────────────────────────────────────────
  String _restTimer = '1m';
  String _weightUnit = 'kg';

  // ── Helpers ───────────────────────────────────────────────────────────────

  TextStyle _sectionHeader() => AppTextStyles.caption.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 2,
        color: AppColors.textV2Tertiary,
      );

  TextStyle _rowLabel({bool danger = false}) => AppTextStyles.body.copyWith(
        fontWeight: FontWeight.w500,
        color: danger ? AppColors.errorV2 : AppColors.textV2Primary,
      );

  TextStyle _rowSub() => AppTextStyles.caption.copyWith(
        fontSize: 11,
        color: AppColors.textV2Tertiary,
      );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authSessionProvider);
    final displayName = authState.valueOrNull?.displayName ?? 'Zyntro User';
    final username = displayName.toLowerCase().replaceAll(' ', '_');
    final initial =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'Z';

    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),

                  // Profile card
                  _buildProfileCard(
                    context,
                    displayName: displayName,
                    username: username,
                    initial: initial,
                  ),

                  // ── Notifications ────────────────────────────────────────
                  _sectionLabel('NOTIFICATIONS'),
                  _buildSectionCard([
                    _toggleRow(
                      label: 'Session invites',
                      sub: 'When a buddy starts a session',
                      value: _sessionInvites,
                      onChanged: (v) => setState(() => _sessionInvites = v),
                    ),
                    _divider(),
                    _toggleRow(
                      label: 'Workout likes',
                      sub: 'When someone reacts to your post',
                      value: _workoutLikes,
                      onChanged: (v) => setState(() => _workoutLikes = v),
                    ),
                    _divider(),
                    _toggleRow(
                      label: 'New followers',
                      sub: 'When someone follows you',
                      value: _newFollowers,
                      onChanged: (v) => setState(() => _newFollowers = v),
                    ),
                    _divider(),
                    _toggleRow(
                      label: 'Buddy activity',
                      sub: 'When buddies finish workouts',
                      value: _buddyActivity,
                      onChanged: (v) => setState(() => _buddyActivity = v),
                    ),
                  ]),

                  // ── Training ─────────────────────────────────────────────
                  _sectionLabel('TRAINING'),
                  _buildSectionCard([
                    _segmentedRow(
                      label: 'Default rest timer',
                      sub: 'Applied after each set',
                      options: const ['30s', '1m', '1.5m', '2m'],
                      selected: _restTimer,
                      onSelected: (v) => setState(() => _restTimer = v),
                    ),
                    _divider(),
                    _segmentedRow(
                      label: 'Weight unit',
                      sub: null,
                      options: const ['kg', 'lbs'],
                      selected: _weightUnit,
                      onSelected: (v) => setState(() => _weightUnit = v),
                    ),
                  ]),

                  // ── Privacy ──────────────────────────────────────────────
                  _sectionLabel('PRIVACY'),
                  _buildSectionCard([
                    _chevronRow(
                      label: 'Profile visibility',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push(AppRoutes.privacySettings);
                      },
                    ),
                    _divider(),
                    _chevronRow(
                      label: 'Post visibility',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push(AppRoutes.privacySettings);
                      },
                    ),
                  ]),

                  // ── Connected Accounts ───────────────────────────────────
                  _sectionLabel('CONNECTED ACCOUNTS'),
                  _buildConnectedAccountsCard(context),

                  // ── Account ──────────────────────────────────────────────
                  _sectionLabel('ACCOUNT'),
                  _buildSectionCard([
                    _chevronRow(
                      label: 'Change password',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push(AppRoutes.changePassword);
                      },
                    ),
                    _divider(),
                    _chevronRow(
                      label: 'Linked devices',
                      sub: '2 devices',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showNetworkDiagnostics(context);
                      },
                    ),
                    _divider(),
                    _chevronRow(
                      label: 'Export my data',
                      sub: 'Download your workout history',
                      onTap: () {
                        HapticFeedback.lightImpact();
                      },
                    ),
                    _divider(),
                    _dangerRow(
                      label: 'Sign out',
                      onTap: () => _confirmSignOut(context),
                    ),
                    _divider(),
                    _dangerRow(
                      label: 'Delete account',
                      sub: 'This cannot be undone',
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push(AppRoutes.deleteAccount);
                      },
                    ),
                  ]),

                  const SizedBox(height: 32),

                  // App version footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Zyntro',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textV2Secondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version 1.0.0',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textV2Tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 12,
        bottom: 14,
        left: 16,
        right: 16,
      ),
      color: AppColors.surfaceV2,
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.surfaceV2Active,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: AppColors.textV2Primary,
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            'Settings',
            style: AppTextStyles.h3.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textV2Primary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile Card ──────────────────────────────────────────────────────────

  Widget _buildProfileCard(
    BuildContext context, {
    required String displayName,
    required String username,
    required String initial,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.accentLime.withValues(alpha: 0.5),
                width: 2,
              ),
              color: AppColors.surfaceV2Active,
            ),
            child: Center(
              child: Text(
                initial,
                style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentLime,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Name + username
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Primary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '@$username · Rank #4',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textV2Secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          // Ghost Edit button
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push(AppRoutes.editProfile);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.surfaceV2Active,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceV2Active),
              ),
              child: Text(
                'Edit',
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textV2Secondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Connected Accounts card ───────────────────────────────────────────────

  Widget _buildConnectedAccountsCard(BuildContext context) {
    final profileAsync = ref.watch(authUserProfileProvider);
    final isFbConnected = profileAsync.valueOrNull?.isFacebookConnected ?? false;

    return _buildSectionCard([
      InkWell(
        onTap: () => isFbConnected
            ? _confirmDisconnectFacebook(context)
            : _connectFacebook(context),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF1877F2).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.facebook,
                  color: Color(0xFF1877F2),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Facebook', style: _rowLabel()),
                    const SizedBox(height: 2),
                    Text(
                      isFbConnected ? 'Tap to disconnect' : 'Find friends on Zyntro',
                      style: _rowSub(),
                    ),
                  ],
                ),
              ),
              if (isFbConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentLime.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Connected',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentLime,
                    ),
                  ),
                )
              else
                Text(
                  'Connect',
                  style: AppTextStyles.body.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1877F2),
                  ),
                ),
            ],
          ),
        ),
      ),
    ]);
  }

  Future<void> _connectFacebook(BuildContext context) async {
    HapticFeedback.lightImpact();
    final uid = ref.read(authSessionProvider).valueOrNull?.id;
    if (uid == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final fbService = ref.read(facebookLinkServiceProvider);
    final result = await fbService.connectFacebook(uid);

    if (!mounted) return;
    ref.invalidate(authUserProfileProvider);
    ref.invalidate(facebookFriendsProvider);

    String message;
    switch (result) {
      case FacebookLinkSuccess(:final value):
        final count = value.length;
        message = count > 0
            ? 'Facebook connected! Found $count friend${count == 1 ? '' : 's'} on Zyntro.'
            : 'Facebook connected.';
      case FacebookLinkNoFriendsPermission():
        message = 'Facebook connected. Friend access wasn\'t granted — reconnect to see friends.';
      case FacebookLinkCancelled():
        message = 'Facebook connection cancelled.';
      case FacebookLinkFailure(:final message):
        _showSnackbarMessenger(messenger, message);
        return;
    }
    _showSnackbarMessenger(messenger, message);
  }

  Future<void> _confirmDisconnectFacebook(BuildContext context) async {
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceV2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Disconnect Facebook?',
          style: AppTextStyles.h5.copyWith(
            color: AppColors.textV2Primary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'You won\'t see Facebook friend suggestions after disconnecting.',
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textV2Secondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textV2Secondary),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.errorV2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Disconnect',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final uid = ref.read(authSessionProvider).valueOrNull?.id;
      if (uid == null) return;
      final fbService = ref.read(facebookLinkServiceProvider);
      await fbService.disconnectFacebook(uid);
      if (!mounted) return;
      ref.invalidate(authUserProfileProvider);
      ref.invalidate(facebookFriendsProvider);
      _showSnackbarMessenger(messenger, 'Facebook disconnected.');
    }
  }

  void _showSnackbarMessenger(ScaffoldMessengerState messenger, String message) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.surfaceV2Active,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Section helpers ───────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8, left: 4),
      child: Text(text, style: _sectionHeader()),
    );
  }

  Widget _buildSectionCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceV2,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _divider() => Divider(
        height: 1,
        thickness: 1,
        color: Colors.white.withValues(alpha: 0.06),
        indent: 0,
        endIndent: 0,
      );

  // ── Row types ─────────────────────────────────────────────────────────────

  Widget _toggleRow({
    required String label,
    required String sub,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _rowLabel()),
                const SizedBox(height: 2),
                Text(sub, style: _rowSub()),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _LimeToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _segmentedRow({
    required String label,
    required String? sub,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: _rowLabel()),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(sub, style: _rowSub()),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          _SegmentedSelector(
            options: options,
            selected: selected,
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }

  Widget _chevronRow({
    required String label,
    String? sub,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _rowLabel()),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub, style: _rowSub()),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textV2Tertiary,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dangerRow({
    required String label,
    String? sub,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: _rowLabel(danger: true)),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub, style: _rowSub()),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.errorV2,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ── Sign-out dialog ───────────────────────────────────────────────────────

  Future<void> _confirmSignOut(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final router = GoRouter.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceV2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout, color: AppColors.errorV2),
            const SizedBox(width: 8),
            Text(
              'Sign Out',
              style: AppTextStyles.h5.copyWith(
                color: AppColors.textV2Primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to sign out?',
          style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textV2Secondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: AppTextStyles.bodyLarge.copyWith(color: AppColors.textV2Secondary),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.errorV2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Sign Out',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      HapticFeedback.heavyImpact();
      await ref.read(authControllerProvider).signOut();
      if (mounted) {
        router.go(AppRoutes.login);
      }
    }
  }

  // ── Network diagnostics sheet ─────────────────────────────────────────────

  void _showNetworkDiagnostics(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceV2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx2, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceV2Active,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Network Diagnostics',
                style: AppTextStyles.h4.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.textV2Primary,
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircuitBreakerStatusWidget(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Lime Toggle ──────────────────────────────────────────────────────────────

class _LimeToggle extends StatelessWidget {
  const _LimeToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onChanged(!value);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: value ? AppColors.accentLime : AppColors.surfaceV2Active,
          borderRadius: BorderRadius.circular(13),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value
                  ? const Color(0xFF080808)
                  : AppColors.textV2Tertiary,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Segmented Selector ────────────────────────────────────────────────────────

class _SegmentedSelector extends StatelessWidget {
  const _SegmentedSelector({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: options.map((opt) {
        final isSelected = opt == selected;
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelected(opt);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color:
                  isSelected ? AppColors.accentLime : AppColors.surfaceV2Elevated,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              opt,
              style: AppTextStyles.caption.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? const Color(0xFF080808)
                    : AppColors.textV2Secondary,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
