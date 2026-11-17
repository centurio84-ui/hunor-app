import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/member.dart';
import '../models/theme_config.dart';
import '../services/app_store.dart';
import '../services/theme_controller.dart';
import '../theme/hunor_theme.dart';
import 'availability_dialog.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final themeCtrl = Provider.of<ThemeController?>(context);
    final u = s.currentUser;
    final org = s.currentOrganization;
    final membership = s.currentMembership;
    final coin = s.coinBalance;

    if (u == null) {
      if (s.isStaging) {
        return Center(
          child: FilledButton(
            onPressed: s.signOut,
            child: const Text('Kijelentkezés'),
          ),
        );
      }
      if (s.isLoading) {
        return const Center(child: CircularProgressIndicator(color: HunorColors.red));
      }
      return const Center(
        child: Text('Nincs bejelentkezett felhasználó.', style: TextStyle(color: HunorColors.muted)),
      );
    }

    if (s.isStaging) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(u.name, style: Theme.of(context).textTheme.headlineSmall),
          Text(s.currentUserProfile?.user.email ?? ''),
          Text(org?.name ?? 'Nincs jóváhagyott szervezet'),
          Text('Tagság: ${membership?.membershipStatus.label ?? "Nincs"}'),
          const SizedBox(height: 16),
          if (themeCtrl != null) ...[
            _buildThemeCard(context, themeCtrl, s),
            const SizedBox(height: 16),
          ],
          const Text('Staging tesztprofil. A profil, készségek és riaszthatóság szerkesztése még nem támogatott. Push és valódi riasztásküldés nincs bekötve.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: s.signOut, child: const Text('Kijelentkezés')),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => _confirmAccountDeletion(context, s),
            style: TextButton.styleFrom(foregroundColor: HunorColors.muted),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text('Fiók és adatok törlésének kérelmezése'),
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        // Felhasználói kártya
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: HunorColors.redDark,
                  child: Icon(Icons.person, size: 34, color: Colors.white),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(u.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                        org?.name ?? 'Szervezet',
                        style: const TextStyle(color: HunorColors.red, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Státusz: ${membership?.membershipStatus.label ?? "Ismeretlen"}',
                        style: const TextStyle(color: HunorColors.muted),
                      ),
                      if (membership != null && membership.positions.isNotEmpty)
                        Text(
                          'Beosztás: ${membership.positions.join(", ")}',
                          style: const TextStyle(color: HunorColors.muted),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Rescue Coin Egyenleg kártya
        if (s.showRescueCoins && coin != null)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: ListTile(
              leading: const Icon(Icons.monetization_on_outlined, color: HunorColors.warning, size: 28),
              title: const Text('Rescue Coin egyenleg', style: TextStyle(fontWeight: FontWeight.w800)),
              subtitle: Text('${coin.balance} ${coin.unit} • Főkönyvi verzió: ${coin.ledgerVersion}'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: HunorColors.warning.withAlpha(40),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${coin.balance} ${coin.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w900, color: HunorColors.warning),
                ),
              ),
            ),
          ),
        if (s.showRescueCoins && coin != null) const SizedBox(height: 10),

        // Témaszinkronizáció kártya (csak adminoknak)
        if (themeCtrl != null && s.isAdmin) ...[
          _buildThemeCard(context, themeCtrl, s),
          const SizedBox(height: 10),
        ],

        // Elérhetőség kártya
        Card(
          child: ListTile(
            leading: Icon(
              u.status == AvailabilityStatus.available
                  ? Icons.check_circle
                  : Icons.event_busy,
              color: switch (u.status) {
                AvailabilityStatus.available => HunorColors.success,
                AvailabilityStatus.sick => HunorColors.red,
                AvailabilityStatus.vacation => HunorColors.blue,
                AvailabilityStatus.training => HunorColors.exercise,
                _ => HunorColors.muted,
              },
            ),
            title: const Text('Szolgálati állapot', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text(
              '${u.status.shortLabel} • ${u.statusPeriodFormatted}',
              style: const TextStyle(color: HunorColors.muted),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showAvailabilityDialog(context),
          ),
        ),
        const SizedBox(height: 10),

        // Képességek kártya
        Text('Képességek', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (u.skills.isEmpty)
                  const Text('Nincs megadott képesség', style: TextStyle(color: HunorColors.muted))
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [for (final x in u.skills) Chip(label: Text(x))],
                  ),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.info_outline, size: 15, color: HunorColors.muted),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'A képességek módosítása a központi webes felületen (hun01usar.hu) érhető el.',
                        style: TextStyle(fontSize: 11, color: HunorColors.muted, fontStyle: FontStyle.italic),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Kijelentkezés
        OutlinedButton.icon(
          onPressed: s.signOut,
          style: OutlinedButton.styleFrom(
            foregroundColor: HunorColors.red,
            side: const BorderSide(color: HunorColors.red),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          icon: const Icon(Icons.logout),
          label: const Text('Kijelentkezés és gyorsítótár ürítése'),
        ),
        const SizedBox(height: 12),

        // Fióktörlési kérelem (Google Play Account Deletion Policy követelmény)
        Center(
          child: TextButton.icon(
            onPressed: () => _confirmAccountDeletion(context, s),
            style: TextButton.styleFrom(
              foregroundColor: HunorColors.muted,
            ),
            icon: const Icon(Icons.delete_outline, size: 18),
            label: const Text(
              'Fiók és adatok törlésének kérelmezése',
              style: TextStyle(fontSize: 13, decoration: TextDecoration.underline),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeCard(BuildContext context, ThemeController themeCtrl, AppStore store) {
    final def = themeCtrl.currentDefinition;
    final source = themeCtrl.themeContext?.source ?? 'helyi';
    final isSyncing = themeCtrl.isLoading;

    return Card(
      child: ListTile(
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: def.primaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 2),
          ),
        ),
        title: Row(
          children: [
            Text(def.name, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            if (isSyncing)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        subtitle: Text('Forrás: $source • ID: ${def.id}', style: const TextStyle(color: HunorColors.muted)),
        trailing: const Icon(Icons.palette_outlined),
        onTap: () => _showThemeSelector(context, themeCtrl),
      ),
    );
  }

  static Future<void> _showThemeSelector(
    BuildContext context,
    ThemeController themeCtrl,
  ) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E222B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final currentId = themeCtrl.currentThemeId;
        final catalog = RescueThemeRegistry.allThemes;

        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    const Icon(Icons.palette_outlined, color: HunorColors.red),
                    const SizedBox(width: 10),
                    const Text(
                      'Téma kiválasztása',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView.separated(
                  controller: scrollCtrl,
                  itemCount: catalog.length,
                  separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (c, index) {
                    final theme = catalog[index];
                    final isSelected = theme.id == currentId;

                    return ListTile(
                      leading: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: theme.primaryColor,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      title: Text(
                        theme.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${!theme.isSeasonal ? "Hétköznapi" : "Szezonális"} • ${theme.id}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle, color: HunorColors.success)
                          : null,
                      onTap: () async {
                        Navigator.pop(ctx);
                        await themeCtrl.setTheme(theme.id);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  static Future<void> _confirmAccountDeletion(BuildContext context, AppStore s) async {
    await showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Fiók és személyes adatok törlése'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A Google Play adatvédelmi szabályzatának megfelelően kérelmezheted a Rescue Platform fiókod és a kapcsolódó személyes adataid (profil, elérhetőség, naplózott műveleti előzmények) végleges törlését.',
              style: TextStyle(height: 1.4),
            ),
            SizedBox(height: 12),
            Text(
              'A megerősítést követően a kérelem azonnal továbbításra kerül a hitelesített szerverhez, és a fiókodból automatikusan kijelentkezel. A kérelem nem vonható vissza.',
              style: TextStyle(height: 1.4, color: HunorColors.muted),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Mégse'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: HunorColors.red),
            onPressed: () async {
              Navigator.pop(c);
              try {
                await s.requestAccountDeletion(reason: 'Felhasználói in-app törlési kérelem');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('A törlési kérelem sikeresen rögzítve a szerveren. Kijelentkeztetve.'),
                      backgroundColor: HunorColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Hiba a törlési kérelem küldésekor: $e'),
                      backgroundColor: HunorColors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Törlési kérelem elküldése'),
          ),
        ],
      ),
    );
  }
}
