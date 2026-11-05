// 설정 문서 넣기: 앱 데이터(app/assets/data)를 읽어 config/guestbook·config/moderation으로 올린다.
// 에뮬레이터: 에뮬레이터를 켠 채 FIRESTORE_EMULATOR_HOST=127.0.0.1:8080 GCLOUD_PROJECT=demo-doobal npm run seed
// 진짜 프로젝트: GCLOUD_PROJECT=<프로젝트 id> npm run seed -- --real (구글 로그인 필요)
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { getApps, initializeApp } from 'firebase-admin/app';
import { getFirestore, type Firestore } from 'firebase-admin/firestore';

const dataDir = join(__dirname, '..', '..', '..', 'app', 'assets', 'data');
const load = (name: string) => JSON.parse(readFileSync(join(dataDir, name), 'utf8'));

/** config/moderation = moderation.json + 허용 이름(명소·시군구). check_moderation.py의 autoWords와 같다 */
export function moderationDoc(): Record<string, any> {
  const doc = load('moderation.json');
  const names: string[] = [
    ...load('landmarks.json').landmarks.map((x: { name: string }) => x.name),
    ...load('sigungu.json').items.map((x: { name: string }) => x.name),
  ];
  return { ...doc, allow: { ...doc.allow, autoWords: [...new Set(names)].sort() } };
}

/** config/guestbook = config.json guestbook 그대로 */
export function guestbookDoc(): Record<string, any> {
  return load('config.json').guestbook;
}

export async function seedConfig(db: Firestore): Promise<void> {
  await db.doc('config/guestbook').set(guestbookDoc());
  await db.doc('config/moderation').set(moderationDoc());
}

if (require.main === module) {
  if (process.env.FIRESTORE_EMULATOR_HOST === undefined && !process.argv.includes('--real')) {
    console.error('에뮬레이터가 아니에요. 진짜 프로젝트에 넣으려면 --real을 붙이세요');
    process.exit(1);
  }
  if (getApps().length === 0) initializeApp();
  const db = getFirestore();
  seedConfig(db).then(
    () => console.log(`설정 문서를 넣었어요 (${process.env.GCLOUD_PROJECT})`),
    (e) => {
      console.error(e);
      process.exit(1);
    },
  );
}
