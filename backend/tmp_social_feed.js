const db = require('./db');

async function createSocialFeedTable() {
    try {
        await db.query(`
            CREATE TABLE IF NOT EXISTS social_feed (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36) NOT NULL,
                event_type ENUM('badge', 'level', 'streak', 'weekly_rank') NOT NULL,
                event_data JSON NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `);
        console.log("social_feed tablosu başarıyla oluşturuldu.");
    } catch (e) {
        console.error("Tablo oluşturma hatası:", e);
    }
    process.exit(0);
}

createSocialFeedTable();
