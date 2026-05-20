const db = require('./db');
async function run() {
    try {
        await db.execute("INSERT IGNORE INTO settings (key_name, value) VALUES ('daily_chest_price_points', '0'), ('weekly_chest_price_points', '500')");
        console.log('DB settings added.');
    } catch(e){
        console.error(e);
    }
    process.exit(0);
}
run();
