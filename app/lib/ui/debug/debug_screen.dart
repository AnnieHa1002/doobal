import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/sync_service.dart';

/// M1 디버그 화면: 오늘 걸음·거리·걷기 1번·여정 진행·도착 예정일, 걸음 출처 확인
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

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
    final r = await svc.sync(DateTime.now().toUtc());
    setState(() => _report = r);
    return '기록 ${r.records}개 (버림 ${r.dropped})';
  }

  Future<String> _inspect() async {
    final svc = await ref.read(syncServiceProvider.future);
    final now = DateTime.now().toUtc();
    final r = await svc.inspect(now.subtract(Duration(hours: svc.rules.refetchHours)), now);
    setState(() => _report = r);
    return '기록 ${r.records}개 (버림 ${r.dropped})';
  }

  Future<String> _start() async {
    final svc = await ref.read(syncServiceProvider.future);
    await svc.startJourney(_destId!, svc.rules.fallbackOrigin, DateTime.now().toUtc());
    return '출발함';
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(snapshotProvider);
    final landmarks = ref.watch(landmarksProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('두발 디버그')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          snapshot.when(
            data: _stats,
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('상태를 읽지 못함: $e'),
          ),
          const Divider(height: 32),
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
                child: const Text('양구에서 출발'),
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
      '마지막 동기화 ${s.lastFetched?.toLocal() ?? '-'}',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final l in lines) Text(l)],
    );
  }

  String _date(DateTime d) => d.toIso8601String().substring(0, 10);
}
