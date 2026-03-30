import '../models/migration_lifecycle.dart';

class FeatureBlueprint {
  final String featureName;
  final Set<String> layers;
  final Set<LayerBoundary> contracts;

  const FeatureBlueprint({
    required this.featureName,
    required this.layers,
    required this.contracts,
  });
}

class BlueprintValidationResult {
  final bool isValid;
  final List<String> issues;

  const BlueprintValidationResult({
    required this.isValid,
    required this.issues,
  });
}

class FeatureBlueprintValidator {
  static const Set<String> _requiredLayers = {
    'presentation',
    'domain',
    'data',
  };

  static const Set<LayerBoundary> _requiredContracts = {
    LayerBoundary.presentationDomain,
    LayerBoundary.domainData,
  };

  const FeatureBlueprintValidator();

  BlueprintValidationResult validate(FeatureBlueprint blueprint) {
    final issues = <String>[];

    if (blueprint.featureName.trim().isEmpty) {
      issues.add('Feature name is required.');
    }

    final normalizedLayers = blueprint.layers
        .map((layer) => layer.trim().toLowerCase())
        .toSet();

    final missingLayers = _requiredLayers.difference(normalizedLayers);
    if (missingLayers.isNotEmpty) {
      issues.add('Missing layers: ${missingLayers.join(', ')}.');
    }

    final missingContracts = _requiredContracts.difference(blueprint.contracts);
    if (missingContracts.isNotEmpty) {
      final contractNames = missingContracts
          .map((boundary) => boundary.wireValue)
          .join(', ');
      issues.add('Missing required contracts: $contractNames.');
    }

    if (blueprint.featureName.trim().toLowerCase() == 'auth') {
      issues.add(
        'Auth is reserved for this migration slice; new proposals must be non-auth.',
      );
    }

    return BlueprintValidationResult(isValid: issues.isEmpty, issues: issues);
  }
}
