CREATE TABLE wfdb_desktop_codes (
    hash TEXT PRIMARY KEY,
    uid INTEGER NOT NULL REFERENCES bbs_user(uid) ON DELETE CASCADE,
    state TEXT NOT NULL,
    challenge TEXT NOT NULL,
    expires_at INTEGER NOT NULL
);
CREATE INDEX wfdb_desktop_codes_expiry ON wfdb_desktop_codes(expires_at);
CREATE INDEX wfdb_desktop_codes_uid ON wfdb_desktop_codes(uid);

CREATE TABLE wfdb_desktop_sessions (
    hash TEXT PRIMARY KEY,
    uid INTEGER NOT NULL REFERENCES bbs_user(uid) ON DELETE CASCADE,
    forum_epoch INTEGER NOT NULL,
    expires_at INTEGER NOT NULL
);
CREATE INDEX wfdb_desktop_sessions_expiry ON wfdb_desktop_sessions(expires_at);
CREATE INDEX wfdb_desktop_sessions_uid ON wfdb_desktop_sessions(uid);
