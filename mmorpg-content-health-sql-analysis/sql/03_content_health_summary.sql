-- =========================================================================================
-- 6. 콘텐츠별 기본 건강도 지표
-- =========================================================================================
SELECT
    cm.content_id,
    cm.content_name,
    cm.content_type,
    cm.difficulty,

    cm.required_level,
    cm.recommended_combat_power,
    cm.min_party_size,
    cm.max_party_size,
    cm.expected_clear_time_sec,

    COUNT(*) AS total_attempt_count,
    COUNT(DISTINCT ca.account_id) AS participant_account_count,
    COUNT(DISTINCT ca.character_id) AS participant_character_count,

    SUM(CASE WHEN ca.result = 'clear' THEN 1 ELSE 0 END) AS clear_attempt_count,
    SUM(CASE WHEN ca.result = 'fail' THEN 1 ELSE 0 END) AS fail_attempt_count,
    SUM(CASE WHEN ca.result = 'give_up' THEN 1 ELSE 0 END) AS give_up_attempt_count,
    SUM(CASE WHEN ca.result = 'disconnect' THEN 1 ELSE 0 END) AS disconnect_attempt_count,

    ROUND(
        SUM(CASE WHEN ca.result = 'clear' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS clear_rate_pct,

    ROUND(
        SUM(CASE WHEN ca.result = 'fail' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS fail_rate_pct,

    ROUND(
        SUM(CASE WHEN ca.result = 'give_up' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS give_up_rate_pct,

    ROUND(
        SUM(CASE WHEN ca.result = 'disconnect' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS disconnect_rate_pct,

    ROUND(AVG(CASE WHEN ca.result = 'clear' THEN ca.clear_time_sec END), 2) AS avg_clear_time_sec,
    ROUND(AVG(ca.death_count), 2) AS avg_death_count,
    ROUND(AVG(ca.revive_count), 2) AS avg_revive_count,
    ROUND(AVG(ca.potion_used_count), 2) AS avg_potion_used_count,
    ROUND(AVG(ca.party_member_count), 2) AS avg_party_member_count,

    SUM(CASE WHEN ca.reward_claimed = 1 THEN 1 ELSE 0 END) AS reward_claimed_count,

    ROUND(
        SUM(CASE WHEN ca.reward_claimed = 1 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0) * 100,
        2
    ) AS reward_claimed_rate_pct
FROM content_attempts ca
JOIN content_master cm
    ON ca.content_id = cm.content_id
GROUP BY
    cm.content_id,
    cm.content_name,
    cm.content_type,
    cm.difficulty,
    cm.required_level,
    cm.recommended_combat_power,
    cm.min_party_size,
    cm.max_party_size,
    cm.expected_clear_time_sec
ORDER BY
    total_attempt_count DESC;

SELECT
    COUNT(*) AS content_count,

    SUM(content_health.total_attempt_count) AS total_attempt_count,
    ROUND(AVG(content_health.total_attempt_count), 2) AS avg_attempt_count_per_content,
    MIN(content_health.total_attempt_count) AS min_attempt_count,
    MAX(content_health.total_attempt_count) AS max_attempt_count,

    ROUND(AVG(content_health.participant_account_count), 2) AS avg_participant_account_count,
    ROUND(AVG(content_health.participant_character_count), 2) AS avg_participant_character_count,

    ROUND(AVG(content_health.clear_rate_pct), 2) AS avg_clear_rate_pct,
    MIN(content_health.clear_rate_pct) AS min_clear_rate_pct,
    MAX(content_health.clear_rate_pct) AS max_clear_rate_pct,

    ROUND(AVG(content_health.fail_rate_pct), 2) AS avg_fail_rate_pct,
    MAX(content_health.fail_rate_pct) AS max_fail_rate_pct,

    ROUND(AVG(content_health.give_up_rate_pct), 2) AS avg_give_up_rate_pct,
    MAX(content_health.give_up_rate_pct) AS max_give_up_rate_pct,

    ROUND(AVG(content_health.disconnect_rate_pct), 2) AS avg_disconnect_rate_pct,
    MAX(content_health.disconnect_rate_pct) AS max_disconnect_rate_pct,

    ROUND(AVG(content_health.avg_clear_time_sec), 2) AS avg_clear_time_sec,
    ROUND(AVG(content_health.avg_death_count), 2) AS avg_death_count,
    ROUND(AVG(content_health.avg_revive_count), 2) AS avg_revive_count,
    ROUND(AVG(content_health.avg_potion_used_count), 2) AS avg_potion_used_count,

    ROUND(AVG(content_health.reward_claimed_rate_pct), 2) AS avg_reward_claimed_rate_pct
FROM (
    SELECT
        cm.content_id,
        cm.content_name,
        cm.content_type,
        cm.difficulty,

        COUNT(*) AS total_attempt_count,
        COUNT(DISTINCT ca.account_id) AS participant_account_count,
        COUNT(DISTINCT ca.character_id) AS participant_character_count,

        ROUND(
            SUM(CASE WHEN ca.result = 'clear' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS clear_rate_pct,

        ROUND(
            SUM(CASE WHEN ca.result = 'fail' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS fail_rate_pct,

        ROUND(
            SUM(CASE WHEN ca.result = 'give_up' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS give_up_rate_pct,

        ROUND(
            SUM(CASE WHEN ca.result = 'disconnect' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS disconnect_rate_pct,

        ROUND(AVG(CASE WHEN ca.result = 'clear' THEN ca.clear_time_sec END), 2) AS avg_clear_time_sec,
        ROUND(AVG(ca.death_count), 2) AS avg_death_count,
        ROUND(AVG(ca.revive_count), 2) AS avg_revive_count,
        ROUND(AVG(ca.potion_used_count), 2) AS avg_potion_used_count,

        ROUND(
            SUM(CASE WHEN ca.reward_claimed = 1 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS reward_claimed_rate_pct
    FROM content_attempts ca
    JOIN content_master cm
        ON ca.content_id = cm.content_id
    GROUP BY
        cm.content_id,
        cm.content_name,
        cm.content_type,
        cm.difficulty
) AS content_health;

SELECT
    content_health.content_id,
    content_health.content_name,
    content_health.content_type,
    content_health.difficulty,

    content_health.total_attempt_count,
    content_health.participant_account_count,

    content_health.clear_rate_pct,
    content_health.fail_rate_pct,
    content_health.give_up_rate_pct,
    content_health.disconnect_rate_pct,

    content_health.avg_clear_time_sec,
    content_health.avg_death_count,
    content_health.avg_potion_used_count,
    content_health.reward_claimed_rate_pct
FROM (
    SELECT
        cm.content_id,
        cm.content_name,
        cm.content_type,
        cm.difficulty,

        COUNT(*) AS total_attempt_count,
        COUNT(DISTINCT ca.account_id) AS participant_account_count,

        ROUND(
            SUM(CASE WHEN ca.result = 'clear' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS clear_rate_pct,

        ROUND(
            SUM(CASE WHEN ca.result = 'fail' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS fail_rate_pct,

        ROUND(
            SUM(CASE WHEN ca.result = 'give_up' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS give_up_rate_pct,

        ROUND(
            SUM(CASE WHEN ca.result = 'disconnect' THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS disconnect_rate_pct,

        ROUND(AVG(CASE WHEN ca.result = 'clear' THEN ca.clear_time_sec END), 2) AS avg_clear_time_sec,
        ROUND(AVG(ca.death_count), 2) AS avg_death_count,
        ROUND(AVG(ca.potion_used_count), 2) AS avg_potion_used_count,

        ROUND(
            SUM(CASE WHEN ca.reward_claimed = 1 THEN 1 ELSE 0 END)
            / NULLIF(COUNT(*), 0) * 100,
            2
        ) AS reward_claimed_rate_pct
    FROM content_attempts ca
    JOIN content_master cm
        ON ca.content_id = cm.content_id
    GROUP BY
        cm.content_id,
        cm.content_name,
        cm.content_type,
        cm.difficulty
) AS content_health
ORDER BY
    content_health.clear_rate_pct ASC,
    content_health.fail_rate_pct DESC,
    content_health.give_up_rate_pct DESC
LIMIT 10;