import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../l10n/app_strings.dart';
import '../models/product_catalog.dart';
import '../services/staff_insights_service.dart';
import '../theme/app_theme.dart';
import '../utils/product_permissions.dart';

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
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ApprovalQueueSheet(userRole: userRole, onOpenProduct: onOpenProduct),
    );
  }

  bool get _canApprove => ProductPermissions.canApproveProducts(userRole);

  Future<void> _approve(BuildContext context, String docId) async {
    try {
      await FirebaseFirestore.instance.collection('products').doc(docId).update({
        'approved': true,
        'visibility': true,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.of('approval_approved'))));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(S.fmt('update_failed', {'error': '$e'}))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

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
                  return Center(child: Text(S.fmt('products_load_error_detail', {'error': '${snap.error}'})));
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
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final productId = ProductCatalog.productIdFrom(data, doc.id);
                    final title = ProductCatalog.titleFrom(data);
                    final price = ProductCatalog.priceFrom(data);

                    return Container(
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.creamDark),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        subtitle: Text(
                          S.fmt('approval_queue_line', {'id': productId, 'price': price.toStringAsFixed(2)}),
                          style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
                        ),
                        trailing: _canApprove
                            ? FilledButton(
                                onPressed: () => _approve(context, doc.id),
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.coral,
                                  foregroundColor: AppColors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                ),
                                child: Text(S.of('approval_approve'), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                              )
                            : Text(
                                S.of('approval_waiting'),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.inkMuted),
                              ),
                        onTap: onOpenProduct == null ? null : () {
                          Navigator.pop(context);
                          onOpenProduct!(doc.id, data);
                        },
                      ),
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
