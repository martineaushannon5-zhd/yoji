import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { after, before, test } from 'node:test';
import assert from 'node:assert/strict';

const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), 'yoji-test-'));
const mediaDir = path.join(dataDir, 'media');
fs.mkdirSync(mediaDir, { recursive: true });

process.env.NODE_ENV = 'test';
process.env.DATA_DIR = dataDir;
process.env.MEDIA_DIR = mediaDir;
process.env.JWT_SECRET = 'test-secret-0123456789abcdef0123456789abcdef';
process.env.ADMIN_TOKEN = 'test-admin-token';
process.env.BCRYPT_ROUNDS = '8';

const { app } = await import('../src/app.js');
const { db, seedVideosIfEmpty } = await import('../src/db.js');
seedVideosIfEmpty();

let server;
let baseUrl = '';
const state = {
  token: '',
  adminToken: 'test-admin-token',
  version: 0
};

before(async () => {
  await new Promise((resolve) => {
    server = app.listen(0, '127.0.0.1', resolve);
  });
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  await new Promise((resolve) => server.close(resolve));
  db.close();
  fs.rmSync(dataDir, { recursive: true, force: true });
});

async function api(pathname, options = {}) {
  const headers = { 'Content-Type': 'application/json' };
  if (options.token) {
    headers.Authorization = `Bearer ${options.token}`;
  }
  if (options.admin) {
    headers['x-admin-token'] = options.admin;
  }
  const res = await fetch(`${baseUrl}${pathname}`, {
    method: options.method || 'GET',
    headers,
    body: options.body === undefined ? undefined : JSON.stringify(options.body)
  });
  let body = null;
  const text = await res.text();
  if (text) {
    body = JSON.parse(text);
  }
  return { status: res.status, body };
}

function ymd(offsetDays) {
  const d = new Date();
  d.setUTCDate(d.getUTCDate() - offsetDays);
  return `${d.getUTCFullYear()}-${d.getUTCMonth() + 1}-${d.getUTCDate()}`;
}

test('healthz', async () => {
  const res = await api('/healthz');
  assert.equal(res.status, 200);
  assert.equal(res.body.status, 'ok');
});

test('注册 / 重复注册 / 登录校验', async () => {
  const register = await api('/api/auth/register', {
    method: 'POST',
    body: { account: 'student01', password: 'secret123' }
  });
  assert.equal(register.status, 200);
  assert.equal(register.body.code, 0);
  assert.ok(register.body.data.token);
  assert.equal(register.body.data.nickname, 'Yoji.student01');
  state.token = register.body.data.token;

  const duplicate = await api('/api/auth/register', {
    method: 'POST',
    body: { account: 'Student01', password: 'secret123' }
  });
  assert.equal(duplicate.status, 409);
  assert.equal(duplicate.body.code, 1003);

  const shortPassword = await api('/api/auth/register', {
    method: 'POST',
    body: { account: 'student02', password: '123' }
  });
  assert.equal(shortPassword.status, 400);

  const wrong = await api('/api/auth/login', {
    method: 'POST',
    body: { account: 'student01', password: 'wrong-password' }
  });
  assert.equal(wrong.status, 401);
  assert.equal(wrong.body.code, 1002);

  const login = await api('/api/auth/login', {
    method: 'POST',
    body: { account: 'student01', password: 'secret123' }
  });
  assert.equal(login.status, 200);
  assert.equal(login.body.data.userId.length > 0, true);
  state.token = login.body.data.token;

  const me = await api('/api/auth/me', { token: state.token });
  assert.equal(me.status, 200);
  assert.equal(me.body.data.account, 'student01');
});

test('进度：首次同步、并集合并、连续天数', async () => {
  const empty = await api('/api/progress', { token: state.token });
  assert.equal(empty.status, 200);
  assert.equal(empty.body.data.version, 0);

  const localData = {
    currentBookId: 'cet4',
    dailyTarget: 20,
    statusMap: { 'c4-1': 2, 'c4-2': 1 },
    masteredAt: { 'c4-1': ymd(1) },
    learnedLog: { [ymd(1)]: ['c4-1'], [ymd(0)]: ['c4-2'] },
    favorites: { 'c4-3': ymd(0) },
    swipeGuideShown: true,
    todayLearned: 1,
    todayDate: ymd(0),
    streak: 0,
    totalLearned: 1,
    learnedDays: 2,
    lastLearnDate: ymd(0),
    videoProgress: { 'ted-anxiety': 30 },
    darkMode: true,
    nickname: '测试用户',
    gender: '男',
    birthday: '2000-1-2',
    favoriteVideos: { 'ted-anxiety': ymd(0) },
    customWords: [
      {
        id: 'cu-1',
        word: 'serendipity',
        phonetic: '/ˌserənˈdɪpəti/',
        meaning: 'n. 意外发现',
        example: '',
        exampleCn: '',
        videoId: 'ted-anxiety'
      }
    ]
  };

  const sync1 = await api('/api/progress/sync', {
    method: 'POST',
    token: state.token,
    body: { data: localData }
  });
  assert.equal(sync1.status, 200);
  const data1 = sync1.body.data.data;
  assert.equal(data1.dailyTarget, 20);
  assert.equal(data1.statusMap['c4-1'], 2);
  assert.equal(data1.streak, 2);
  assert.equal(data1.videoProgress['ted-anxiety'], 30);
  assert.equal(data1.nickname, '测试用户');
  assert.equal(data1.gender, '男');
  assert.equal(data1.birthday, '2000-1-2');
  assert.ok(data1.favoriteVideos['ted-anxiety']);
  assert.equal(data1.customWords.length, 1);
  assert.equal(data1.customWords[0].word, 'serendipity');
  state.version = sync1.body.data.version;

  // 第二台设备：已掌握 c4-2、收藏 c4-4，云端应取并集而不是互相覆盖
  const sync2 = await api('/api/progress/sync', {
    method: 'POST',
    token: state.token,
    body: {
      data: {
        currentBookId: 'cet6',
        dailyTarget: 10,
        statusMap: { 'c4-2': 2 },
        learnedLog: { [ymd(1)]: ['c4-9'] },
        favorites: { 'c4-4': ymd(2) },
        totalLearned: 5,
        videoProgress: { 'casey-sloppy': 99 },
        gender: '女',
        favoriteVideos: { 'casey-sloppy': ymd(1) },
        customWords: [
          {
            id: 'cu-2',
            word: 'resilience',
            phonetic: '/rɪˈzɪliəns/',
            meaning: 'n. 韧性',
            example: '',
            exampleCn: ''
          }
        ]
      }
    }
  });
  assert.equal(sync2.status, 200);
  const data2 = sync2.body.data.data;
  assert.equal(data2.currentBookId, 'cet6');
  assert.equal(data2.statusMap['c4-2'], 2);
  assert.equal(data2.statusMap['c4-1'], 2);
  assert.ok(data2.favorites['c4-3']);
  assert.ok(data2.favorites['c4-4']);
  assert.deepEqual(data2.learnedLog[ymd(1)].sort(), ['c4-1', 'c4-9'].sort());
  assert.equal(data2.videoProgress['casey-sloppy'], 99);
  assert.equal(data2.totalLearned, 5);
  assert.equal(data2.gender, '女');
  assert.ok(data2.favoriteVideos['ted-anxiety']);
  assert.ok(data2.favoriteVideos['casey-sloppy']);
  assert.equal(data2.customWords.length, 2);

  const fetched = await api('/api/progress', { token: state.token });
  assert.equal(fetched.status, 200);
  assert.equal(fetched.body.data.version, sync2.body.data.version);
});

test('进度：乐观锁与强制覆盖', async () => {
  const conflict = await api('/api/progress', {
    method: 'PUT',
    token: state.token,
    body: { data: { dailyTarget: 30 }, expectedVersion: 0 }
  });
  assert.equal(conflict.status, 409);
  assert.equal(conflict.body.code, 1008);

  const force = await api('/api/progress', {
    method: 'PUT',
    token: state.token,
    body: {
      data: { currentBookId: 'cet4', dailyTarget: 15, statusMap: {}, learnedLog: {} },
      force: true
    }
  });
  assert.equal(force.status, 200);
  assert.equal(force.body.data.data.dailyTarget, 15);
  assert.equal(Object.keys(force.body.data.data.statusMap).length, 0);
});

test('视频：公开列表 + 后台增删改', async () => {
  const list = await api('/api/videos');
  assert.equal(list.status, 200);
  assert.equal(list.body.data.videos.length, 2);
  assert.ok(list.body.data.videos[0].videoUrl.startsWith('/media/'));

  const denied = await api('/api/admin/videos');
  assert.equal(denied.status, 401);

  const ping = await api('/api/admin/ping', { admin: state.adminToken });
  assert.equal(ping.status, 200);

  const created = await api('/api/admin/videos', {
    method: 'POST',
    admin: state.adminToken,
    body: {
      id: 'demo-video',
      title: '演示视频',
      videoUrl: '/media/videos/demo.mp4',
      thumbUrl: '/media/thumbs/demo.jpg',
      date: ymd(0),
      sortOrder: 9
    }
  });
  assert.equal(created.status, 200);
  assert.equal(created.body.data.id, 'demo-video');

  const patched = await api('/api/admin/videos/demo-video', {
    method: 'PATCH',
    admin: state.adminToken,
    body: { title: '演示视频（改）', visible: false }
  });
  assert.equal(patched.status, 200);
  assert.equal(patched.body.data.title, '演示视频（改）');

  const hiddenList = await api('/api/videos');
  assert.equal(hiddenList.body.data.videos.length, 2);

  const removed = await api('/api/admin/videos/demo-video', {
    method: 'DELETE',
    admin: state.adminToken
  });
  assert.equal(removed.status, 200);
});

test('管理后台：登录、统计、用户列表、删除', async () => {
  const denied = await api('/api/admin/login', {
    method: 'POST',
    body: { account: 'admin', password: 'wrong-password' }
  });
  assert.equal(denied.status, 401);

  const login = await api('/api/admin/login', {
    method: 'POST',
    body: { account: 'admin', password: state.adminToken }
  });
  assert.equal(login.status, 200);
  const adminJwt = login.body.data.token;
  assert.ok(adminJwt);

  const noAuth = await api('/api/admin/stats');
  assert.equal(noAuth.status, 401);

  const statsRes = await api('/api/admin/stats', { token: adminJwt });
  assert.equal(statsRes.status, 200);
  assert.ok(statsRes.body.data.totalUsers >= 1);
  assert.equal(statsRes.body.data.trend.length, 14);

  const usersRes = await api('/api/admin/users?search=student01', { token: adminJwt });
  assert.equal(usersRes.status, 200);
  assert.equal(usersRes.body.data.users.length, 1);
  assert.equal(usersRes.body.data.users[0].account, 'student01');
  assert.equal(typeof usersRes.body.data.users[0].mastered, 'number');
  assert.equal(usersRes.body.data.users[0].activeDates, undefined);

  // 创建一个一次性用户，验证删除与级联
  const disposable = await api('/api/auth/register', {
    method: 'POST',
    body: { account: 'delete-me', password: 'secret123' }
  });
  assert.equal(disposable.status, 200);
  const disposableId = disposable.body.data.userId;
  const removed = await api(`/api/admin/users/${disposableId}`, {
    method: 'DELETE',
    token: adminJwt
  });
  assert.equal(removed.status, 200);

  const removedLogin = await api('/api/auth/login', {
    method: 'POST',
    body: { account: 'delete-me', password: 'secret123' }
  });
  assert.equal(removedLogin.status, 401);
});

test('退出登录后旧 token 立即失效', async () => {
  const logout = await api('/api/auth/logout', { method: 'POST', token: state.token });
  assert.equal(logout.status, 200);

  const me = await api('/api/auth/me', { token: state.token });
  assert.equal(me.status, 401);

  const relogin = await api('/api/auth/login', {
    method: 'POST',
    body: { account: 'student01', password: 'secret123' }
  });
  assert.equal(relogin.status, 200);
  const meAgain = await api('/api/auth/me', { token: relogin.body.data.token });
  assert.equal(meAgain.status, 200);
});
