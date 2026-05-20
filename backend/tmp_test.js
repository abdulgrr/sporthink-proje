const db = require('./db');

async function test() {
    try {
        // Yeni sorgu (is_valid filtresiz)
        const [res] = await db.query(`
            SELECT u.id, u.first_name, SUM(s.step_count) as total_score
            FROM users u
            JOIN steps s ON u.id = s.user_id
            WHERE YEARWEEK(s.day, 1) = YEARWEEK(CURDATE(), 1)
            GROUP BY u.id
            ORDER BY total_score DESC
            LIMIT 10
        `);
        console.log("Leaderboard sonucu:", res);
    } catch(e) {
        console.error(e);
    }
    process.exit(0);
}
test();
