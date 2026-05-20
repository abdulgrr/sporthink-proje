const db = require('./db');

async function migrate() {
    try {
        console.log('1. notifications tablosu oluşturuluyor...');
        await db.query(`
            CREATE TABLE IF NOT EXISTS notifications (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36) NULL,
                title VARCHAR(255) NOT NULL,
                message TEXT NOT NULL,
                type VARCHAR(50) DEFAULT 'system',
                is_read BOOLEAN DEFAULT FALSE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `);
        console.log('   ✅ notifications tablosu başarıyla oluşturuldu.');

        console.log('\n🎉 V5 Migration tamamlandı!');
    } catch (e) {
        console.error('Migration hatası:', e);
    } finally {
        process.exit();
    }
}

migrate();
