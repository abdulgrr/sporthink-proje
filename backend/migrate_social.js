const db = require('./db');

async function migrate() {
    try {
        // social_likes tablosu
        await db.query(`
            CREATE TABLE IF NOT EXISTS social_likes (
                id VARCHAR(36) PRIMARY KEY,
                feed_id VARCHAR(36) NOT NULL,
                user_id VARCHAR(36) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_like (feed_id, user_id),
                INDEX idx_feed (feed_id),
                INDEX idx_user (user_id)
            )
        `);
        console.log('✅ social_likes tablosu oluşturuldu');

        // social_comments tablosu
        await db.query(`
            CREATE TABLE IF NOT EXISTS social_comments (
                id VARCHAR(36) PRIMARY KEY,
                feed_id VARCHAR(36) NOT NULL,
                user_id VARCHAR(36) NOT NULL,
                content VARCHAR(200) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_feed (feed_id),
                INDEX idx_user (user_id)
            )
        `);
        console.log('✅ social_comments tablosu oluşturuldu');

        console.log('✅ Tüm tablolar hazır!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

migrate();
