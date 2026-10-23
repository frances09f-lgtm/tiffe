from pathlib import Path

p = Path('lib/staff/partner_hub.dart')
s = p.read_text()
def once(old, new):
    global s
    assert s.count(old) == 1, (old[:120], s.count(old))
    s = s.replace(old, new)

if 'Timer? ordersPoll;' not in s:
    once('  final String role;\n  const PartnerHub({super.key, required this.backend, required this.role});', '''  final String role;
  /// Optional read seam for isolated tests; production still uses the session's RLS.
  final Future<List<Map<String, dynamic>>> Function()? readOrders;
  const PartnerHub({
    super.key,
    required this.backend,
    required this.role,
    this.readOrders,
  });''')
    once("  String? itemsError;", "  String? itemsError;\n  Timer? ordersPoll;\n  Future<void>? ordersRequest;\n  String? ordersError;\n  bool ordersRefreshing = false;\n  int ordersRevision = 0;")
    start = s.index('    os = widget.backend.orders().listen(')
    end = s.index('    ms = widget.backend.menu()', start)
    s = s[:start] + '''    os = widget.backend.orders().listen(
      acceptOrders,
      onError: (Object error, StackTrace stack) => orderLoadFailed(),
    );
    // Realtime remains the fast path. A separate SELECT recovers a stalled socket.
    ordersPoll = Timer.periodic(
      const Duration(seconds: 15),
      (_) => refreshOrders(),
    );
''' + s[end:]
    once('  Future<void> reload() async {', '''  void orderLoadFailed() {
    if (!mounted) return;
    setState(() => ordersError =
        'Orders could not load. The list may be out of date. Tap Refresh to retry.');
  }

  Future<void> acceptOrders(List<Map<String, dynamic>> rows) async {
    if (!mounted) return;
    ordersRevision++;
    setState(() {
      orders = rows;
      ordersError = null;
    });
    try {
      final got = await widget.backend.orderItems(
        rows.map((o) => o['id'] as String).toList(),
      );
      if (mounted) setState(() {
        items = got;
        itemsError = null;
      });
    } catch (_) {
      if (mounted) setState(() => itemsError =
          'Bhaji counts could not be loaded. Refresh to retry.');
    }
  }

  Future<void> refreshOrders() {
    if (!mounted) return Future.value();
    // Timer, button and pull-to-refresh share one in-flight request.
    return ordersRequest ??= readOrdersOnce().whenComplete(() {
      ordersRequest = null;
    });
  }

  Future<void> readOrdersOnce() async {
    setState(() => ordersRefreshing = true);
    final revision = ordersRevision;
    try {
      final read = widget.readOrders ?? () async {
        final rows = await widget.backend.client
            .from('orders')
            .select()
            .order('created_at', ascending: false);
        return List<Map<String, dynamic>>.from(rows);
      };
      final rows = await read().timeout(const Duration(seconds: 10));
      // Do not overwrite a newer realtime snapshot with an older SELECT result.
      if (mounted && revision == ordersRevision) await acceptOrders(rows);
    } catch (_) {
      orderLoadFailed();
    } finally {
      if (mounted) setState(() => ordersRefreshing = false);
    }
  }

  Future<void> reload() async {''')
    once('  void dispose() {\n    os?.cancel();', '  void dispose() {\n    ordersPoll?.cancel();\n    os?.cancel();')
    once('''            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,''', '''            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: ordersRefreshing ? null : refreshOrders,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: Text(ordersRefreshing ? 'Refreshing...' : 'Refresh'),
                    ),
                  ),
                  if (ordersError != null)
                    Semantics(
                      liveRegion: true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(ordersError!),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,''')
    once('''                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(wide ? 32 : 16),''', '''                    child: RefreshIndicator(
                      onRefresh: refreshOrders,
                      child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.all(wide ? 32 : 16),''')
    once('''                          child: body,
                        ),
                      ),
                    ),''', '''                          child: body,
                        ),
                      ),
                      ),
                    ),''')
    p.write_text(s)
    for path in ['pubspec.yaml', 'lib/live/bug_report.dart']:
        f = Path(path)
        text = f.read_text()
        assert '1.0.46+46' in text
        f.write_text(text.replace('1.0.46+46', '1.0.47+47'))

# The Firebase upload uses the existing project and app. It adds no testers and
# sends no tester invitations. Payment, login and staff role code are untouched.
f = Path('scripts/firebase_staff_v4.cjs')
if not f.exists():
    text = Path('scripts/firebase_staff_v2.cjs').read_text()
    text = text.replace("r.buildVersion==='2'", "r.buildVersion==='4'")
    text = text.replace('v2-existing-release-reconcile-before-retry', 'v4-existing-release-reconcile-before-retry')
    text = text.replace("release.buildVersion!=='2'||release.displayVersion!=='1.0.2'", "release.buildVersion!=='4'||release.displayVersion!=='1.0.4'")
    text = text.replace("fs.readFileSync('STAFF-V2-CANDIDATE.md','utf8')", "'Tiffe Staff v4: orders re-read every 15 seconds, Refresh, pull-to-refresh and load errors. CI passed. Not tested on a phone.'")
    a = text.index("const testers=await req(")
    b = text.index("const live=await req(", a)
    text = text[:a] + text[b:]
    text = text.replace('firebase-staff-v2-result.json', 'firebase-staff-v4-result.json')
    text = text.replace("recipients:['frances09f@gmail.com','sourabhsutar1112@gmail.com'],distributed:true", "recipients:[],distributed:false,uploaded:true")
    f.write_text(text)
print('Staff-only refresh patch ready; payment, login and role sources unchanged')
