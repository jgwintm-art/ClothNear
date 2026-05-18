/// Optional per-store operational settings for analytics.
/// Stored at: stores/{storeId}/settings/operations
class StoreOperationsModel {
  final int printerCount;
  final int lowStockThreshold;
  final double avgMinutesPerItem;
  final double avgMinutesPerCustomItem;
  final double workerDailyCapacityMinutes;
  final double printerDailyCapacityMinutes;

  const StoreOperationsModel({
    this.printerCount = 1,
    this.lowStockThreshold = 5,
    this.avgMinutesPerItem = 15,
    this.avgMinutesPerCustomItem = 25,
    this.workerDailyCapacityMinutes = 480,
    this.printerDailyCapacityMinutes = 480,
  });

  factory StoreOperationsModel.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) {
      return const StoreOperationsModel();
    }
    return StoreOperationsModel(
      printerCount: (map['printerCount'] as num?)?.toInt() ?? 1,
      lowStockThreshold: (map['lowStockThreshold'] as num?)?.toInt() ?? 5,
      avgMinutesPerItem: (map['avgMinutesPerItem'] as num?)?.toDouble() ?? 15,
      avgMinutesPerCustomItem:
          (map['avgMinutesPerCustomItem'] as num?)?.toDouble() ?? 25,
      workerDailyCapacityMinutes:
          (map['workerDailyCapacityMinutes'] as num?)?.toDouble() ?? 480,
      printerDailyCapacityMinutes:
          (map['printerDailyCapacityMinutes'] as num?)?.toDouble() ?? 480,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'printerCount': printerCount,
      'lowStockThreshold': lowStockThreshold,
      'avgMinutesPerItem': avgMinutesPerItem,
      'avgMinutesPerCustomItem': avgMinutesPerCustomItem,
      'workerDailyCapacityMinutes': workerDailyCapacityMinutes,
      'printerDailyCapacityMinutes': printerDailyCapacityMinutes,
    };
  }
}
