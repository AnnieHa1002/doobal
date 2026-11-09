// 손 확인용 가짜 카카오 서버 (에뮬레이터 전용). 함수 에뮬레이터가 .env.demo-doobal의 KAKAO_API_BASE로 묻는다.
// 앱 디버그 빌드의 가짜 카카오(FakeKakaoLogin)는 토큰 'valid:<카카오 id>'를 준다. 시험의 가짜 서버(test/account.test.ts)와 같은 꼴
// 켜기: npm run build && node lib/scripts/fake_kakao.js
import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { join } from 'node:path';

const env = Object.fromEntries(
  readFileSync(join(__dirname, '..', '..', '.env.demo-doobal'), 'utf8')
    .split('\n')
    .filter((l) => l.includes('=') && !l.startsWith('#'))
    .map((l) => l.split('=', 2)),
);
const url = new URL(env.KAKAO_API_BASE);

createServer((req, res) => {
  const send = (status: number, body: unknown) => {
    res.writeHead(status, { 'content-type': 'application/json' });
    res.end(JSON.stringify(body));
  };
  const [kind, id] = (req.headers.authorization ?? '').replace('Bearer ', '').split(':');
  if (req.url !== '/v1/user/access_token_info' || kind !== 'valid' || !/^\d+$/.test(id ?? '')) {
    return send(401, { code: -401, msg: 'this access token does not exist' });
  }
  console.log(`카카오 id ${id}`);
  return send(200, { id: Number(id), expires_in: 7199, app_id: Number(env.KAKAO_APP_ID) });
}).listen(Number(url.port), url.hostname, () => console.log(`가짜 카카오 ${url.href}`));
