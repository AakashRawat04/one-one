/// Describes which pricing tier is currently active, resolved from
/// Firebase Remote Config.
enum SubscriptionTier {
  /// Gradual user growth — lower prices.
  normal,

  /// Sudden large influx — higher prices to protect server costs.
  extreme,
}
