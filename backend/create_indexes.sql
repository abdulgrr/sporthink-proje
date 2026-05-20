-- Veritabanı İndeksleri ve Tablo Oluşturma Scripti

-- Refresh Tokens Tablosu
CREATE TABLE IF NOT EXISTS refresh_tokens (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36) NOT NULL,
    token TEXT NOT NULL,
    expires_at DATETIME NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_token (token(255)),
    INDEX idx_expires_at (expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Steps Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_steps_user_id ON steps(user_id);
CREATE INDEX IF NOT EXISTS idx_steps_day ON steps(day);
CREATE INDEX IF NOT EXISTS idx_steps_user_day ON steps(user_id, day);
CREATE INDEX IF NOT EXISTS idx_steps_created_at ON steps(created_at);

-- Users Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_username ON users(username);
CREATE INDEX IF NOT EXISTS idx_users_total_points ON users(total_points DESC);
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- PointsLedger Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_pointsledger_user_id ON pointsledger(user_id);
CREATE INDEX IF NOT EXISTS idx_pointsledger_type ON pointsledger(type);
CREATE INDEX IF NOT EXISTS idx_pointsledger_source ON pointsledger(source);
CREATE INDEX IF NOT EXISTS idx_pointsledger_created_at ON pointsledger(created_at);

-- Notifications Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_type ON notifications(type);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);

-- UserRewards Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_userrewards_user_id ON userrewards(user_id);
CREATE INDEX IF NOT EXISTS idx_userrewards_status ON userrewards(status);
CREATE INDEX IF NOT EXISTS idx_userrewards_created_at ON userrewards(created_at);

-- Products Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_products_is_active ON products(is_active);
CREATE INDEX IF NOT EXISTS idx_products_price_points ON products(price_points);

-- Badges Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_badges_requirement_type ON badges(requirement_type);
CREATE INDEX IF NOT EXISTS idx_badges_requirement_value ON badges(requirement_value);

-- UserBadges Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_userbadges_user_id ON user_badges(user_id);
CREATE INDEX IF NOT EXISTS idx_userbadges_badge_id ON user_badges(badge_id);

-- DailyQuests Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_daily_quests_difficulty ON daily_quests(difficulty);
CREATE INDEX IF NOT EXISTS idx_daily_quests_is_active ON daily_quests(is_active);

-- UserQuestProgress Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_userquestprogress_user_id ON user_quest_progress(user_id);
CREATE INDEX IF NOT EXISTS idx_userquestprogress_quest_date ON user_quest_progress(quest_date);
CREATE INDEX IF NOT EXISTS idx_userquestprogress_is_completed ON user_quest_progress(is_completed);

-- ChestDrops Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_chestdrops_chest_name ON chest_drops(chest_name);
CREATE INDEX IF NOT EXISTS idx_chestdrops_probability ON chest_drops(probability_percent);

-- Follows Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_follows_follower_id ON follows(follower_id);
CREATE INDEX IF NOT EXISTS idx_follows_following_id ON follows(following_id);
CREATE INDEX IF NOT EXISTS idx_follows_unique ON follows(follower_id, following_id);

-- Settings Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_settings_key_name ON settings(key_name);

-- Tips Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_tips_is_active ON Tips(is_active);
CREATE INDEX IF NOT EXISTS idx_tips_created_at ON Tips(created_at);

-- AuditLogs Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_auditlogs_user_id ON auditlogs(user_id);
CREATE INDEX IF NOT EXISTS idx_auditlogs_action ON auditlogs(action);
CREATE INDEX IF NOT EXISTS idx_auditlogs_created_at ON auditlogs(created_at);

-- StepSync Tablosu İndeksleri
CREATE INDEX IF NOT EXISTS idx_stepsync_user_id ON StepSync(user_id);
CREATE INDEX IF NOT EXISTS idx_stepsync_client_batch_id ON StepSync(client_batch_id);
CREATE INDEX IF NOT EXISTS idx_stepsync_created_at ON StepSync(created_at);