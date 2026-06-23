# MMORPG 콘텐츠 건강도 SQL 분석 프로젝트

## 1. 프로젝트 개요

이 프로젝트는 MMORPG 합성 데이터를 기반으로 콘텐츠별 이용 현황, 목표 대비 클리어율, 난이도 요인, 전투력 구간별 성과, 보상 효율, 보스 패턴 영향을 SQL로 분석한 개인 포트폴리오 프로젝트입니다.

분석 목적은 단순히 클리어율이 낮은 콘텐츠를 찾는 것이 아니라, 콘텐츠가 설계 의도에 맞게 소비되고 있는지 진단하고, 개선이 필요한 콘텐츠와 원인 후보를 도출하는 것입니다.

## 2. 분석 목표

* 48개 콘텐츠의 전체 이용 현황을 비교한다.
* 콘텐츠별 참여율, 클리어율, 실패율, 포기율, 접속 종료율을 집계한다.
* 목표 클리어율 대비 실제 클리어율 차이를 계산해 이상 콘텐츠를 선별한다.
* 전투력 구간별 클리어율과 실패율을 분석해 특정 스펙 구간에서 문제가 발생하는지 확인한다.
* 난이도 요인, 보상 효율, 보스 패턴 영향을 분석해 개선 대상 콘텐츠의 원인 후보를 도출한다.
* 최종적으로 Abyss Monarch Hard를 주요 개선 대상으로 선정하고 개선 방향을 제시한다.

## 3. 사용 데이터

본 프로젝트는 Python으로 생성한 MMORPG 합성 데이터를 MySQL에 적재한 뒤 SQL로 분석했습니다.

주요 테이블은 다음과 같습니다.

| 테이블명                 | 설명               |
| -------------------- | ---------------- |
| accounts             | 계정 정보            |
| characters           | 캐릭터 정보 및 전투력 정보  |
| daily_activity       | 일자별 접속 및 활동 로그   |
| content_master       | 콘텐츠 기본 정보        |
| content_design_goals | 콘텐츠별 설계 목표값      |
| content_attempts     | 콘텐츠 시도 로그        |
| boss_pattern_logs    | 보스 패턴 피격 및 사망 로그 |
| reward_logs          | 보상 지급 로그         |
| enhancement_logs     | 강화 로그            |
| payments             | 결제 로그            |

분석 과정에서 `content_attempts.avg_party_combat_power` 컬럼은 최종 분석 기준에서 제외했습니다. 해당 컬럼은 파티 평균 전투력이며, 개인 기준 권장 전투력과 직접 비교하기에 적합하지 않고 일부 값에서 캐릭터 최대 전투력을 초과하는 이상값이 확인되었기 때문입니다.

따라서 최종 전투력 분석은 `characters.combat_power`와 `content_master.recommended_combat_power`를 기준으로 수행했습니다.

## 4. 분석 방법론

분석은 다음 4단계 흐름으로 진행했습니다.

| 단계                | 내용                                               |
| ----------------- | ------------------------------------------------ |
| 1. 현황 분석          | 콘텐츠별 참여율, 클리어율, 실패율, 시도 수 등 기본 지표를 집계            |
| 2. 특이점 발견         | 목표 클리어율 대비 실제 클리어율이 낮은 콘텐츠와 동급 대비 참여율이 낮은 콘텐츠 확인 |
| 3. 가설 수립 및 심층 분석  | 전투력 구간, 난이도 요인, 보상 효율, 보스 패턴 로그를 기준으로 원인 후보 분석   |
| 4. 근본 원인 및 개선안 도출 | 개선 대상 콘텐츠를 선정하고 난이도, 패턴, 보상 구조 관점에서 개선 방향 제시     |

이 프로젝트에서는 `목표 대비 클리어율`을 콘텐츠 건강도 판단의 핵심 기준으로 사용했습니다.
다만 클리어율만으로 개선 대상을 선정하지 않고, 참여율, 실패율, 전투력 구간별 성과, 보상 효율, 보스 패턴 영향을 함께 검토했습니다.

## 5. 프로젝트 구조

```text
mmorpg-content-health-sql-analysis
├── README.md
├── sql
│   ├── 00_create_tables_and_load_data.sql
│   ├── 01_data_quality_check.sql
│   ├── 02_basic_analysis.sql
│   ├── 03_content_health_summary.sql
│   ├── 04_content_health_gap_analysis.sql
│   ├── 05_content_usage_overview.sql
│   ├── 06_difficulty_factor_analysis.sql
│   ├── 07_eligible_user_participation_analysis.sql
│   ├── 08_combat_power_segment_analysis.sql
│   ├── 09_reward_efficiency_analysis.sql
│   └── 10_abyss_monarch_hard_deep_dive.sql
└── result
    ├── content_usage_overview.csv
    ├── content_health_gap_analysis.csv
    ├── difficulty_factor_analysis.csv
    ├── eligible_user_participation_analysis.csv
    ├── combat_power_segment_analysis.csv
    ├── reward_efficiency_analysis.csv
    └── abyss_monarch_hard_deep_dive
        ├── 01_release_operation_check.csv
        ├── 02_combat_power_band_performance.csv
        ├── 03_boss_pattern_impact.csv
        ├── 04_p999_result_impact.csv
        └── 05_p999_by_combat_power_band.csv
```

## 6. SQL 분석 파일 설명

| 파일명                                           | 분석 내용                                               |
| --------------------------------------------- | --------------------------------------------------- |
| `00_create_tables_and_load_data.sql`          | MySQL 데이터베이스 생성, 10개 테이블 생성, CSV 적재                 |
| `01_data_quality_check.sql`                   | PK/FK 관계, 참조 무결성, 필수값, 날짜 논리, 상태값 정합성 점검            |
| `02_basic_analysis.sql`                       | 전체 데이터 규모, 날짜 범위, 계정/캐릭터 수, 콘텐츠 시도 결과 분포 확인         |
| `03_content_health_summary.sql`               | 콘텐츠별 기본 건강도 지표 집계                                   |
| `04_content_health_gap_analysis.sql`          | 목표값 대비 실제 지표 차이 계산 및 health_status 분류               |
| `05_content_usage_overview.sql`               | 48개 콘텐츠 이용 현황, 참여율, 시도 수 순위, 동급 콘텐츠 대비 참여 차이 분석     |
| `06_difficulty_factor_analysis.sql`           | 실패율, 사망 수, 클리어 시간을 기준으로 난이도 요인 스택 계산                |
| `07_eligible_user_participation_analysis.sql` | 도전 가능 캐릭터 기준 실제 참여 규모 분석                            |
| `08_combat_power_segment_analysis.sql`        | 개인 전투력 구간별 클리어율 및 실패율 분석                            |
| `09_reward_efficiency_analysis.sql`           | 보상 가치, 시도당 보상, 분당 보상 효율 분석                          |
| `10_abyss_monarch_hard_deep_dive.sql`         | Abyss Monarch Hard의 전투력 구간, 보스 패턴, P999 패턴 영향 심층 분석 |


## 7. 주요 분석 흐름

### 7-1. 전체 콘텐츠 이용 현황 분석

먼저 48개 전체 콘텐츠를 대상으로 시도 수, 참여 계정 수, 참여 캐릭터 수, 클리어율, 실패율, 포기율, 접속 종료율을 집계했습니다.

이 단계에서는 특정 콘텐츠 하나를 바로 선정하지 않고, 콘텐츠 유형과 난이도 기준으로 동급 콘텐츠 대비 참여 차이와 시도 수 순위를 함께 확인했습니다.

### 7-2. 목표 대비 클리어율 분석

콘텐츠별 실제 클리어율과 설계 목표 클리어율의 차이를 계산했습니다.

```sql
actual_clear_rate - target_clear_rate AS clear_rate_gap
```

이 값을 기준으로 목표 대비 클리어율이 낮은 콘텐츠를 선별하고, 이후 심층 분석 대상으로 확장했습니다.

### 7-3. 난이도 요인 분석

목표 대비 클리어율이 낮은 콘텐츠를 대상으로 실패율, 평균 사망 횟수, 평균 클리어 시간을 분석했습니다.

동일 난이도 평균 실패율보다 높은지, 목표 사망 횟수와 목표 클리어 시간을 초과하는지를 기준으로 난이도 요인 스택을 계산했습니다.

### 7-4. 전투력 구간별 분석

초기 분석에서는 `content_attempts.avg_party_combat_power`를 사용했으나, 해당 컬럼은 최종 분석에서 제외했습니다.

최종 분석에서는 `characters.combat_power`를 기준으로 개인 전투력을 사용했고, 권장 전투력 대비 다음 구간으로 나누어 클리어율과 실패율을 분석했습니다.

* 권장 전투력 80% 미만
* 권장 전투력 80~100%
* 권장 전투력 100~110%
* 권장 전투력 110~120%
* 권장 전투력 120% 이상

### 7-5. Abyss Monarch Hard 심층 분석

최종 개선 후보로 Abyss Monarch Hard를 선정하고, 전투력 구간별 성과와 보스 패턴 로그를 분석했습니다.

특히 특정 패턴인 `P999`에 대해 피격률, 사망 유발 비중, 피격 시 실패율, 전투력 구간별 발생률을 확인하여 실패 원인 후보로 검토했습니다.

## 8. 주요 인사이트

* 전체 콘텐츠를 한 번에 개선 대상으로 판단하지 않고, 참여율, 시도 수, 목표 대비 클리어율, 동급 콘텐츠 대비 차이를 기준으로 이상 콘텐츠 후보를 먼저 선별했습니다.
* 목표 대비 클리어율이 낮은 콘텐츠 중 일부는 단순히 전투력이 부족해서 실패하는 것이 아니라, 실패율, 클리어 시간, 보스 패턴 영향이 함께 작용하는 것으로 판단했습니다.
* `avg_party_combat_power`는 데이터 이상값과 기준 불일치 문제로 최종 분석에서 제외했습니다.
* 전투력 분석은 `characters.combat_power`를 기준으로 다시 수행했고, 권장 전투력 대비 구간별 클리어율과 실패율을 확인했습니다.
* Abyss Monarch Hard는 목표 대비 클리어율이 낮고, 특정 전투력 구간 및 보스 패턴에서 실패 부담이 확인되어 주요 개선 후보로 선정했습니다.
* Fallen King Mythic은 보상 효율을 별도로 분석했지만, 필드 보스 특성상 시간이 지나며 자연스럽게 도태될 수 있는 콘텐츠로 판단해 최종 개선 대상에서는 제외했습니다.

## 9. 개선 방향

최종 개선 대상으로 Abyss Monarch Hard를 선정했습니다.

개선 방향은 단순한 난이도 완화가 아니라, 콘텐츠의 의도된 긴장감은 유지하면서 특정 실패 부담을 조정하는 방향으로 정리했습니다.

* P999 패턴의 피격 후 실패율이 높은 경우, 패턴 자체를 삭제하기보다 사전 경고 시간, 회피 가능 구간, 피해량, 연속 피격 구조를 점검한다.
* 권장 전투력 이상 구간에서도 실패율이 높다면, 보스 패턴 난이도 또는 파티 생존 구조를 우선 점검한다.
* 권장 전투력 미달 캐릭터의 진입 비중이 높다면, 입장 조건 또는 추천 전투력 안내를 강화한다.
* 보상 효율이 낮아 반복 도전 유인이 부족한 경우, 클리어 보상보다 실패 후 재도전 유인을 보완하는 방향을 검토한다.

이 개선안은 콘텐츠를 쉽게 만드는 것이 아니라, 설계 목표 클리어율에 맞게 콘텐츠 경험을 조정하는 것을 목적으로 합니다.

## 10. 사용 기술

* SQL / MySQL
* Python
* Tableau
* Notion
* GitHub

## 11. 결과물

* SQL 분석 코드: `sql/`
* SQL 실행 결과 CSV: `result/`
* Tableau 대시보드: 별도 Tableau Public 또는 이미지로 정리
* 상세 분석 문서: Notion 페이지에 정리

## 12. 프로젝트 의의

이 프로젝트는 합성 데이터를 기반으로 하지만, 실제 MMORPG 서비스에서 활용할 수 있는 콘텐츠 건강도 진단 흐름을 SQL로 구현한 프로젝트입니다.

단순 지표 집계에서 끝나지 않고, 다음 흐름으로 분석을 확장했습니다.

1. 전체 콘텐츠 현황 확인
2. 목표 대비 이상 콘텐츠 선별
3. 난이도, 전투력, 보상, 보스 패턴 기준의 원인 분석
4. 개선 대상 콘텐츠 선정
5. 개선 방향 제시

이를 통해 SQL을 사용한 데이터 검증, 지표 설계, 이상 콘텐츠 탐색, 원인 분석, 개선안 도출 과정을 하나의 포트폴리오 프로젝트로 정리했습니다.

