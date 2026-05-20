const db = require('./db');

async function dumpSchema() {
    try {
        const [tables] = await db.query('SHOW TABLES');
        for (const tableRow of tables) {
            const tableName = Object.values(tableRow)[0];
            try {
                const [columns] = await db.query(`DESCRIBE ${tableName}`);
                console.log(`\nTable: ${tableName}`);
                console.table(columns.map(c => ({ Field: c.Field, Type: c.Type, Key: c.Key })));
            } catch (err) {
                console.log(`\nTable error: ${tableName} :: ${err.message}`);
            }
        }
    } catch (e) {
        console.error(e);
    } finally {
        process.exit();
    }
}
dumpSchema();
