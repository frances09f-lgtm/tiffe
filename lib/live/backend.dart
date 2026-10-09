import 'package:supabase_flutter/supabase_flutter.dart';

class BackendConfig {
  static const ownerEmail = String.fromEnvironment('TIFFE_OWNER_EMAIL');
  static String loginEmail(String input, {required bool admin}) {
    final value = input.trim();
    return admin && value.toLowerCase() == 'admin' && ownerEmail.isNotEmpty
        ? ownerEmail
        : value;
  }

  static const url = String.fromEnvironment('TIFFE_SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('TIFFE_SUPABASE_KEY');
  static bool get configured => url.isNotEmpty && publishableKey.isNotEmpty;
  static bool _initialized = false;
  static Future<SupabaseClient?> initialize() async {
    if (!configured) return null;
    if (_initialized) return Supabase.instance.client;
    await Supabase.initialize(url: url, publishableKey: publishableKey);
    _initialized = true;
    return Supabase.instance.client;
  }
}

/// Both entry points use the same schema. RLS scopes streams to the session.
class TiffeBackend {
  final SupabaseClient client;
  TiffeBackend(this.client);
  String? get userId => client.auth.currentUser?.id;
  Stream<AuthState> get authChanges => client.auth.onAuthStateChange;
  Future<AuthResponse> signIn(String email, String password) =>
      client.auth.signInWithPassword(email: email, password: password);
  Future<AuthResponse> signUp(String email, String password) =>
      client.auth.signUp(email: email, password: password);
  Future<void> signOut() => client.auth.signOut();
  Stream<List<Map<String, dynamic>>> menu() =>
      client.from('menu_items').stream(primaryKey: ['id']).order('sort_order');
  Stream<List<Map<String, dynamic>>> settings() =>
      client.from('settings').stream(primaryKey: ['id']);
  Stream<List<Map<String, dynamic>>> orders({bool customer = false}) {
    final stream = client.from('orders').stream(primaryKey: ['id']);
    return customer
        ? stream
              .eq('customer_id', userId ?? '')
              .order('created_at', ascending: false)
        : stream.order('created_at', ascending: false);
  }

  Stream<List<Map<String, dynamic>>> subscriptions() => client
      .from('subscriptions')
      .stream(primaryKey: ['id'])
      .eq('customer_id', userId ?? '');
  Future<String?> role() async {
    if (userId == null) return null;
    final row = await client
        .from('staff_members')
        .select('role')
        .eq('user_id', userId!)
        .maybeSingle();
    return row?['role'] as String?;
  }

  Future<void> saveMenu({
    String? id,
    required String name,
    required String description,
    required bool available,
  }) async {
    final values = {
      'name': name,
      'description': description,
      'available': available,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (id == null) {
      await client.from('menu_items').insert(values);
    } else {
      await client.from('menu_items').update(values).eq('id', id);
    }
  }

  Future<Map<String, dynamic>?> currentSettings() async =>
      client.from('settings').select().eq('id', true).maybeSingle();

  Future<Map<String, dynamic>?> profile() async {
    if (userId == null) return null;
    return client.from('profiles').select().eq('id', userId!).maybeSingle();
  }

  Future<void> saveProfile({
    required String name,
    required String phone,
    required String address,
    required String area,
  }) async {
    if (userId == null) throw StateError('Sign in required');
    await client.from('profiles').upsert({
      'id': userId,
      'name': name,
      'phone': phone,
      'address': address,
      'area': area,
    });
  }

  Future<String> placeOrder({
    required String date,
    required List<List<String>> tiffins,
    required String idempotencyKey,
    String instructions = '',
    String? subscriptionId,
  }) async {
    return (await client.rpc(
      'place_order',
      params: {
        'p_date': date,
        'p_tiffins': tiffins,
        'p_key': idempotencyKey,
        'p_instructions': instructions,
        'p_subscription': subscriptionId,
      },
    )) as String;
  }

  Future<void> advance(String id, String status, {DateTime? eta}) async =>
      client.rpc(
        'advance_order',
        params: {
          'p_order': id,
          'p_status': status,
          'p_eta': eta?.toUtc().toIso8601String(),
        },
      );
}
