import 'package:flutter_test/flutter_test.dart';
import 'package:zyntro_flutter/core/migration/migration.dart';

void main() {
  const validator = FeatureBlueprintValidator();

  test('passes when required layers and contracts are present', () {
    const blueprint = FeatureBlueprint(
      featureName: 'sessions',
      layers: {'presentation', 'domain', 'data'},
      contracts: {
        LayerBoundary.presentationDomain,
        LayerBoundary.domainData,
      },
    );

    final result = validator.validate(blueprint);
    expect(result.isValid, isTrue);
    expect(result.issues, isEmpty);
  });

  test('fails when required layers are missing', () {
    const blueprint = FeatureBlueprint(
      featureName: 'sessions',
      layers: {'presentation', 'data'},
      contracts: {
        LayerBoundary.presentationDomain,
      },
    );

    final result = validator.validate(blueprint);
    expect(result.isValid, isFalse);
    expect(result.issues.join(' '), contains('Missing layers'));
    expect(result.issues.join(' '), contains('Missing required contracts'));
  });

  test('fails for auth proposals in deferred blueprint flow', () {
    const blueprint = FeatureBlueprint(
      featureName: 'auth',
      layers: {'presentation', 'domain', 'data'},
      contracts: {
        LayerBoundary.presentationDomain,
        LayerBoundary.domainData,
      },
    );

    final result = validator.validate(blueprint);
    expect(result.isValid, isFalse);
    expect(result.issues.join(' '), contains('reserved for this migration slice'));
  });
}
