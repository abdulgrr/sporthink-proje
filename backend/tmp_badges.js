require('dotenv').config();
const db = require('./db');
async function run() {
    try {
        await db.query("INSERT IGNORE INTO badges (name, description, requirement_type, requirement_value, image_url) VALUES ('Popüler', '10 takipçiye ulaş.', 'follower_count', 10, '🏆'), ('Şampiyon', 'Haftalık sıralamada ilk 3''e gir.', 'weekly_rank', 3, '👑')");
        console.log('Badges inserted');
    } catch (e) {
        console.error(e);
    }
    process.exit(0);
}
run();
