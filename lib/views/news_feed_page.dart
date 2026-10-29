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
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, index) {
          final item = newsList[index];
          return Card(
            elevation: item.isPinned ? 3 : 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: item.isPinned
                  ? const BorderSide(color: HunorColors.accent, width: 1.5)
                  : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _openNewsDetails(ctx, item),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (item.isPinned) ...[
                          const Icon(Icons.push_pin, size: 16, color: HunorColors.accent),
                          const SizedBox(width: 6),
                          const Text(
                            'Kiemelt',
                            style: TextStyle(fontSize: 12, color: HunorColors.accent, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                        ] else
                          const Spacer(),
                        Text(
                          _formatDate(item.publishedAt),
                          style: const TextStyle(fontSize: 12, color: HunorColors.muted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.summary,
                      style: const TextStyle(color: Colors.white70, height: 1.35),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
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
        initialChildSize: 0.75,
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
                  if (item.authorName != null) ...[
                    const Icon(Icons.account_circle_outlined, size: 16, color: HunorColors.muted),
                    const SizedBox(width: 6),
                    Text(item.authorName!, style: const TextStyle(fontSize: 13, color: HunorColors.muted)),
                    const Spacer(),
                  ],
                  Text(_formatDate(item.publishedAt), style: const TextStyle(fontSize: 13, color: HunorColors.muted)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                item.title,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const Divider(color: Colors.white12, height: 24),
              Text(
                item.content,
                style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.white),
              ),
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
