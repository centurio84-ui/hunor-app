import 'package:flutter/material.dart';

/// RP-THEME-001 / RP-THEME-002 szerinti szerveres témakontextus modell.
class ThemeContext {
  final String contractVersion;
  final String organizationId;
  final String effectiveThemeId;
  final String source; // 'global', 'organization', 'user'
  final String? organizationThemeId;
  final int organizationVersion;
  final bool allowPersonal;
  final String globalThemeId;
  final int globalVersion;
  final String? userThemeId;
  final int userVersion;
  final bool canManageOrganization;
  final bool canManageGlobal;

  const ThemeContext({
    required this.contractVersion,
    required this.organizationId,
    required this.effectiveThemeId,
    required this.source,
    this.organizationThemeId,
    required this.organizationVersion,
    required this.allowPersonal,
    required this.globalThemeId,
    required this.globalVersion,
    this.userThemeId,
    required this.userVersion,
    this.canManageOrganization = false,
    this.canManageGlobal = false,
  });

  factory ThemeContext.fromJson(Map<String, dynamic> json) {
    return ThemeContext(
      contractVersion: json['contract_version']?.toString() ?? 'rp-theme-1',
      organizationId: json['organization_id']?.toString() ?? '',
      effectiveThemeId: json['effective_theme_id']?.toString() ?? 'weekday-01-alpin',
      source: json['source']?.toString() ?? 'global',
      organizationThemeId: json['organization_theme_id']?.toString(),
      organizationVersion: (json['organization_version'] as num?)?.toInt() ?? 0,
      allowPersonal: json['allow_personal'] == true,
      globalThemeId: json['global_theme_id']?.toString() ?? 'weekday-01-alpin',
      globalVersion: (json['global_version'] as num?)?.toInt() ?? 1,
      userThemeId: json['user_theme_id']?.toString(),
      userVersion: (json['user_version'] as num?)?.toInt() ?? 0,
      canManageOrganization: json['can_manage_organization'] == true,
      canManageGlobal: json['can_manage_global'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'contract_version': contractVersion,
    'organization_id': organizationId,
    'effective_theme_id': effectiveThemeId,
    'source': source,
    'organization_theme_id': organizationThemeId,
    'organization_version': organizationVersion,
    'allow_personal': allowPersonal,
    'global_theme_id': globalThemeId,
    'global_version': globalVersion,
    'user_theme_id': userThemeId,
    'user_version': userVersion,
    'can_manage_organization': canManageOrganization,
    'can_manage_global': canManageGlobal,
  };

  ThemeContext copyWith({
    String? effectiveThemeId,
    String? source,
    String? userThemeId,
    int? userVersion,
  }) {
    return ThemeContext(
      contractVersion: contractVersion,
      organizationId: organizationId,
      effectiveThemeId: effectiveThemeId ?? this.effectiveThemeId,
      source: source ?? this.source,
      organizationThemeId: organizationThemeId,
      organizationVersion: organizationVersion,
      allowPersonal: allowPersonal,
      globalThemeId: globalThemeId,
      globalVersion: globalVersion,
      userThemeId: userThemeId ?? this.userThemeId,
      userVersion: userVersion ?? this.userVersion,
      canManageOrganization: canManageOrganization,
      canManageGlobal: canManageGlobal,
    );
  }
}

/// Témakatalógus tétel.
class ThemeCatalogItem {
  final String id;
  final String name;
  final String category; // 'weekday', 'seasonal'
  final String description;
  final Color primaryColor;

  const ThemeCatalogItem({
    required this.id,
    required this.name,
    required this.category,
    this.description = '',
    required this.primaryColor,
  });

  factory ThemeCatalogItem.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString() ?? json['theme_id']?.toString() ?? '';
    final def = RescueThemeRegistry.findById(id);
    return ThemeCatalogItem(
      id: id,
      name: json['name']?.toString() ?? json['label']?.toString() ?? def.name,
      category: json['category']?.toString() ??
          (id.startsWith('seasonal') ? 'seasonal' : 'weekday'),
      description: json['description']?.toString() ?? def.description,
      primaryColor: def.primaryColor,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'description': description,
  };
}

/// A 14 kanonikus téma definíciója és Flutter-megfeleltetése.
class RescueThemeDefinition {
  final String id;
  final String name;
  final String description;
  final Color primaryColor;
  final Color accentColor;
  final bool isSeasonal;

  const RescueThemeDefinition({
    required this.id,
    required this.name,
    required this.description,
    required this.primaryColor,
    required this.accentColor,
    this.isSeasonal = false,
  });
}

class RescueThemeRegistry {
  static const String defaultThemeId = 'weekday-01-alpin';

  static const List<RescueThemeDefinition> allThemes = [
    RescueThemeDefinition(
      id: 'weekday-01-alpin',
      name: 'Alpin',
      description: 'Hivatalos HUNOR műveleti vörös és grafit sötét felület.',
      primaryColor: Color(0xFFD71920),
      accentColor: Color(0xFFA80F14),
    ),
    RescueThemeDefinition(
      id: 'weekday-02-alatamasztas',
      name: 'Alá- és megtámasztás',
      description: 'Szerkezetbiztosítási borostyánsárga és acélszürke elemek.',
      primaryColor: Color(0xFFE5A93C),
      accentColor: Color(0xFFC78A22),
    ),
    RescueThemeDefinition(
      id: 'weekday-03-k9',
      name: 'K9',
      description: 'Keresőkutyás egység meleg arany és földbarna tónusai.',
      primaryColor: Color(0xFFD48B38),
      accentColor: Color(0xFFA66219),
    ),
    RescueThemeDefinition(
      id: 'weekday-04-medic',
      name: 'Medic',
      description: 'Egészségügyi és életmentő smaragdzöld kiemelések.',
      primaryColor: Color(0xFF10B981),
      accentColor: Color(0xFF059669),
    ),
    RescueThemeDefinition(
      id: 'weekday-05-torzs',
      name: 'Törzs',
      description: 'Műveletirányítási hadikék és fegyelmezett hidegszürke.',
      primaryColor: Color(0xFF3B82F6),
      accentColor: Color(0xFF1D4ED8),
    ),
    RescueThemeDefinition(
      id: 'weekday-06-logisztika',
      name: 'Logisztika',
      description: 'Anyagellátási acélkék és semleges ipari paletta.',
      primaryColor: Color(0xFF64748B),
      accentColor: Color(0xFF475569),
    ),
    RescueThemeDefinition(
      id: 'weekday-07-it',
      name: 'IT',
      description: 'Távközlési és informatikai neoncián kontraszt.',
      primaryColor: Color(0xFF06B6D4),
      accentColor: Color(0xFF0891B2),
    ),
    RescueThemeDefinition(
      id: 'weekday-08-liaison',
      name: 'Liaison',
      description: 'Összekötő tiszti diplomáciai lila és mélykék.',
      primaryColor: Color(0xFF8B5CF6),
      accentColor: Color(0xFF6D28D9),
    ),
    RescueThemeDefinition(
      id: 'weekday-09-muszaki-mentes',
      name: 'Műszaki mentés',
      description: 'Nehézgépes és műszaki beavatkozó narancs kontraszt.',
      primaryColor: Color(0xFFF97316),
      accentColor: Color(0xFFC2410C),
    ),
    RescueThemeDefinition(
      id: 'seasonal-01-karacsony',
      name: 'Karácsony',
      description: 'Ünnepi mélyzöld és melegvörös téli hangulat.',
      primaryColor: Color(0xFF059669),
      accentColor: Color(0xFFDC2626),
      isSeasonal: true,
    ),
    RescueThemeDefinition(
      id: 'seasonal-02-husvet',
      name: 'Húsvét',
      description: 'Tavaszi friss fűzöld és pasztell kiemelések.',
      primaryColor: Color(0xFF84CC16),
      accentColor: Color(0xFF65A30D),
      isSeasonal: true,
    ),
    RescueThemeDefinition(
      id: 'seasonal-03-magyar-nemzeti-unnep',
      name: 'Magyar nemzeti ünnepek',
      description: 'Klasszikus nemzeti piros és zöld sötét tónusokkal.',
      primaryColor: Color(0xFFC8102E),
      accentColor: Color(0xFF007A3D),
      isSeasonal: true,
    ),
    RescueThemeDefinition(
      id: 'seasonal-04-megemlekezes',
      name: 'Megemlékezés',
      description: 'Méltóságteljes antracit és sötétfekete tónusok.',
      primaryColor: Color(0xFF64748B),
      accentColor: Color(0xFF334155),
      isSeasonal: true,
    ),
    RescueThemeDefinition(
      id: 'seasonal-05-halloween',
      name: 'Halloween',
      description: 'Éjszakai sötét grafit és töknarancs kiemelések.',
      primaryColor: Color(0xFFEA580C),
      accentColor: Color(0xFF9A3412),
      isSeasonal: true,
    ),
  ];

  static List<String> get catalogIds => allThemes.map((t) => t.id).toList();

  static RescueThemeDefinition findById(String id) {
    return allThemes.firstWhere(
      (t) => t.id == id,
      orElse: () => allThemes.first,
    );
  }

  static bool isValidThemeId(String? id) {
    if (id == null) return false;
    return allThemes.any((t) => t.id == id);
  }
}
