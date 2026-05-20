const db = require('./db');

async function run() {
    try {
        await db.query("UPDATE daily_quests SET is_active = 0 WHERE quest_type = 'steps'");
        
        // Insert new step quests
        const queries = [
            ['steps_2k', '2.000 adım at', 'Güne enerjik başla!', 2000, 2, 2, 'easy', 'steps'],
            ['steps_2_5k', '2.500 adım at', 'Küçük bir yürüyüş her zaman iyidir.', 2500, 2, 2, 'easy', 'steps'],
            ['steps_3k', '3.000 adım at', 'Adımlarını hızlandır!', 3000, 3, 3, 'easy', 'steps'],
            ['steps_3_5k', '3.500 adım at', 'Harika gidiyorsun!', 3500, 3, 3, 'easy', 'steps'],
            ['steps_4k', '4.000 adım at', 'Günlük rutini yakala.', 4000, 4, 4, 'easy', 'steps'],

            ['steps_4_5k', '4.500 adım at', 'Ortalamanın üzerine çık!', 4500, 4, 4, 'medium', 'steps'],
            ['steps_5k', '5.000 adım at', 'Yolun yarısı bitti!', 5000, 5, 5, 'medium', 'steps'],
            ['steps_5_5k', '5.500 adım at', 'Durmak yok, yola devam.', 5500, 5, 5, 'medium', 'steps'],
            ['steps_6k', '6.000 adım at', 'Sağlığın için güzel bir adım.', 6000, 6, 6, 'medium', 'steps'],
            ['steps_6_5k', '6.500 adım at', 'Harika bir performans.', 6500, 6, 6, 'hard', 'steps'],

            ['steps_7k', '7.000 adım at', 'Çok iyi gidiyorsun!', 7000, 7, 7, 'hard', 'steps'],
            ['steps_7_5k', '7.500 adım at', 'Neredeyse hedefine ulaşıyorsun.', 7500, 7, 7, 'hard', 'steps'],
            ['steps_8k', '8.000 adım at', 'Zorlu bir görev!', 8000, 8, 8, 'hard', 'steps'],
            ['steps_8_5k', '8.500 adım at', 'Gerçekten inanılmaz!', 8500, 8, 8, 'hard', 'steps'],
            ['steps_9k', '9.000 adım at', 'Sınırları zorla!', 9000, 9, 9, 'hard', 'steps'],
            ['steps_9_5k', '9.500 adım at', 'Sadece biraz daha.', 9500, 9, 9, 'hard', 'steps'],
            ['steps_10k', '10.000 adım at', 'Efsanevi 10 bin adım barajı!', 10000, 10, 10, 'hard', 'steps']
        ];

        for (const q of queries) {
            await db.query(
                "INSERT INTO daily_quests (quest_key, title, description, target_value, reward_points, reward_xp, difficulty, quest_type, is_active) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1) ON DUPLICATE KEY UPDATE target_value = VALUES(target_value), is_active = 1, title = VALUES(title), reward_points = VALUES(reward_points), reward_xp = VALUES(reward_xp), difficulty = VALUES(difficulty)",
                q
            );
        }
        
        console.log("Quests updated");
    } catch (e) {
        console.error(e);
    }
    process.exit(0);
}
run();
