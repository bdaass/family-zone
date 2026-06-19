import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../services/product_catalog_service.dart';
import '../services/product_write_service.dart';
import '../services/staff_insights_service.dart';
import '../theme/app_theme.dart';
import '../utils/product_permissions.dart';
import 'product_image_carousel.dart';

class ApprovalQueueSheet extends StatelessWidget {
  final String userRole;
  final void Function(String docId, Map<String, dynamic> data)? onOpenProduct;

  const ApprovalQueueSheet({
    super.key,
    required this.userRole,
    this.onOpenProduct,
  });

  static Future<void> show(
    BuildContext context, {
    required String userRole,
    void Function(String docId, Map<String, dynamic> data)? onOpenProduct,
  }) {
    return showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ApprovalQueueSheet(userRole: userRole, onOpenProduct: onOpenProduct),
    );
  }

  bool get _canApprove => ProductPermissions.canApproveProducts(userRole);

  Future<void> _approve(BuildContext context, String docId) async {
    try {
      await ProductWriteService.approveProduct(docId);
      ProductCatalogService.instance.invalidate();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('approval_approved'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('update_failed'))));
      }
    }
  }

  Future<void> _decline(BuildContext context, String docId, Map<String, dynamic> data) async {
    final isEdit = ProductCatalog.hasPendingEdit(data);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of('approval_decline_confirm_title')),
        content: Text(isEdit ? S.of('approval_decline_edit_body') : S.of('approval_decline_new_body')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(S.of('cancel'))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(S.of('approval_decline'))),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ProductWriteService.declineProduct(docId);
      ProductCatalogService.instance.invalidate();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('approval_declined'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('update_failed'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(color: AppColors.creamDark, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.pending_actions_rounded, color: AppColors.coral, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    S.of('approval_queue_title'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.ink),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          if (!_canApprove)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                S.of('approval_queue_employee_hint'),
                style: const TextStyle(fontSize: 12, color: AppColors.inkMuted, height: 1.35),
              ),
            ),
          Flexible(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: StaffInsightsService.pendingApprovalStream(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.coral));
                }
                if (snap.hasError) {
                  return Center(child: Text(S.of('products_load_error_detail')));
                }

                final docs = StaffInsightsService.sortByCreatedDesc(snap.data?.docs ?? []);
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      S.of('approval_queue_empty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.inkMuted, height: 1.4),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    return _ApprovalCard(
                      docId: doc.id,
                      data: data,
                      canModerate: _canApprove,
                      onApprove: () => _approve(context, doc.id),
                      onDecline: () => _decline(context, doc.id, data),
                      onOpen: onOpenProduct == null
                          ? null
                          : () {
                              Navigator.pop(context);
                              onOpenProduct!(doc.id, data);
                            },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool canModerate;
  final VoidCallback onApprove;
  final VoidCallback onDecline;
  final VoidCallback? onOpen;

  const _ApprovalCard({
    required this.docId,
    required this.data,
    required this.canModerate,
    required this.onApprove,
    required this.onDecline,
    this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final productId = ProductCatalog.productIdFrom(data, docId);
    final title = ProductCatalog.titleFrom(data);
    final hasEditPending = ProductCatalog.hasPendingEdit(data);
    final imageUrl = ProductCatalog.primaryImageUrlOrNull(data);
    final changes = ProductCatalog.approvalChangeLines(data);

    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.creamDark),
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: imageUrl != null
                          ? ProductThumbnail(imageUrl: imageUrl, fit: BoxFit.cover)
                          : ColoredBox(
                              color: AppColors.creamDark,
                              child: Icon(Icons.image_not_supported_outlined, color: AppColors.inkMuted.withValues(alpha: 0.6)),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.ink)),
                        const SizedBox(height: 4),
                        Text(
                          S.fmt('product_id_label', {'id': productId}),
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (hasEditPending ? AppColors.violet : AppColors.coral).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            hasEditPending ? S.fmt('approval_queue_edit_line', {'id': productId}) : S.of('approval_new_item_badge'),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: hasEditPending ? AppColors.violet : AppColors.coral,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                S.of('approval_changes_heading'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.inkMuted, letterSpacing: 0.3),
              ),
              const SizedBox(height: 8),
              ...changes.map(
                (line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 12, color: AppColors.coral, fontWeight: FontWeight.w900)),
                      Expanded(
                        child: Text(
                          line,
                          style: const TextStyle(fontSize: 12, color: AppColors.ink, height: 1.35, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (canModerate) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onDecline,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.inkMuted,
                          side: const BorderSide(color: AppColors.creamDark),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(S.of('approval_decline'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: onApprove,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.coral,
                          foregroundColor: AppColors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: Text(S.of('approval_approve'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    S.of('approval_waiting'),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
