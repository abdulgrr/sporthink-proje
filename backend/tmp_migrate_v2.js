const db = require('./db');

async function migrate() {
    try {
        console.log('1. Users tablosuna xp sütunu ekleniyor...');
        await db.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS xp INT DEFAULT 0`);
        console.log('   ✅ xp sütunu eklendi.');

        console.log('2. daily_quests tablosu oluşturuluyor...');
        await db.query(`
            CREATE TABLE IF NOT EXISTS daily_quests (
                id INT AUTO_INCREMENT PRIMARY KEY,
                quest_key VARCHAR(50) NOT NULL UNIQUE,
                title VARCHAR(100) NOT NULL,
                description VARCHAR(255),
                target_value INT DEFAULT 1,
                reward_points INT DEFAULT 5,
                reward_xp INT DEFAULT 5,
                is_active BOOLEAN DEFAULT TRUE,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
        console.log('   ✅ daily_quests tablosu oluşturuldu.');

        console.log('3. user_quest_progress tablosu oluşturuluyor...');
        await db.query(`
            CREATE TABLE IF NOT EXISTS user_quest_progress (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36) NOT NULL,
                quest_id INT NOT NULL,
                quest_date DATE NOT NULL,
                current_value INT DEFAULT 0,
                is_completed BOOLEAN DEFAULT FALSE,
                completed_at DATETIME NULL,
                UNIQUE KEY unique_user_quest_day (user_id, quest_id, quest_date),
                INDEX idx_user_date (user_id, quest_date)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
        console.log('   ✅ user_quest_progress tablosu oluşturuldu.');

        console.log('4. Başlangıç görevleri ekleniyor...');
        const quests = [
            ['steps_5000',  'Bugün 5.000 adım at',      '5.000 adıma ulaşarak bu görevi tamamla!', 5000, 5, 5],
            ['steps_10000', 'Bugün 10.000 adım at',     '10.000 adıma ulaşarak bu görevi tamamla!', 10000, 10, 10],
            ['sync_steps',  'Adımlarını senkronize et', 'Adımlarını sunucuya gönder.',               1, 3, 3],
            ['open_chest',  'Bir sandık aç',            'Günlük veya haftalık sandık aç.',           1, 3, 3],
            ['all_complete', 'Tüm görevleri tamamla',   'Diğer 4 görevi tamamlayarak bonus kazan!',  4, 10, 10],
        ];

        for (const q of quests) {
            await db.query(
                `INSERT IGNORE INTO daily_quests (quest_key, title, description, target_value, reward_points, reward_xp) VALUES (?, ?, ?, ?, ?, ?)`,
                q
            );
        }
        console.log('   ✅ 5 görev eklendi.');

        console.log('\n🎉 Migration tamamlandı!');
    } catch (e) {
        console.error('Migration hatası:', e);
    } finally {
        process.exit();
    }
}

migrate();
