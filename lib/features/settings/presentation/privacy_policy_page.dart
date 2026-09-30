import 'package:flutter/material.dart';

import 'legal_markdown_page.dart';

/// Privacy policy page — loads canonical `docs/privacy-policy.md` (Z-PRV-003).
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalMarkdownPage(
      title: 'Privacy Policy',
      assetPath: 'docs/privacy-policy.md',
    );
  }
}
