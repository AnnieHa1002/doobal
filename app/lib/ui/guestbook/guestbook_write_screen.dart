import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/guestbook.dart';
import '../common/corner_button.dart';
import '../common/format.dart';
import '../common/game_button.dart';
import '../common/palette.dart';
import '../common/toast.dart';

/// 어디서 쓰는 글인지 알리는 태그: 도착이면 "경복궁 도착"(첫 여정은 "내 동네 스케치 도착"),
/// 걸음 숫자면 "12,345보"
String guestbookTag(GuestbookTicket t) => t.kind == TicketKind.milestone
    ? '${formatInt(t.milestone!)}보'
    : '${t.placeName} 도착';

/// 방명록 쓰기 (UI 명세 9장). 위에 태그, 걸음 숫자 기회면 남은 걸음, 처음 쓸 때만 동의 한 줄,
/// 입력 칸(글자 수 상한은 config guestbook.maxChars)과 글자 수, 주 버튼 "남기기".
/// 글이 유효할 때만 버튼이 켜지고, 누르면 이 기기에 저장하고 닫는다. 서버로 보내는 건 M5에서 한다
class GuestbookWriteScreen extends ConsumerStatefulWidget {
  const GuestbookWriteScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<GuestbookWriteScreen> createState() => _GuestbookWriteScreenState();
}

class _GuestbookWriteScreenState extends ConsumerState<GuestbookWriteScreen> {
  final _controller = TextEditingController();
  var _busy = false;

  /// 처음 읽은 기회. 글을 쓰고 기회를 다시 읽으면 null이 되는데, 그동안 화면이 바뀌지 않게 남겨 둔다
  GuestbookTicket? _ticket;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 저장하고 토스트를 띄운 뒤 닫는다. 그새 기회가 끝났으면(StateError) 그 사유를 토스트로 알리고 닫는다.
  /// 어느 쪽이든 쉼터 표지판·도착 화면 버튼이 새로 읽는다
  Future<void> _save(GuestbookTicket ticket) async {
    if (_busy) return;
    setState(() => _busy = true);
    var message = '방명록을 남겼어요';
    try {
      final svc = await ref.read(syncServiceProvider.future);
      await svc.writeGuestbook(ticket.id, _controller.text, ref.read(clockProvider)());
    } on StateError catch (e) {
      message = e.message;
    }
    if (!mounted) return;
    ref.invalidate(snapshotProvider);
    ref.invalidate(guestbookTicketProvider);
    showToast(context, message);
    Navigator.of(context).pop();
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
    final valid = cleanPost(_controller.text, maxChars) != null;
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
                    _Tag(guestbookTag(ticket)),
                    if (ticket.stepsLeft != null)
                      Text(
                        '남은 ${formatInt(ticket.stepsLeft!)}보',
                        key: const ValueKey('guestbook-steps-left'),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Palette.terracotta,
                        ),
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
                // TODO(M5): 금칙어는 올리기 전에 입력 칸 아래에 안내한다 (앱·서버 두 번 검사)
                TextField(
                  key: const ValueKey('guestbook-input'),
                  controller: _controller,
                  minLines: 5,
                  maxLines: 8,
                  keyboardType: TextInputType.multiline,
                  inputFormatters: [_RuneLimit(maxChars)],
                  style: const TextStyle(fontSize: 16, color: Palette.ink),
                  decoration: _inputDecoration('한마디를 남겨 보세요'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${postLength(_controller.text)}/$maxChars',
                    key: const ValueKey('guestbook-count'),
                    style: const TextStyle(fontSize: 13, color: Palette.subInk),
                  ),
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
    border: border(2.5),
    enabledBorder: border(2.5),
    focusedBorder: border(3.5),
  );
}

/// 어디서 쓰는지 알리는 알약 (카드색, 잉크 2px 테두리)
class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('guestbook-tag'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Palette.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Palette.ink, width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Palette.ink),
      ),
    );
  }
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
