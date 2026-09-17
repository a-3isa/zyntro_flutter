import 'package:flutter/material.dart';

import 'legal_markdown_page.dart';

/// Public Meta / GDPR-style data deletion instructions (Z-AUTH-004 / Z-PRV-003).
///
/// Reachable without sign-in so Meta App Review can open the URL from the
/// Facebook Login dashboard without an account.
class DataDeletionPage extends StatelessWidget {
  const DataDeletionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalMarkdownPage(
      title: 'Data Deletion',
      assetPath: 'docs/data-deletion.md',
    );
  }
}
