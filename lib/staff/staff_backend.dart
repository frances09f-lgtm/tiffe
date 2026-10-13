import '../live/backend.dart';

extension StaffOrderStream on TiffeBackend {
  Stream<List<Map<String, dynamic>>> staffOrders(String role) =>
      role == 'delivery'
      ? client
            .from('orders')
            .stream(primaryKey: ['id'])
            .eq('assigned_to', userId!)
            .order('delivery_date')
      : orders();
}
