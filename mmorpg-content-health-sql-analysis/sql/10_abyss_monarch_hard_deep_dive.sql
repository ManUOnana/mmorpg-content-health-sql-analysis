-- ============================================================
-- 10_abyss_monarch_hard_deep_dive.sql
--
-- 분석 단계:
-- Abyss Monarch Hard 심층 원인 분석
--
-- 분석 목적:
-- - 개선 후보로 선정한 Abyss Monarch Hard(content_id = 23)를 심층 분석한다.
-- - 출시 후 경과 일수를 확인해 단순 적응 기간 이슈인지 판단한다.
-- - 전투력 구간별 클리어율, 실패율, 사망 수, 클리어 시간을 분석한다.
-- - 보스 패턴별 피격률, 사망 유발 비중, 피격 여부에 따른 실패율 차이를 확인한다.
-- - 특정 패턴 P999가 실패율에 미치는 영향을 점검한다.
--
-- 주요 기준:
-- - 전투력 분석은 characters.combat_power 기준으로 수행한다.
-- - avg_party_combat_power는 사용하지 않는다.
-- ============================================================

WITH latest_goal AS (
    SELECT cdg.*
    FROM content_design_goals cdg
    JOIN (
        SELECT
            content_id,
            difficulty,
            MAX(valid_from) AS max_valid_from
        FROM content_design_goals
        GROUP BY content_id, difficulty
    ) x
        ON cdg.content_id = x.content_id
        AND cdg.difficulty = x.difficulty
        AND cdg.valid_from = x.max_valid_from
)
SELECT
    cm.content_id AS `content_id`,
    cm.content_name AS `콘텐츠명`,
    cm.content_type AS `콘텐츠 유형`,
    cm.difficulty AS `난이도`,
    cm.release_date AS `출시일`,

    MIN(DATE(ca.attempt_started_at)) AS `첫 시도일`,
    MAX(DATE(ca.attempt_started_at)) AS `분석 기준일`,
    DATEDIFF(MAX(DATE(ca.attempt_started_at)), cm.release_date) AS `출시 후 경과 일수`,

    COUNT(*) AS `총 시도 수`,
    COUNT(DISTINCT ca.character_id) AS `참여 캐릭터 수`,

    lg.target_clear_rate AS `목표 클리어율(%)`,
    ROUND(SUM(ca.result = 'clear') * 100.0 / COUNT(*), 2) AS `실제 클리어율(%)`,
    ROUND(
        SUM(ca.result = 'clear') * 100.0 / COUNT(*) - lg.target_clear_rate,
        2
    ) AS `목표 대비 클리어율 차이(%p)`,

    CASE
        WHEN DATEDIFF(MAX(DATE(ca.attempt_started_at)), cm.release_date) < 30
            THEN '출시 초기: 개선 확정보다 관찰 우선'
        WHEN DATEDIFF(MAX(DATE(ca.attempt_started_at)), cm.release_date) BETWEEN 30 AND 89
            THEN '초기 적응 구간: 관찰과 부분 개선 검토'
        ELSE '충분한 기간 경과: 개선 후보로 판단 가능'
    END AS `운영 판단 기준`
FROM content_master cm
JOIN content_attempts ca
    ON cm.content_id = ca.content_id
LEFT JOIN latest_goal lg
    ON cm.content_id = lg.content_id
    AND cm.difficulty = lg.difficulty
WHERE cm.content_id = 23
GROUP BY
    cm.content_id,
    cm.content_name,
    cm.content_type,
    cm.difficulty,
    cm.release_date,
    lg.target_clear_rate;
    
    -- ===================================================================================================================
    
WITH latest_goal AS (
    SELECT cdg.*
    FROM content_design_goals cdg
    JOIN (
        SELECT
            content_id,
            difficulty,
            MAX(valid_from) AS max_valid_from
        FROM content_design_goals
        GROUP BY content_id, difficulty
    ) x
        ON cdg.content_id = x.content_id
        AND cdg.difficulty = x.difficulty
        AND cdg.valid_from = x.max_valid_from
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
        c.combat_power,
        cm.recommended_combat_power,
        cm.expected_clear_time_sec,
        lg.target_clear_rate,
        lg.target_avg_clear_time_sec,
        lg.target_death_count_avg,
        CASE
            WHEN c.combat_power < cm.recommended_combat_power * 0.8
                THEN '01_80% 미만'
            WHEN c.combat_power < cm.recommended_combat_power
                THEN '02_80% 이상~100% 미만'
            WHEN c.combat_power < cm.recommended_combat_power * 1.1
                THEN '03_100% 이상~110% 미만'
            WHEN c.combat_power < cm.recommended_combat_power * 1.2
                THEN '04_110% 이상~120% 미만'
            ELSE '05_120% 이상'
        END AS combat_power_band
    FROM content_attempts ca
    JOIN characters c
        ON ca.character_id = c.character_id
    JOIN content_master cm
        ON ca.content_id = cm.content_id
    LEFT JOIN latest_goal lg
        ON cm.content_id = lg.content_id
        AND cm.difficulty = lg.difficulty
    WHERE ca.content_id = 23
)
SELECT
    combat_power_band AS `전투력 구간`,
    COUNT(*) AS `시도 수`,
    COUNT(DISTINCT character_id) AS `참여 캐릭터 수`,

    ROUND(AVG(combat_power), 0) AS `평균 캐릭터 전투력`,
    ROUND(AVG(combat_power / recommended_combat_power * 100), 2) AS `권장 전투력 대비 평균 비율(%)`,

    target_clear_rate AS `목표 클리어율(%)`,
    ROUND(SUM(result = 'clear') * 100.0 / COUNT(*), 2) AS `클리어율(%)`,
    ROUND(SUM(result = 'fail') * 100.0 / COUNT(*), 2) AS `실패율(%)`,
    ROUND(SUM(result = 'give_up') * 100.0 / COUNT(*), 2) AS `포기율(%)`,
    ROUND(SUM(result = 'disconnect') * 100.0 / COUNT(*), 2) AS `접속 종료율(%)`,

    ROUND(
        SUM(result = 'clear') * 100.0 / COUNT(*) - target_clear_rate,
        2
    ) AS `목표 대비 클리어율 차이(%p)`,

    ROUND(AVG(death_count), 2) AS `평균 사망 수`,
    target_death_count_avg AS `목표 평균 사망 수`,
    ROUND(AVG(death_count) - target_death_count_avg, 2) AS `목표 대비 사망 수 차이`,

    ROUND(AVG(CASE WHEN result = 'clear' THEN clear_time_sec END), 2) AS `클리어 성공 시 평균 클리어 시간(초)`,
    target_avg_clear_time_sec AS `목표 평균 클리어 시간(초)`,
    ROUND(
        AVG(CASE WHEN result = 'clear' THEN clear_time_sec END) - target_avg_clear_time_sec,
        2
    ) AS `목표 대비 클리어 시간 차이(초)`

FROM attempt_base
GROUP BY
    combat_power_band,
    target_clear_rate,
    target_avg_clear_time_sec,
    target_death_count_avg
ORDER BY combat_power_band;

-- =================================================================================================================

WITH attempt_base AS (
    SELECT
        ca.attempt_id,
        ca.character_id,
        ca.result
    FROM content_attempts ca
    WHERE ca.content_id = 23
),
pattern_attempt AS (
    SELECT
        bpl.attempt_id,
        bpl.pattern_code,
        bpl.pattern_name,
        bpl.phase_no,

        MAX(bpl.was_hit) AS was_hit_in_attempt,
        MAX(bpl.is_fatal) AS fatal_in_attempt,

        SUM(bpl.damage_taken) AS total_damage_taken,
        AVG(CASE WHEN bpl.was_hit = 1 THEN bpl.damage_taken END) AS avg_damage_when_hit,

        MAX(ab.result = 'clear') AS is_clear_attempt,
        MAX(ab.result = 'fail') AS is_fail_attempt,
        MAX(ab.result = 'give_up') AS is_give_up_attempt,
        MAX(ab.result = 'disconnect') AS is_disconnect_attempt
    FROM boss_pattern_logs bpl
    JOIN attempt_base ab
        ON bpl.attempt_id = ab.attempt_id
    WHERE bpl.content_id = 23
    GROUP BY
        bpl.attempt_id,
        bpl.pattern_code,
        bpl.pattern_name,
        bpl.phase_no
)
SELECT
    phase_no AS `페이즈`,
    pattern_code AS `패턴 코드`,
    pattern_name AS `패턴명`,

    COUNT(*) AS `패턴 노출 시도 수`,

    SUM(was_hit_in_attempt = 1) AS `피격 시도 수`,
    ROUND(SUM(was_hit_in_attempt = 1) * 100.0 / COUNT(*), 2) AS `피격률(%)`,

    SUM(fatal_in_attempt = 1) AS `사망 유발 시도 수`,
    ROUND(SUM(fatal_in_attempt = 1) * 100.0 / COUNT(*), 2) AS `사망 유발 비중(%)`,

    ROUND(AVG(avg_damage_when_hit), 2) AS `피격 시 평균 피해량`,

    ROUND(SUM(is_fail_attempt = 1) * 100.0 / COUNT(*), 2) AS `패턴 노출 후 실패율(%)`,

    ROUND(
        SUM(CASE WHEN was_hit_in_attempt = 1 THEN is_fail_attempt ELSE 0 END) * 100.0
        / NULLIF(SUM(was_hit_in_attempt = 1), 0),
        2
    ) AS `피격 시 실패율(%)`,

    ROUND(
        SUM(CASE WHEN was_hit_in_attempt = 0 THEN is_fail_attempt ELSE 0 END) * 100.0
        / NULLIF(SUM(was_hit_in_attempt = 0), 0),
        2
    ) AS `회피 시 실패율(%)`,

    ROUND(
        (
            SUM(CASE WHEN was_hit_in_attempt = 1 THEN is_fail_attempt ELSE 0 END) * 100.0
            / NULLIF(SUM(was_hit_in_attempt = 1), 0)
        )
        -
        (
            SUM(CASE WHEN was_hit_in_attempt = 0 THEN is_fail_attempt ELSE 0 END) * 100.0
            / NULLIF(SUM(was_hit_in_attempt = 0), 0)
        ),
        2
    ) AS `피격-회피 실패율 차이(%p)`

FROM pattern_attempt
GROUP BY
    phase_no,
    pattern_code,
    pattern_name
ORDER BY
    `피격-회피 실패율 차이(%p)` DESC,
    `사망 유발 비중(%)` DESC,
    `피격률(%)` DESC;
    
-- =========================================================================================

SELECT
    ca.result AS `시도 결과`,
    COUNT(DISTINCT ca.attempt_id) AS `P999 발생 시도 수`,
    COUNT(*) AS `P999 로그 수`,
    SUM(bpl.was_hit = 1) AS `피격 로그 수`,
    ROUND(SUM(bpl.was_hit = 1) * 100.0 / COUNT(*), 2) AS `피격률(%)`,
    SUM(bpl.is_fatal = 1) AS `사망 유발 로그 수`,
    ROUND(SUM(bpl.is_fatal = 1) * 100.0 / COUNT(*), 2) AS `사망 유발 비중(%)`,
    ROUND(AVG(bpl.damage_taken), 2) AS `평균 피해량`
FROM boss_pattern_logs bpl
JOIN content_attempts ca
    ON bpl.attempt_id = ca.attempt_id
WHERE bpl.content_id = 23
  AND bpl.pattern_code = 'P999'
GROUP BY ca.result
ORDER BY `P999 발생 시도 수` DESC;

-- =========================================================================================

WITH attempt_base AS (
    SELECT
        ca.attempt_id,
        ca.result,
        c.character_id,
        c.combat_power,
        cm.recommended_combat_power,
        CASE
            WHEN c.combat_power < cm.recommended_combat_power * 0.8
                THEN '01_80% 미만'
            WHEN c.combat_power < cm.recommended_combat_power
                THEN '02_80% 이상~100% 미만'
            WHEN c.combat_power < cm.recommended_combat_power * 1.1
                THEN '03_100% 이상~110% 미만'
            WHEN c.combat_power < cm.recommended_combat_power * 1.2
                THEN '04_110% 이상~120% 미만'
            ELSE '05_120% 이상'
        END AS combat_power_band
    FROM content_attempts ca
    JOIN characters c
        ON ca.character_id = c.character_id
    JOIN content_master cm
        ON ca.content_id = cm.content_id
    WHERE ca.content_id = 23
),
p999_attempts AS (
    SELECT DISTINCT
        attempt_id
    FROM boss_pattern_logs
    WHERE content_id = 23
      AND pattern_code = 'P999'
)
SELECT
    ab.combat_power_band AS `전투력 구간`,
    COUNT(*) AS `전체 시도 수`,
    SUM(ab.result = 'fail') AS `실패 시도 수`,
    COUNT(p999.attempt_id) AS `P999 발생 시도 수`,
    ROUND(COUNT(p999.attempt_id) * 100.0 / COUNT(*), 2) AS `전체 시도 대비 P999 발생률(%)`,
    ROUND(COUNT(p999.attempt_id) * 100.0 / NULLIF(SUM(ab.result = 'fail'), 0), 2) AS `실패 시도 대비 P999 비중(%)`,
    ROUND(SUM(ab.result = 'clear') * 100.0 / COUNT(*), 2) AS `클리어율(%)`,
    ROUND(SUM(ab.result = 'fail') * 100.0 / COUNT(*), 2) AS `실패율(%)`
FROM attempt_base ab
LEFT JOIN p999_attempts p999
    ON ab.attempt_id = p999.attempt_id
GROUP BY ab.combat_power_band
ORDER BY ab.combat_power_band;