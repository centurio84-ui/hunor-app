import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/rescue_news.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';

class NewsFeedPage extends StatelessWidget {
  const NewsFeedPage({super.key});

  String _formatDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  String _categoryLabel(String? cat) {
    switch (cat) {
      case 'earthquake':
        return 'Földrengés';
      case 'weather':
        return 'Időjárás';
      case 'deployment':
        return 'Kiküldetés / Riasztás';
      case 'training':
        return 'Gyakorlat';
      case 'other':
      default:
        return 'Közlemény';
    }
  }

  IconData _categoryIcon(String? cat) {
    switch (cat) {
      case 'earthquake':
        return Icons.warning_amber_rounded;
      case 'weather':
        return Icons.cloud_outlined;
      case 'deployment':
        return Icons.flag_outlined;
      case 'training':
        return Icons.sports_kabaddi_outlined;
      default:
        return Icons.newspaper_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final newsList = store.news;

    if (newsList.isEmpty) {
      return RefreshIndicator(
        onRefresh: store.loadData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 80),
            Icon(Icons.newspaper_outlined, size: 54, color: HunorColors.muted),
            SizedBox(height: 16),
            Center(
              child: Text(
                'Nincsenek elérhető hírek ebben a szervezetben.',
                style: TextStyle(fontWeight: FontWeight.w700, color: HunorColors.muted),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: store.loadData,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: newsList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 14),
        itemBuilder: (ctx, index) {
          final item = newsList[index];
          final hasCover = item.imageUrls.isNotEmpty;

          return Card(
            elevation: item.isPinned ? 3 : 1,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: item.isPinned
                  ? const BorderSide(color: HunorColors.red, width: 1.5)
                  : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openNewsDetails(ctx, item),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasCover) ...[
                    Stack(
                      children: [
                        Image.network(
                          item.imageUrls.first,
                          height: 190,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                        if (item.imageUrls.length > 1)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.photo_library_outlined, size: 14, color: Colors.white),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${item.imageUrls.length} kép',
                                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (item.category != null && item.category!.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                decoration: BoxDecoration(
                                  color: HunorColors.surface2,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(_categoryIcon(item.category), size: 12, color: HunorColors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      _categoryLabel(item.category),
                                      style: const TextStyle(fontSize: 11, color: HunorColors.orange, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            if (item.isPinned) ...[
                              const Icon(Icons.push_pin, size: 14, color: HunorColors.red),
                              const SizedBox(width: 4),
                              const Text(
                                'Kiemelt',
                                style: TextStyle(fontSize: 11, color: HunorColors.red, fontWeight: FontWeight.bold),
                              ),
                            ],
                            const Spacer(),
                            Text(
                              _formatDate(item.publishedAt),
                              style: const TextStyle(fontSize: 12, color: HunorColors.muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          item.title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                        ),
                        if (item.summary.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            item.summary,
                            style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 13.5),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (item.tags.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: item.tags.map((tag) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: HunorColors.surface2,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '#$tag',
                                style: const TextStyle(fontSize: 11, color: HunorColors.muted),
                              ),
                            )).toList(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openNewsDetails(BuildContext context, RescueNewsItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: HunorColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, scrollController) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: ListView(
            controller: scrollController,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (item.category != null && item.category!.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: HunorColors.surface2,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _categoryLabel(item.category),
                        style: const TextStyle(fontSize: 11, color: HunorColors.orange, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (item.authorName != null) ...[
                    const Icon(Icons.account_circle_outlined, size: 16, color: HunorColors.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        item.authorName!,
                        style: const TextStyle(fontSize: 13, color: HunorColors.muted),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  Text(_formatDate(item.publishedAt), style: const TextStyle(fontSize: 13, color: HunorColors.muted)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const Divider(color: Colors.white12, height: 24),

              // Képek és csatolmányok megjelenítése
              if (item.media.isNotEmpty) ...[
                for (final m in item.media) ...[
                  if (m.url.isNotEmpty && m.kind != 'video') ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        m.url,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                    if (m.caption.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          m.caption,
                          style: const TextStyle(fontSize: 12, color: HunorColors.muted, fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                ],
              ] else if (item.imageUrls.isNotEmpty) ...[
                for (final url in item.imageUrls) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      url,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              // Teljes szöveges tartalom / leírás
              if (item.content.isNotEmpty)
                Text(
                  item.content,
                  style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.white),
                )
              else if (item.summary.isNotEmpty)
                Text(
                  item.summary,
                  style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.white),
                ),

              // Helyszín / Térkép
              if (item.mapQuery != null && item.mapQuery!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HunorColors.surface2,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.location_on, color: HunorColors.red, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ESEMÉNY HELYSZÍNE',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: HunorColors.muted),
                            ),
                            Text(
                              item.mapQuery!,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () async {
                          final uri = Uri.tryParse('https://maps.google.com/maps?q=${Uri.encodeComponent(item.mapQuery!)}');
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.open_in_new, size: 14),
                        label: const Text('Térkép', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ),
              ],

              // Kapcsolódó források és hivatkozások
              if (item.links.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('Hivatkozások és források', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 8),
                ...item.links.map((l) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onPressed: () async {
                      final uri = Uri.tryParse(l.url);
                      if (uri != null && await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: Text(
                      l.label.isNotEmpty ? l.label : l.url,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )),
              ],

              if (item.externalUrl != null && item.externalUrl!.isNotEmpty) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    final uri = Uri.tryParse(item.externalUrl!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Hivatkozás megnyitása böngészőben'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
