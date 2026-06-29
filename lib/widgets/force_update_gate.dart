import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_strings.dart';
import '../services/app_version_service.dart';
import '../theme/app_theme.dart';

/// On Android/iOS, reads Firestore `app_config/mobile` and blocks the app when
/// `force_update` is true and the installed build is older than `current_version`.
class ForceUpdateGate extends StatefulWidget {
  const ForceUpdateGate({super.key, required this.child});

  final Widget child;

  @override
  State<ForceUpdateGate> createState() => _ForceUpdateGateState();
}

class _ForceUpdateGateState extends State<ForceUpdateGate> {
  late final Future<AppVersionCheckResult> _checkFuture = AppVersionService.instance.checkForUpdate();

  Future<void> _openStore(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppVersionService.instance.isSupportedPlatform) {
      return widget.child;
    }

    return FutureBuilder<AppVersionCheckResult>(
      future: _checkFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _ForceUpdateLoading();
        }

        final result = snapshot.data;
        if (result == null || !result.forceUpdateRequired) {
          return widget.child;
        }

        return _ForceUpdateScreen(
          installedVersion: result.installedVersion,
          requiredVersion: result.config.currentVersion,
          storeUrl: result.storeUrl,
          onUpdatePressed: () => _openStore(result.storeUrl),
        );
      },
    );
  }
}

class _ForceUpdateLoading extends StatelessWidget {
  const _ForceUpdateLoading();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo.png', width: 72, height: 72),
              const SizedBox(height: 20),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.coral),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForceUpdateScreen extends StatelessWidget {
  const _ForceUpdateScreen({
    required this.installedVersion,
    required this.requiredVersion,
    required this.storeUrl,
    required this.onUpdatePressed,
  });

  final String installedVersion;
  final String requiredVersion;
  final String? storeUrl;
  final VoidCallback onUpdatePressed;

  @override
  Widget build(BuildContext context) {
    final hasStoreLink = storeUrl != null && storeUrl!.trim().isNotEmpty;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.cream,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/images/logo.png', width: 96, height: 96),
                  const SizedBox(height: 28),
                  Text(
                    S.of('force_update_title'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    S.fmt('force_update_message', {
                      'installed': installedVersion,
                      'required': requiredVersion,
                    }),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.inkMuted.withValues(alpha: 0.95),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: hasStoreLink ? onUpdatePressed : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Text(
                        S.of('force_update_button'),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                  if (!hasStoreLink && kDebugMode) ...[
                    const SizedBox(height: 12),
                    Text(
                      S.of('force_update_missing_store_url'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: AppColors.inkMuted.withValues(alpha: 0.8)),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
