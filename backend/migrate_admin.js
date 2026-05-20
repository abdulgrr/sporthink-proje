const db = require('./db');

async function migrate() {
    try {
        // Ban alanları ekle
        await db.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS is_banned TINYINT(1) DEFAULT 0`);
        await db.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS ban_reason VARCHAR(500) DEFAULT NULL`);
        await db.query(`ALTER TABLE users ADD COLUMN IF NOT EXISTS ban_until DATETIME DEFAULT NULL`);
        console.log('✅ Ban alanları eklendi');

        // Settings'e yeni ayarlar ekle
        await db.query(`INSERT IGNORE INTO settings (key_name, value) VALUES ('max_comment_length', '100')`);
        await db.query(`INSERT IGNORE INTO settings (key_name, value) VALUES ('max_daily_comments', '50')`);
        console.log('✅ Yorum ayarları eklendi');

        console.log('✅ Tüm migration tamamlandı!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Hata:', error);
        process.exit(1);
    }
}

migrate();
