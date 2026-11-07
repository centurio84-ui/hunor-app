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
        expect(RescueThemeRegistry.isValidThemeId(id), isTrue, reason: 'Missing theme $id');
        final def = RescueThemeRegistry.findById(id);
        expect(def.isSeasonal, isFalse);
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
        expect(RescueThemeRegistry.isValidThemeId(id), isTrue, reason: 'Missing theme $id');
        final def = RescueThemeRegistry.findById(id);
        expect(def.isSeasonal, isTrue);
        expect(def.name.isNotEmpty, isTrue);
      }
    });

    test('safely falls back to default Alpin dark theme for unknown themeId', () {
      final fallbackUnknown = RescueThemeRegistry.findById('unknown-nonexistent-id');
      expect(fallbackUnknown.id, RescueThemeRegistry.defaultThemeId);
    });

    test('deserializes ThemeContext from JSON', () {
      final json = {
        'contract_version': 'rp-theme-1',
        'organization_id': 'org-123',
        'effective_theme_id': 'weekday-04-medic',
        'source': 'user',
        'organization_theme_id': 'weekday-01-alpin',
        'organization_version': 1,
        'allow_personal': true,
        'global_theme_id': 'weekday-01-alpin',
        'global_version': 1,
        'user_theme_id': 'weekday-04-medic',
        'user_version': 2,
        'can_manage_organization': false,
        'can_manage_global': false,
      };

      final ctx = ThemeContext.fromJson(json);
      expect(ctx.contractVersion, 'rp-theme-1');
      expect(ctx.organizationId, 'org-123');
      expect(ctx.effectiveThemeId, 'weekday-04-medic');
      expect(ctx.source, 'user');
      expect(ctx.userThemeId, 'weekday-04-medic');
      expect(ctx.userVersion, 2);
      expect(ctx.organizationThemeId, 'weekday-01-alpin');
      expect(ctx.organizationVersion, 1);
      expect(ctx.globalThemeId, 'weekday-01-alpin');
      expect(ctx.globalVersion, 1);
    });
  });
}
