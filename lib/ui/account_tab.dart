import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../data/dates.dart';
import '../data/store.dart';
import '../data/sync.dart';
import 'widgets.dart';

class AccountTab extends StatefulWidget {
  const AccountTab({super.key});

  @override
  State<AccountTab> createState() => _AccountTabState();
}

class _AccountTabState extends State<AccountTab> {
  int? _fileSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    StoreScope.of(context).localFileSize().then((v) {
      if (mounted && v != _fileSize) setState(() => _fileSize = v);
    });
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _guard(Future<void> Function() action, {String? success}) async {
    try {
      await action();
      if (success != null) _snack(success);
    } on AuthCancelled {
      return;
    } catch (e) {
      _snack(AuthService.message(e));
    }
  }

  Future<String?> _askPassword(String title) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: TextField(
              controller: ctrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Obecne hasło'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text),
                child: const Text('Dalej'),
              ),
            ],
          ),
    );
  }

  Future<void> _changePassword() async {
    final current = TextEditingController(), next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Zmień hasło'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: current,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Obecne hasło'),
                ),
                TextField(
                  controller: next,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Nowe hasło (min. 8 znaków)',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Zmień'),
              ),
            ],
          ),
    );
    if (ok != true) return;
    if (next.text.length < 8) {
      _snack('Nowe hasło musi mieć co najmniej 8 znaków.');
      return;
    }
    await _guard(
      () => AuthService.changePassword(current.text, next.text),
      success: 'Hasło zostało zmienione.',
    );
  }

  Future<void> _deleteAccount(SyncService sync) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Usunąć konto?'),
            content: const Text(
              'Konto, wszystkie treningi i plany zostaną trwale usunięte z telefonu i z chmury. '
              'Tej operacji nie można cofnąć.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Anuluj'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Usuń konto'),
              ),
            ],
          ),
    );
    if (confirm != true) return;
    String? password;
    if (AuthService.usesPassword) {
      password = await _askPassword('Potwierdź hasłem');
      if (password == null) return;
    }
    final store = sync.store;
    await _guard(() async {
      await AuthService.reauthenticate(password: password);
      await sync.deleteCloudData();
      await store.deleteLocalData();
      await AuthService.deleteUser();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final sync = SyncScope.maybeOf(context);
    final user = sync == null ? null : AuthService.currentUser;
    final sets = store.allSets.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Konto')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (user == null) ...[
            const EmptyHint(
              'Tryb offline: dane są zapisywane tylko na tym telefonie.',
              icon: Icons.cloud_off,
            ),
            if (demoStoreOverride.value != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () => demoStoreOverride.value = null,
                  icon: const Icon(Icons.person_outline),
                  label: const Text('Zaloguj się'),
                ),
              ),
          ] else ...[
            ListTile(
              leading: CircleAvatar(
                radius: 26,
                backgroundImage:
                    user.photoURL != null ? NetworkImage(user.photoURL!) : null,
                child:
                    user.photoURL == null
                        ? Text(
                          (user.displayName ?? user.email ?? '?')[0]
                              .toUpperCase(),
                        )
                        : null,
              ),
              title: Text(
                user.displayName?.isNotEmpty == true
                    ? user.displayName!
                    : 'Użytkownik',
              ),
              subtitle: Text(user.email ?? ''),
            ),
            if (AuthService.usesPassword && !user.emailVerified)
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: Colors.amber.shade900,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Potwierdź adres e-mail',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Kliknij link, który wysłaliśmy na Twoją skrzynkę.',
                      ),
                      Row(
                        children: [
                          TextButton(
                            onPressed:
                                () => _guard(
                                  AuthService.resendVerification,
                                  success: 'Wysłano ponownie.',
                                ),
                            child: const Text('Wyślij ponownie'),
                          ),
                          TextButton(
                            onPressed:
                                () => _guard(() async {
                                  final ok =
                                      await AuthService.refreshVerified();
                                  if (mounted) setState(() {});
                                  _snack(
                                    ok
                                        ? 'Adres potwierdzony.'
                                        : 'Adres nie jest jeszcze potwierdzony.',
                                  );
                                }),
                            child: const Text('Już potwierdziłem'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SectionHeader('Synchronizacja'),
            ListTile(
              leading: Icon(switch (sync!.state) {
                SyncState.idle =>
                  store.hasPendingSync
                      ? Icons.cloud_upload_outlined
                      : Icons.cloud_done,
                SyncState.syncing => Icons.sync,
                SyncState.offline => Icons.cloud_off,
                SyncState.error => Icons.error_outline,
              }),
              title: Text(switch (sync.state) {
                SyncState.idle =>
                  store.hasPendingSync
                      ? 'Oczekuje na wysłanie'
                      : 'Wszystko zapisane w chmurze',
                SyncState.syncing => 'Synchronizuję…',
                SyncState.offline => 'Brak internetu – zmiany wyślę później',
                SyncState.error => 'Błąd synchronizacji',
              }),
              subtitle: Text(
                sync.state == SyncState.error
                    ? sync.lastError ?? ''
                    : sync.lastSynced != null
                    ? 'Ostatnio: ${formatDay(sync.lastSynced!)} ${sync.lastSynced!.hour}:${sync.lastSynced!.minute.toString().padLeft(2, '0')}'
                    : '',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: sync.syncNow,
              ),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.storage),
            title: Text('Zapisano $sets serii z ${store.months.length} mies.'),
            subtitle: Text(
              'Zajmują ${_fileSize == null ? '…' : _formatBytes(_fileSize!)} na telefonie · bez limitu',
            ),
          ),
          const SectionHeader('Wygląd'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'light',
                  icon: Icon(Icons.light_mode_outlined),
                  label: Text('Jasny'),
                ),
                ButtonSegment(
                  value: 'system',
                  icon: Icon(Icons.settings_suggest_outlined),
                  label: Text('Auto'),
                ),
                ButtonSegment(
                  value: 'dark',
                  icon: Icon(Icons.dark_mode_outlined),
                  label: Text('Ciemny'),
                ),
              ],
              selected: {store.themeMode},
              onSelectionChanged: (s) {
                store.setThemeMode(s.first);
                appThemeMode.value = themeModeFromStore(s.first);
              },
            ),
          ),
          if (user != null) ...[
            const SectionHeader('Bezpieczeństwo'),
            if (AuthService.usesPassword)
              ListTile(
                leading: const Icon(Icons.password),
                title: const Text('Zmień hasło'),
                onTap: _changePassword,
              ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Wyloguj się'),
              onTap: () => _guard(AuthService.signOut),
            ),
            ListTile(
              leading: Icon(Icons.delete_forever, color: Colors.red.shade400),
              title: Text(
                'Usuń konto',
                style: TextStyle(color: Colors.red.shade400),
              ),
              onTap: () => _deleteAccount(sync!),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatBytes(int b) =>
    b < 1024
        ? '$b B'
        : b < 1024 * 1024
        ? '${fmtNum(b / 1024, 1)} KB'
        : '${fmtNum(b / 1024 / 1024, 1)} MB';
