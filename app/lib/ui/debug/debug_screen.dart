import 'spirit_preview_screen.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/companion_providers.dart';
import '../../app/providers.dart';
import '../../app/sync_service.dart';
import '../../domain/companion_engine.dart' show storyNoticeKey;
import '../../domain/notification_policy.dart';
import '../common/palette.dart';
import '../companion/meet_flow.dart';
import 'rive_preview_screen.dart';

/// 개발 화면이 띄우는 이야기 알림의 번호 (알림 기록의 번호와 겹치지 않을 만큼 크게)
const _debugNoticeId = 1 << 30;

/// 거리 배수 고르기 선택지 (테스트용이라 코드에 둔다)
const debugDistanceScales = [1.0, 10.0, 100.0];

String _scaleNumber(double scale) => scale == scale.roundToDouble() ? '${scale.round()}' : '$scale';

/// 1×가 아닐 때 쉼터에 띄우는 표시: "거리 ×10"
String distanceScaleBadge(double scale) => '거리 ×${_scaleNumber(scale)}';

/// M1 디버그 화면: 오늘 걸음·거리·걷기 1번·여정 진행·도착 예정일, 걸음 출처 확인
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key, this.title = '두발 디버그'});

  final String title;

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  String? _message;
  SyncReport? _report;
  String? _destId;
  var _busy = false;

  Future<void> _run(String label, Future<String> Function() job) async {
    setState(() => _busy = true);
    try {
      final done = await job();
      setState(() => _message = '$label: $done');
    } catch (e) {
      setState(() => _message = '$label 실패: $e');
    } finally {
      ref.invalidate(snapshotProvider);
      setState(() => _busy = false);
    }
  }

  Future<String> _permission() async {
    final ok = await ref.read(stepSourceProvider).requestPermission();
    return ok ? '허용됨' : '거부됨';
  }

  Future<String> _sync() async {
    final svc = await ref.read(syncServiceProvider.future);
    final r = await svc.sync(ref.read(clockProvider)());
    setState(() => _report = r);
    return '기록 ${r.records}개 (버림 ${r.dropped})';
  }

  Future<String> _inspect() async {
    final svc = await ref.read(syncServiceProvider.future);
    final now = ref.read(clockProvider)();
    final r = await svc.inspect(now.subtract(Duration(hours: svc.rules.refetchHours)), now);
    setState(() => _report = r);
    return '기록 ${r.records}개 (버림 ${r.dropped})';
  }

  Future<String> _start() async {
    final svc = await ref.read(syncServiceProvider.future);
    await svc.startJourney(_destId!, ref.read(clockProvider)());
    return '출발함';
  }

  Future<String> _stop() async {
    final svc = await ref.read(syncServiceProvider.future);
    await svc.stopJourney(ref.read(clockProvider)());
    return '멈춤';
  }

  /// 칸 없이 다음 동행을 바로 만나 길 위 만남 흐름을 본다 (폰에서 2km를 안 걸어도 되게)
  Future<String> _meetNext() async {
    final svc = await ref.read(syncServiceProvider.future);
    final now = ref.read(clockProvider)();
    final met = await svc.debugMeetNext(now);
    if (met == null) return '다 만남';
    final view = await svc.companionsView();
    if (!mounted) return met.name;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (page) => Scaffold(
        backgroundColor: Palette.moss,
        body: MeetFlow(
          companion: met,
          walkingWith: view.metById(view.walkingWith)?.companion,
          rules: svc.rules,
          onChoose: (together) async {
            await svc.finishMeeting(met.id, ref.read(clockProvider)(), together: together);
            ref.invalidate(companionsViewProvider);
            if (page.mounted) Navigator.of(page).pop();
          },
        ),
      ),
    ));
    return met.name;
  }

  /// 함께 걷는(없으면 마지막) 동행의 이야기를 한 장 더 연다 (걷기 4번을 안 채워도 읽어 보게)
  Future<String> _openChapter() async {
    final svc = await ref.read(syncServiceProvider.future);
    final view = await svc.companionsView();
    final met = view.metById(view.walkingWith ?? view.lastWith);
    if (met == null) return '만난 동행 없음';
    await svc.debugOpenNextChapter(met.companion.id);
    ref.invalidate(companionsViewProvider);
    return '${met.companion.name} 한 장 더';
  }

  /// 지금 열린 장의 이야기 알림(N3)을 바로 띄운다 (폰에서 눌러 그 장이 열리는지 보게. 기록에는 안 남는다)
  Future<String> _noticeChapter() async {
    final svc = await ref.read(syncServiceProvider.future);
    final view = await svc.companionsView();
    final met = view.metById(view.walkingWith ?? view.lastWith);
    if (met == null) return '만난 동행 없음';
    final message = buildNotice(
      NoticeCandidate(NoticeKind.n3,
          key: storyNoticeKey(met.companion.id, met.chapter),
          vars: {'companion': met.companion.name}),
      await ref.read(noticeCatalogProvider.future),
      '',
      ref.read(clockProvider)(),
    );
    await ref.read(systemNotifierProvider).show(
        _debugNoticeId, message.kind, message.title, message.body, message.payload);
    return message.payload;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(snapshotProvider);
    final landmarks = ref.watch(landmarksProvider).value ?? const [];
    final scale = ref.watch(debugDistanceScaleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          snapshot.when(
            data: _stats,
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('상태를 읽지 못함: $e'),
          ),
          const Divider(height: 32),
          // 테스트용 거리 배수: 여정 진행 거리에만 곱한다. 앱을 다시 켜면 1×
          if (kDebugMode) ...[
            const Text('거리 배수 (테스트용, 다시 켜면 1×)'),
            const SizedBox(height: 8),
            SegmentedButton<double>(
              key: const ValueKey('distance-scale'),
              showSelectedIcon: false,
              segments: [
                for (final s in debugDistanceScales)
                  ButtonSegment(value: s, label: Text('${_scaleNumber(s)}×')),
              ],
              selected: {scale},
              onSelectionChanged: (v) =>
                  ref.read(debugDistanceScaleProvider.notifier).set(v.first),
            ),
            if (scale != 1) ...[
              const SizedBox(height: 8),
              Text(
                '${distanceScaleBadge(scale)}: 걸은 거리에 곱해서 빨리 도착해요 (경비·하루 요약은 그대로)',
                key: const ValueKey('distance-scale-note'),
              ),
            ],
            const Divider(height: 32),
          ],
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _run('권한', _permission),
                child: const Text('걸음 권한 요청'),
              ),
              FilledButton(
                onPressed: _busy ? null : () => _run('동기화', _sync),
                child: const Text('지금 동기화'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _run('출처 보기', _inspect),
                child: const Text('최근 48시간 출처 보기'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _run('여정', _stop),
                child: const Text('멈추기'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const RivePreviewScreen()),
                ),
                child: const Text('Rive 시험'),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const SpiritPreviewScreen()),
                ),
                child: const Text('정령 움직임'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _run('길 위 만남', _meetNext),
                child: const Text('길 위 만남'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _run('이야기', _openChapter),
                child: const Text('이야기 한 장 더'),
              ),
              OutlinedButton(
                onPressed: _busy ? null : () => _run('이야기 알림', _noticeChapter),
                child: const Text('이야기 알림'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: const Text('목적지'),
                  value: _destId,
                  items: [
                    for (final l in landmarks)
                      DropdownMenuItem(value: l.id, child: Text('${l.id} ${l.name}')),
                  ],
                  onChanged: (v) => setState(() => _destId = v),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _busy || _destId == null ? null : () => _run('여정', _start),
                child: const Text('지금 자리에서 출발'),
              ),
            ],
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!),
          ],
          if (_report != null) ...[
            const SizedBox(height: 16),
            const Text('출처별 걸음 (sourceId)'),
            for (final e in _report!.stepsBySource.entries) Text('${e.key}: ${e.value}보'),
          ],
        ],
      ),
    );
  }

  Widget _stats(Snapshot s) {
    final j = s.journey;
    final lines = [
      '오늘 (${s.today})',
      '걸음 ${s.todaySteps}보 · 거리 ${(s.todayDistanceM / 1000).toStringAsFixed(2)}km',
      '걷기 1번 ${s.countedSessions}번',
      '여행 경비 ${s.fundKm.toStringAsFixed(2)}km',
      '출발 동네 ${s.home?.name ?? '없음'}',
      if (j == null)
        '여정 없음'
      else ...[
        '여정 → ${j.dest.name}',
        '진행 ${j.progress.progressKm.toStringAsFixed(2)} / ${j.totalKm.toStringAsFixed(2)}km '
            '(${(j.progress.ratio * 100).toStringAsFixed(1)}%)',
        j.progress.arrived
            ? '도착함'
            : '남은 ${j.progress.remainingKm.toStringAsFixed(2)}km · 도착 예정 ${_date(j.eta)}',
      ],
      '누적 ${s.totalKm.toStringAsFixed(2)}km · 그림 ${s.paintingsCount}점 · '
          '새 소품 ${s.unseenProps}개 · 새 그림 ${s.unseenPaintings}점',
      if (s.pendingArrival case final a?)
        '도착 화면 대기: ${a.dest.name} ${a.visitNo}번째 · 액자 ${a.prevFrame?.name ?? '-'} → '
            '${a.newFrame.name}',
      '마지막 동기화 ${s.lastFetched?.toLocal() ?? '-'}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final l in lines) Text(l)],
    );
  }

  String _date(DateTime d) => d.toIso8601String().substring(0, 10);
}
