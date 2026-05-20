const db = require('./db');

async function run() {
    try {
        console.log('Running DB updates...');
        
        // 1. Insert new settings if not exist
        await db.query("INSERT IGNORE INTO settings (key_name, value) VALUES ('xp_difficulty_modifier', '250')");
        await db.query("INSERT IGNORE INTO settings (key_name, value) VALUES ('level_up_points_reward', '100')");
        
        // 2. Clear old 'steps' quests
        await db.query("DELETE FROM daily_quests WHERE quest_type = 'steps'");
        
        // 3. Insert specific steps quests (Easy 2500, Medium 5000, Hard 7500)
        await db.query(`
            INSERT INTO daily_quests (quest_type, quest_key, title, description, difficulty, target_value, reward_points, reward_xp) 
            VALUES 
            ('steps', 'steps_2500', '2.500 Adım', 'Bugün 2.500 adım atarak hedefe ulaş.', 'easy', 2500, 50, 50),
            ('steps', 'steps_5000', '5.000 Adım', 'Günlük 5.000 adım hedefini tamamla.', 'medium', 5000, 100, 100),
            ('steps', 'steps_7500', '7.500 Adım', 'Zorlu görev: Bugün tam 7.500 adım at!', 'hard', 7500, 200, 200)
        `);
        
        // 4. Update existing progress if any has target > 7500 or just let them reset tomorrow.
        
        console.log('DB updates completed.');
    } catch (error) {
        console.error('Error:', error);
    } finally {
        process.exit(0);
    }
}

run();
