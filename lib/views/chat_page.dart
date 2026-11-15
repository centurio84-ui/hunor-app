import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chat_message.dart';
import '../services/app_store.dart';
import '../theme/hunor_theme.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = context.read<AppStore>();
      store.markChatAsRead();
      store.loadChatMessages().then((_) => _scrollToBottom());
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _controller.clear();

    final store = context.read<AppStore>();
    try {
      await store.sendChatMessage(text);
      Future.delayed(const Duration(milliseconds: 150), _scrollToBottom);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nem sikerült elküldeni az üzenetet: $e'),
            backgroundColor: HunorColors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final messages = store.chatMessages;
    final myId = store.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.chat_bubble_rounded, size: 18, color: HunorColors.gold),
                SizedBox(width: 8),
                Text('Csapat Chat', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              ],
            ),
            Text(
              'HUNOR Központi Műveleti Chat (${store.members.length} tag)',
              style: const TextStyle(fontSize: 11, color: HunorColors.muted),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Értesítés és jelvény tesztelése',
            icon: const Icon(Icons.notifications_active_outlined, color: HunorColors.orange),
            onPressed: () async {
              await store.simulateTestNotification();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔔 Értesítési teszt: Hang lejátszva, rezgés aktív, app ikon jelvény frissítve!'),
                    backgroundColor: HunorColors.surface2,
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
          ),
          IconButton(
            tooltip: 'Frissítés',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () async {
              await store.loadChatMessages();
              _scrollToBottom();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.forum_outlined, size: 64, color: HunorColors.muted.withOpacity(0.5)),
                        const SizedBox(height: 14),
                        const Text(
                          'Még nincsenek üzenetek.',
                          style: TextStyle(color: HunorColors.muted, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Kezdd el a beszélgetést a csapattal!',
                          style: TextStyle(color: HunorColors.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.authorId == myId;
                      final member = store.members.where((m) => m.id == msg.authorId).firstOrNull;
                      final rank = member?.rank ?? '';

                      return _MessageBubble(
                        message: msg,
                        isMe: isMe,
                        authorRank: rank,
                      );
                    },
                  ),
          ),
          // Alsó beviteli mező
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: HunorColors.surface1,
              border: Border(top: BorderSide(color: HunorColors.border.withOpacity(0.5))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textCapitalization: TextCapitalization.sentences,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(
                        hintText: 'Üzenet írása a csapatnak...',
                        hintStyle: const TextStyle(fontSize: 14, color: HunorColors.muted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        filled: true,
                        fillColor: HunorColors.surface2,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      onSubmitted: (_) => _handleSend(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: HunorColors.gold,
                    radius: 22,
                    child: IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: HunorColors.navy),
                            )
                          : const Icon(Icons.send_rounded, color: HunorColors.navy, size: 20),
                      onPressed: _isSending ? null : _handleSend,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;
  final String authorRank;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.authorRank,
  });

  @override
  Widget build(BuildContext context) {
    final timeStr = '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? HunorColors.navyDark : HunorColors.surface2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          border: Border.all(
            color: isMe ? HunorColors.gold.withOpacity(0.4) : HunorColors.border.withOpacity(0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.authorName,
                    style: const TextStyle(
                      color: HunorColors.gold,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                  if (authorRank.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      '($authorRank)',
                      style: const TextStyle(
                        color: HunorColors.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
            ],
            Text(
              message.content,
              style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3),
            ),
            const SizedBox(height: 4),
            Text(
              timeStr,
              style: TextStyle(
                color: Colors.white.withOpacity(0.45),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
