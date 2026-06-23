/* ============================================================
   01_content_usage_overview.sql

   분석 단계:
   1단계. 전체 콘텐츠 이용 현황 분석

   분석 목적:
   - 48개 전체 콘텐츠의 이용 현황을 비교한다.
   - 어떤 콘텐츠가 많이 이용되고, 어떤 콘텐츠가 외면받는지 확인한다.
   - clear_rate_gap 하나로 대상을 선정하지 않고,
     참여율, 시도 수, 참여자 수, 동급 콘텐츠 대비 참여 차이를 먼저 본다.

   출력 파일:
   - 01_content_usage_overview.csv

   주요 기준:
   - content_id 기준으로 48개 콘텐츠 전체를 출력한다.
   - 활성 계정/캐릭터는 daily_activity 기준으로 산정한다.
   - content_type + difficulty 기준의 동급 콘텐츠 비교 지표를 포함한다.
   ============================================================ */

WITH analysis_period AS (
    SELECT
        MIN(DATE(attempt_started_at)) AS start_date,
        MAX(DATE(attempt_started_at)) AS end_date
    FROM content_attempts
),

active_account_summary AS (
    SELECT
        COUNT(DISTINCT da.account_id) AS active_account_count
    FROM daily_activity da
    JOIN analysis_period ap
        ON da.activity_date BETWEEN ap.start_date AND ap.end_date
    WHERE da.play_minutes > 0
),

active_character_summary AS (
    SELECT
        COUNT(DISTINCT da.character_id) AS active_character_count
    FROM daily_activity da
    JOIN characters ch
        ON da.character_id = ch.character_id
    JOIN analysis_period ap
        ON da.activity_date BETWEEN ap.start_date AND ap.end_date
    WHERE da.play_minutes > 0
      AND ch.is_deleted = 0
),

content_usage AS (
    SELECT
        ca.content_id,

        COUNT(*) AS attempt_count,
        COUNT(DISTINCT ca.account_id) AS participant_account_count,
        COUNT(DISTINCT ca.character_id) AS participant_character_count,
        COUNT(DISTINCT ca.party_id) AS party_count,

        SUM(CASE WHEN ca.result = 'clear' THEN 1 ELSE 0 END) AS clear_count,
        SUM(CASE WHEN ca.result = 'fail' THEN 1 ELSE 0 END) AS fail_count,
        SUM(CASE WHEN ca.result = 'give_up' THEN 1 ELSE 0 END) AS give_up_count,
        SUM(CASE WHEN ca.result = 'disconnect' THEN 1 ELSE 0 END) AS disconnect_count,
        SUM(CASE WHEN ca.result <> 'clear' THEN 1 ELSE 0 END) AS non_clear_count,

        ROUND(AVG(ca.death_count), 2) AS avg_death_count,
        ROUND(AVG(ca.revive_count), 2) AS avg_revive_count,
        ROUND(AVG(ca.potion_used_count), 2) AS avg_potion_used_count,

        ROUND(AVG(CASE WHEN ca.result = 'clear' THEN ca.clear_time_sec END), 2) AS avg_clear_time_sec,
        ROUND(AVG(ca.party_member_count), 2) AS avg_party_member_count,

        MIN(DATE(ca.attempt_started_at)) AS first_attempt_date,
        MAX(DATE(ca.attempt_started_at)) AS last_attempt_date

    FROM content_attempts ca
    GROUP BY ca.content_id
),

content_base AS (
    SELECT
        cm.content_id,

        REGEXP_REPLACE(
            cm.content_name,
            ' (Easy|Normal|Hard|Mythic)$',
            ''
        ) AS content_line_name,

        cm.content_name,
        cm.content_type,
        cm.difficulty,

        CASE cm.difficulty
            WHEN 'easy' THEN 1
            WHEN 'normal' THEN 2
            WHEN 'hard' THEN 3
            WHEN 'mythic' THEN 4
            ELSE 99
        END AS difficulty_order,

        cm.required_level,
        cm.recommended_combat_power,
        cm.min_party_size,
        cm.max_party_size,
        cm.entry_limit_type,
        cm.entry_limit_count,
        cm.expected_clear_time_sec,
        cm.is_active,

        cdg.target_participation_rate,
        cdg.target_clear_rate,
        cdg.target_avg_clear_time_sec,
        cdg.target_retry_rate,
        cdg.target_death_count_avg,
        cdg.target_reward_value,

        COALESCE(cu.attempt_count, 0) AS attempt_count,
        COALESCE(cu.participant_account_count, 0) AS participant_account_count,
        COALESCE(cu.participant_character_count, 0) AS participant_character_count,
        COALESCE(cu.party_count, 0) AS party_count,

        COALESCE(cu.clear_count, 0) AS clear_count,
        COALESCE(cu.fail_count, 0) AS fail_count,
        COALESCE(cu.give_up_count, 0) AS give_up_count,
        COALESCE(cu.disconnect_count, 0) AS disconnect_count,
        COALESCE(cu.non_clear_count, 0) AS non_clear_count,

        cu.avg_death_count,
        cu.avg_revive_count,
        cu.avg_potion_used_count,
        cu.avg_clear_time_sec,
        cu.avg_party_member_count,
        cu.first_attempt_date,
        cu.last_attempt_date,

        aas.active_account_count,
        acs.active_character_count

    FROM content_master cm
    LEFT JOIN content_design_goals cdg
        ON cm.content_id = cdg.content_id
    LEFT JOIN content_usage cu
        ON cm.content_id = cu.content_id
    CROSS JOIN active_account_summary aas
    CROSS JOIN active_character_summary acs
    WHERE cm.is_active = 1
),

content_metric AS (
    SELECT
        cb.*,

        ROUND(
            cb.participant_account_count / NULLIF(cb.active_account_count, 0) * 100,
            2
        ) AS account_participation_rate_pct,

        ROUND(
            cb.participant_character_count / NULLIF(cb.active_character_count, 0) * 100,
            2
        ) AS character_participation_rate_pct,

        ROUND(
            cb.attempt_count / NULLIF(SUM(cb.attempt_count) OVER (), 0) * 100,
            2
        ) AS attempt_share_pct,

        ROUND(
            cb.participant_account_count
            / NULLIF(SUM(cb.participant_account_count) OVER (), 0) * 100,
            2
        ) AS participant_account_share_pct,

        CASE
            WHEN cb.attempt_count = 0 THEN 0
            ELSE ROUND(cb.clear_count / cb.attempt_count * 100, 2)
        END AS clear_rate_pct,

        CASE
            WHEN cb.attempt_count = 0 THEN 0
            ELSE ROUND(cb.fail_count / cb.attempt_count * 100, 2)
        END AS fail_rate_pct,

        CASE
            WHEN cb.attempt_count = 0 THEN 0
            ELSE ROUND(cb.give_up_count / cb.attempt_count * 100, 2)
        END AS give_up_rate_pct,

        CASE
            WHEN cb.attempt_count = 0 THEN 0
            ELSE ROUND(cb.disconnect_count / cb.attempt_count * 100, 2)
        END AS disconnect_rate_pct,

        CASE
            WHEN cb.attempt_count = 0 THEN 0
            ELSE ROUND(cb.non_clear_count / cb.attempt_count * 100, 2)
        END AS non_clear_rate_pct,

        CASE
            WHEN cb.participant_account_count = 0 THEN 0
            ELSE ROUND(cb.attempt_count / cb.participant_account_count, 2)
        END AS avg_attempts_per_participant_account

    FROM content_base cb
),

content_peer_metric AS (
    SELECT
        cm.*,

        ROUND(
            cm.account_participation_rate_pct - cm.target_participation_rate,
            2
        ) AS participation_rate_gap_pp,

        ROUND(
            cm.clear_rate_pct - cm.target_clear_rate,
            2
        ) AS clear_rate_gap_pp,

        ROUND(
            cm.avg_clear_time_sec - cm.target_avg_clear_time_sec,
            2
        ) AS clear_time_gap_sec,

        ROUND(
            cm.account_participation_rate_pct
            - AVG(cm.account_participation_rate_pct)
                OVER (PARTITION BY cm.content_type, cm.difficulty),
            2
        ) AS peer_participation_gap_pp,

        ROUND(
            cm.attempt_count
            - AVG(cm.attempt_count)
                OVER (PARTITION BY cm.content_type, cm.difficulty),
            2
        ) AS peer_attempt_gap,

        RANK() OVER (
            ORDER BY cm.attempt_count DESC
        ) AS total_attempt_rank,

        RANK() OVER (
            PARTITION BY cm.content_type, cm.difficulty
            ORDER BY cm.attempt_count DESC
        ) AS peer_attempt_rank,

        RANK() OVER (
            ORDER BY cm.account_participation_rate_pct DESC
        ) AS total_participation_rank,

        RANK() OVER (
            PARTITION BY cm.content_type, cm.difficulty
            ORDER BY cm.account_participation_rate_pct DESC
        ) AS peer_participation_rank

    FROM content_metric cm
)

SELECT
    content_id,
    content_line_name,
    content_name,
    content_type,
    difficulty,
    difficulty_order,

    required_level,
    recommended_combat_power,
    min_party_size,
    max_party_size,
    entry_limit_type,
    entry_limit_count,
    expected_clear_time_sec,

    active_account_count,
    active_character_count,

    attempt_count,
    participant_account_count,
    participant_character_count,
    party_count,

    account_participation_rate_pct,
    character_participation_rate_pct,
    attempt_share_pct,
    participant_account_share_pct,
    avg_attempts_per_participant_account,

    target_participation_rate,
    participation_rate_gap_pp,

    clear_count,
    fail_count,
    give_up_count,
    disconnect_count,
    non_clear_count,

    clear_rate_pct,
    fail_rate_pct,
    give_up_rate_pct,
    disconnect_rate_pct,
    non_clear_rate_pct,

    target_clear_rate,
    clear_rate_gap_pp,

    avg_death_count,
    avg_revive_count,
    avg_potion_used_count,
    avg_clear_time_sec,
    target_avg_clear_time_sec,
    clear_time_gap_sec,

    avg_party_member_count,

    peer_participation_gap_pp,
    peer_attempt_gap,

    total_attempt_rank,
    peer_attempt_rank,
    total_participation_rank,
    peer_participation_rank,

    first_attempt_date,
    last_attempt_date,

    CASE
        WHEN attempt_count = 0 THEN '미이용 콘텐츠'
        WHEN peer_participation_gap_pp <= -5 THEN '동급 대비 참여 낮음'
        WHEN peer_participation_gap_pp >= 5 THEN '동급 대비 참여 높음'
        ELSE '동급 평균권'
    END AS participation_status,

    CASE
        WHEN participation_rate_gap_pp <= -5 THEN '목표 대비 참여 낮음'
        WHEN participation_rate_gap_pp >= 5 THEN '목표 대비 참여 높음'
        ELSE '목표 부근'
    END AS target_participation_status,

    CASE
        WHEN account_participation_rate_pct >= AVG(account_participation_rate_pct) OVER ()
             AND non_clear_rate_pct >= AVG(non_clear_rate_pct) OVER ()
            THEN '참여 높음 + 실패 부담 높음'

        WHEN account_participation_rate_pct < AVG(account_participation_rate_pct) OVER ()
             AND non_clear_rate_pct < AVG(non_clear_rate_pct) OVER ()
            THEN '참여 낮음 + 실패 부담 낮음'

        WHEN account_participation_rate_pct < AVG(account_participation_rate_pct) OVER ()
             AND non_clear_rate_pct >= AVG(non_clear_rate_pct) OVER ()
            THEN '참여 낮음 + 실패 부담 높음'

        WHEN account_participation_rate_pct >= AVG(account_participation_rate_pct) OVER ()
             AND non_clear_rate_pct < AVG(non_clear_rate_pct) OVER ()
            THEN '참여 높음 + 실패 부담 낮음'

        ELSE '기타'
    END AS usage_failure_segment

FROM content_peer_metric
ORDER BY
    total_attempt_rank ASC,
    content_type,
    difficulty_order,
    content_id;