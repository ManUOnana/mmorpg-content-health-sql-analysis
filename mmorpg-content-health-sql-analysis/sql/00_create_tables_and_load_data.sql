CREATE DATABASE mmorpg_project;
USE mmorpg_project;
SHOW VARIABLES LIKE 'local_infile';
SET GLOBAL local_infile = 1;
SELECT DATABASE();
SHOW TABLES;

-- ============================================================
-- create table
-- ============================================================
CREATE TABLE accounts (
    account_id BIGINT PRIMARY KEY,
    created_at DATETIME NOT NULL,
    last_login_at DATETIME NULL,
    signup_channel VARCHAR(30) NOT NULL,
    platform VARCHAR(20) NOT NULL,
    country_code CHAR(2) NOT NULL,
    account_status VARCHAR(20) NOT NULL,
    is_tester TINYINT(1) NOT NULL,
    marketing_opt_in TINYINT(1) NULL
);
CREATE TABLE characters (
    character_id BIGINT PRIMARY KEY,
    account_id BIGINT NOT NULL,
    server_id INT NOT NULL,
    character_name VARCHAR(50) NOT NULL,
    class_name VARCHAR(30) NOT NULL,
    created_at DATETIME NOT NULL,
    level INT NOT NULL,
    combat_power BIGINT NOT NULL,
    gear_score INT NOT NULL,
    main_story_chapter INT NOT NULL,
    guild_id BIGINT NULL,
    is_deleted TINYINT(1) NOT NULL,

    INDEX idx_characters_account_id (account_id),
    INDEX idx_characters_level_cp (level, combat_power),

    CONSTRAINT fk_characters_account
        FOREIGN KEY (account_id)
        REFERENCES accounts(account_id)
);
CREATE TABLE content_master (
    content_id BIGINT PRIMARY KEY,
    content_name VARCHAR(100) NOT NULL,
    content_type VARCHAR(30) NOT NULL,
    difficulty VARCHAR(20) NOT NULL,
    required_level INT NOT NULL,
    recommended_combat_power BIGINT NOT NULL,
    min_party_size INT NOT NULL,
    max_party_size INT NOT NULL,
    entry_limit_type VARCHAR(20) NOT NULL,
    entry_limit_count INT NULL,
    expected_clear_time_sec INT NOT NULL,
    release_date DATE NOT NULL,
    is_active TINYINT(1) NOT NULL,

    INDEX idx_content_type_difficulty (content_type, difficulty)
);
CREATE TABLE content_design_goals (
    goal_id BIGINT PRIMARY KEY,
    content_id BIGINT NOT NULL,
    difficulty VARCHAR(20) NOT NULL,
    season_id VARCHAR(20) NOT NULL,
    target_participation_rate DECIMAL(5,2) NOT NULL,
    target_clear_rate DECIMAL(5,2) NOT NULL,
    target_avg_clear_time_sec INT NOT NULL,
    target_retry_rate DECIMAL(5,2) NOT NULL,
    target_death_count_avg DECIMAL(5,2) NOT NULL,
    target_reward_value BIGINT NOT NULL,
    valid_from DATE NOT NULL,
    valid_to DATE NULL,

    INDEX idx_design_goals_content_id (content_id),

    CONSTRAINT fk_design_goals_content
        FOREIGN KEY (content_id)
        REFERENCES content_master(content_id)
);
CREATE TABLE daily_activity (
    activity_date DATE NOT NULL,
    account_id BIGINT NOT NULL,
    character_id BIGINT NOT NULL,
    login_count INT NOT NULL,
    session_count INT NOT NULL,
    play_minutes INT NOT NULL,
    combat_minutes INT NOT NULL,
    non_combat_minutes INT NOT NULL,
    content_attempt_count INT NOT NULL,
    boss_attempt_count INT NOT NULL,
    enhancement_attempt_count INT NOT NULL,
    payment_count INT NOT NULL,
    earned_gold BIGINT NOT NULL,
    spent_gold BIGINT NOT NULL,

    INDEX idx_daily_activity_date (activity_date),
    INDEX idx_daily_activity_account_date (account_id, activity_date),
    INDEX idx_daily_activity_character_date (character_id, activity_date),

    CONSTRAINT fk_daily_activity_account
        FOREIGN KEY (account_id)
        REFERENCES accounts(account_id),

    CONSTRAINT fk_daily_activity_character
        FOREIGN KEY (character_id)
        REFERENCES characters(character_id)
);
CREATE TABLE content_attempts (
    attempt_id BIGINT PRIMARY KEY,
    account_id BIGINT NOT NULL,
    character_id BIGINT NOT NULL,
    content_id BIGINT NOT NULL,
    party_id BIGINT NULL,
    attempt_started_at DATETIME NOT NULL,
    attempt_ended_at DATETIME NULL,
    difficulty VARCHAR(20) NOT NULL,
    result VARCHAR(20) NOT NULL,
    clear_time_sec INT NULL,
    fail_reason VARCHAR(50) NULL,
    death_count INT NOT NULL,
    revive_count INT NOT NULL,
    potion_used_count INT NOT NULL,
    party_member_count INT NOT NULL,
    avg_party_combat_power BIGINT NULL,
    reward_claimed TINYINT(1) NOT NULL,

    INDEX idx_attempts_account (account_id),
    INDEX idx_attempts_character (character_id),
    INDEX idx_attempts_content (content_id),
    INDEX idx_attempts_started_at (attempt_started_at),
    INDEX idx_attempts_result (result),

    CONSTRAINT fk_attempts_account
        FOREIGN KEY (account_id)
        REFERENCES accounts(account_id),

    CONSTRAINT fk_attempts_character
        FOREIGN KEY (character_id)
        REFERENCES characters(character_id),

    CONSTRAINT fk_attempts_content
        FOREIGN KEY (content_id)
        REFERENCES content_master(content_id)
);
CREATE TABLE boss_pattern_logs (
    pattern_log_id BIGINT PRIMARY KEY,
    attempt_id BIGINT NOT NULL,
    character_id BIGINT NOT NULL,
    content_id BIGINT NOT NULL,
    boss_name VARCHAR(100) NOT NULL,
    phase_no INT NOT NULL,
    pattern_code VARCHAR(50) NOT NULL,
    pattern_name VARCHAR(100) NOT NULL,
    pattern_started_at DATETIME NOT NULL,
    pattern_duration_sec INT NOT NULL,
    was_hit TINYINT(1) NOT NULL,
    damage_taken BIGINT NOT NULL,
    is_fatal TINYINT(1) NOT NULL,
    avoid_success TINYINT(1) NOT NULL,
    position_zone VARCHAR(30) NULL,

    INDEX idx_boss_attempt (attempt_id),
    INDEX idx_boss_content_pattern (content_id, pattern_code),
    INDEX idx_boss_fatal (is_fatal),

    CONSTRAINT fk_boss_attempt
        FOREIGN KEY (attempt_id)
        REFERENCES content_attempts(attempt_id),

    CONSTRAINT fk_boss_character
        FOREIGN KEY (character_id)
        REFERENCES characters(character_id),

    CONSTRAINT fk_boss_content
        FOREIGN KEY (content_id)
        REFERENCES content_master(content_id)
);
CREATE TABLE reward_logs (
    reward_id BIGINT PRIMARY KEY,
    attempt_id BIGINT NULL,
    account_id BIGINT NOT NULL,
    character_id BIGINT NOT NULL,
    content_id BIGINT NULL,
    rewarded_at DATETIME NOT NULL,
    reward_source VARCHAR(30) NOT NULL,
    item_id BIGINT NOT NULL,
    item_name VARCHAR(100) NOT NULL,
    item_type VARCHAR(30) NOT NULL,
    item_rarity VARCHAR(20) NOT NULL,
    quantity INT NOT NULL,
    estimated_gold_value BIGINT NULL,
    is_first_clear_reward TINYINT(1) NOT NULL,

    INDEX idx_reward_attempt (attempt_id),
    INDEX idx_reward_account (account_id),
    INDEX idx_reward_character (character_id),
    INDEX idx_reward_content (content_id),
    INDEX idx_reward_time (rewarded_at),

    CONSTRAINT fk_reward_attempt
        FOREIGN KEY (attempt_id)
        REFERENCES content_attempts(attempt_id),

    CONSTRAINT fk_reward_account
        FOREIGN KEY (account_id)
        REFERENCES accounts(account_id),

    CONSTRAINT fk_reward_character
        FOREIGN KEY (character_id)
        REFERENCES characters(character_id),

    CONSTRAINT fk_reward_content
        FOREIGN KEY (content_id)
        REFERENCES content_master(content_id)
);
CREATE TABLE enhancement_logs (
    enhancement_id BIGINT PRIMARY KEY,
    account_id BIGINT NOT NULL,
    character_id BIGINT NOT NULL,
    enhanced_at DATETIME NOT NULL,
    item_id BIGINT NOT NULL,
    item_type VARCHAR(30) NOT NULL,
    before_enhance_level INT NOT NULL,
    after_enhance_level INT NOT NULL,
    success_rate DECIMAL(5,2) NOT NULL,
    result VARCHAR(20) NOT NULL,
    gold_cost BIGINT NOT NULL,
    material_item_id BIGINT NULL,
    material_count INT NOT NULL,
    used_protection_item TINYINT(1) NOT NULL,
    pity_stack_before INT NULL,

    INDEX idx_enhancement_account (account_id),
    INDEX idx_enhancement_character (character_id),
    INDEX idx_enhancement_time (enhanced_at),
    INDEX idx_enhancement_result (result),

    CONSTRAINT fk_enhancement_account
        FOREIGN KEY (account_id)
        REFERENCES accounts(account_id),

    CONSTRAINT fk_enhancement_character
        FOREIGN KEY (character_id)
        REFERENCES characters(character_id)
);
CREATE TABLE payments (
    payment_id BIGINT PRIMARY KEY,
    account_id BIGINT NOT NULL,
    character_id BIGINT NULL,
    paid_at DATETIME NOT NULL,
    product_id BIGINT NOT NULL,
    product_name VARCHAR(100) NOT NULL,
    product_type VARCHAR(30) NOT NULL,
    price_krw INT NOT NULL,
    currency_code CHAR(3) NOT NULL,
    payment_method VARCHAR(30) NULL,
    payment_status VARCHAR(20) NOT NULL,
    refund_at DATETIME NULL,
    is_first_payment TINYINT(1) NOT NULL,
    linked_event_id VARCHAR(30) NULL,

    INDEX idx_payments_account (account_id),
    INDEX idx_payments_character (character_id),
    INDEX idx_payments_paid_at (paid_at),
    INDEX idx_payments_status (payment_status),

    CONSTRAINT fk_payments_account
        FOREIGN KEY (account_id)
        REFERENCES accounts(account_id),

    CONSTRAINT fk_payments_character
        FOREIGN KEY (character_id)
        REFERENCES characters(character_id)
);

-- ============================================================
-- 1. accounts
-- ============================================================

LOAD DATA LOCAL INFILE 'C:/Users/thstn/Data analyst/mmorpg_pj/mmorpg_synthetic_csv/accounts.csv'
INTO TABLE accounts
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    account_id,
    created_at,
    @last_login_at,
    signup_channel,
    platform,
    country_code,
    account_status,
    is_tester,
    @marketing_opt_in
)
SET
    last_login_at = NULLIF(@last_login_at, ''),
    marketing_opt_in = NULLIF(@marketing_opt_in, '');


-- ============================================================
-- 2. characters
-- ============================================================

LOAD DATA LOCAL INFILE 'C:/Users/thstn/Data analyst/mmorpg_pj/mmorpg_synthetic_csv/characters.csv'
INTO TABLE characters
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    character_id,
    account_id,
    server_id,
    character_name,
    class_name,
    created_at,
    level,
    combat_power,
    gear_score,
    main_story_chapter,
    @guild_id,
    is_deleted
)
SET
    guild_id = NULLIF(@guild_id, '');


-- ============================================================
-- 3. content_master
-- ============================================================

LOAD DATA LOCAL INFILE 'C:/Users/thstn/Data analyst/mmorpg_pj/mmorpg_synthetic_csv/content_master.csv'
INTO TABLE content_master
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    content_id,
    content_name,
    content_type,
    difficulty,
    required_level,
    recommended_combat_power,
    min_party_size,
    max_party_size,
    entry_limit_type,
    @entry_limit_count,
    expected_clear_time_sec,
    release_date,
    is_active
)
SET
    entry_limit_count = NULLIF(@entry_limit_count, '');


-- ============================================================
-- 4. content_design_goals
-- ============================================================

LOAD DATA LOCAL INFILE 'C:/Users/thstn/Data analyst/mmorpg_pj/mmorpg_synthetic_csv/content_design_goals.csv'
INTO TABLE content_design_goals
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    goal_id,
    content_id,
    difficulty,
    season_id,
    target_participation_rate,
    target_clear_rate,
    target_avg_clear_time_sec,
    target_retry_rate,
    target_death_count_avg,
    target_reward_value,
    valid_from,
    @valid_to
)
SET
    valid_to = NULLIF(@valid_to, '');


-- ============================================================
-- 5. daily_activity
-- ============================================================

LOAD DATA LOCAL INFILE 'C:/Users/thstn/Data analyst/mmorpg_pj/mmorpg_synthetic_csv/daily_activity.csv'
INTO TABLE daily_activity
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    activity_date,
    account_id,
    character_id,
    login_count,
    session_count,
    play_minutes,
    combat_minutes,
    non_combat_minutes,
    content_attempt_count,
    boss_attempt_count,
    enhancement_attempt_count,
    payment_count,
    earned_gold,
    spent_gold
);


-- ============================================================
-- 6. content_attempts
-- ============================================================

LOAD DATA LOCAL INFILE 'C:/Users/thstn/Data analyst/mmorpg_pj/mmorpg_synthetic_csv/content_attempts.csv'
INTO TABLE content_attempts
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    attempt_id,
    account_id,
    character_id,
    content_id,
    @party_id,
    attempt_started_at,
    @attempt_ended_at,
    difficulty,
    result,
    @clear_time_sec,
    @fail_reason,
    death_count,
    revive_count,
    potion_used_count,
    party_member_count,
    @avg_party_combat_power,
    reward_claimed
)
SET
    party_id = NULLIF(@party_id, ''),
    attempt_ended_at = NULLIF(@attempt_ended_at, ''),
    clear_time_sec = NULLIF(@clear_time_sec, ''),
    fail_reason = NULLIF(@fail_reason, ''),
    avg_party_combat_power = NULLIF(@avg_party_combat_power, '');


-- ============================================================
-- 7. boss_pattern_logs
-- ============================================================

LOAD DATA LOCAL INFILE 'C:/Users/thstn/Data analyst/mmorpg_pj/mmorpg_synthetic_csv/boss_pattern_logs.csv'
INTO TABLE boss_pattern_logs
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    pattern_log_id,
    attempt_id,
    character_id,
    content_id,
    boss_name,
    phase_no,
    pattern_code,
    pattern_name,
    pattern_started_at,
    pattern_duration_sec,
    was_hit,
    damage_taken,
    is_fatal,
    avoid_success,
    @position_zone
)
SET
    position_zone = NULLIF(@position_zone, '');


-- ============================================================
-- 8. reward_logs
-- ============================================================

LOAD DATA LOCAL INFILE 'C:/Users/thstn/Data analyst/mmorpg_pj/mmorpg_synthetic_csv/reward_logs.csv'
INTO TABLE reward_logs
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    reward_id,
    @attempt_id,
    account_id,
    character_id,
    @content_id,
    rewarded_at,
    reward_source,
    item_id,
    item_name,
    item_type,
    item_rarity,
    quantity,
    @estimated_gold_value,
    is_first_clear_reward
)
SET
    attempt_id = NULLIF(@attempt_id, ''),
    content_id = NULLIF(@content_id, ''),
    estimated_gold_value = NULLIF(@estimated_gold_value, '');


-- ============================================================
-- 9. enhancement_logs
-- ============================================================

LOAD DATA LOCAL INFILE 'C:/Users/thstn/Data analyst/mmorpg_pj/mmorpg_synthetic_csv/enhancement_logs.csv'
INTO TABLE enhancement_logs
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    enhancement_id,
    account_id,
    character_id,
    enhanced_at,
    item_id,
    item_type,
    before_enhance_level,
    after_enhance_level,
    success_rate,
    result,
    gold_cost,
    @material_item_id,
    material_count,
    used_protection_item,
    @pity_stack_before
)
SET
    material_item_id = NULLIF(@material_item_id, ''),
    pity_stack_before = NULLIF(@pity_stack_before, '');


-- ============================================================
-- 10. payments
-- ============================================================

LOAD DATA LOCAL INFILE 'C:/Users/thstn/Data analyst/mmorpg_pj/mmorpg_synthetic_csv/payments.csv'
INTO TABLE payments
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(
    payment_id,
    account_id,
    boss_pattern_logs,
    @character_id,
    paid_at,
    product_id,
    product_name,
    product_type,
    price_krw,
    currency_code,
    @payment_method,
    payment_status,
    @refund_at,
    is_first_payment,
    @linked_event_id
)
SET
    character_id = NULLIF(@character_id, ''),
    payment_method = NULLIF(@payment_method, ''),
    refund_at = NULLIF(@refund_at, ''),
    linked_event_id = NULLIF(@linked_event_id, '');

-- ============================================================
-- 각 테이블 행 수 확인
-- ============================================================
    
SELECT 'accounts' AS table_name, COUNT(*) AS row_count FROM accounts
UNION ALL
SELECT 'characters', COUNT(*) FROM characters
UNION ALL
SELECT 'daily_activity', COUNT(*) FROM daily_activity
UNION ALL
SELECT 'content_master', COUNT(*) FROM content_master
UNION ALL
SELECT 'content_design_goals', COUNT(*) FROM content_design_goals
UNION ALL
SELECT 'content_attempts', COUNT(*) FROM content_attempts
UNION ALL
SELECT 'boss_pattern_logs', COUNT(*) FROM boss_pattern_logs
UNION ALL
SELECT 'reward_logs', COUNT(*) FROM reward_logs
UNION ALL
SELECT 'enhancement_logs', COUNT(*) FROM enhancement_logs
UNION ALL
SELECT 'payments', COUNT(*) FROM payments;

-- ============================================================
-- warning 발생 원인 탐색
-- ============================================================

SELECT COUNT(*) AS invalid_playtime_over_24h
FROM daily_activity
WHERE play_minutes > 1440;

SELECT COUNT(*) AS invalid_attempt_time_reverse
FROM content_attempts
WHERE attempt_ended_at < attempt_started_at;

SELECT COUNT(*) AS invalid_clear_without_clear_time
FROM content_attempts
WHERE result = 'clear'
  AND clear_time_sec IS NULL;
  
SELECT COUNT(*) AS invalid_refund_time_reverse
FROM payments
WHERE refund_at < paid_at;

SELECT COUNT(*) AS invalid_reward_on_failed_attempt
FROM reward_logs rl
JOIN content_attempts ca
    ON rl.attempt_id = ca.attempt_id
WHERE ca.result IN ('fail', 'give_up')
  AND rl.reward_source = 'content_clear';
  
   