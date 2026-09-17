import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../widgets/zyntro_back_button.dart';
import 'widgets/joint_post_composer.dart';

/// Standalone host for [JointPostComposer], reached at `/joint-post/:postId`.
///
/// Task 13 made the composer embeddable so recap can show it under the stats
/// body. This page covers the *other* entry point: a partner who tapped the
/// `joint_post_invite` notification. They are no longer in the recap flow —
/// they may be opening the app hours later — so they get the composer on its
/// own route rather than a recap page for a session they already left.
class JointPostPage extends ConsumerWidget {
  final String postId;

  const JointPostPage({super.key, required this.postId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.backgroundV2,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  ZyntroBackButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/?tab=feed');
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Post together',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textV2Primary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: JointPostComposer(postId: postId),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
