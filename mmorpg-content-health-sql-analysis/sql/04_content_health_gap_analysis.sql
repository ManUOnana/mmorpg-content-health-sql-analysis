SET @start_date = '2026-05-01';
SET @end_date   = '2026-05-31';

WITH active_characters AS (
    SELECT DISTINCT
        da.character_id,
        da.account_id,
        c.level,
        c.combat_power
    FROM daily_activity da
    INNER JOIN characters c
        ON da.character_id = c.character_id
    WHERE da.activity_date BETWEEN @start_date AND @end_date
      AND c.is_deleted = 0
),

eligible_by_content AS (
    SELECT
        cm.content_id,
        COUNT(DISTINCT ac.character_id) AS eligible_character_count,
        COUNT(DISTINCT CASE 
            WHEN ac.combat_power >= cm.recommended_combat_power 
            THEN ac.character_id 
        END) AS recommended_ready_character_count
    FROM content_master cm
    LEFT JOIN active_characters ac
        ON ac.level >= cm.required_level
    WHERE cm.is_active = 1
    GROUP BY cm.content_id
),

attempt_by_character AS (
    SELECT
        ca.content_id,
        ca.character_id,
        COUNT(*) AS attempt_count
    FROM content_attempts ca
    WHERE DATE(ca.attempt_started_at) BETWEEN @start_date AND @end_date
    GROUP BY ca.content_id, ca.character_id
),

attempt_summary AS (
    SELECT
        ca.content_id,
        COUNT(*) AS total_attempt_count,
        COUNT(DISTINCT ca.character_id) AS participant_character_count,

        SUM(CASE WHEN ca.result = 'clear' THEN 1 ELSE 0 END) AS clear_count,
        SUM(CASE WHEN ca.result = 'fail' THEN 1 ELSE 0 END) AS fail_count,

        AVG(CASE WHEN ca.result = 'clear' THEN ca.clear_time_sec END) AS avg_clear_time_sec,
        AVG(ca.death_count) AS avg_death_count,
        AVG(ca.revive_count) AS avg_revive_count,
        AVG(ca.potion_used_count) AS avg_potion_used_count,
        AVG(ca.party_member_count) AS avg_party_member_count,

        SUM(CASE WHEN ca.reward_claimed = 1 THEN 1 ELSE 0 END) AS reward_claimed_count
    FROM content_attempts ca
    WHERE DATE(ca.attempt_started_at) BETWEEN @start_date AND @end_date
    GROUP BY ca.content_id
),

retry_summary AS (
    SELECT
        content_id,
        COUNT(DISTINCT CASE 
            WHEN attempt_count >= 2 THEN character_id 
        END) AS retry_character_count
    FROM attempt_by_character
    GROUP BY content_id
),

reward_summary AS (
    SELECT
        content_id,
        COUNT(*) AS reward_log_count,
        AVG(estimated_gold_value) AS avg_reward_value,
        SUM(estimated_gold_value) AS total_reward_value
    FROM reward_logs
    WHERE DATE(rewarded_at) BETWEEN @start_date AND @end_date
    GROUP BY content_id
)

SELECT
    cm.content_id,
    cm.content_name,
    cm.content_type,
    cm.difficulty,
    cm.required_level,
    cm.recommended_combat_power,

    COALESCE(ebc.eligible_character_count, 0) AS eligible_character_count,
    COALESCE(ebc.recommended_ready_character_count, 0) AS recommended_ready_character_count,

    COALESCE(ast.total_attempt_count, 0) AS total_attempt_count,
    COALESCE(ast.participant_character_count, 0) AS participant_character_count,

    ROUND(
        COALESCE(ast.participant_character_count, 0)
        / NULLIF(ebc.eligible_character_count, 0) * 100,
        2
    ) AS participation_rate,

    ROUND(
        COALESCE(ebc.recommended_ready_character_count, 0)
        / NULLIF(ebc.eligible_character_count, 0) * 100,
        2
    ) AS recommended_ready_rate,

    ROUND(
        COALESCE(ast.clear_count, 0)
        / NULLIF(ast.total_attempt_count, 0) * 100,
        2
    ) AS clear_rate,

    ROUND(
        COALESCE(ast.fail_count, 0)
        / NULLIF(ast.total_attempt_count, 0) * 100,
        2
    ) AS fail_rate,

    ROUND(
        COALESCE(rs.retry_character_count, 0)
        / NULLIF(ast.participant_character_count, 0) * 100,
        2
    ) AS retry_rate,

    ROUND(ast.avg_clear_time_sec, 2) AS avg_clear_time_sec,
    ROUND(ast.avg_death_count, 2) AS avg_death_count,
    ROUND(ast.avg_revive_count, 2) AS avg_revive_count,
    ROUND(ast.avg_potion_used_count, 2) AS avg_potion_used_count,
    ROUND(ast.avg_party_member_count, 2) AS avg_party_member_count,

    ROUND(
        COALESCE(ast.reward_claimed_count, 0)
        / NULLIF(ast.clear_count, 0) * 100,
        2
    ) AS reward_claim_rate,

    ROUND(rws.avg_reward_value, 2) AS avg_reward_value,

    dg.target_participation_rate,
    dg.target_clear_rate,
    dg.target_avg_clear_time_sec,
    dg.target_retry_rate,
    dg.target_death_count_avg,
    dg.target_reward_value,

    ROUND(
        (
            COALESCE(ast.participant_character_count, 0)
            / NULLIF(ebc.eligible_character_count, 0) * 100
        ) - dg.target_participation_rate,
        2
    ) AS participation_gap,

    ROUND(
        (
            COALESCE(ast.clear_count, 0)
            / NULLIF(ast.total_attempt_count, 0) * 100
        ) - dg.target_clear_rate,
        2
    ) AS clear_rate_gap,

    ROUND(
        ast.avg_clear_time_sec - dg.target_avg_clear_time_sec,
        2
    ) AS clear_time_gap,

    ROUND(
        ast.avg_death_count - dg.target_death_count_avg,
        2
    ) AS death_count_gap,

    CASE
        WHEN ast.total_attempt_count IS NULL THEN 'NO_DATA'
        WHEN (
            COALESCE(ast.participant_character_count, 0)
            / NULLIF(ebc.eligible_character_count, 0) * 100
        ) < dg.target_participation_rate * 0.7
            THEN 'LOW_PARTICIPATION'
        WHEN (
            COALESCE(ast.clear_count, 0)
            / NULLIF(ast.total_attempt_count, 0) * 100
        ) < dg.target_clear_rate - 15
            THEN 'LOW_CLEAR_RATE'
        WHEN ast.avg_clear_time_sec > dg.target_avg_clear_time_sec * 1.3
            THEN 'LONG_CLEAR_TIME'
        WHEN ast.avg_death_count > dg.target_death_count_avg * 1.5
            THEN 'HIGH_DEATH_COUNT'
        ELSE 'NORMAL'
    END AS health_status

FROM content_master cm
LEFT JOIN eligible_by_content ebc
    ON cm.content_id = ebc.content_id
LEFT JOIN attempt_summary ast
    ON cm.content_id = ast.content_id
LEFT JOIN retry_summary rs
    ON cm.content_id = rs.content_id
LEFT JOIN reward_summary rws
    ON cm.content_id = rws.content_id
LEFT JOIN content_design_goals dg
    ON cm.content_id = dg.content_id
   AND cm.difficulty = dg.difficulty
   AND dg.valid_from <= @end_date
WHERE cm.is_active = 1
ORDER BY
    CASE health_status
        WHEN 'LOW_PARTICIPATION' THEN 1
        WHEN 'LOW_CLEAR_RATE' THEN 2
        WHEN 'LONG_CLEAR_TIME' THEN 3
        WHEN 'HIGH_DEATH_COUNT' THEN 4
        WHEN 'NO_DATA' THEN 5
        ELSE 6
    END,
    participation_gap ASC,
    clear_rate_gap ASC;

-- 특정 콘텐츠의 설계 목표값 매핑 확인
    
SELECT
    cm.content_id,
    cm.content_name,
    cm.difficulty,
    dg.target_participation_rate,
    dg.target_clear_rate,
    dg.target_avg_clear_time_sec,
    dg.target_death_count_avg,
    dg.valid_from,
    dg.valid_to
FROM content_master cm
LEFT JOIN content_design_goals dg
    ON cm.content_id = dg.content_id
   AND cm.difficulty = dg.difficulty
WHERE cm.content_id IN (1, 20, 24, 48);