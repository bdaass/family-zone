import 'package:flutter_test/flutter_test.dart';
import 'package:family_zone/models/mobile_app_config.dart';
import 'package:family_zone/utils/app_version.dart';

void main() {
  group('AppVersion', () {
    test('parses semantic versions and build numbers', () {
      expect(AppVersion.parse('1.0.0').toString(), '1.0.0');
      expect(AppVersion.parse('2.3.4+12').toString(), '2.3.4');
      expect(AppVersion.parse('1.0').toString(), '1.0.0');
    });

    test('compares versions numerically', () {
      expect(AppVersion.parse('1.0.0').isOlderThan(AppVersion.parse('1.0.1')), isTrue);
      expect(AppVersion.parse('1.1.0').isOlderThan(AppVersion.parse('1.0.9')), isFalse);
      expect(AppVersion.parse('2.0.0').isOlderThan(AppVersion.parse('1.9.9')), isFalse);
    });
  });

  group('MobileAppConfig', () {
    test('requires force update only when flag is on and version is older', () {
      const config = MobileAppConfig(currentVersion: '1.1.0', forceUpdate: true);
      expect(config.requiresForceUpdate('1.0.0'), isTrue);
      expect(config.requiresForceUpdate('1.1.0'), isFalse);
      expect(config.requiresForceUpdate('1.2.0'), isFalse);
    });

    test('does not force update when flag is off', () {
      const config = MobileAppConfig(currentVersion: '2.0.0', forceUpdate: false);
      expect(config.requiresForceUpdate('1.0.0'), isFalse);
    });
  });
}
