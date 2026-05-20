const mysql = require('mysql2');
require('dotenv').config();

// Bağlantı havuzu (pool) oluşturuyoruz ki sistem çökmesin
const pool = mysql.createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

// Bağlantıyı test edelim
pool.getConnection((err, connection) => {
    if (err) {
        console.error('Veritabanına bağlanırken hata oluştu:', err.message);
    } else {
        console.log('🔥 MySQL Veritabanına başarıyla bağlanıldı!');
        connection.release();
    }
});

// Diğer dosyalarda kullanabilmek için export ediyoruz (Promise yapısıyla)
module.exports = pool.promise();