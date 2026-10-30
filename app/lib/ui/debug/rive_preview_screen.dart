import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart' as rive;

import '../../domain/blink.dart';

/// Rive 시험 화면 (개발자 화면에서만 연다, M2 ⑥).
/// assets/rive/rive_test_v01.riv: 아트보드 1024×1280, head 그룹(회전 중심 523,538)
/// 안에 머리·뜬 눈·감은 눈, blink 애니메이션 12F(0F 뜸 · 6F 감음 · 12F 뜸).
/// 깜빡임 간격(3~6초, 가끔 두 번)은 Rive가 아니라 여기서 정한다(config character.blink).
class RivePreviewScreen extends StatefulWidget {
  const RivePreviewScreen({super.key, this.random});

  /// 테스트에서 난수를 고정할 때만 넣는다
  final Random? random;

  static const asset = 'assets/rive/rive_test_v01.riv';
  static const blinkAnimation = 'blink';

  @override
  State<RivePreviewScreen> createState() => _RivePreviewScreenState();
}

class _RivePreviewScreenState extends State<RivePreviewScreen> {
  rive.File? _file;
  rive.Artboard? _artboard;
  rive.SingleAnimationPainter? _painter;
  BlinkRule? _rule;
  late final Random _rng = widget.random ?? Random();
  final List<Timer> _timers = [];
  int _blinks = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final config = jsonDecode(await rootBundle.loadString('assets/data/config.json'))
          as Map<String, dynamic>;
      _rule = BlinkRule.fromConfig(config);
      await rive.RiveNative.init();
      final file = await rive.File.asset(RivePreviewScreen.asset, riveFactory: rive.Factory.rive);
      if (!mounted) {
        file?.dispose();
        return;
      }
      final artboard = file?.defaultArtboard();
      if (file == null || artboard == null) {
        setState(() => _error = 'Rive 파일이나 아트보드를 읽지 못했어요');
        return;
      }
      setState(() {
        _file = file;
        _artboard = artboard;
      });
      _blink();
      _schedule();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  /// blink는 한 번 재생하고 끝나는 애니메이션이라, 깜빡일 때마다 새 painter로 처음부터 튼다
  void _blink() {
    final old = _painter;
    setState(() {
      _painter = rive.SingleAnimationPainter(RivePreviewScreen.blinkAnimation);
      _blinks++;
    });
    if (old != null) WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  void _schedule() {
    final rule = _rule;
    if (rule == null || !mounted) return;
    _timers.removeWhere((t) => !t.isActive);
    final times = nextBlinks(rule, _rng);
    for (final t in times) {
      _timers.add(Timer(t, () {
        if (mounted) _blink();
      }));
    }
    // 마지막 깜빡임이 끝난 뒤 다음 묶음을 잡는다
    _timers.add(Timer(times.last, _schedule));
  }

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    _painter?.dispose();
    _artboard?.dispose();
    _file?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final artboard = _artboard;
    final painter = _painter;
    return Scaffold(
      appBar: AppBar(title: const Text('Rive 시험')),
      body: Column(
        children: [
          Expanded(
            child: _error != null
                ? Center(child: Text(_error!, textAlign: TextAlign.center))
                : artboard == null || painter == null
                    ? const Center(child: CircularProgressIndicator())
                    : rive.RiveArtboardWidget(
                        key: ValueKey(_blinks),
                        artboard: artboard,
                        painter: painter,
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('깜빡임 $_blinks번'),
                FilledButton(
                  onPressed: painter == null ? null : _blink,
                  child: const Text('지금 깜빡'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
