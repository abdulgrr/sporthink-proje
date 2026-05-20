const db = require('./db');

async function migrate() {
    try {
        // 1. user_devices tablosuna week_start kolonu ekle
        try {
            await db.execute(`ALTER TABLE user_devices ADD COLUMN week_start DATE DEFAULT NULL`);
            console.log('✅ user_devices.week_start kolonu eklendi.');
        } catch (e) {
            if (e.code === 'ER_DUP_FIELDNAME') console.log('ℹ️ week_start zaten mevcut.');
            else throw e;
        }

        // 2. UNIQUE kısıtlamasını kaldır (artık haftalık bazda kontrol edeceğiz)
        try {
            await db.execute(`ALTER TABLE user_devices DROP INDEX unique_device`);
            console.log('✅ Eski unique_device kısıtlaması kaldırıldı.');
        } catch (e) {
            console.log('ℹ️ unique_device kısıtlaması zaten yok veya farklı isimde.');
        }

        // 3. Yeni composite unique ekle (device_id + week_start)
        try {
            await db.execute(`ALTER TABLE user_devices ADD UNIQUE INDEX unique_device_week (device_id, week_start)`);
            console.log('✅ Yeni unique_device_week kısıtlaması eklendi.');
        } catch (e) {
            if (e.code === 'ER_DUP_KEYNAME') console.log('ℹ️ unique_device_week zaten mevcut.');
            else throw e;
        }

        console.log('\n🎉 Migration tamamlandı!');
        process.exit(0);
    } catch (error) {
        console.error('❌ Migration hatası:', error);
        process.exit(1);
    }
}

migrate();
