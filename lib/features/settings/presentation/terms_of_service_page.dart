import 'package:flutter/material.dart';

import 'legal_markdown_page.dart';

/// Terms of service — loads canonical `docs/terms-of-service.md` (Z-PRV-003).
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalMarkdownPage(
      title: 'Terms of Service',
      assetPath: 'docs/terms-of-service.md',
    );
  }
}
