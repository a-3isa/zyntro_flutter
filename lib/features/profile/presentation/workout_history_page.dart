import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/auth_providers.dart';
import '../../../utils/haptic_manager.dart';
import '../../../widgets/premium_animations.dart';
import '../../../widgets/premium_effects.dart';
import 'package:go_router/go_router.dart';

/// Workout model for history display.
class Workout {
  final String id;
  final String userId;
  final String sessionId;
  final String type;
  final String title;
  final Map<String, dynamic>? summary;
  final List<String> participants;
  final DateTime endedAt;
  final DateTime createdAt;

  Workout({
    required this.id,
    required this.userId,
    required this.sessionId,
    required this.type,
    required this.title,
    this.summary,
    required this.participants,
    required this.endedAt,
    required this.createdAt,
  });

  factory Workout.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Workout(
      id: doc.id,
      userId: data['userId'] ?? '',
      sessionId: data['sessionId'] ?? '',
      type: data['type'] ?? '',
      title: data['title'] ?? '',
      summary: data['summary'] as Map<String, dynamic>?,
      participants: List<String>.from(data['participants'] ?? []),
      endedAt: (data['endedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  int get totalExercises => summary?['totalExercises'] ?? 0;
  int get totalSets => summary?['totalSets'] ?? 0;
}

/// Workout history page showing all past workouts for a user.
class WorkoutHistoryPage extends ConsumerStatefulWidget {
  final String? userId;

  const WorkoutHistoryPage({super.key, this.userId});

  @override
  ConsumerState<WorkoutHistoryPage> createState() => _WorkoutHistoryPageState();
}

class _WorkoutHistoryPageState extends ConsumerState<WorkoutHistoryPage> {
  final List<Workout> _workouts = [];
  bool _isLoading = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDoc;
  String _selectedFilter = 'All';
  late PageController _pageController;
  int _currentCarouselIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
    _loadWorkouts();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkouts() async {
    final authState = ref.read(authSessionProvider);
    final userId = widget.userId ?? authState.valueOrNull?.id;
    if (userId == null) return;

    setState(() => _isLoading = true);

    try {
      final firestore = ref.read(authFirestoreProvider);
      Query<Map<String, dynamic>> query = firestore
          .collection('workouts')
          .where('userId', isEqualTo: userId);

      if (_selectedFilter != 'All') {
        query = query.where('type', isEqualTo: _selectedFilter.toLowerCase());
      }

      query = query.orderBy('endedAt', descending: true).limit(20);

      if (_lastDoc != null) {
        query = query.startAfterDocument(_lastDoc!);
      }

      final snapshot = await query.get();
      final workouts = snapshot.docs
          .map((doc) => Workout.fromFirestore(doc))
          .toList();

      setState(() {
        _workouts.addAll(workouts);
        _lastDoc = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length == 20;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[WorkoutHistoryPage] Error loading workouts: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refresh() async {
    _workouts.clear();
    _lastDoc = null;
    _hasMore = true;
    await _loadWorkouts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: Column(
        children: [
          // Custom Header
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 8,
              left: 16,
              right: 16,
            ),
            child: Row(
              children: [
                BounceAnimation(
                  onTap: () {
                    HapticManager.light();
                    context.pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceSecondaryDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textDark,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: GradientText(
                    text: 'Workout History',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    colors: [AppColors.textDark, AppColors.textSecondaryDark],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                HapticManager.medium();
                await _refresh();
              },
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceDark,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _workouts.isEmpty) {
      // Shimmer loading state
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 5,
        itemBuilder: (context, index) => ShimmerLoading(
          child: Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(AppBorderRadius.md),
            ),
            child: Row(
              children: [
                ShimmerSkeleton(
                  width: 48,
                  height: 48,
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShimmerSkeleton.text(width: 150),
                      const SizedBox(height: 8),
                      ShimmerSkeleton.text(width: 80, height: 12),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_workouts.isEmpty) {
      return Center(
        child: FadeInAnimation(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PulseAnimation(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSecondaryDark,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.fitness_center,
                    size: 48,
                    color: AppColors.textSecondaryDark,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No workouts yet',
                style: TextStyle(
                  fontSize: AppFontSize.lg,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Complete a session to see it here!',
                style: TextStyle(color: AppColors.textSecondaryDark),
              ),
            ],
          ),
        ),
      );
    }

    // Group workouts by date, skipping the ones shown in carousel if we want
    // But usually history shows all. Let's show all in list too, or maybe
    // the carousel is just a "Featured" view of the top ones.
    final grouped = _groupWorkoutsByDate(_workouts);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFeaturedCarousel(),
              _buildFilters(),
              const Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.lg,
                  AppSpacing.lg,
                  0,
                ),
                child: Text(
                  'History',
                  style: TextStyle(
                    fontSize: AppFontSize.lg,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index == grouped.length) {
                if (_isLoading) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                if (_hasMore) {
                  _loadWorkouts();
                }
                return const SizedBox.shrink();
              }
              final entry = grouped.entries.elementAt(index);
              return _buildDateSection(entry.key, entry.value);
            }, childCount: grouped.length + (_hasMore ? 1 : 0)),
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedCarousel() {
    if (_workouts.isEmpty) return const SizedBox.shrink();
    final featured = _workouts.take(5).toList();

    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          height: 180,
          child: PageView.builder(
            controller: _pageController,
            itemCount: featured.length,
            onPageChanged: (index) =>
                setState(() => _currentCarouselIndex = index),
            itemBuilder: (context, index) {
              final workout = featured[index];
              // Premium card build
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: _buildFeaturedCard(workout),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildPageIndicator(featured.length),
      ],
    );
  }

  Widget _buildFeaturedCard(Workout workout) {
    final typeColor = workout.type == 'strength'
        ? AppColors.primary
        : AppColors.secondary;

    return Container(
      decoration: BoxDecoration(
        color: typeColor,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        gradient: LinearGradient(
          colors: [typeColor, typeColor.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: typeColor.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  workout.type.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
              Text(
                DateFormat('MMM d').format(workout.endedAt),
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
          Text(
            workout.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              const Icon(Icons.timer, color: Colors.white70, size: 16),
              const SizedBox(width: 4),
              Text(
                DateFormat('h:mm a').format(workout.endedAt),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        final isActive = index == _currentCarouselIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: isActive ? 16 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.textTertiaryDark,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildFilters() {
    final filters = ['All', 'Strength', 'Cardio', 'HIIT']; // Example filters
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                if (selected && _selectedFilter != filter) {
                  setState(() {
                    _selectedFilter = filter;
                    _isLoading = true;
                    _workouts.clear();
                    _lastDoc = null;
                    _hasMore = true;
                  });
                  _loadWorkouts();
                }
              },
              backgroundColor: AppColors.surfaceSecondaryDark,
              selectedColor: AppColors.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondaryDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected ? AppColors.primary : AppColors.borderDark,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Map<String, List<Workout>> _groupWorkoutsByDate(List<Workout> workouts) {
    final grouped = <String, List<Workout>>{};
    final dateFormat = DateFormat('EEEE, MMMM d');

    for (final workout in workouts) {
      final dateKey = dateFormat.format(workout.endedAt);
      grouped.putIfAbsent(dateKey, () => []).add(workout);
    }

    return grouped;
  }

  Widget _buildDateSection(String date, List<Workout> workouts) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Text(
            date,
            style: TextStyle(
              fontSize: AppFontSize.md,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
        ),
        ...workouts.asMap().entries.map(
          (entry) => _buildWorkoutCard(entry.value, entry.key),
        ),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildWorkoutCard(Workout workout, int index) {
    final timeFormat = DateFormat('h:mm a');
    final typeIcon = workout.type == 'strength'
        ? Icons.fitness_center
        : Icons.directions_run;
    final typeGradient = workout.type == 'strength'
        ? AppColors.primaryGradient
        : AppColors.secondaryGradient;

    return SlideInAnimation.fromBottom(
      index: index,
      delay: const Duration(milliseconds: 50),
      child: BounceAnimation(
        onTap: () {
          HapticManager.light();
          // Navigate to session recap if needed
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
            border: Border.all(color: AppColors.borderDark),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                // Type icon with gradient background
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: typeGradient),
                    borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                  ),
                  child: Icon(typeIcon, color: Colors.white),
                ),
                const SizedBox(width: AppSpacing.md),

                // Workout details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workout.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: AppFontSize.md,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        timeFormat.format(workout.endedAt),
                        style: TextStyle(
                          fontSize: AppFontSize.sm,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                    ],
                  ),
                ),

                // Stats
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.repeat,
                          size: 16,
                          color: AppColors.textSecondaryDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${workout.totalSets} sets',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${workout.totalExercises} exercises',
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: AppColors.textSecondaryDark,
                      ),
                    ),
                  ],
                ),

                // Buddy indicator with glow
                if (workout.participants.length > 1) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xs),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.secondaryGradient,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.secondary.withValues(alpha: 0.3),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.people,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

