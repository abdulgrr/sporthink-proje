const bcrypt = require('bcrypt');
const crypto = require('crypto');
const db = require('./db');

async function createAdminUser() {
    try {
        // Admin kullanıcısının var olup olmadığını kontrol et
        const [existingAdmin] = await db.query(
            'SELECT * FROM Users WHERE username = ?',
            ['admin']
        );

        if (existingAdmin.length > 0) {
            console.log('Admin kullanıcısı zaten mevcut!');
            return;
        }

        // Şifre hash'leme
        const password = 'admin123';
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // Admin kullanıcısını oluştur
        const adminId = crypto.randomUUID();
        await db.query(
            `INSERT INTO Users (id, username, first_name, last_name, email, password_hash, role, avatar_url)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
            [adminId, 'admin', 'Admin', 'User', 'admin@sporthink.com', hashedPassword, 'admin', 'https://api.dicebear.com/7.x/avataaars/svg?seed=admin']
        );

        console.log('✅ Admin kullanıcısı başarıyla oluşturuldu!');
        console.log('📝 Kullanıcı adı: admin');
        console.log('🔑 Şifre: admin123');
        console.log('🌐 Admin Panel: http://localhost:3000/admin');

    } catch (error) {
        console.error('❌ Admin kullanıcısı oluşturulurken hata:', error);
    }
}

async function createAuditLogsTable() {
    try {
        await db.query(`
            CREATE TABLE IF NOT EXISTS auditlogs (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36),
                action VARCHAR(100) NOT NULL,
                details TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                INDEX idx_user_id (user_id),
                INDEX idx_action (action),
                INDEX idx_created_at (created_at)
            ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
        `);
        console.log('✅ Auditlogs tablosu başarıyla oluşturuldu!');
    } catch (error) {
        console.error('❌ Auditlogs tablosu oluşturulurken hata:', error);
    }
}

// Script'i çalıştır
async function runSetup() {
    console.log('🚀 Admin kurulumu başlatılıyor...');

    await createAuditLogsTable();
    await createAdminUser();

    console.log('✨ Kurulum tamamlandı!');
    process.exit(0);
}

runSetup();