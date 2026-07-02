import 'package:shared_preferences/shared_preferences.dart';

import '../../models/client.dart';
import '../../models/invoice.dart';
import '../../models/service_item.dart';
import '../db/app_database.dart';
import '../db/json_collection_store.dart';

/// One-time migration of clients and the service-item catalog (previously
/// stored as JSON blobs in SharedPreferences/[BusinessProfile]) into the
/// local Drift database.
class LegacyDataMigrator {
  static String _flagKey(String businessId) =>
      'items_clients_migrated_to_drift_v1_$businessId';

  static String _invoicesFlagKey(String businessId) =>
      'invoices_migrated_to_drift_v1_$businessId';

  /// Copies [clients] and [serviceItems] into [db] if it is still empty and
  /// the migration hasn't already run for [businessId]. Safe to call on
  /// every load — a no-op once the flag is set.
  static Future<void> migrateIfNeeded({
    required AppDatabase db,
    required List<Client> clients,
    required List<ServiceItem> serviceItems,
    required SharedPreferences prefs,
    required String businessId,
  }) async {
    final flagKey = _flagKey(businessId);
    if (prefs.getBool(flagKey) ?? false) return;

    if (clients.isNotEmpty && await db.clientsDao.count() == 0) {
      await db.clientsDao.replaceAll(clients);
    }
    if (serviceItems.isNotEmpty && await db.itemsDao.countItems() == 0) {
      await db.itemsDao.replaceAll(serviceItems);
    }
    await prefs.setBool(flagKey, true);
  }

  /// Copies [invoices] (previously stored as a JSON blob in SharedPreferences)
  /// into [db] if it is still empty and the migration hasn't already run for
  /// [businessId]. Safe to call on every load — a no-op once the flag is set.
  static Future<void> migrateInvoicesIfNeeded({
    required AppDatabase db,
    required List<Invoice> invoices,
    required SharedPreferences prefs,
    required String businessId,
  }) async {
    final flagKey = _invoicesFlagKey(businessId);
    if (prefs.getBool(flagKey) ?? false) return;

    if (invoices.isNotEmpty && await db.invoicesDao.count() == 0) {
      await db.invoicesDao.replaceAll(invoices);
    }
    await prefs.setBool(flagKey, true);
  }

  /// Generic one-time migration for collections backed by a
  /// [JsonCollectionStore]. Copies [items] into [store] if it is still empty
  /// and the migration hasn't already run for [flagKey]. Safe to call on
  /// every load — a no-op once the flag is set.
  static Future<void> migrateCollectionIfNeeded<T>({
    required JsonCollectionStore<T> store,
    required List<T> items,
    required SharedPreferences prefs,
    required String flagKey,
  }) async {
    if (prefs.getBool(flagKey) ?? false) return;
    if (items.isNotEmpty && await store.count() == 0) {
      await store.replaceAll(items);
    }
    await prefs.setBool(flagKey, true);
  }
}
