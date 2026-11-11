#!/usr/bin/env python3
"""리포에 키·토큰·인증서가 들어가지 않았는지 본다. 걸리면 1로 끝난다 (CLAUDE.md '비밀 값').

    python3 tools/check_secrets.py              # 지금 올라갈 것: 추적 파일 + 스테이징
    python3 tools/check_secrets.py --range origin/main..HEAD   # push할 커밋들에 더해진 줄
    python3 tools/check_secrets.py --history    # 모든 기록 (한 번씩 점검할 때)

걸린 값은 앞 6글자만 보여 준다(화면·기록에 키를 남기지 않게).
에뮬레이터·시험용 가짜 값은 아래 FAKE에 적고, 값 자체에 Demo·Fake·EmulatorOnly 같은 말을 넣는다.
"""
import re
import subprocess
import sys

# 리포에 두면 안 되는 파일 (이름)
FORBIDDEN_FILES = [
    (re.compile(r'(^|/)google-services\.json$'), 'Firebase 안드로이드 설정'),
    (re.compile(r'(^|/)GoogleService-Info\.plist$'), 'Firebase iOS 설정'),
    (re.compile(r'(^|/)firebase_options\.dart$'), 'flutterfire 설정(실제 키)'),
    (re.compile(r'(^|/)key\.properties$'), '안드로이드 서명 설정'),
    (re.compile(r'\.(jks|keystore|p8|p12|pem|mobileprovision|cer)$'), '서명 키·인증서'),
    (re.compile(r'(^|/)\.env(\.[^/]+)?$'), '환경 변수(비밀)'),
    (re.compile(r'(^|/)[^/]*(service[-_]?account|adminsdk)[^/]*\.json$', re.I), '서비스 계정 키'),
    (re.compile(r'(^|/)\.runtimeconfig\.json$'), '함수 설정'),
    (re.compile(r'(^|/)secrets?(\.[^/]+)?\.(json|xcconfig|properties)$', re.I), '비밀 값 파일'),
]
# 이름은 걸리지만 가짜 값만 든 파일 (내용은 아래 줄 검사를 그대로 받는다)
ALLOWED_FILES = {'functions/.env.demo-doobal'}

# 줄 안의 키 꼴
PATTERNS = [
    (re.compile(r'AIza[0-9A-Za-z_\-]{35}'), 'Google API 키'),
    (re.compile(r'-----BEGIN [A-Z ]*PRIVATE KEY-----'), '개인 키'),
    (re.compile(r'"private_key(_id)?"\s*:'), '서비스 계정 키'),
    (re.compile(r'\bgh[pousr]_[A-Za-z0-9]{36}\b|\bgithub_pat_[A-Za-z0-9_]{20,}'), 'GitHub 토큰'),
    (re.compile(r'\bAKIA[0-9A-Z]{16}\b'), 'AWS 키'),
    (re.compile(r'\bxox[abprs]-[A-Za-z0-9-]{10,}'), 'Slack 토큰'),
    (re.compile(r'\bsk-(ant-)?[A-Za-z0-9_\-]{20,}'), 'API 비밀 키'),
    (re.compile(r'\bAAAA[A-Za-z0-9_\-]{7}:[A-Za-z0-9_\-]{100,}'), 'FCM 서버 키'),
    (re.compile(r'ca-app-pub-\d{16}[~/]\d{10}'), 'AdMob 앱·광고 단위 ID'),
    (re.compile(r'(?i)(api[_-]?key|secret|token|password|passwd)["\']?\s*[:=]\s*["\'][A-Za-z0-9_\-+/=]{24,}["\']'),
     '키처럼 보이는 값'),
]

# 리포에 두는 가짜 값 (이것만 통과)
FAKE = {
    'AIzaSyDemoKeyForFirebaseEmulatorOnly000',  # T1b 에뮬레이터 demo-doobal 전용 (app/lib/data/firebase_backend.dart)
}

# 글이 아닌 파일은 내용 검사를 건너뛴다
BINARY = re.compile(r'\.(png|jpe?g|webp|gif|riv|ttf|otf|woff2?|mp3|mp4|zip|aab|apk|so|jar|ico|pdf)$', re.I)


def git(*args):
    return subprocess.run(['git', *args], capture_output=True, text=True, errors='replace', check=True).stdout


def mask(s):
    return s[:6] + '…'


def check_line(where, line, found):
    for rx, label in PATTERNS:
        for m in rx.finditer(line):
            if any(f in m.group(0) for f in FAKE):
                continue
            found.append(f'{where}: {label} {mask(m.group(0))}')


def check_name(path, found):
    if path in ALLOWED_FILES:
        return
    for rx, label in FORBIDDEN_FILES:
        if rx.search(path):
            found.append(f'{path}: 올리면 안 되는 파일 ({label})')


def scan_tree(found):
    paths = set(git('ls-files').splitlines()) | set(git('diff', '--cached', '--name-only', '--diff-filter=AM').splitlines())
    for path in sorted(paths):
        check_name(path, found)
        if BINARY.search(path):
            continue
        try:
            text = git('show', f':{path}')
        except subprocess.CalledProcessError:
            continue
        for n, line in enumerate(text.splitlines(), 1):
            check_line(f'{path}:{n}', line, found)


def scan_patch(log_args, found):
    path = '?'
    commit = '?'
    for line in git('log', '-p', '--no-color', '--format=commit %h', *log_args).splitlines():
        if line.startswith('commit '):
            commit = line.split()[1]
        elif line.startswith('+++ b/'):
            path = line[6:]
            check_name(path, found)
        elif line.startswith('+') and not line.startswith('+++') and not BINARY.search(path):
            check_line(f'{commit} {path}', line[1:], found)


def main():
    found = []
    if '--range' in sys.argv:
        scan_patch([sys.argv[sys.argv.index('--range') + 1]], found)
    elif '--history' in sys.argv:
        scan_patch(['--all'], found)
    else:
        scan_tree(found)
    found = list(dict.fromkeys(found))
    if found:
        print('비밀 값 의심', len(found))
        for f in found[:50]:
            print('  ', f)
        sys.exit(1)
    print('비밀 값 없음')


if __name__ == '__main__':
    main()
