const db = require('./db');

async function migrate() {
    try {
        // 1. user_devices tablosu
        await db.execute(`
            CREATE TABLE IF NOT EXISTS user_devices (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36) NOT NULL,
                device_id VARCHAR(255) NOT NULL,
                device_model VARCHAR(255),
                registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                is_active BOOLEAN DEFAULT TRUE,
                UNIQUE KEY unique_device (device_id),
                INDEX idx_user (user_id),
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `);
        console.log('✅ user_devices tablosu oluşturuldu.');

        // 2. StepSync tablosuna device_id kolonu ekle
        try {
            await db.execute(`ALTER TABLE StepSync ADD COLUMN device_id VARCHAR(255) DEFAULT NULL`);
            console.log('✅ StepSync tablosuna device_id kolonu eklendi.');
        } catch (e) {
            if (e.code === 'ER_DUP_FIELDNAME') {
                console.log('ℹ️ StepSync.device_id zaten mevcut.');
            } else throw e;
        }

        // 3. Steps tablosuna is_suspicious kolonu ekle
        try {
            await db.execute(`ALTER TABLE Steps ADD COLUMN is_suspicious BOOLEAN DEFAULT FALSE`);
            console.log('✅ Steps tablosuna is_suspicious kolonu eklendi.');
        } catch (e) {
            if (e.code === 'ER_DUP_FIELDNAME') {
                console.log('ℹ️ Steps.is_suspicious zaten mevcut.');
            } else throw e;
        }

        // 4. Settings tablosuna anti-cheat ayarları ekle
        const antiCheatSettings = [
            ['max_steps_per_hour', '15000'],
            ['max_steps_per_day', '50000'],
            ['max_syncs_per_day', '20'],
            ['anticheat_enabled', '1'],
        ];

        for (const [key, value] of antiCheatSettings) {
            await db.execute(`
                INSERT IGNORE INTO settings (key_name, value) 
                VALUES (?, ?)
            `, [key, value]);
        }
        console.log('✅ Anti-cheat ayarları eklendi.');

        console.log('\n🎉 Migration tamamlandı!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration hatası:', error);
        process.exit(1);
    }
}

migrate();
