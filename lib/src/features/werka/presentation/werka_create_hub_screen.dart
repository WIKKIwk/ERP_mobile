import '../../../app/app_router.dart';
import '../../../core/widgets/app_shell.dart';
import 'widgets/werka_dock.dart';
import 'package:flutter/material.dart';

class WerkaCreateHubScreen extends StatelessWidget {
  const WerkaCreateHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return AppShell(
      title: 'Qayd',
      subtitle: '',
      leading: const _CreateHubBackButton(),
      bottom: const WerkaDock(activeTab: null),
      contentPadding: const EdgeInsets.fromLTRB(10, 0, 12, 0),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Card.filled(
              margin: EdgeInsets.zero,
              color: scheme.surfaceContainerLow,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
              child: Column(
                children: [
                  InkWell(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.werkaUnannouncedSupplier,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 20,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Aytilmagan mol',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Supplier, mol va miqdorni bir oqimda tanlang',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Divider(height: 1, thickness: 1),
                  InkWell(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(28),
                      bottomRight: Radius.circular(28),
                    ),
                    onTap: () => Navigator.of(context).pushNamed(
                      AppRoutes.werkaCustomerIssueCustomer,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 20,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Mol jo‘natish',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Customerga jo‘natma yaratish oqimi',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateHubBackButton extends StatelessWidget {
  const _CreateHubBackButton();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: 52,
      child: IconButton.filledTonal(
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(Icons.arrow_back_rounded, size: 28),
      ),
    );
  }
}
