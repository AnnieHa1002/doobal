"""flutter test 출력 요약 (tools/verify_tree.sh가 씀). core <log> | one <log> <file> <ui_log> | ui <ui_log>"""
import re
import sys

PAT = re.compile(r'\d+:\d+ \+(\d+)(?: ~(\d+))?(?: -(\d+))?: (.*)')


def last_counts(path):
    p = s = f = None
    tail = ''
    for line in open(path, encoding='utf-8', errors='replace'):
        m = PAT.match(line.strip())
        if m:
            p, s, f = int(m.group(1)), int(m.group(2) or 0), int(m.group(3) or 0)
            tail = m.group(4)
    return p, s, f, tail


mode = sys.argv[1]
if mode == 'core':
    p, s, f, tail = last_counts(sys.argv[2])
    if p is None:
        print('핵심 결과 없음')
    else:
        end = 'All tests passed!' if 'All tests passed' in tail else ('Some tests failed.' if f else tail[:60])
        print(f'핵심 통과 {p} 건너뜀 {s} 실패 {f} {end}')
elif mode == 'one':
    p, s, f, tail = last_counts(sys.argv[2])
    with open(sys.argv[4], 'a', encoding='utf-8') as out:
        if p is None:
            out.write(f'{sys.argv[3]}\tNONE\n')
        else:
            out.write(f'{sys.argv[3]}\t{p}\t{s}\t{f}\n')
elif mode == 'ui':
    files = pas = sk = fa = 0
    bad = []
    for line in open(sys.argv[2], encoding='utf-8'):
        parts = line.rstrip('\n').split('\t')
        files += 1
        if parts[1] == 'NONE':
            bad.append(f'{parts[0]} 결과 없음')
            continue
        p, s, f = map(int, parts[1:4])
        pas, sk, fa = pas + p, sk + s, fa + f
        if f:
            bad.append(f'{parts[0]} 실패 {f}')
    print(f'UI 파일 {files} 통과 {pas} 건너뜀 {sk} 실패 {fa}')
    print('\n'.join(bad) if bad else '실패 없음')
