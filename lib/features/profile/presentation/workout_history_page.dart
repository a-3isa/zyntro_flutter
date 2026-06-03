import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_text_styles.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/auth_providers.dart';
import '../../../utils/haptic_manager.dart';

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
      final workouts = snapshot.docs.map((doc) => Workout.fromFirestore(doc)).toList();

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
      backgroundColor: AppColors.backgroundV2,
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 8,
              bottom: 8,
              left: 16,
              right: 16,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticManager.light();
                    context.pop();
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceV2Elevated,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.arrow_back,
                      color: AppColors.textV2Primary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Workout History',
                  style: AppTextStyles.h4.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Primary,
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
              color: AppColors.accentLime,
              backgroundColor: AppColors.surfaceV2,
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading && _workouts.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: 5,
        itemBuilder: (context, index) => Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceV2,
            borderRadius: BorderRadius.circular(AppBorderRadius.md),
          ),
          child: const Row(
            children: [
              SizedBox(width: 48, height: 48),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 150, height: 14),
                    SizedBox(height: 8),
                    SizedBox(width: 80, height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_workouts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surfaceV2Elevated,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.fitness_center, size: 48, color: AppColors.accentLime),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'No workouts yet',
              style: AppTextStyles.h5.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.textV2Primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Complete a session to see it here!',
              style: TextStyle(color: AppColors.textV2Secondary),
            ),
          ],
        ),
      );
    }

    final grouped = _groupWorkoutsByDate(_workouts);

    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFeaturedCarousel(),
              _buildFilters(),
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, 0),
                child: Text(
                  'History',
                  style: AppTextStyles.h5.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textV2Primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == grouped.length) {
                  if (_isLoading) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSpacing.lg),
                        child: CircularProgressIndicator(color: AppColors.accentLime),
                      ),
                    );
                  }
                  if (_hasMore) _loadWorkouts();
                  return const SizedBox.shrink();
                }
                final entry = grouped.entries.elementAt(index);
                return _buildDateSection(entry.key, entry.value);
              },
              childCount: grouped.length + (_hasMore ? 1 : 0),
            ),
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
            onPageChanged: (index) => setState(() => _currentCarouselIndex = index),
            itemBuilder: (context, index) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: _buildFeaturedCard(featured[index]),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _buildPageIndicator(featured.length),
      ],
    );
  }

  Widget _buildFeaturedCard(Workout workout) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceV2Elevated,
        borderRadius: BorderRadius.circular(AppBorderRadius.lg),
        border: Border.all(color: AppColors.surfaceV2Active),
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
                  color: AppColors.accentLime.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  workout.type.toUpperCase(),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.accentLime,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
              ),
              Text(
                DateFormat('MMM d').format(workout.endedAt),
                style: TextStyle(color: AppColors.textV2Secondary),
              ),
            ],
          ),
          Text(
            workout.title,
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textV2Primary,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            children: [
              Icon(Icons.timer, color: AppColors.textV2Secondary, size: 16),
              const SizedBox(width: 4),
              Text(
                DateFormat('h:mm a').format(workout.endedAt),
                style: TextStyle(color: AppColors.textV2Primary, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward, color: AppColors.accentLime),
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
            color: isActive ? AppColors.accentLime : AppColors.textV2Tertiary,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }

  Widget _buildFilters() {
    final filters = ['All', 'Strength', 'Cardio', 'HIIT'];
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
              backgroundColor: AppColors.surfaceV2Elevated,
              selectedColor: AppColors.accentLime,
              labelStyle: TextStyle(
                color: isSelected ? AppColors.backgroundV2 : AppColors.textV2Secondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              checkmarkColor: AppColors.backgroundV2,
              side: BorderSide(
                color: isSelected ? AppColors.accentLime : AppColors.surfaceV2Active,
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
            style: AppTextStyles.bodyLarge.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textV2Primary,
            ),
          ),
        ),
        ...workouts.asMap().entries.map((entry) => _buildWorkoutCard(entry.value, entry.key)),
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }

  Widget _buildWorkoutCard(Workout workout, int index) {
    final timeFormat = DateFormat('h:mm a');
    final typeIcon = workout.type == 'strength' ? Icons.fitness_center : Icons.directions_run;

    return GestureDetector(
      onTap: () => HapticManager.light(),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surfaceV2,
          borderRadius: BorderRadius.circular(AppBorderRadius.md),
          border: Border.all(color: AppColors.surfaceV2Active),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accentLime.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppBorderRadius.sm),
                ),
                child: Icon(typeIcon, color: AppColors.accentLime),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: AppFontSize.md,
                        color: AppColors.textV2Primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      timeFormat.format(workout.endedAt),
                      style: TextStyle(
                        fontSize: AppFontSize.sm,
                        color: AppColors.textV2Secondary,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.repeat, size: 16, color: AppColors.textV2Secondary),
                      const SizedBox(width: 4),
                      Text(
                        '${workout.totalSets} sets',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color: AppColors.textV2Primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '${workout.totalExercises} exercises',
                    style: TextStyle(
                      fontSize: AppFontSize.sm,
                      color: AppColors.textV2Secondary,
                    ),
                  ),
                ],
              ),
              if (workout.participants.length > 1) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: AppColors.accentLime.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people, size: 16, color: AppColors.accentLime),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
