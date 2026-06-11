class ProductPermissions {
  static bool isStaff(String role) => role == 'admin' || role == 'employee';

  static bool isClient(String role) => role == 'client';

  static bool canDelete(String role) => role == 'admin';

  static bool canEdit(String role) => role == 'admin' || role == 'employee';

  static bool canToggleVisibility(String role) => role == 'admin';

  static bool canApproveProducts(String role) => role == 'admin';

  static bool isApproved(Map<String, dynamic> data) => data['approved'] != false;

  static bool isVisible(Map<String, dynamic> data) => data['visibility'] == true;

  static bool isPendingApproval(Map<String, dynamic> data) => data['approved'] == false;

  /// Guests and clients only see approved, visible products.
  static bool isPublicCatalogItem(Map<String, dynamic> data) {
    return isVisible(data) && isApproved(data);
  }
}
