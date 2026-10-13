// ignore_for_file: curly_braces_in_flow_control_structures
class StaffPolicy {
  static bool canEnter(String? role) =>
      {'owner', 'kitchen', 'delivery'}.contains(role);
  static bool canAssign(String? role) => role == 'owner';
  static bool canCustomers(String? role) => role == 'owner';
  static bool visible(String role, String userId, Map<String, dynamic> o) =>
      role != 'delivery' || o['assigned_to'] == userId;
  static String? next(String role, Map<String, dynamic> o) {
    if (role == 'delivery')
      return o['status'] == 'Out for Delivery' ? 'Delivered' : null;
    if (role == 'owner' || role == 'kitchen')
      return switch (o['status']) {
        'Confirmed' => 'Preparing',
        'Preparing' => 'Packed',
        'Packed' =>
          role == 'owner' &&
                  o['payment_status'] == 'verified' &&
                  o['assigned_to'] != null
              ? 'Out for Delivery'
              : null,
        _ => null,
      };
    return null;
  }
}
