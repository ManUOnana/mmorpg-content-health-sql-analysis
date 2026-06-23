WITH 최신_목표값 AS (
    SELECT
        goal_id,
        content_id,
        difficulty,
        target_clear_rate,
        target_avg_clear_time_sec,
        target_death_count_avg,
        target_retry_rate,
        ROW_NUMBER() OVER (
            PARTITION BY content_id
            ORDER BY valid_from DESC
        ) AS rn
    FROM content_design_goals
),

콘텐츠별_실제지표 AS (
    SELECT
        cm.content_id,
        cm.content_name,
        cm.content_type,
        cm.difficulty,
        cm.recommended_combat_power,
        cm.expected_clear_time_sec,

        lg.target_clear_rate,
        lg.target_avg_clear_time_sec,
        lg.target_death_count_avg,
        lg.target_retry_rate,

        COUNT(*) AS total_attempt_count,

        SUM(CASE WHEN ca.result = 'clear' THEN 1 ELSE 0 END) AS clear_count,
        SUM(CASE WHEN ca.result = 'fail' THEN 1 ELSE 0 END) AS fail_count,
        SUM(CASE WHEN ca.result = 'give_up' THEN 1 ELSE 0 END) AS give_up_count,
        SUM(CASE WHEN ca.result = 'disconnect' THEN 1 ELSE 0 END) AS disconnect_count,

        SUM(CASE WHEN ca.result = 'clear' THEN 1 ELSE 0 END) / COUNT(*) * 100 AS actual_clear_rate,
        SUM(CASE WHEN ca.result = 'fail' THEN 1 ELSE 0 END) / COUNT(*) * 100 AS actual_fail_rate,
        SUM(CASE WHEN ca.result = 'give_up' THEN 1 ELSE 0 END) / COUNT(*) * 100 AS actual_give_up_rate,
        SUM(CASE WHEN ca.result = 'disconnect' THEN 1 ELSE 0 END) / COUNT(*) * 100 AS actual_disconnect_rate,

        AVG(ca.death_count) AS actual_avg_death_count,
        AVG(CASE WHEN ca.result = 'clear' THEN ca.clear_time_sec END) AS actual_avg_clear_time_sec

    FROM content_master cm
    JOIN content_attempts ca
        ON cm.content_id = ca.content_id
    JOIN 최신_목표값 lg
        ON cm.content_id = lg.content_id
       AND lg.rn = 1
    GROUP BY
        cm.content_id,
        cm.content_name,
        cm.content_type,
        cm.difficulty,
        cm.recommended_combat_power,
        cm.expected_clear_time_sec,
        lg.target_clear_rate,
        lg.target_avg_clear_time_sec,
        lg.target_death_count_avg,
        lg.target_retry_rate
),

난이도별_평균지표 AS (
    SELECT
        difficulty,
        AVG(actual_fail_rate) AS difficulty_avg_fail_rate,
        AVG(actual_avg_death_count) AS difficulty_avg_death_count,
        AVG(actual_avg_clear_time_sec) AS difficulty_avg_clear_time_sec
    FROM 콘텐츠별_실제지표
    GROUP BY difficulty
),

분석대상_콘텐츠 AS (
    SELECT
        cm.*,
        db.difficulty_avg_fail_rate,
        db.difficulty_avg_death_count,
        db.difficulty_avg_clear_time_sec
    FROM 콘텐츠별_실제지표 cm
    JOIN 난이도별_평균지표 db
        ON cm.difficulty = db.difficulty
    WHERE cm.content_id IN (48, 24, 20, 47, 32, 23)
),

난이도_스택계산 AS (
    SELECT
        content_id,
        content_name,
        content_type,
        difficulty,
        recommended_combat_power,

        total_attempt_count,
        clear_count,
        fail_count,
        give_up_count,
        disconnect_count,

        target_clear_rate,
        actual_clear_rate,
        actual_clear_rate - target_clear_rate AS clear_rate_gap,

        actual_fail_rate,
        difficulty_avg_fail_rate,
        actual_fail_rate - difficulty_avg_fail_rate AS fail_rate_gap_vs_difficulty,

        target_death_count_avg,
        actual_avg_death_count,
        (actual_avg_death_count - target_death_count_avg)
            / NULLIF(target_death_count_avg, 0) * 100 AS death_count_gap_pct,

        target_avg_clear_time_sec,
        actual_avg_clear_time_sec,
        (actual_avg_clear_time_sec - target_avg_clear_time_sec)
            / NULLIF(target_avg_clear_time_sec, 0) * 100 AS clear_time_gap_pct,

        CASE
            WHEN actual_fail_rate - difficulty_avg_fail_rate >= 5 THEN 1
            ELSE 0
        END AS fail_rate_stack,

        CASE
            WHEN (actual_avg_death_count - target_death_count_avg)
                 / NULLIF(target_death_count_avg, 0) * 100 >= 20 THEN 1
            ELSE 0
        END AS death_count_stack,

        CASE
            WHEN (actual_avg_clear_time_sec - target_avg_clear_time_sec)
                 / NULLIF(target_avg_clear_time_sec, 0) * 100 >= 20 THEN 1
            ELSE 0
        END AS clear_time_stack

    FROM 분석대상_콘텐츠
)

SELECT
    content_id AS `콘텐츠 ID`,
    content_name AS `콘텐츠명`,
    difficulty AS `난이도`,
    content_type AS `콘텐츠 유형`,
    recommended_combat_power AS `권장 전투력`,

    total_attempt_count AS `전체 시도 수`,
    clear_count AS `클리어 수`,
    fail_count AS `실패 수`,
    give_up_count AS `포기 수`,
    disconnect_count AS `접속 종료 수`,

    ROUND(target_clear_rate, 2) AS `목표 클리어율(%)`,
    ROUND(actual_clear_rate, 2) AS `실제 클리어율(%)`,
    ROUND(clear_rate_gap, 2) AS `목표 대비 클리어율 차이(%p)`,

    ROUND(actual_fail_rate, 2) AS `실제 실패율(%)`,
    ROUND(difficulty_avg_fail_rate, 2) AS `동일 난이도 평균 실패율(%)`,
    ROUND(fail_rate_gap_vs_difficulty, 2) AS `동일 난이도 대비 실패율 차이(%p)`,

    ROUND(target_death_count_avg, 2) AS `목표 평균 사망 횟수`,
    ROUND(actual_avg_death_count, 2) AS `실제 평균 사망 횟수`,
    ROUND(death_count_gap_pct, 2) AS `목표 대비 사망 횟수 차이율(%)`,

    ROUND(target_avg_clear_time_sec, 2) AS `목표 평균 클리어 시간(초)`,
    ROUND(actual_avg_clear_time_sec, 2) AS `실제 평균 클리어 시간(초)`,
    ROUND(clear_time_gap_pct, 2) AS `목표 대비 클리어 시간 차이율(%)`,

    fail_rate_stack AS `실패율 스택`,
    death_count_stack AS `사망 횟수 스택`,
    clear_time_stack AS `클리어 시간 스택`,

    fail_rate_stack + death_count_stack + clear_time_stack AS `난이도 요인 스택 합계`,

    CASE
        WHEN fail_rate_stack + death_count_stack + clear_time_stack >= 2
            THEN '난이도 문제 가능성 높음'
        WHEN fail_rate_stack + death_count_stack + clear_time_stack = 1
            THEN '난이도 문제 가능성 있음'
        ELSE '난이도 문제 가능성 낮음'
    END AS `난이도 요인 판단`

FROM 난이도_스택계산
ORDER BY
    `난이도 요인 스택 합계` DESC,
    `목표 대비 클리어율 차이(%p)` ASC;