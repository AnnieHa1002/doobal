import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../app/guestbook_server.dart';
import '../../domain/guestbook.dart';
import '../../domain/time_kst.dart';
import '../common/app_text.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import '../common/toast.dart';
import '../walking/paint_trail_host.dart';
import 'guestbook_read_screen.dart';
import 'guestbook_tag.dart';

/// 방명록 쓰기 (UI 명세 9장). 위에 태그, 걸음 숫자 기회면 남은 걸음, 처음 쓸 때만 동의 한 줄,
/// 입력 칸(글자 수 상한은 config guestbook.maxChars)과 글자 수, 주 버튼 "남기기".
/// 쓰는 중에 금칙어에 걸리면 입력 칸 아래에 테라코타 글자로 안내하고 "남기기"를 끈다 (어떤 단어인지는
/// 알리지 않는다). 글이 유효할 때만 버튼이 켜지고, 누르면 이 기기에 저장하고 닫는다.
/// 남기면 방명록 읽기(5-2)로 이어진다 (이 화면을 바꿔서, 읽기에서 뒤로 가면 들어온 곳).
/// 연결돼 있으면 서버에 먼저 올린다 (GuestbookServer). 서버가 금칙어로 막으면 이 기기에도 남기지 않고
/// 초안을 그대로 두어 고치게 하고, 작성 제한 중이면 그때까지 쓸 수 없다고 알린다. 연결이 안 되면 이 기기에만
/// 남기고 연결되면 올라간다. 금칙어 문서는 화면을 열 때 서버에서 다시 받는다
class GuestbookWriteScreen extends ConsumerStatefulWidget {
  const GuestbookWriteScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<GuestbookWriteScreen> createState() => _GuestbookWriteScreenState();
}

class _GuestbookWriteScreenState extends ConsumerState<GuestbookWriteScreen>
    with HoldsPaintTrail {
  final _controller = TextEditingController();
  var _busy = false;

  /// 처음 읽은 기회. 글을 쓰고 기회를 다시 읽으면 null이 되는데, 그동안 화면이 바뀌지 않게 남겨 둔다
  GuestbookTicket? _ticket;

  /// 서버가 막은 까닭 (금칙어·작성 제한). 글을 고치면 지운다
  String? _serverBlock;

  @override
  void initState() {
    super.initState();
    // 방명록을 열 때 금칙어 문서를 다시 받는다 (M5). 서버가 없으면 앱에 든 것 그대로
    if (ref.read(serverBackendProvider) != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.invalidate(moderationProvider);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 남기고 방명록 읽기로 바꾼다. 그새 기회가 끝났으면 그 사유를 토스트로 알리고 닫는다. 서버가 막으면
  /// 초안을 두고 입력 칸 아래에 알린다. 남기거나 닫으면 쉼터 표지판·도착 화면 버튼·노트의 내 방명록이 새로 읽는다
  Future<void> _save(GuestbookTicket ticket) async {
    if (_busy) return;
    setState(() => _busy = true);
    final gb = await ref.read(guestbookServerProvider.future);
    final outcome = await gb.send(ticket.id, _controller.text);
    if (!mounted) return;
    switch (outcome) {
      case SendBlocked(:final message):
        setState(() {
          _busy = false;
          _serverBlock = message;
        });
        return;
      case SendBanned(:final until):
        final text = '${formatMonthDay(kstDate(until))}까지 방명록을 쓸 수 없어요';
        setState(() {
          _busy = false;
          _serverBlock = text;
        });
        showToast(context, text);
        return;
      case SendClosed(:final message):
        _refresh();
        showToast(context, message);
        Navigator.of(context).pop();
        return;
      case SendDone() || SendQueued():
        _refresh();
        showToast(context, '방명록을 남겼어요');
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => GuestbookReadScreen(ticketId: ticket.id)),
        );
    }
  }

  void _refresh() {
    ref.invalidate(snapshotProvider);
    ref.invalidate(guestbookTicketProvider);
    ref.invalidate(myPostsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final maxChars = ref.watch(rulesProvider).value?.guestbookMaxChars;
    final loaded = ref.watch(guestbookTicketProvider(widget.ticketId));
    _ticket = loaded.value ?? _ticket;
    final ticket = _ticket;
    final consented = ref.watch(guestbookConsentProvider).value;

    final Widget body;
    if (ticket != null && maxChars != null) {
      body = _form(ticket, maxChars, showConsent: consented == false);
    } else if (loaded.hasValue || loaded.hasError) {
      // 기회가 없거나 이미 썼거나 닫혔다
      body = const Center(
        child: Text(
          '방명록을 남길 수 있는 때가 지났어요',
          key: ValueKey('guestbook-closed'),
          style: TextStyle(fontSize: 16, color: Palette.ink),
        ),
      );
    } else {
      body = const SizedBox.shrink();
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: CornerButton(
                  icon: Icons.arrow_back,
                  label: '뒤로',
                  size: 44,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }

  Widget _form(GuestbookTicket ticket, int maxChars, {required bool showConsent}) {
    // 규칙을 읽는 동안에는 막지 않는다 (서버가 다시 검사한다, M5)
    final moderation = ref.watch(moderationProvider).value;
    final names = ref.watch(moderationNamesProvider);
    final blockedHere = moderation?.isBlocked(_controller.text, names: names) ?? false;
    final blockMessage = blockedHere ? moderation!.message : _serverBlock;
    final blocked = blockMessage != null;
    final valid = cleanPost(_controller.text, maxChars) != null && !blocked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    GuestbookTagPill(guestbookTag(ticket), key: const ValueKey('guestbook-tag')),
                    if (ticket.stepsLeft != null)
                      Text(
                        '남은 ${formatInt(ticket.stepsLeft!)}보',
                        key: const ValueKey('guestbook-steps-left'),
                        style: context.display(14, color: Palette.terracotta),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                if (showConsent) ...[
                  // TODO: 약관 v03 문구가 정해지면 바꾼다 (지금은 가안)
                  const Text(
                    '남긴 글은 다른 사람들에게 보여요. 이용약관에 동의하고 남겨요',
                    key: ValueKey('guestbook-consent'),
                    style: TextStyle(fontSize: 13, height: 1.4, color: Palette.subInk),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  key: const ValueKey('guestbook-input'),
                  controller: _controller,
                  minLines: 5,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  inputFormatters: [_RuneLimit(maxChars)],
                  style: const TextStyle(fontSize: 16, color: Palette.ink),
                  decoration: _inputDecoration('한마디를 남겨 보세요'),
                  onChanged: (_) => setState(() => _serverBlock = null),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: blocked
                          ? Padding(
                              padding: EdgeInsets.only(left: 4),
                              child: Text(
                                blockMessage,
                                key: ValueKey('guestbook-blocked'),
                                style: TextStyle(fontSize: 13, color: Palette.terracotta),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${postLength(_controller.text)}/$maxChars',
                      key: const ValueKey('guestbook-count'),
                      style: const TextStyle(fontSize: 13, color: Palette.subInk),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        GameButton(
          label: '남기기',
          onPressed: valid && !_busy ? () => _save(ticket) : null,
        ),
      ],
    );
  }
}

InputDecoration _inputDecoration(String hint) {
  OutlineInputBorder border(double width) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Palette.ink, width: width),
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Palette.subInk),
    filled: true,
    fillColor: Palette.card,
    contentPadding: const EdgeInsets.all(14),
    border: border(InkLine.panel),
    enabledBorder: border(InkLine.panel),
    focusedBorder: border(InkLine.focus),
  );
}

/// 글자(rune) 수가 [max]를 넘으면 앞에서 [max]자만 남긴다 (붙여 넣기도 자른다)
class _RuneLimit extends TextInputFormatter {
  const _RuneLimit(this.max);

  final int max;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (postLength(newValue.text) <= max) return newValue;
    final text = clipPost(newValue.text, max);
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}
