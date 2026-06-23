-- ============================================================
-- content_attempts 참조 무결성 점검
-- accounts, characters, content_master에 존재하지 않는 참조값 확인
-- ============================================================

SELECT COUNT(*) AS orphan_content_attempts
FROM content_attempts ca
LEFT JOIN accounts a ON ca.account_id = a.account_id
LEFT JOIN characters c ON ca.character_id = c.character_id
LEFT JOIN content_master cm ON ca.content_id = cm.content_id
WHERE a.account_id IS NULL
   OR c.character_id IS NULL
   OR cm.content_id IS NULL;
   
SELECT c.account_id
FROM characters c
LEFT JOIN accounts a
    ON c.account_id = a.account_id
WHERE a.account_id IS NULL;

SELECT ca.character_id
FROM content_attempts ca
LEFT JOIN characters c
    ON ca.character_id = c.character_id
WHERE c.character_id IS NULL;

SELECT ca.content_id
FROM content_attempts ca
LEFT JOIN content_master cm
ON ca.content_id= cm.content_id
WHERE cm.content_id IS NULL;

SELECT bpl.attempt_id
FROM boss_pattern_logs bpl
LEFT JOIN content_attempts ca
    ON bpl.attempt_id = ca.attempt_id
WHERE ca.attempt_id IS NULL;

SELECT rl.attempt_id
FROM reward_logs rl
LEFT JOIN content_attempts ca
    ON rl.attempt_id = ca.attempt_id
WHERE rl.attempt_id IS NOT NULL
  AND ca.attempt_id IS NULL;