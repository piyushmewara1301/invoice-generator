// StockTransferService no longer uses Firestore.
// All transfer and shop-registry data is stored in the shared Drive-backed
// local store managed by AppProvider, so this file is intentionally empty.
// The class is kept to avoid breaking any stray imports.
class StockTransferService {
  const StockTransferService._();
}
