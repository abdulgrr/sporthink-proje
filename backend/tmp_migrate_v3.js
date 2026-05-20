const db = require('./db');

async function migrate() {
    try {
        console.log('1. daily_quests tablosuna yeni sütunlar ekleniyor...');
        
        // Add difficulty column
        try {
            await db.query(`ALTER TABLE daily_quests ADD COLUMN difficulty ENUM('easy', 'medium', 'hard') NOT NULL DEFAULT 'easy'`);
            console.log('   ✅ difficulty sütunu eklendi.');
        } catch(e) {
            if(e.code !== 'ER_DUP_FIELDNAME') throw e;
        }

        // Add quest_type column
        try {
            await db.query(`ALTER TABLE daily_quests ADD COLUMN quest_type VARCHAR(50) NOT NULL DEFAULT 'other'`);
            console.log('   ✅ quest_type sütunu eklendi.');
        } catch(e) {
            if(e.code !== 'ER_DUP_FIELDNAME') throw e;
        }

        console.log('2. Eski görevler ve ilerlemeler temizleniyor...');
        // user_quest_progress referans ettiği için önce orayı silebiliriz veya truncate edebiliriz
        await db.query(`DELETE FROM user_quest_progress`);
        await db.query(`DELETE FROM daily_quests`);
        console.log('   ✅ Eski görev verileri temizlendi.');

        console.log('3. Yeni görev havuzu ekleniyor...');
        
        const quests = [
            // KOLAY
            ['easy_steps', '3.000 adım at', 'Sağlıklı bir güne başlamak için iyi bir adım!', 3000, 3, 3, 'easy', 'steps'],
            ['easy_sync', 'Adımlarını senkronize et', 'Uygulamaya girip güncel adımlarını sunucuya gönder.', 1, 2, 2, 'easy', 'sync'],
            ['easy_follow', 'Birini takip et', 'Sosyalleşmek güzeldir, yeni birini takip et.', 1, 3, 3, 'easy', 'follow'],
            
            // ORTA
            ['medium_steps', '7.500 adım at', 'Günün çoğunu hareketli geçiriyorsun!', 7500, 7, 7, 'medium', 'steps'],
            ['medium_chest', 'Bir sandık aç', 'Dükkandan günlük veya haftalık sandığını aç.', 1, 5, 5, 'medium', 'open_chest'],
            ['medium_steps_10k', '10.000 adım at', 'Efsanevi 10 bin adım barajı!', 10000, 10, 10, 'medium', 'steps'],
            
            // ZOR
            ['hard_steps', '15.000 adım at', 'Bugün durmak bilmiyorsun!', 15000, 15, 15, 'hard', 'steps'],
            ['hard_buy', 'Dükkandan alışveriş yap', 'Puanlarını harcama zamanı! Dükkandan bir ürün satın al.', 1, 20, 20, 'hard', 'shop_buy'],
            ['hard_steps_20k', '20.000 adım at', 'İnanılmaz bir performans!', 20000, 25, 25, 'hard', 'steps']
        ];

        for (const q of quests) {
            await db.query(
                `INSERT INTO daily_quests (quest_key, title, description, target_value, reward_points, reward_xp, difficulty, quest_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
                q
            );
        }
        console.log(`   ✅ ${quests.length} yeni görev eklendi.`);

        console.log('\n🎉 V3 Migration tamamlandı!');
    } catch (e) {
        console.error('Migration hatası:', e);
    } finally {
        process.exit();
    }
}

migrate();
