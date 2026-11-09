import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../data/db/app_db.dart' show PostStatus;
import '../../data/server.dart';
import '../../domain/time_kst.dart';
import '../common/app_text.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import '../common/toast.dart';
import 'guestbook_tag.dart';

/// 방명록 읽기 (5-2): 같은 장소·같은 걸음 숫자에서 남긴 글. 쓰기 화면에서 `남기기`를 누르면 이어진다.
/// 위에 장소(도착) 또는 걸음 숫자와 'n명 중 5명', 내가 방금 쓴 글, 다른 여행자의 글 5개(무작위, 서버
/// readGuestbook), `다른 5개 보기`. 글마다 하트(숫자)와 신고. 서버는 글 하나에 내 반응 하나라서
/// 신고하면 하트가 빠지고 하트를 누르면 신고가 빠진다. 연결이 안 되면 내 글만 보이고 한 줄로 알린다.
/// 글쓴이 동그라미·'동행과/혼자'는 서버 저장 항목에 없어서 빼고 닉네임·시간만 (서버 T1a 결정 3번).
/// 뒤로는 들어온 곳(쉼터·도착 화면·노트)
class GuestbookReadScreen extends ConsumerStatefulWidget {
  const GuestbookReadScreen({super.key, required this.ticketId});

  /// 방금 쓴 글의 기회 번호
  final String ticketId;

  @override
  ConsumerState<GuestbookReadScreen> createState() => _GuestbookReadScreenState();
}

/// 다른 글 읽기 상태: 읽는 중, 읽음, 연결 안 됨
enum _Load { loading, done, offline }

class _GuestbookReadScreenState extends ConsumerState<GuestbookReadScreen> {
  var _load = _Load.loading;
  GuestbookPage? _page;

  /// 반응을 보내는 중인 글 (두 번 누르지 않게)
  final _busy = <String>{};

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<String?> _scope() async {
    final posts = await ref.read(myPostsProvider.future);
    return posts.where((p) => p.ticketId == widget.ticketId).firstOrNull?.scope;
  }

  Future<void> _read() async {
    if (_load != _Load.loading) setState(() => _load = _Load.loading);
    GuestbookPage? page;
    try {
      final scope = await _scope();
      if (scope != null) page = await (await ref.read(guestbookServerProvider.future)).read(scope);
    } catch (e) {
      debugPrint('다른 방명록 읽기 실패: $e');
    }
    if (!mounted) return;
    setState(() {
      _page = page;
      _load = page == null ? _Load.offline : _Load.done;
    });
  }

  /// 반응 바꾸기. 같은 반응을 다시 누르면 취소다
  Future<void> _react(OtherPost p, String kind) async {
    if (!_busy.add(p.postId)) return;
    final next = p.myReaction == kind ? null : kind;
    String? toast;
    try {
      final r = await (await ref.read(guestbookServerProvider.future)).react(p.postId, next);
      _replace(p.postId, p.withReaction(r.hearts, r.myReaction));
      if (next == 'report') toast = '신고했어요';
    } on ServerError catch (e) {
      if (e.reason == 'no-post') {
        _replace(p.postId, null);
        toast = '지워진 글이에요';
      } else {
        toast = '인터넷에 연결한 뒤 다시 해 주세요';
      }
    } catch (e) {
      debugPrint('반응 실패: $e');
      toast = '인터넷에 연결한 뒤 다시 해 주세요';
    }
    _busy.remove(p.postId);
    if (!mounted) return;
    setState(() {});
    if (toast != null) showToast(context, toast);
  }

  /// 글 하나를 바꾸거나(null이면) 뺀다
  void _replace(String postId, OtherPost? post) {
    final page = _page;
    if (page == null) return;
    _page = GuestbookPage(page.total, [
      for (final p in page.posts)
        if (p.postId != postId) p else ?post,
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final posts = ref.watch(myPostsProvider);
    final mine = posts.value?.where((p) => p.ticketId == widget.ticketId).firstOrNull;
    final page = _page;
    // 보여 준 글 밖에도 글이 있을 때만 (total에는 서버에 올라간 내 글도 들어 있다)
    final more = page != null &&
        page.total - page.posts.length - (mine?.status == PostStatus.sent ? 1 : 0) > 0;
    final now = ref.read(clockProvider)();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                CornerButton(
                  icon: Icons.arrow_back,
                  label: '뒤로',
                  size: 44,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
                const SizedBox(width: 8),
                if (mine != null)
                  Expanded(
                    child: Text(
                      _title(mine),
                      key: const ValueKey('guestbook-read-title'),
                      style: context.display(22),
                    ),
                  ),
              ],
            ),
            if (page != null && page.posts.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 52),
                child: Text(
                  '${formatInt(page.total)}명 중 ${page.posts.length}명',
                  key: const ValueKey('guestbook-read-count'),
                  style: AppText.bodySub,
                ),
              ),
            const SizedBox(height: 16),
            if (mine != null) _myCard(context, mine),
            const SizedBox(height: 12),
            ..._others(context, page, now),
            if (more) ...[
              const SizedBox(height: 8),
              GameButton(
                label: '다른 5개 보기',
                kind: GameButtonKind.secondary,
                onPressed: _load == _Load.loading ? null : _read,
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _others(BuildContext context, GuestbookPage? page, DateTime now) {
    switch (_load) {
      case _Load.loading when page == null:
        return const [];
      case _Load.offline:
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              '연결되면 다른 여행자의 글을 볼 수 있어요',
              key: ValueKey('guestbook-read-offline'),
              textAlign: TextAlign.center,
              style: AppText.bodySub,
            ),
          ),
        ];
      case _ when page != null && page.posts.isEmpty:
        return [
          Padding(
            key: const ValueKey('guestbook-read-empty'),
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text('처음 지나는 여행자예요', style: context.display(16)),
                const SizedBox(height: 4),
                const Text('아직 아무도 남기지 않았어요', style: AppText.bodySub),
              ],
            ),
          ),
        ];
      case _:
        return [for (final p in page!.posts) _OtherCard(p, now, onReact: _react)];
    }
  }

  /// 도착 글은 장소 이름, 걸음 숫자 글은 `12,345보 지점`
  String _title(GuestbookPostView p) =>
      p.milestone != null ? '${formatInt(p.milestone!)}보 지점' : p.placeName ?? '';

  Widget _myCard(BuildContext context, GuestbookPostView p) {
    return Container(
      key: const ValueKey('guestbook-read-post'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Palette.ink, width: InkLine.panel),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              GuestbookTagPill(guestbookPostTag(p)),
              Text(
                '내가 방금 쓴 글 · ${formatMonthDay(kstDate(p.createdAt))}',
                style: const TextStyle(fontSize: 13, color: Palette.subInk),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(p.text, style: const TextStyle(fontSize: 15, height: 1.6, color: Palette.ink)),
        ],
      ),
    );
  }
}

/// 다른 여행자의 글 하나: 닉네임 · 언제, 본문, 하트(숫자)와 신고
class _OtherCard extends StatelessWidget {
  const _OtherCard(this.post, this.now, {required this.onReact});

  final OtherPost post;
  final DateTime now;
  final void Function(OtherPost post, String kind) onReact;

  @override
  Widget build(BuildContext context) {
    final hearted = post.myReaction == 'heart';
    final reported = post.myReaction == 'report';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        key: ValueKey('guestbook-other-${post.postId}'),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
        decoration: BoxDecoration(
          color: Palette.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Palette.ink, width: InkLine.panel),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(post.nickname, style: context.display(16)),
                Text(formatAgo(post.createdAt, now), style: AppText.label),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(post.text, style: AppText.body.copyWith(height: 1.5)),
            ),
            Row(
              children: [
                Tooltip(
                  message: '하트',
                  child: TextButton.icon(
                    key: ValueKey('heart-${post.postId}'),
                    style: TextButton.styleFrom(
                      foregroundColor: Palette.terracotta,
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () => onReact(post, 'heart'),
                    icon: Icon(hearted ? Icons.favorite : Icons.favorite_border, size: 20),
                    label: Text(formatInt(post.hearts)),
                  ),
                ),
                const Spacer(),
                TextButton(
                  key: ValueKey('report-${post.postId}'),
                  style: TextButton.styleFrom(
                    foregroundColor: Palette.subInk,
                    minimumSize: const Size(44, 44),
                  ),
                  onPressed: () => onReact(post, 'report'),
                  child: Text(
                    reported ? '신고함' : '신고',
                    style: const TextStyle(fontSize: 13, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
