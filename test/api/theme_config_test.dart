import 'package:flutter_test/flutter_test.dart';
import 'package:hunor_app/models/theme_config.dart';

void main() {
  group('RescueThemeRegistry', () {
    test('contains all 14 official catalog themes', () {
      expect(RescueThemeRegistry.allThemes.length, 14);
      expect(RescueThemeRegistry.catalogIds.length, 14);
    });

    test('verifies all 9 weekday theme IDs and names', () {
      final weekdayExpected = [
        'weekday-01-alpin',
        'weekday-02-alatamasztas',
        'weekday-03-k9',
        'weekday-04-medic',
        'weekday-05-torzs',
        'weekday-06-logisztika',
        'weekday-07-it',
        'weekday-08-liaison',
        'weekday-09-muszaki-mentes',
      ];
      for (final id in weekdayExpected) {
        expect(RescueThemeRegistry.hasTheme(id), isTrue, reason: 'Missing theme $id');
        final def = RescueThemeRegistry.findById(id);
        expect(def.group, 'weekday');
        expect(def.name.isNotEmpty, isTrue);
      }
    });

    test('verifies all 5 seasonal theme IDs and names', () {
      final seasonalExpected = [
        'seasonal-01-karacsony',
        'seasonal-02-husvet',
        'seasonal-03-magyar-nemzeti-unnep',
        'seasonal-04-megemlekezes',
        'seasonal-05-halloween',
      ];
      for (final id in seasonalExpected) {
        expect(RescueThemeRegistry.hasTheme(id), isTrue, reason: 'Missing theme $id');
        final def = RescueThemeRegistry.findById(id);
        expect(def.group, 'seasonal');
        expect(def.name.isNotEmpty, isTrue);
      }
    });

    test('safely falls back to default dark theme for unknown or null themeId', () {
      final fallbackUnknown = RescueThemeRegistry.resolveTheme('unknown-nonexistent-id');
      expect(fallbackUnknown.id, 'weekday-01-alpin');

      final fallbackNull = RescueThemeRegistry.resolveTheme(null);
      expect(fallbackNull.id, 'weekday-01-alpin');
    });

    test('deserializes ThemeContext from JSON', () {
      final json = {
        'contract_version': 'rp-theme-1',
        'organization_id': 'org-123',
        'active_theme_id': 'weekday-04-medic',
        'theme_source': 'user',
        'user_preference': {
          'theme_id': 'weekday-04-medic',
          'version': 2,
          'updated_at': '2026-10-26T12:00:00Z',
        },
        'organization_preference': {
          'theme_id': 'weekday-01-alpin',
          'version': 1,
          'updated_at': '2026-10-25T12:00:00Z',
        },
        'system_default': {
          'theme_id': 'weekday-01-alpin',
          'source': 'weekday',
          'computed_at': '2026-10-26T00:00:00Z',
        },
      };

      final ctx = ThemeContext.fromJson(json);
      expect(ctx.contractVersion, 'rp-theme-1');
      expect(ctx.organizationId, 'org-123');
      expect(ctx.activeThemeId, 'weekday-04-medic');
      expect(ctx.themeSource, 'user');
      expect(ctx.userPreference?.themeId, 'weekday-04-medic');
      expect(ctx.userPreference?.version, 2);
      expect(ctx.organizationPreference?.themeId, 'weekday-01-alpin');
      expect(ctx.organizationPreference?.version, 1);
      expect(ctx.systemDefault?.themeId, 'weekday-01-alpin');
      expect(ctx.systemDefault?.source, 'weekday');
    });
  });
}
