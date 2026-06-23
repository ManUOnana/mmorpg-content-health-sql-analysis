-- ============================================================
-- 08_combat_power_segment_analysis.sql
--
-- 분석 단계:
-- 전투력 구간별 클리어율 / 실패율 분석
--
-- 분석 목적:
-- - 목표 대비 클리어율이 낮은 콘텐츠 6개를 대상으로 전투력 구간별 성과를 분석한다.
-- - characters.combat_power와 content_master.recommended_combat_power를 비교하여 개인 기준 전투력 구간을 분류한다.
-- - 콘텐츠별, 파티 인원별, 전투력 구간별 클리어율과 실패율을 확인한다.
-- - 목표 클리어율에 미달하는 구간을 식별해 난이도 또는 진입 조건 문제를 점검한다.
--
-- 주의:
-- - avg_party_combat_power는 사용하지 않는다.
-- - 개인 전투력 기준 분석이므로 characters.combat_power를 사용한다.
-- ============================================================

WITH 전투력_구간_기초 AS (
    SELECT
        ca.content_id,
        cm.content_name,
        cm.difficulty,
        ca.character_id,
        ca.party_member_count,
        c.combat_power,
        cm.recommended_combat_power,
        cdg.target_clear_rate,
        ca.result,

        CASE
            WHEN c.combat_power / NULLIF(cm.recommended_combat_power, 0) < 0.8
                THEN '권장 전투력 80% 미만'
            WHEN c.combat_power / NULLIF(cm.recommended_combat_power, 0) < 1.0
                THEN '권장 전투력 80~100%'
            WHEN c.combat_power / NULLIF(cm.recommended_combat_power, 0) < 1.1
                THEN '권장 전투력 100~110%'
            WHEN c.combat_power / NULLIF(cm.recommended_combat_power, 0) < 1.2
                THEN '권장 전투력 110~120%'
            ELSE '권장 전투력 120% 이상'
        END AS 전투력_구간,

        CASE
            WHEN c.combat_power / NULLIF(cm.recommended_combat_power, 0) < 0.8 THEN 1
            WHEN c.combat_power / NULLIF(cm.recommended_combat_power, 0) < 1.0 THEN 2
            WHEN c.combat_power / NULLIF(cm.recommended_combat_power, 0) < 1.1 THEN 3
            WHEN c.combat_power / NULLIF(cm.recommended_combat_power, 0) < 1.2 THEN 4
            ELSE 5
        END AS 전투력_구간_정렬순서

    FROM content_attempts ca
    INNER JOIN characters c
        ON ca.character_id = c.character_id
    INNER JOIN content_master cm
        ON ca.content_id = cm.content_id
    INNER JOIN content_design_goals cdg
        ON cm.content_id = cdg.content_id
       AND cm.difficulty = cdg.difficulty
    WHERE ca.content_id IN (48, 24, 20, 47, 32, 23)
),

전투력_구간_집계 AS (
    SELECT
        content_id,
        content_name,
        difficulty,
        CONCAT(party_member_count, '인') AS 파티_인원,
        party_member_count AS 파티_정렬순서,
        전투력_구간,
        전투력_구간_정렬순서,
        recommended_combat_power,
        target_clear_rate,

        COUNT(*) AS 전체_시도수,
        COUNT(DISTINCT character_id) AS 도전_캐릭터수,

        SUM(CASE WHEN result = 'clear' THEN 1 ELSE 0 END) AS 클리어_시도수,
        ROUND(
            SUM(CASE WHEN result = 'clear' THEN 1 ELSE 0 END) / COUNT(*) * 100,
            2
        ) AS 클리어율,

        SUM(CASE WHEN result = 'fail' THEN 1 ELSE 0 END) AS 실패_시도수,
        ROUND(
            SUM(CASE WHEN result = 'fail' THEN 1 ELSE 0 END) / COUNT(*) * 100,
            2
        ) AS 실패율

    FROM 전투력_구간_기초
    GROUP BY
        content_id,
        content_name,
        difficulty,
        party_member_count,
        전투력_구간,
        전투력_구간_정렬순서,
        recommended_combat_power,
        target_clear_rate
)

SELECT
    content_id AS `콘텐츠ID`,
    content_name AS `콘텐츠명`,
    difficulty AS `난이도`,
    파티_인원 AS `파티 인원`,
    전투력_구간 AS `전투력 구간`,
    recommended_combat_power AS `권장 전투력`,

    전체_시도수 AS `전체 시도 수`,
    도전_캐릭터수 AS `도전 캐릭터 수`,

    클리어_시도수 AS `클리어 시도 수`,
    클리어율 AS `클리어율(%)`,
    target_clear_rate AS `목표 클리어율(%)`,
    ROUND(클리어율 - target_clear_rate, 2) AS `목표 대비 차이(%p)`,

    실패_시도수 AS `실패 시도 수`,
    실패율 AS `실패율(%)`,

    CASE
        WHEN 클리어율 >= target_clear_rate THEN '목표 이상'
        ELSE '목표 미달'
    END AS `목표 달성 여부`

FROM 전투력_구간_집계
WHERE 클리어율 < target_clear_rate
ORDER BY
    content_id,
    파티_정렬순서,
    전투력_구간_정렬순서;