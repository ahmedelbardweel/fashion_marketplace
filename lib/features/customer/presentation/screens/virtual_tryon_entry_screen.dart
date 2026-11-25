import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../virtual_tryon/domain/tryon_quota.dart';
import '../../../virtual_tryon/presentation/tryon_quota_provider.dart';
import 'decart_tryon_screen.dart';
import 'vidu_tryon_screen.dart';

/// Routes customers automatically to whichever Virtual Try-On engine the Admin
/// currently selected (`Decart AI` live camera OR `Vidu AI` high-res photo).
class VirtualTryonEntryScreen extends ConsumerWidget {
  const VirtualTryonEntryScreen({super.key, required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotaAsync = ref.watch(tryonQuotaProvider);
    final quota = quotaAsync.valueOrNull;

    if (quota == null && quotaAsync.isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final provider = quota?.activeProvider ?? TryonProvider.decart;
    if (provider == TryonProvider.vidu) {
      return ViduTryonScreen(productId: productId);
    }
    return DecartTryonScreen(productId: productId);
  }
}
