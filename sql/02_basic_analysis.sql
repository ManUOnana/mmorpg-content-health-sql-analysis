-- =========================================================================================
-- 1. 전체 데이터 규오 확인
-- =========================================================================================
SELECT 'accounts' AS table_name, COUNT(*) AS row_count FROM accounts
UNION ALL
SELECT 'characters' AS table_name, COUNT(*) AS row_count FROM characters
UNION ALL
SELECT 'daily_activity' AS table_name, COUNT(*) AS row_count FROM daily_activity
UNION ALL
SELECT 'content_attempts' AS table_name, COUNT(*) AS row_count FROM content_attempts
UNION ALL
SELECT 'boss_pattern_logs' AS table_name, COUNT(*) AS row_count FROM boss_pattern_logs
UNION ALL
SELECT 'reward_logs' AS table_name, COUNT(*) AS row_count FROM reward_logs
UNION ALL
SELECT 'enhancement_logs' AS table_name, COUNT(*) AS row_count FROM enhancement_logs
UNION ALL
SELECT 'payments' AS table_name, COUNT(*) AS row_count FROM payments
UNION ALL
SELECT 'content_master' AS table_name, COUNT(*) AS row_count FROM content_master
UNION ALL
SELECT 'content_design_goals' AS table_name, COUNT(*) AS row_count FROM content_design_goals
ORDER BY row_count DESC;
-- =========================================================================================
-- 2. 주요 날짜 범위 확인
-- =========================================================================================
SELECT
    'accounts.created_at' AS date_source,
    MIN(DATE(created_at)) AS min_date,
    MAX(DATE(created_at)) AS max_date,
    DATEDIFF(MAX(DATE(created_at)), MIN(DATE(created_at))) + 1 AS date_span_days,
    COUNT(*) AS row_count
FROM accounts

UNION ALL

SELECT
    'characters.created_at' AS date_source,
    MIN(DATE(created_at)) AS min_date,
    MAX(DATE(created_at)) AS max_date,
    DATEDIFF(MAX(DATE(created_at)), MIN(DATE(created_at))) + 1 AS date_span_days,
    COUNT(*) AS row_count
FROM characters

UNION ALL

SELECT
    'daily_activity.activity_date' AS date_source,
    MIN(activity_date) AS min_date,
    MAX(activity_date) AS max_date,
    DATEDIFF(MAX(activity_date), MIN(activity_date)) + 1 AS date_span_days,
    COUNT(*) AS row_count
FROM daily_activity

UNION ALL

SELECT
    'content_attempts.attempt_started_at' AS date_source,
    MIN(DATE(attempt_started_at)) AS min_date,
    MAX(DATE(attempt_started_at)) AS max_date,
    DATEDIFF(MAX(DATE(attempt_started_at)), MIN(DATE(attempt_started_at))) + 1 AS date_span_days,
    COUNT(*) AS row_count
FROM content_attempts

UNION ALL

SELECT
    'boss_pattern_logs.pattern_started_at' AS date_source,
    MIN(DATE(pattern_started_at)) AS min_date,
    MAX(DATE(pattern_started_at)) AS max_date,
    DATEDIFF(MAX(DATE(pattern_started_at)), MIN(DATE(pattern_started_at))) + 1 AS date_span_days,
    COUNT(*) AS row_count
FROM boss_pattern_logs

UNION ALL

SELECT
    'reward_logs.rewarded_at' AS date_source,
    MIN(DATE(rewarded_at)) AS min_date,
    MAX(DATE(rewarded_at)) AS max_date,
    DATEDIFF(MAX(DATE(rewarded_at)), MIN(DATE(rewarded_at))) + 1 AS date_span_days,
    COUNT(*) AS row_count
FROM reward_logs

UNION ALL

SELECT
    'enhancement_logs.enhanced_at' AS date_source,
    MIN(DATE(enhanced_at)) AS min_date,
    MAX(DATE(enhanced_at)) AS max_date,
    DATEDIFF(MAX(DATE(enhanced_at)), MIN(DATE(enhanced_at))) + 1 AS date_span_days,
    COUNT(*) AS row_count
FROM enhancement_logs

UNION ALL

SELECT
    'payments.paid_at' AS date_source,
    MIN(DATE(paid_at)) AS min_date,
    MAX(DATE(paid_at)) AS max_date,
    DATEDIFF(MAX(DATE(paid_at)), MIN(DATE(paid_at))) + 1 AS date_span_days,
    COUNT(*) AS row_count
FROM payments;
-- =========================================================================================
-- 3. 유저 수 및 캐릭터 수 기본 현황
-- =========================================================================================
SELECT
    COUNT(DISTINCT a.account_id) AS total_account_count,

    COUNT(DISTINCT CASE
        WHEN a.account_status = 'active'
        THEN a.account_id
    END) AS active_account_count,

    COUNT(DISTINCT CASE
        WHEN a.account_status <> 'active'
        THEN a.account_id
    END) AS non_active_account_count,

    COUNT(DISTINCT CASE
        WHEN a.is_tester = 1
        THEN a.account_id
    END) AS tester_account_count,

    COUNT(DISTINCT CASE
        WHEN a.is_tester = 0
        THEN a.account_id
    END) AS normal_account_count,

    COUNT(DISTINCT c.character_id) AS total_character_count,

    COUNT(DISTINCT CASE
        WHEN c.is_deleted = 0
        THEN c.character_id
    END) AS active_character_count,

    COUNT(DISTINCT CASE
        WHEN c.is_deleted = 1
        THEN c.character_id
    END) AS deleted_character_count,

    ROUND(
        COUNT(DISTINCT c.character_id) / NULLIF(COUNT(DISTINCT a.account_id), 0),
        2
    ) AS avg_character_count_per_account,

    ROUND(AVG(CASE
        WHEN c.is_deleted = 0
        THEN c.level
    END), 2) AS avg_active_character_level,

    ROUND(AVG(CASE
        WHEN c.is_deleted = 0
        THEN c.combat_power
    END), 2) AS avg_active_character_combat_power,

    ROUND(AVG(CASE
        WHEN c.is_deleted = 0
        THEN c.gear_score
    END), 2) AS avg_active_character_gear_score
FROM accounts a
LEFT JOIN characters c
    ON a.account_id = c.account_id;
-- =========================================================================================
-- 4. 일자별 활동 규모 확인
-- =========================================================================================
SELECT
    activity_date,

    COUNT(DISTINCT account_id) AS dau,
    COUNT(DISTINCT character_id) AS active_character_count,

    SUM(login_count) AS total_login_count,
    SUM(session_count) AS total_session_count,

    SUM(play_minutes) AS total_play_minutes,
    ROUND(
        SUM(play_minutes) / NULLIF(COUNT(DISTINCT account_id), 0),
        2
    ) AS avg_play_minutes_per_account,

    SUM(combat_minutes) AS total_combat_minutes,
    SUM(non_combat_minutes) AS total_non_combat_minutes,

    SUM(content_attempt_count) AS total_content_attempt_count,
    SUM(boss_attempt_count) AS total_boss_attempt_count,
    SUM(enhancement_attempt_count) AS total_enhancement_attempt_count,
    SUM(payment_count) AS total_payment_count,

    SUM(earned_gold) AS total_earned_gold,
    SUM(spent_gold) AS total_spent_gold
FROM daily_activity
GROUP BY activity_date
ORDER BY activity_date;
-- =========================================================================================
-- 5. 콘텐츠 시도 수 및 클리어/실패 일별 분포
-- =========================================================================================
SELECT
    DATE(attempt_started_at) AS attempt_date,
    result AS attempt_result,

    COUNT(*) AS attempt_count,
    COUNT(DISTINCT account_id) AS participant_account_count,
    COUNT(DISTINCT character_id) AS participant_character_count,

    ROUND(AVG(clear_time_sec), 2) AS avg_clear_time_sec,
    ROUND(AVG(death_count), 2) AS avg_death_count,
    ROUND(AVG(revive_count), 2) AS avg_revive_count,
    ROUND(AVG(potion_used_count), 2) AS avg_potion_used_count
FROM content_attempts
GROUP BY
    DATE(attempt_started_at),
    result
ORDER BY
    attempt_date,
    attempt_result;
    
SELECT
    COUNT(DISTINCT DATE(attempt_started_at)) AS date_count,

    MIN(DATE(attempt_started_at)) AS min_attempt_date,
    MAX(DATE(attempt_started_at)) AS max_attempt_date,

    COUNT(*) AS total_attempt_count,

    SUM(CASE WHEN result = 'clear' THEN 1 ELSE 0 END) AS clear_attempt_count,
    SUM(CASE WHEN result = 'fail' THEN 1 ELSE 0 END) AS fail_attempt_count,

    ROUND(
        SUM(CASE WHEN result = 'clear' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS clear_rate_pct,

    ROUND(
        SUM(CASE WHEN result = 'fail' THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS fail_rate_pct,

    COUNT(DISTINCT account_id) AS participant_account_count,
    COUNT(DISTINCT character_id) AS participant_character_count,

    ROUND(AVG(CASE WHEN result = 'clear' THEN clear_time_sec END), 2) AS avg_clear_time_sec,
    ROUND(AVG(death_count), 2) AS avg_death_count,
    ROUND(AVG(revive_count), 2) AS avg_revive_count,
    ROUND(AVG(potion_used_count), 2) AS avg_potion_used_count
FROM content_attempts;

SELECT
    result AS attempt_result,
    COUNT(*) AS attempt_count,
    ROUND(COUNT(*) / (SELECT COUNT(*) FROM content_attempts) * 100, 2) AS attempt_rate_pct
FROM content_attempts
GROUP BY result
ORDER BY attempt_count DESC;
