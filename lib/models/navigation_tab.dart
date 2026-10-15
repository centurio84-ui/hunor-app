class NavigationTab {
  const NavigationTab({required this.id, required this.title, required this.routePath,
    required this.isVisible, required this.sortOrder, this.iconName});
  final String id, title, routePath;
  final String? iconName;
  final bool isVisible;
  final int sortOrder;
  factory NavigationTab.fromJson(Map<String, dynamic> row) => NavigationTab(
    id: row['id'] as String, title: row['title'] as String,
    routePath: row['route_path'] as String, iconName: row['icon_name'] as String?,
    isVisible: row['is_visible'] == true, sortOrder: (row['sort_order'] as num).toInt());
}
