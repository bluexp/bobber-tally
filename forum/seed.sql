
UPDATE bbs_kv SET v = json_set(v,
    '$.sitename', '无限库 WFDB 论坛', '$.brief', '魔兽世界：无限 · Forever & Fish',
    '$.lang', 'zh-cn', '$.user_resetpw_on', 0
) WHERE k = 'setting';

UPDATE bbs_group SET allowpost = 0 WHERE gid = 0;
UPDATE bbs_group SET allowattach = 0;

UPDATE bbs_forum SET
    name = '钓点实测',
    name_i18n = '{"zh-cn":"钓点实测","en-us":"Fishing observations"}',
    brief = '分享钓点和实钓记录'
WHERE fid = 1 AND name = '默认版块';

INSERT OR IGNORE INTO bbs_forum (fid, name, name_i18n, rank, brief) VALUES
    (2, '插件与客户端', '{"zh-cn":"插件与客户端","en-us":"Add-ons and desktop app"}', 2, 'BobberTally 和 WFDB 客户端的使用与反馈'),
    (3, '攻略交流', '{"zh-cn":"攻略交流","en-us":"Guides and discussion"}', 3, '钓鱼、烹饪与无限服心得');
