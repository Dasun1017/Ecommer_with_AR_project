import '../../../models/product_model.dart';

class ArProductModelResolver {
  static const String defaultTopwearModel = 'assets/3d_models/T-Shirt.glb';
  static const String oversizedTopwearModel =
      'assets/3d_models/Oversized T-Shirt.glb';

  static String resolve(Product product) {
    final source = product.arModelUrl?.trim();
    if (source != null && _isSupportedModelSource(source)) {
      return source;
    }

    final normalizedName = product.name.toLowerCase();
    final normalizedCategory = product.category.toLowerCase();
    final combined = '$normalizedName $normalizedCategory';

    if (combined.contains('oversized')) {
      return oversizedTopwearModel;
    }

    if (combined.contains('shirt') ||
        combined.contains('t-shirt') ||
        combined.contains('tee') ||
        combined.contains('top')) {
      return defaultTopwearModel;
    }

    return defaultTopwearModel;
  }

  static bool _isSupportedModelSource(String source) {
    final normalized = source.toLowerCase();
    return normalized.endsWith('.glb') || normalized.endsWith('.gltf');
  }
}
