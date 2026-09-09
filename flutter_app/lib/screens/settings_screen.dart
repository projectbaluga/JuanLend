import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../store/app_state.dart';
import '../store/backup_service.dart';
import '../widgets/custom_card.dart';
import '../widgets/responsive_container.dart';

enum _BackupAction { saveFile, share, viewJson }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _dataBackupUnlocked = false;

  Future<bool> _confirmIdentity(BuildContext context, AppState state) async {
    if (_dataBackupUnlocked) return true;

    final user = state.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to perform Data & Backup actions.')),
      );
      return false;
    }

    final passCtrl = TextEditingController();
    String? errorMsg;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirm Identity'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Enter password for ${user.username} to access Data & Backup actions.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  if (errorMsg != null) ...[
                    Text(
                      errorMsg!,
                      style: const TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Account Password',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) {
                      final entered = passCtrl.text;
                      if (user.verifyPassword(entered.trim())) {
                        Navigator.pop(dialogCtx, true);
                      } else {
                        setDialogState(() {
                          errorMsg = 'Incorrect password. Access denied.';
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final entered = passCtrl.text;
                    if (user.verifyPassword(entered.trim())) {
                      Navigator.pop(dialogCtx, true);
                    } else {
                      setDialogState(() {
                        errorMsg = 'Incorrect password. Access denied.';
                      });
                    }
                  },
                  child: const Text('Verify & Proceed'),
                ),
              ],
            );
          },
        );
      },
    );

    passCtrl.dispose();

    if (result == true) {
      if (mounted) {
        setState(() {
          _dataBackupUnlocked = true;
        });
      }
      return true;
    }
    return false;
  }

  void _promptExportPassphrase(BuildContext context, AppState state, {required _BackupAction action}) {
    final passCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          title: const Text('Export Backup Encryption'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Optional: Enter a passphrase to encrypt this backup with AES-GCM (PBKDF2). Leave blank to export with HMAC integrity signature.',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Encryption Passphrase (Optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final pass = passCtrl.text.trim();
                Navigator.pop(dialogCtx);
                final jsonStr = state.exportDataJson(passphrase: pass.isNotEmpty ? pass : null);

                switch (action) {
                  case _BackupAction.saveFile:
                    try {
                      final filePath = await BackupService.saveBackupToFile(jsonStr);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Backup saved to $filePath')),
                      );
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save backup file: $e')),
                      );
                    }
                    break;
                  case _BackupAction.share:
                    try {
                      await BackupService.shareBackup(jsonStr);
                    } catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to share backup: $e')),
                      );
                    }
                    break;
                  case _BackupAction.viewJson:
                    _showExportDialog(context, jsonStr);
                    break;
                }
              },
              child: const Text('Continue Export'),
            ),
          ],
        );
      },
    );
  }

  void _handleRestoreContent(BuildContext context, AppState state, String content) {
    if (content.contains('"encrypted": true')) {
      final passCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (dialogCtx) {
          return AlertDialog(
            title: const Text('Encrypted Backup Detected'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This backup file is encrypted. Please enter the passphrase used during export to decrypt and restore data.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Decryption Passphrase',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final pass = passCtrl.text.trim();
                  Navigator.pop(dialogCtx);
                  _executeRestore(context, state, content, passphrase: pass);
                },
                child: const Text('Decrypt & Restore'),
              ),
            ],
          );
        },
      );
    } else {
      _showConfirmDialog(
        context: context,
        title: 'Restore Backup from File?',
        message: 'This action will overwrite your current local borrowers and loans data with the selected file.',
        onConfirm: () => _executeRestore(context, state, content),
      );
    }
  }

  void _executeRestore(BuildContext context, AppState state, String content, {String? passphrase}) async {
    try {
      await state.importDataJson(content, passphrase: passphrase);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data successfully restored from backup file!')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to restore data: ${e is FormatException ? e.message : e.toString()}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showExportDialog(BuildContext context, String jsonStr) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Exported JSON Data'),
          content: SizedBox(
            width: double.maxFinite,
            height: 240,
            child: SingleChildScrollView(
              child: SelectableText(
                jsonStr,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('JSON copied to clipboard!')),
                );
                Navigator.pop(ctx);
              },
              child: const Text('Copy to Clipboard'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showConfirmDialog({
    required BuildContext context,
    required String title,
    required String message,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(ctx);
                onConfirm();
              },
              child: const Text('Confirm', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final isDesktop = ResponsiveContainer.isDesktop(context);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: ResponsiveContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isDesktop) ...[
                const Text(
                  'Settings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
              ],

              // 1. Business / Operator Section
              _BusinessNameSection(
                initialName: state.businessName,
                onSave: (newName) => state.setBusinessName(newName),
              ),

              const SizedBox(height: 16),

              // 2. Currency & Formatting Section
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Currency & Formatting', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Currency', style: TextStyle(fontSize: 13)),
                        DropdownButton<String>(
                          value: state.currencyCode,
                          items: const [
                            DropdownMenuItem(value: 'PHP', child: Text('PHP (₱)')),
                            DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                            DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                            DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
                          ],
                          onChanged: (val) {
                            if (val != null) state.setCurrencyCode(val);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Date Format', style: TextStyle(fontSize: 13)),
                        DropdownButton<String>(
                          value: state.dateFormat,
                          items: const [
                            DropdownMenuItem(value: 'MMM d, yyyy', child: Text('Jan 15, 2026')),
                            DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('2026-01-15')),
                            DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('15/01/2026')),
                          ],
                          onChanged: (val) {
                            if (val != null) state.setDateFormat(val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 3. Loan Defaults Section
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Loan Defaults', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Default Repayment Frequency', style: TextStyle(fontSize: 13)),
                        DropdownButton<String>(
                          value: state.defaultRepaymentFrequency,
                          items: const [
                            DropdownMenuItem(value: 'daily', child: Text('Daily')),
                            DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                            DropdownMenuItem(value: 'biweekly', child: Text('Bi-weekly')),
                            DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                          ],
                          onChanged: (val) {
                            if (val != null) state.setDefaultRepaymentFrequency(val);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Default Interest Method', style: TextStyle(fontSize: 13)),
                        DropdownButton<String>(
                          value: state.defaultInterestMethod,
                          items: const [
                            DropdownMenuItem(value: 'reducing', child: Text('Reducing Balance')),
                            DropdownMenuItem(value: 'flat', child: Text('Flat / Add-on ("5-6")')),
                            DropdownMenuItem(value: 'interest_only', child: Text('Interest-Only')),
                            DropdownMenuItem(value: 'one_time', child: Text('One-Time Payment')),
                          ],
                          onChanged: (val) {
                            if (val != null) state.setDefaultInterestMethod(val);
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Default Term (Periods)', style: TextStyle(fontSize: 13)),
                        Text('${state.defaultTermPeriods} periods', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Slider(
                      value: state.defaultTermPeriods.toDouble(),
                      min: 1,
                      max: 60,
                      divisions: 59,
                      label: '${state.defaultTermPeriods} periods',
                      onChanged: (val) => state.setDefaultTermPeriods(val.round()),
                    ),
                    const Divider(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Default Interest Rate (%)', style: TextStyle(fontSize: 13)),
                        DropdownButton<double>(
                          value: state.defaultInterestRate,
                          items: const [
                            DropdownMenuItem(value: 8.0, child: Text('8.0%')),
                            DropdownMenuItem(value: 10.0, child: Text('10.0%')),
                            DropdownMenuItem(value: 12.0, child: Text('12.0%')),
                            DropdownMenuItem(value: 14.0, child: Text('14.0%')),
                            DropdownMenuItem(value: 16.0, child: Text('16.0%')),
                            DropdownMenuItem(value: 20.0, child: Text('20.0%')),
                          ],
                          onChanged: (val) {
                            if (val != null) state.setDefaultInterestRate(val);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 4. Appearance Section
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Appearance', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Dark Mode', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('Use dark theme palette', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      value: state.isDarkMode,
                      onChanged: (val) => state.setThemeMode(val ? ThemeMode.dark : ThemeMode.light),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 5. Full Features / Unlock Section
              const _FullFeaturesSection(),

              const SizedBox(height: 16),

              // 6. Data & Backup Section
              CustomCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Data & Backup', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        Icon(
                          _dataBackupUnlocked ? Icons.lock_open : Icons.lock_outline,
                          size: 16,
                          color: _dataBackupUnlocked ? Colors.greenAccent : Colors.grey,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Back up to File', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('Save backup JSON (with optional encryption passphrase)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: const Icon(Icons.save_alt, size: 18),
                      onTap: () async {
                        if (await _confirmIdentity(context, state)) {
                          if (!context.mounted) return;
                          _promptExportPassphrase(context, state, action: _BackupAction.saveFile);
                        }
                      },
                    ),
                    const Divider(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Share Backup', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('Export encrypted or signed JSON file to other apps', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: const Icon(Icons.share, size: 18),
                      onTap: () async {
                        if (await _confirmIdentity(context, state)) {
                          if (!context.mounted) return;
                          _promptExportPassphrase(context, state, action: _BackupAction.share);
                        }
                      },
                    ),
                    const Divider(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Restore from File', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('Pick and import backup file with integrity & decryption checks', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: const Icon(Icons.upload_file, size: 18),
                      onTap: () async {
                        if (await _confirmIdentity(context, state)) {
                          if (!context.mounted) return;
                          try {
                            final content = await BackupService.pickAndReadBackup();
                            if (content == null || !context.mounted) return;
                            _handleRestoreContent(context, state, content);
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to read file: $e')),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Export Data (JSON)', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('Export borrowers and loans to JSON string', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: const Icon(Icons.download, size: 18),
                      onTap: () async {
                        if (await _confirmIdentity(context, state)) {
                          if (!context.mounted) return;
                          _promptExportPassphrase(context, state, action: _BackupAction.viewJson);
                        }
                      },
                    ),
                    const Divider(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Restore Sample Data', style: TextStyle(fontSize: 13)),
                      subtitle: const Text('Reset store and re-seed 3 sample borrowers & loans', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: const Icon(Icons.restart_alt, size: 18),
                      onTap: () async {
                        if (await _confirmIdentity(context, state)) {
                          if (!context.mounted) return;
                          _showConfirmDialog(
                            context: context,
                            title: 'Restore Sample Data?',
                            message: 'This will wipe current records and reload the original 3 sample borrowers and loans.',
                            onConfirm: () => state.restoreSampleData(),
                          );
                        }
                      },
                    ),
                    const Divider(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Clear All Data', style: TextStyle(fontSize: 13, color: Colors.redAccent)),
                      subtitle: const Text('Wipe all local borrowers and loans', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: const Icon(Icons.delete_forever, size: 18, color: Colors.redAccent),
                      onTap: () async {
                        if (await _confirmIdentity(context, state)) {
                          if (!context.mounted) return;
                          _showConfirmDialog(
                            context: context,
                            title: 'Clear All Data?',
                            message: 'Are you sure you want to delete all borrowers and loans? This action cannot be undone.',
                            onConfirm: () => state.clearAllData(),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 7. About Section
              CustomCard(
                child: FutureBuilder<PackageInfo>(
                  future: PackageInfo.fromPlatform(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('About ${state.appName}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ],
                      );
                    }

                    final pkgVer = snapshot.data?.version.trim() ?? '';
                    final ver = state.appVersion.isNotEmpty
                        ? state.appVersion
                        : (pkgVer.isNotEmpty ? pkgVer : '1.0.0');

                    final pkgBuild = snapshot.data?.buildNumber.trim() ?? '';
                    final build = state.appBuild.isNotEmpty
                        ? state.appBuild
                        : (pkgBuild.isNotEmpty ? pkgBuild : '1');

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('About ${state.appName}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('${state.appName} v$ver', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Text('Build $build', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.appDescription,
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FullFeaturesSection extends StatefulWidget {
  const _FullFeaturesSection();

  @override
  State<_FullFeaturesSection> createState() => _FullFeaturesSectionState();
}

class _FullFeaturesSectionState extends State<_FullFeaturesSection> {
  final TextEditingController _licenseCtrl = TextEditingController();

  @override
  void dispose() {
    _licenseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);

    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Full Features', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (state.isFeaturesUnlocked) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.check_circle, size: 18, color: Colors.greenAccent),
                    SizedBox(width: 8),
                    Text('Full Features Unlocked', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => state.lockFeatures(),
                  icon: const Icon(Icons.lock, size: 16),
                  label: const Text('Lock again'),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Unlicensed edition is limited to 5 borrowers. Enter unlock code to enable full features.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _licenseCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Enter unlock code...',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () async {
                    final key = _licenseCtrl.text;
                    if (key.trim().isEmpty) return;
                    final success = await state.unlockFeatures(key);
                    if (!context.mounted) return;
                    if (success) {
                      _licenseCtrl.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Full features successfully unlocked!')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid unlock code')),
                      );
                    }
                  },
                  child: const Text('Unlock'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _BusinessNameSection extends StatefulWidget {
  final String initialName;
  final ValueChanged<String> onSave;

  const _BusinessNameSection({required this.initialName, required this.onSave});

  @override
  State<_BusinessNameSection> createState() => _BusinessNameSectionState();
}

class _BusinessNameSectionState extends State<_BusinessNameSection> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final val = _controller.text.trim();
    if (val.isNotEmpty && val != widget.initialName) {
      widget.onSave(val);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Business / Operator', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Operator Name', style: TextStyle(fontSize: 13)),
              SizedBox(
                width: 180,
                child: Focus(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) _save();
                  },
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      border: OutlineInputBorder(),
                    ),
                    onEditingComplete: _save,
                    onSubmitted: (_) => _save(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
