const db = require('./db');

async function migrate() {
    try {
        await db.query(`
            CREATE TABLE IF NOT EXISTS Tips (
                id INT AUTO_INCREMENT PRIMARY KEY,
                text TEXT NOT NULL,
                is_active BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);
        console.log("Tips table created.");

        // Check if empty
        const [rows] = await db.query('SELECT COUNT(*) as count FROM Tips');
        if (rows[0].count === 0) {
            await db.query(`
                INSERT INTO Tips (text) VALUES
                ('Her gün en az 10.000 adım atmak kalp sağlığını destekler.'),
                ('Düzenli yürüyüş yapmak stresi azaltır ve ruh halini iyileştirir.'),
                ('Günde en az 2 litre su içmeyi unutma! Su, metabolizmanı hızlandırır.'),
                ('Adımlarını seriye (streak) dönüştürerek daha fazla puan kazanabilirsin.'),
                ('Haftalık sandıkları açmak için pazar günlerini kaçırma!')
            `);
            console.log("Initial tips seeded.");
        }
    } catch (e) {
        console.error("Migration error:", e);
    } finally {
        process.exit();
    }
}
migrate();
