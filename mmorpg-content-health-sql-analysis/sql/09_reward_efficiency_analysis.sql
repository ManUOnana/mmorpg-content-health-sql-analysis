-- ============================================================
-- 09_reward_efficiency_analysis.sql
--
-- 분석 단계:
-- 보상 효율 분석
--
-- 분석 목적:
-- - Fallen King Mythic의 결과별 보상 효율을 확인한다.
-- - Mythic 난이도 콘텐츠 간 보상 효율을 비교한다.
-- - Fallen King 라인의 난이도별 보상 효율을 비교한다.
-- - 시도당 평균 보상 가치, 클리어 기준 분당 보상 가치, 전체 시도 기준 분당 보상 가치를 통해
--   콘텐츠 반복 참여 유인이 충분한지 점검한다.
--
-- 주요 지표:
-- - 시도 수
-- - 참여 캐릭터 수
-- - 클리어율
-- - 실패율
-- - 클리어 시 평균 보상 가치
-- - 시도당 평균 보상 가치
-- - 클리어 기준 분당 보상 가치
-- - 전체 시도 기준 분당 보상 가치
-- ============================================================

WITH attempt_base AS (
    SELECT
        ca.attempt_id,
        ca.account_id,
        ca.character_id,
        ca.content_id,
        ca.result,
        ca.reward_claimed,
        ca.death_count,
        ca.party_member_count,
        ca.attempt_started_at,
        ca.attempt_ended_at,
        COALESCE(
            ca.clear_time_sec,
            TIMESTAMPDIFF(SECOND, ca.attempt_started_at, ca.attempt_ended_at)
        ) AS duration_sec,
        c.combat_power,
        cm.content_name,
        cm.content_type,
        cm.difficulty,
        cm.recommended_combat_power
    FROM content_attempts ca
    JOIN characters c
        ON ca.character_id = c.character_id
    JOIN content_master cm
        ON ca.content_id = cm.content_id
    WHERE ca.content_id = 32
),
attempt_rewards AS (
    SELECT
        attempt_id,
        COUNT(*) AS reward_row_count,
        SUM(quantity) AS total_reward_quantity,
        SUM(estimated_gold_value) AS total_reward_value
    FROM reward_logs
    WHERE content_id = 32
    GROUP BY attempt_id
)
SELECT
    ab.result AS `결과`,
    COUNT(*) AS `시도 수`,
    COUNT(DISTINCT ab.character_id) AS `참여 캐릭터 수`,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS `결과 비중(%)`,
    ROUND(AVG(ab.death_count), 2) AS `평균 사망 수`,
    ROUND(AVG(ab.duration_sec), 2) AS `평균 진행 시간(초)`,
    SUM(ab.reward_claimed = 1) AS `보상 수령 시도 수`,
    ROUND(AVG(COALESCE(ar.total_reward_quantity, 0)), 2) AS `시도당 평균 보상 수량`,
    ROUND(AVG(COALESCE(ar.total_reward_value, 0)), 2) AS `시도당 평균 보상 가치`,
    ROUND(AVG(CASE WHEN ar.total_reward_value IS NOT NULL THEN ar.total_reward_value END), 2) AS `보상 지급 시 평균 보상 가치`,
    ROUND(
        AVG(COALESCE(ar.total_reward_value, 0) / NULLIF(ab.duration_sec, 0) * 60),
        2
    ) AS `분당 평균 보상 가치`
FROM attempt_base ab
LEFT JOIN attempt_rewards ar
    ON ab.attempt_id = ar.attempt_id
GROUP BY ab.result
ORDER BY `시도 수` DESC;

-- ========================================================================================================================================

WITH attempt_rewards AS (
    SELECT
        attempt_id,
        SUM(estimated_gold_value) AS total_reward_value,
        SUM(quantity) AS total_reward_quantity
    FROM reward_logs
    GROUP BY attempt_id
),
attempt_base AS (
    SELECT
        ca.attempt_id,
        ca.character_id,
        ca.content_id,
        ca.result,
        ca.clear_time_sec,
        ca.death_count,
        ca.party_member_count,
        COALESCE(
            ca.clear_time_sec,
            TIMESTAMPDIFF(SECOND, ca.attempt_started_at, ca.attempt_ended_at)
        ) AS duration_sec,
        COALESCE(ar.total_reward_value, 0) AS total_reward_value,
        COALESCE(ar.total_reward_quantity, 0) AS total_reward_quantity
    FROM content_attempts ca
    LEFT JOIN attempt_rewards ar
        ON ca.attempt_id = ar.attempt_id
),
mythic_contents AS (
    SELECT
        cm.content_id,
        cm.content_name,
        cm.content_type,
        cm.difficulty,
        cm.recommended_combat_power,
        cm.expected_clear_time_sec
    FROM content_master cm
    WHERE cm.difficulty = 'mythic'
)
SELECT
    mc.content_id AS `content_id`,
    mc.content_name AS `콘텐츠명`,
    mc.content_type AS `콘텐츠 유형`,
    mc.difficulty AS `난이도`,
    COUNT(ab.attempt_id) AS `시도 수`,
    COUNT(DISTINCT ab.character_id) AS `참여 캐릭터 수`,

    ROUND(SUM(ab.result = 'clear') * 100.0 / COUNT(*), 2) AS `클리어율(%)`,
    ROUND(SUM(ab.result = 'fail') * 100.0 / COUNT(*), 2) AS `실패율(%)`,
    ROUND(SUM(ab.result = 'give_up') * 100.0 / COUNT(*), 2) AS `포기율(%)`,
    ROUND(SUM(ab.result = 'disconnect') * 100.0 / COUNT(*), 2) AS `접속 종료율(%)`,

    ROUND(AVG(CASE WHEN ab.result = 'clear' THEN ab.clear_time_sec END), 2) AS `클리어 성공 시 평균 시간(초)`,
    ROUND(AVG(ab.duration_sec), 2) AS `전체 시도 평균 진행 시간(초)`,

    ROUND(AVG(CASE WHEN ab.result = 'clear' THEN ab.total_reward_value END), 2) AS `클리어 시 평균 보상 가치`,
    ROUND(AVG(ab.total_reward_value), 2) AS `시도당 평균 보상 가치`,

    ROUND(
        AVG(CASE 
            WHEN ab.result = 'clear' 
            THEN ab.total_reward_value / NULLIF(ab.clear_time_sec, 0) * 60 
        END),
        2
    ) AS `클리어 기준 분당 보상 가치`,

    ROUND(
        AVG(ab.total_reward_value / NULLIF(ab.duration_sec, 0) * 60),
        2
    ) AS `전체 시도 기준 분당 보상 가치`

FROM mythic_contents mc
JOIN attempt_base ab
    ON mc.content_id = ab.content_id
GROUP BY
    mc.content_id,
    mc.content_name,
    mc.content_type,
    mc.difficulty,
    mc.recommended_combat_power,
    mc.expected_clear_time_sec
ORDER BY
    `전체 시도 기준 분당 보상 가치` DESC;
    
-- ================================================================================================================

WITH attempt_rewards AS (
    SELECT
        attempt_id,
        SUM(estimated_gold_value) AS total_reward_value
    FROM reward_logs
    GROUP BY attempt_id
),
attempt_base AS (
    SELECT
        ca.attempt_id,
        ca.character_id,
        ca.content_id,
        ca.result,
        ca.clear_time_sec,
        COALESCE(ar.total_reward_value, 0) AS total_reward_value
    FROM content_attempts ca
    LEFT JOIN attempt_rewards ar
        ON ca.attempt_id = ar.attempt_id
    WHERE ca.content_id IN (29, 30, 31, 32)
)
SELECT
    cm.content_id AS `content_id`,
    cm.content_name AS `콘텐츠명`,
    cm.difficulty AS `난이도`,
    cm.recommended_combat_power AS `권장 전투력`,
    cm.expected_clear_time_sec AS `예상 클리어 시간(초)`,
    COUNT(ab.attempt_id) AS `시도 수`,
    COUNT(DISTINCT ab.character_id) AS `참여 캐릭터 수`,

    ROUND(SUM(ab.result = 'clear') * 100.0 / COUNT(*), 2) AS `클리어율(%)`,
    ROUND(SUM(ab.result = 'fail') * 100.0 / COUNT(*), 2) AS `실패율(%)`,
    ROUND(SUM(ab.result = 'give_up') * 100.0 / COUNT(*), 2) AS `포기율(%)`,

    ROUND(AVG(CASE WHEN ab.result = 'clear' THEN ab.clear_time_sec END), 2) AS `클리어 성공 시 평균 시간(초)`,
    ROUND(AVG(CASE WHEN ab.result = 'clear' THEN ab.total_reward_value END), 2) AS `클리어 시 평균 보상 가치`,

    ROUND(
        AVG(CASE
            WHEN ab.result = 'clear'
            THEN ab.total_reward_value / NULLIF(ab.clear_time_sec, 0) * 60
        END),
        2
    ) AS `클리어 기준 분당 보상 가치`,

    ROUND(
        AVG(ab.total_reward_value),
        2
    ) AS `전체 시도 기준 평균 보상 가치`

FROM content_master cm
JOIN attempt_base ab
    ON cm.content_id = ab.content_id
WHERE cm.content_id IN (29, 30, 31, 32)
GROUP BY
    cm.content_id,
    cm.content_name,
    cm.difficulty,
    cm.recommended_combat_power,
    cm.expected_clear_time_sec
ORDER BY
    CASE cm.difficulty
        WHEN 'easy' THEN 1
        WHEN 'normal' THEN 2
        WHEN 'hard' THEN 3
        WHEN 'mythic' THEN 4
    END;