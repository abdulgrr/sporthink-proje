const db = require('./db');

async function migrate() {
    try {
        console.log('1. Eski görevler ve ilerlemeler temizleniyor...');
        await db.query(`DELETE FROM user_quest_progress`);
        await db.query(`DELETE FROM daily_quests`);
        console.log('   ✅ Eski görev verileri temizlendi.');

        console.log('2. Yeni, dengeli görev havuzu ekleniyor...');
        
        const quests = [
            // KOLAY (🟢 - Yeşil)
            ['steps_3000', '3.000 adım at', 'Sağlıklı bir güne başlamak için iyi bir adım!', 3000, 3, 3, 'easy', 'steps'],
            ['steps_5000', '5.000 adım at', '5.000 adımlık hedefi tamamla!', 5000, 5, 5, 'easy', 'steps'],
            ['sync_steps', 'Adımlarını eşitle', 'Uygulamaya girip güncel adımlarını sunucuya gönder.', 1, 2, 2, 'easy', 'sync'],
            ['leaderboard', 'Sıralamaya göz at', 'Acaba bugün kaçıncı sıradasın? Liderlik tablosuna bak.', 1, 2, 2, 'easy', 'leaderboard'],
            
            // ORTA (🟠 - Turuncu)
            ['steps_8000', '8.000 adım at', 'Günün çoğunu hareketli geçiriyorsun!', 8000, 8, 8, 'medium', 'steps'],
            ['steps_10k', '10.000 adım at', 'Efsanevi 10 bin adım barajı!', 10000, 10, 10, 'medium', 'steps'],
            ['open_chest', 'Bir sandık aç', 'Dükkandan günlük veya haftalık sandığını aç.', 1, 5, 5, 'medium', 'open_chest'],
            ['follow_user', 'Birini takip et', 'Sosyalleşmek güzeldir, yeni birini takip et.', 1, 5, 5, 'medium', 'follow'],
            
            // ZOR (🔴 - Kırmızı)
            ['steps_12k', '12.000 adım at', 'İnanılmaz bir performans!', 12000, 12, 12, 'hard', 'steps'],
            ['steps_15k', '15.000 adım at', 'Bugün durmak bilmiyorsun!', 15000, 15, 15, 'hard', 'steps'],
            ['shop_buy', 'Dükkandan harcama yap', 'Puanlarını kullanma zamanı! Dükkandan bir ürün al.', 1, 20, 20, 'hard', 'shop_buy'],
            ['inventory_use', 'Envanterinden eşya kullan', 'Ödüllerini değerlendir! Envanterindeki bir eşyayı kullan.', 1, 15, 15, 'hard', 'inventory_use']
        ];

        for (const q of quests) {
            await db.query(
                `INSERT INTO daily_quests (quest_key, title, description, target_value, reward_points, reward_xp, difficulty, quest_type) VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
                q
            );
        }
        console.log(`   ✅ ${quests.length} yeni görev eklendi.`);

        console.log('\n🎉 V4 Migration tamamlandı!');
    } catch (e) {
        console.error('Migration hatası:', e);
    } finally {
        process.exit();
    }
}

migrate();
