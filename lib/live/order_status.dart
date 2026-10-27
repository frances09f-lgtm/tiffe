/// Order and menu rules shared by the customer screens and the background
/// order check. They work with the database before and after the tiffe-v56
/// migration (database/tiffe-v56-order-placed-and-menu-archive.sql).
library;

/// Status shown for a new order the kitchen has not accepted yet.
const kOrderPlaced = 'Order placed';

/// True when the kitchen has not accepted this order yet. Rows from before
/// the migration have no awaiting_acceptance value and count as confirmed,
/// so no existing order changes how it reads.
bool awaitingAcceptance(Map o) =>
    o['status'] == 'Placed' ||
    o['status'] == kOrderPlaced ||
    (o['status'] == 'Confirmed' && o['awaiting_acceptance'] == true);

/// The order as the customer sees it: "Order placed" until staff accept,
/// then the database status ("Confirmed", "Preparing", ...).
Map<String, dynamic> customerOrderView(Map<String, dynamic> o) =>
    awaitingAcceptance(o) && o['status'] != kOrderPlaced
    ? {...o, 'status': kOrderPlaced}
    : o;

/// False for a bhaji the kitchen removed (archived). Removed bhajis stay in
/// the table so past orders keep their history, but leave every menu.
bool menuItemActive(Map m) => m['archived_at'] == null;

List<Map<String, dynamic>> activeMenu(List<Map<String, dynamic>> rows) => [
  for (final m in rows)
    if (menuItemActive(m)) m,
];
