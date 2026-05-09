import 'package:flutter/material.dart';

class OnboardingScaffold extends StatelessWidget {
  const OnboardingScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.bottom,
    this.showBack = false,
    this.onBack,
    this.progress,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? bottom;
  final bool showBack;
  final VoidCallback? onBack;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showBack)
                      IconButton.filledTonal(
                        onPressed: onBack ?? () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                    if (progress != null) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 8,
                          value: progress,
                          backgroundColor: theme.colorScheme.primaryContainer,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              sliver: SliverToBoxAdapter(child: child),
            ),
            if (bottom != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: bottom,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
