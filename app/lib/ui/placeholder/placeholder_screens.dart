import 'package:flutter/material.dart';

import '../debug/debug_screen.dart';

/// 제목과 "준비 중"만 있는 임시 화면
class _Placeholder extends StatelessWidget {
  const _Placeholder(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: const Center(child: Text('준비 중')),
    );
  }
}

/// 지도: 지도 그림이 나오기 전까지는 목적지를 고르는 디버그 화면을 쓴다
class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context) => const DebugScreen(title: '지도 (임시)');
}

/// 화집 (배낭)
class AlbumScreen extends StatelessWidget {
  const AlbumScreen({super.key});

  @override
  Widget build(BuildContext context) => const _Placeholder('화집');
}

class NoteScreen extends StatelessWidget {
  const NoteScreen({super.key});

  @override
  Widget build(BuildContext context) => const _Placeholder('노트');
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) => const _Placeholder('나의 정보');
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('개발자 화면'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => const DebugScreen())),
          ),
        ],
      ),
    );
  }
}
