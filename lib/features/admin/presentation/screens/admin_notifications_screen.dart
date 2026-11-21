import 'package:fashion_marketplace/core/utils/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_design.dart';
import '../../../../core/utils/snackbar_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_bottom_sheet.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_empty.dart';
import '../../../../core/widgets/app_refresh_indicator.dart';
import '../../../../core/widgets/app_skeleton.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/gaza_region_picker_sheet.dart';
import '../../../../core/widgets/loading_fixtures.dart';
import '../../domain/models/gaza_region.dart';
import '../providers/admin_providers.dart';
import '../widgets/admin_app_bar.dart';
import '../widgets/admin_components.dart';

class AdminNotificationsScreen extends ConsumerStatefulWidget {
  const AdminNotificationsScreen({super.key});

  @override
  ConsumerState<AdminNotificationsScreen> createState() =>
      _AdminNotificationsScreenState();
}

class _AdminNotificationsScreenState
    extends ConsumerState<AdminNotificationsScreen> {
  Future<void> _openComposer() async {
    final titleCtrl = TextEditingController();
    final bodyCtrl = TextEditingController();
    var audience = 'all';
    String? targetRegion;
    var sending = false;
    final formKey = GlobalKey<FormState>();

    await AppBottomSheet.show<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      maxHeightFactor: 0.92,
      child: StatefulBuilder(
        builder: (sheetCtx, setSheetState) {
          return AppBottomSheetScaffold(
            title: 'إرسال إشعار جديد'.tr,
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'الجمهور المستهدف'.tr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: AppFont.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      ChoiceChip(
                        label: Text('الجميع'.tr),
                        selected: audience == 'all',
                        onSelected: (_) => setSheetState(() => audience = 'all'),
                      ),
                      ChoiceChip(
                        label: Text('العملاء فقط'.tr),
                        selected: audience == 'customer',
                        onSelected: (_) =>
                            setSheetState(() => audience = 'customer'),
                      ),
                      ChoiceChip(
                        label: Text('المحلات فقط'.tr),
                        selected: audience == 'shop',
                        onSelected: (_) =>
                            setSheetState(() => audience = 'shop'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  Text(
                    'تخصيص لمنطقة في قطاع غزة (اختياري)'.tr,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: AppFont.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: targetRegion != null
                              ? '${'المنطقة'.tr}: $targetRegion'
                              : 'كل مناطق قطاع غزة'.tr,
                          variant: AppButtonVariant.secondary,
                          onPressed: sending
                              ? null
                              : () async {
                                  final regions =
                                      ref
                                          .read(adminGazaRegionsProvider)
                                          .asData
                                          ?.value ??
                                      kDefaultGazaRegions;
                                  final picked =
                                      await showGazaRegionPickerSheet(
                                        context: sheetCtx,
                                        regions: regions,
                                        selectedRegionName: targetRegion,
                                        allowClear: true,
                                        title: 'استهداف منطقة في قطاع غزة',
                                      );
                                  if (picked == null || !sheetCtx.mounted) {
                                    return;
                                  }
                                  setSheetState(() {
                                    targetRegion = picked.name.isEmpty
                                        ? null
                                        : picked.name;
                                  });
                                },
                        ),
                      ),
                      if (targetRegion != null) ...[
                        const SizedBox(width: AppSpacing.sm),
                        AppButton(
                          label: 'مسح'.tr,
                          variant: AppButtonVariant.secondary,
                          expand: false,
                          onPressed: sending
                              ? null
                              : () => setSheetState(() => targetRegion = null),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: titleCtrl,
                    label: 'عنوان الإشعار *'.tr,
                    hint: 'مثال: عروض جديدة في غزة أو تحديث التوصيل'.tr,
                    validator: (v) =>
                        Validators.required(v, field: 'العنوان'.tr),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  AppTextField(
                    controller: bodyCtrl,
                    label: 'نص الإشعار *'.tr,
                    hint: 'اكتب تفاصيل الإشعار بوضوح...'.tr,
                    maxLines: 4,
                    validator: (v) =>
                        Validators.required(v, field: 'نص الإشعار'.tr),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  AppButton(
                    label: 'إرسال الإشعار الآن'.tr,
                    isLoading: sending,
                    onPressed: () async {
                      FocusScope.of(sheetCtx).unfocus();
                      if (formKey.currentState?.validate() != true) return;
                      setSheetState(() => sending = true);
                      final actions = ref.read(adminActionProvider.notifier);
                      final ok = await actions.sendNotification(
                        title: titleCtrl.text,
                        body: bodyCtrl.text,
                        audience: audience,
                        targetRegion: targetRegion,
                      );
                      if (!mounted) return;
                      if (!ok) {
                        if (sheetCtx.mounted) {
                          setSheetState(() => sending = false);
                        }
                        final err = ref.read(adminActionProvider).error;
                        showAppSnackBar(
                          context,
                          err == null
                              ? 'تعذر إرسال الإشعار'.tr
                              : actions.errorMessage(err),
                          isError: true,
                        );
                        return;
                      }
                      if (sheetCtx.mounted) Navigator.of(sheetCtx).pop();
                      showAppSnackBar(context, 'تم إرسال الإشعار بنجاح'.tr);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 300));
    titleCtrl.dispose();
    bodyCtrl.dispose();
  }

  String _formatDate(DateTime dt) {
    final l = dt.toLocal();
    return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year} • ${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final notifsAsync = ref.watch(adminNotificationsProvider);
    final busy = ref.watch(adminActionProvider).isLoading;

    return AdminScaffold(
      title: 'الإشعارات الجماعية والموجهة'.tr,
      showBack: true,
      showBottomNav: false,
      bottom: AppButton(
        label: 'إرسال إشعار جديد'.tr,
        isLoading: busy,
        onPressed: _openComposer,
      ),
      body: notifsAsync.skeletonWhen(
        placeholder: LoadingFixtures.notifications,
        error: (err, _) => ListView(
          padding: AppSpacing.page,
          children: [
            AdminNoticeBanner(
              title: 'تعذر تحميل الإشعارات',
              message: ref.read(adminRepositoryProvider).mapError(err),
              tone: BadgeTone.error,
              actionLabel: 'إعادة المحاولة',
              onAction: () => ref.invalidate(adminNotificationsProvider),
            ),
          ],
        ),
        data: (items) {
          if (items.isEmpty) {
            return AdminCenteredEmptyView(
              onRefresh: () => ref.refresh(adminNotificationsProvider.future),
              title: 'لا توجد إشعارات مرسلة بعد',
              message:
                  'أرسل أول إشعار للعملاء أو المحلات أو لمناطق محددة في قطاع غزة.',
            );
          }

          return AppRefreshIndicator(
            onRefresh: () => ref.refresh(adminNotificationsProvider.future),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.page,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final n = items[index];
                return Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: SellerDesign.statCardBackground,
                    borderRadius: BorderRadius.circular(CardDesign.radius),
                    border: Border.all(color: SellerDesign.statCardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: AppFont.bold),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          AppStatusBadge(
                            label: n.audienceLabel,
                            tone: n.targetRegion != null
                                ? BadgeTone.primary
                                : BadgeTone.neutral,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        n.body,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _formatDate(n.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
