const db = require('./db');

async function setupTables() {
    try {
        console.log('Creating chest_drops table...');
        await db.query(`
            CREATE TABLE IF NOT EXISTS chest_drops (
                id INT AUTO_INCREMENT PRIMARY KEY,
                chest_name VARCHAR(50) NOT NULL,
                reward_type VARCHAR(50) NOT NULL,
                reward_value VARCHAR(255) NOT NULL,
                probability_percent DECIMAL(5,2) NOT NULL DEFAULT 0.00
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
        `);
        console.log('Table chest_drops created successfully!');
    } catch (e) {
        console.error('Error setting up tables:', e);
    } finally {
        process.exit();
    }
}
setupTables();
