import { Hono } from 'hono';
import { BanScope, effectiveBanScope } from '@freeidx/shared';
import type { ReadEnv } from '../shared';
import { core } from '../shared';
import { loadViewer } from '../../core/loaders';

const base = '/wfdb/connect';
const pattern = /^[A-Za-z0-9_-]{43}$/;
const live = () => Math.floor(Date.now() / 1000);
const encode = (bytes: Uint8Array) =>
  btoa(String.fromCharCode(...bytes)).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
const random = () => encode(crypto.getRandomValues(new Uint8Array(32)));
async function digest(value: string): Promise<string> {
  return encode(new Uint8Array(await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value))));
}
const escape = (value: string) => value.replace(/[&<>"']/g, char =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]!);

function page(message: string, status = 200): Response {
  return new Response(`<!doctype html><html lang="zh-CN"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><meta name="referrer" content="no-referrer">
<title>无限库 WFDB · 连接客户端</title>
<style>body{font:1rem system-ui;max-width:38rem;margin:12vh auto;padding:0 1.25rem;line-height:1.7;color:#17222e;background:#f4f7fb}main{padding:1.5rem;background:#fff;border-radius:1rem;border:1px solid #d5dfeb}a{color:#1c5794}a+a{margin-left:1rem}button{padding:.5rem 1rem;cursor:pointer;font:inherit}h1{font-size:1.35rem;margin-top:0}</style>
<main><h1>连接无限库 WFDB 客户端</h1>${message}</main></html>`, {
    status,
    headers: {
      'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store',
      'Referrer-Policy': 'no-referrer', 'X-Content-Type-Options': 'nosniff',
      'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; form-action 'self'; frame-ancestors 'none'; base-uri 'none'",
    },
  });
}

function recordFields(state: unknown, proof: unknown): state is string {
  return typeof state === 'string' && typeof proof === 'string' && pattern.test(state) && pattern.test(proof);
}

function invalid(): Response {
  return page('<p>授权请求无效。请回客户端重新开始。</p>', 400);
}

function response(data: object, status = 200): Response {
  return Response.json(data, { status, headers: { 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' } });
}

export function companionRoutes(): Hono<ReadEnv> {
  const app = new Hono<ReadEnv>();

  app.get(base, async c => {
    const { state, challenge } = c.req.query();
    if (!recordFields(state, challenge)) return invalid();
    const { db, cache } = core(c);
    const viewer = await loadViewer(cache, db, c);
    if (!viewer.uid) {
      return page('<p>请先在新标签页登录论坛。首次使用可注册一个 WFDB 账号。</p>' +
        '<p><a href="/login" target="_blank" rel="noopener">登录论坛</a> <a href="/register" target="_blank" rel="noopener">注册账号</a></p>' +
        `<p><a href="${base}?state=${state}&amp;challenge=${challenge}">登录后继续</a></p>`);
    }
    if (viewer.ok !== 1 || effectiveBanScope(viewer.banScope, viewer.banUntil, live()) & (BanScope.LOGIN | BanScope.READ)) {
      return page('<p>当前账号无法连接客户端。请到论坛查看账号状态。</p>', 403);
    }
    return page(`<p>用 <strong>${escape(viewer.username)}</strong> 登录 Mac 客户端。客户端将读取你的论坛用户名和账号编号。</p>
      <form method="post" action="${base}"><input type="hidden" name="state" value="${state}">
      <input type="hidden" name="challenge" value="${challenge}"><button type="submit">授权客户端</button></form>`);
  });

  app.post(base, async c => {
    if (c.req.header('Origin') !== new URL(c.req.url).origin) return invalid();
    const { state, challenge } = await c.req.parseBody();
    if (!recordFields(state, challenge)) return invalid();
    const { db, cache } = core(c);
    const viewer = await loadViewer(cache, db, c);
    if (!viewer.uid || viewer.ok !== 1 || effectiveBanScope(viewer.banScope, viewer.banUntil, live()) & (BanScope.LOGIN | BanScope.READ)) {
      return page('<p>请用有效的论坛账号登录后重试。</p>', 403);
    }
    const code = random();
    const now = live();
    await c.env.DB.batch([
      c.env.DB.prepare('DELETE FROM wfdb_desktop_codes WHERE expires_at <= ?').bind(now),
      c.env.DB.prepare('DELETE FROM wfdb_desktop_sessions WHERE expires_at <= ?').bind(now),
      c.env.DB.prepare('INSERT INTO wfdb_desktop_codes (hash, uid, state, challenge, expires_at) VALUES (?, ?, ?, ?, ?)')
        .bind(await digest(code), viewer.uid, state, challenge, now + 120),
    ]);
    return page(`<p>已授权。请在两分钟内返回客户端。</p>
      <p><a href="cc.wfdb.companion://account/callback?code=${code}&amp;state=${state}">返回 WFDB 客户端</a></p>`);
  });

  app.post('/wfdb/desktop/token', async c => {
    if (!c.req.header('Content-Type')?.startsWith('application/json') || c.req.header('Origin')) {
      return response({ error: 'invalid_request' }, 400);
    }
    const size = Number(c.req.header('Content-Length'));
    if (size > 512) return response({ error: 'invalid_request' }, 400);
    const body = await c.req.text();
    if (body.length > 512) return response({ error: 'invalid_request' }, 400);
    let values: Record<string, unknown>;
    try { values = JSON.parse(body) ?? {}; } catch { return response({ error: 'invalid_request' }, 400); }
    const { code, state, verifier } = values;
    if (typeof code !== 'string' || !pattern.test(code) || !recordFields(state, verifier)) {
      return response({ error: 'invalid_request' }, 400);
    }
    const db = c.env.DB;
    const now = live();
    const grant = await db.prepare('DELETE FROM wfdb_desktop_codes WHERE hash = ? AND state = ? AND challenge = ? AND expires_at > ? RETURNING uid')
      .bind(await digest(code), state, await digest(verifier as string), now).first<{ uid: number }>();
    if (!grant) return response({ error: 'invalid_grant' }, 401);
    const user = await db.prepare('SELECT uid, username, ok, token_version, ban_scope, ban_until FROM bbs_user WHERE uid = ?')
      .bind(grant.uid).first<UserRow>();
    if (!active(user)) return response({ error: 'invalid_account' }, 403);
    const token = random();
    await db.prepare('INSERT INTO wfdb_desktop_sessions (hash, uid, forum_epoch, expires_at) VALUES (?, ?, ?, ?)')
      .bind(await digest(token), user.uid, user.token_version, now + 30 * 86400).run();
    return response({ token, account: { id: user.uid, username: user.username } });
  });

  app.get('/wfdb/desktop/me', async c => {
    const token = bearer(c.req.header('Authorization'));
    if (!token) return response({ error: 'not_signed_in' }, 401);
    const user = await c.env.DB.prepare(`SELECT u.uid, u.username, u.ok, u.token_version, u.ban_scope, u.ban_until
      FROM wfdb_desktop_sessions s JOIN bbs_user u ON u.uid = s.uid
      WHERE s.hash = ? AND s.expires_at > ? AND s.forum_epoch = u.token_version`)
      .bind(await digest(token), live()).first<UserRow>();
    return active(user) ? response({ id: user.uid, username: user.username }) : response({ error: 'not_signed_in' }, 401);
  });

  app.post('/wfdb/desktop/logout', async c => {
    const token = bearer(c.req.header('Authorization'));
    if (!token) return response({ error: 'not_signed_in' }, 401);
    await c.env.DB.prepare('DELETE FROM wfdb_desktop_sessions WHERE hash = ?').bind(await digest(token)).run();
    return new Response(null, { status: 204, headers: { 'Cache-Control': 'no-store' } });
  });
  return app;
}

interface UserRow {
  uid: number;
  username: string;
  ok: number;
  token_version: number;
  ban_scope: number;
  ban_until: number;
}

function active(user: UserRow | null): user is UserRow {
  return !!user && user.ok === 1 && !(effectiveBanScope(user.ban_scope, user.ban_until, live()) & (BanScope.LOGIN | BanScope.READ));
}

function bearer(header: string | undefined): string | undefined {
  return /^Bearer ([A-Za-z0-9_-]{43})$/.exec(header ?? '')?.[1];
}
