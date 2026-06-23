```sql
-- ============================================================
-- 07_eligible_user_participation_analysis.sql
--
-- 분석 단계:
-- 도전 가능 캐릭터 기준 참여 규모 분석
--
-- 분석 목적:
-- - 목표 대비 클리어율이 낮은 콘텐츠 6개를 대상으로 도전 가능 규모를 확인한다.
-- - 권장 전투력 이상, 권장 전투력 80% 이상 캐릭터 수 대비 실제 참여율을 계산한다.
-- - 동일 난이도 평균과 비교하여 참여 부족, 반복 도전, 권장 전투력 미달 진입 여부를 판단한다.
--
-- 주의:
-- - 본 쿼리는 character_id 기준으로 집계하므로, 정확한 표현은 '유저 수'보다 '캐릭터 수'이다.
-- ============================================================

WITH 콘텐츠별_도전가능캐릭터 AS (
    SELECT
        cm.content_id,
        cm.content_name,
        cm.content_type,
        cm.difficulty,
        cm.required_level,
        cm.recommended_combat_power,

        COUNT(DISTINCT CASE
            WHEN ch.is_deleted = 0
             AND ch.level >= cm.required_level
             AND ch.combat_power >= cm.recommended_combat_power
            THEN ch.character_id
        END) AS eligible_character_count_100,

        COUNT(DISTINCT CASE
            WHEN ch.is_deleted = 0
             AND ch.level >= cm.required_level
             AND ch.combat_power >= cm.recommended_combat_power * 0.8
            THEN ch.character_id
        END) AS eligible_character_count_80

    FROM content_master cm
    CROSS JOIN characters ch
    WHERE cm.is_active = 1
    GROUP BY
        cm.content_id,
        cm.content_name,
        cm.content_type,
        cm.difficulty,
        cm.required_level,
        cm.recommended_combat_power
),

콘텐츠별_실제도전 AS (
    SELECT
        cm.content_id,

        COUNT(*) AS total_attempt_count,
        COUNT(DISTINCT ca.character_id) AS actual_attempt_character_count,

        COUNT(DISTINCT CASE
            WHEN ch.level >= cm.required_level
             AND ch.combat_power >= cm.recommended_combat_power
            THEN ca.character_id
        END) AS actual_attempt_character_count_100,

        COUNT(DISTINCT CASE
            WHEN ch.level >= cm.required_level
             AND ch.combat_power >= cm.recommended_combat_power * 0.8
            THEN ca.character_id
        END) AS actual_attempt_character_count_80,

        COUNT(DISTINCT CASE
            WHEN ch.level < cm.required_level
              OR ch.combat_power < cm.recommended_combat_power * 0.8
            THEN ca.character_id
        END) AS actual_attempt_character_count_under_80,

        SUM(CASE WHEN ca.result = 'clear' THEN 1 ELSE 0 END) AS clear_count,
        SUM(CASE WHEN ca.result = 'fail' THEN 1 ELSE 0 END) AS fail_count,
        SUM(CASE WHEN ca.result = 'give_up' THEN 1 ELSE 0 END) AS give_up_count,
        SUM(CASE WHEN ca.result = 'disconnect' THEN 1 ELSE 0 END) AS disconnect_count

    FROM content_attempts ca
    JOIN content_master cm
        ON ca.content_id = cm.content_id
    JOIN characters ch
        ON ca.character_id = ch.character_id
    WHERE ch.is_deleted = 0
    GROUP BY
        cm.content_id
),

콘텐츠별_참여지표 AS (
    SELECT
        eu.content_id,
        eu.content_name,
        eu.content_type,
        eu.difficulty,
        eu.required_level,
        eu.recommended_combat_power,

        eu.eligible_character_count_100,
        eu.eligible_character_count_80,

        COALESCE(at.actual_attempt_character_count, 0) AS actual_attempt_character_count,
        COALESCE(at.actual_attempt_character_count_100, 0) AS actual_attempt_character_count_100,
        COALESCE(at.actual_attempt_character_count_80, 0) AS actual_attempt_character_count_80,
        COALESCE(at.actual_attempt_character_count_under_80, 0) AS actual_attempt_character_count_under_80,

        COALESCE(at.total_attempt_count, 0) AS total_attempt_count,
        COALESCE(at.clear_count, 0) AS clear_count,
        COALESCE(at.fail_count, 0) AS fail_count,
        COALESCE(at.give_up_count, 0) AS give_up_count,
        COALESCE(at.disconnect_count, 0) AS disconnect_count,

        COALESCE(at.actual_attempt_character_count_100, 0)
            / NULLIF(eu.eligible_character_count_100, 0) * 100 AS participation_rate_100,

        COALESCE(at.actual_attempt_character_count_80, 0)
            / NULLIF(eu.eligible_character_count_80, 0) * 100 AS participation_rate_80,

        COALESCE(at.actual_attempt_character_count_under_80, 0)
            / NULLIF(at.actual_attempt_character_count, 0) * 100 AS under_80_attempt_character_ratio,

        COALESCE(at.total_attempt_count, 0)
            / NULLIF(at.actual_attempt_character_count, 0) AS avg_attempt_per_character,

        COALESCE(at.clear_count, 0)
            / NULLIF(at.total_attempt_count, 0) * 100 AS clear_rate,

        COALESCE(at.fail_count, 0)
            / NULLIF(at.total_attempt_count, 0) * 100 AS fail_rate,

        COALESCE(at.give_up_count, 0)
            / NULLIF(at.total_attempt_count, 0) * 100 AS give_up_rate,

        COALESCE(at.disconnect_count, 0)
            / NULLIF(at.total_attempt_count, 0) * 100 AS disconnect_rate

    FROM 콘텐츠별_도전가능캐릭터 eu
    LEFT JOIN 콘텐츠별_실제도전 at
        ON eu.content_id = at.content_id
),

난이도별_평균참여지표 AS (
    SELECT
        difficulty,
        AVG(participation_rate_100) AS difficulty_avg_participation_rate_100,
        AVG(participation_rate_80) AS difficulty_avg_participation_rate_80,
        AVG(avg_attempt_per_character) AS difficulty_avg_attempt_per_character,
        AVG(total_attempt_count) AS difficulty_avg_attempt_count
    FROM 콘텐츠별_참여지표
    GROUP BY difficulty
)

SELECT
    cp.content_id AS `콘텐츠 ID`,
    cp.content_name AS `콘텐츠명`,
    cp.content_type AS `콘텐츠 유형`,
    cp.difficulty AS `난이도`,
    cp.required_level AS `요구 레벨`,
    cp.recommended_combat_power AS `권장 전투력`,

    cp.eligible_character_count_100 AS `권장 전투력 이상 캐릭터 수`,
    cp.eligible_character_count_80 AS `권장 전투력 80% 이상 캐릭터 수`,

    cp.actual_attempt_character_count AS `전체 실제 도전 캐릭터 수`,
    cp.actual_attempt_character_count_100 AS `권장 전투력 이상 실제 도전 캐릭터 수`,
    cp.actual_attempt_character_count_80 AS `권장 전투력 80% 이상 실제 도전 캐릭터 수`,
    cp.actual_attempt_character_count_under_80 AS `권장 전투력 80% 미만 실제 도전 캐릭터 수`,

    cp.total_attempt_count AS `전체 시도 수`,

    ROUND(cp.participation_rate_100, 2) AS `권장 이상 캐릭터 대비 실제 참여율(%)`,
    ROUND(cp.participation_rate_80, 2) AS `권장 80% 이상 캐릭터 대비 실제 참여율(%)`,
    ROUND(cp.under_80_attempt_character_ratio, 2) AS `권장 80% 미만 도전 캐릭터 비중(%)`,

    ROUND(da.difficulty_avg_participation_rate_100, 2) AS `동일 난이도 평균 권장 이상 참여율(%)`,
    ROUND(cp.participation_rate_100 - da.difficulty_avg_participation_rate_100, 2)
        AS `동일 난이도 대비 권장 이상 참여율 차이(%p)`,

    ROUND(da.difficulty_avg_participation_rate_80, 2) AS `동일 난이도 평균 권장 80% 이상 참여율(%)`,
    ROUND(cp.participation_rate_80 - da.difficulty_avg_participation_rate_80, 2)
        AS `동일 난이도 대비 권장 80% 이상 참여율 차이(%p)`,

    ROUND(cp.avg_attempt_per_character, 2) AS `도전 캐릭터당 평균 시도 수`,
    ROUND(da.difficulty_avg_attempt_per_character, 2) AS `동일 난이도 평균 도전 캐릭터당 시도 수`,
    ROUND(cp.avg_attempt_per_character - da.difficulty_avg_attempt_per_character, 2)
        AS `동일 난이도 대비 캐릭터당 시도 수 차이`,

    ROUND(da.difficulty_avg_attempt_count, 0) AS `동일 난이도 평균 전체 시도 수`,
    ROUND(cp.total_attempt_count - da.difficulty_avg_attempt_count, 0)
        AS `동일 난이도 대비 전체 시도 수 차이`,

    ROUND(cp.clear_rate, 2) AS `클리어율(%)`,
    ROUND(cp.fail_rate, 2) AS `실패율(%)`,
    ROUND(cp.give_up_rate, 2) AS `포기율(%)`,
    ROUND(cp.disconnect_rate, 2) AS `접속 종료율(%)`,

    CASE
        WHEN cp.participation_rate_80 < da.difficulty_avg_participation_rate_80
             AND cp.avg_attempt_per_character < da.difficulty_avg_attempt_per_character
            THEN '도전 가능 캐릭터 대비 참여 낮고 반복 도전도 낮음'

        WHEN cp.participation_rate_80 < da.difficulty_avg_participation_rate_80
             AND cp.avg_attempt_per_character >= da.difficulty_avg_attempt_per_character
            THEN '도전 가능 캐릭터 대비 참여는 낮지만 참여 캐릭터는 반복 도전'

        WHEN cp.participation_rate_80 >= da.difficulty_avg_participation_rate_80
             AND cp.fail_rate >= 50
            THEN '도전 가능 캐릭터 대비 참여는 있으나 실패 부담 높음'

        WHEN cp.under_80_attempt_character_ratio >= 30
            THEN '권장 전투력 미달 캐릭터 진입 비중 높음'

        WHEN cp.participation_rate_80 >= da.difficulty_avg_participation_rate_80
            THEN '도전 가능 캐릭터 대비 참여 규모 양호'

        ELSE '추가 확인 필요'
    END AS `참여 규모 판단`

FROM 콘텐츠별_참여지표 cp
JOIN 난이도별_평균참여지표 da
    ON cp.difficulty = da.difficulty
WHERE cp.content_id IN (48, 24, 20, 47, 32, 23)
ORDER BY
    `권장 80% 이상 캐릭터 대비 실제 참여율(%)` ASC;