const crypto = require('crypto');
const db = require('./db');

async function migrate() {
    const connection = await db.getConnection();
    try {
        console.log('🚀 Avatar sistemi migration başlıyor...');
        await connection.beginTransaction();

        // 1. avatar_items tablosu
        await connection.query(`
            CREATE TABLE IF NOT EXISTS avatar_items (
                id VARCHAR(36) PRIMARY KEY,
                category ENUM('eyes', 'mouth', 'head') NOT NULL,
                item_key VARCHAR(50) NOT NULL UNIQUE,
                display_name VARCHAR(100),
                price INT DEFAULT 0,
                is_default BOOLEAN DEFAULT FALSE,
                is_active BOOLEAN DEFAULT TRUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        `);
        console.log('✅ avatar_items tablosu oluşturuldu.');

        // 2. user_avatar_items tablosu (sahiplik)
        await connection.query(`
            CREATE TABLE IF NOT EXISTS user_avatar_items (
                id VARCHAR(36) PRIMARY KEY,
                user_id VARCHAR(36) NOT NULL,
                item_key VARCHAR(50) NOT NULL,
                purchased_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_user_item (user_id, item_key),
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `);
        console.log('✅ user_avatar_items tablosu oluşturuldu.');

        // 3. social_reactions tablosu
        await connection.query(`
            CREATE TABLE IF NOT EXISTS social_reactions (
                id VARCHAR(36) PRIMARY KEY,
                feed_id VARCHAR(36) NOT NULL,
                user_id VARCHAR(36) NOT NULL,
                reaction_type VARCHAR(10) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE KEY unique_reaction (feed_id, user_id),
                FOREIGN KEY (feed_id) REFERENCES social_feed(id) ON DELETE CASCADE,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
            )
        `);
        console.log('✅ social_reactions tablosu oluşturuldu.');

        // 4. Avatar parçalarını ekle (IGNORE = zaten varsa atla)
        const items = [
            // === GÖZLER ===
            // Ücretsiz
            { category: 'eyes', key: 'goz_normal',        name: 'Normal',     price: 0, is_default: true },
            { category: 'eyes', key: 'goz_anime',         name: 'Anime',      price: 0, is_default: false },
            { category: 'eyes', key: 'goz_kedi',          name: 'Kedi',       price: 0, is_default: false },
            { category: 'eyes', key: 'goz_gozluk',        name: 'Gözlük',     price: 0, is_default: false },
            { category: 'eyes', key: 'goz_kizgin',        name: 'Kızgın',     price: 0, is_default: false },
            { category: 'eyes', key: 'goz_sevinc',        name: 'Sevinç',     price: 0, is_default: false },
            { category: 'eyes', key: 'goz_olu',           name: 'X_X',        price: 0, is_default: false },
            // Ücretli
            { category: 'eyes', key: 'goz_kalp',          name: 'Kalp',       price: 300, is_default: false },
            { category: 'eyes', key: 'goz_didyouseethat', name: 'Yan Bakış',  price: 300, is_default: false },
            { category: 'eyes', key: 'goz_uyku',          name: 'Uykulu',     price: 200, is_default: false },
            { category: 'eyes', key: 'goz_uzgun',         name: 'Üzgün',      price: 200, is_default: false },
            { category: 'eyes', key: 'goz_kirpma',        name: 'Kırpma',     price: 250, is_default: false },

            // === AĞIZLAR ===
            // Ücretsiz
            { category: 'mouth', key: 'agiz_mutlu',       name: 'Mutlu',      price: 0, is_default: true },
            { category: 'mouth', key: 'agiz_gulumse',     name: 'Gülümse',    price: 0, is_default: false },
            { category: 'mouth', key: 'agiz_yanyatmis3',  name: ':3',         price: 0, is_default: false },
            { category: 'mouth', key: 'agiz_blehh',       name: 'Blehh',      price: 0, is_default: false },
            { category: 'mouth', key: 'agiz_duzblehh',    name: 'Düz Blehh',  price: 0, is_default: false },
            { category: 'mouth', key: 'agiz_vampir',      name: 'Vampir',     price: 0, is_default: false },
            { category: 'mouth', key: 'agiz_s',           name: 'S',          price: 0, is_default: false },
            { category: 'mouth', key: 'agiz_uzgun',       name: 'Üzgün',      price: 0, is_default: false },
            { category: 'mouth', key: 'agiz_roblox',      name: 'Roblox',     price: 0, is_default: false },
            { category: 'mouth', key: 'agiz_altindis',    name: 'Altın Diş',  price: 0, is_default: false },
            // Ücretli
            { category: 'mouth', key: 'agiz_sasir',       name: 'Şaşkın',     price: 300, is_default: false },
            { category: 'mouth', key: 'agiz_dissikma',    name: 'Diş Sıkma',  price: 250, is_default: false },
            { category: 'mouth', key: 'agiz_fermuar',     name: 'Fermuar',     price: 350, is_default: false },
            { category: 'mouth', key: 'agiz_biyik',       name: 'Bıyık',      price: 200, is_default: false },
            { category: 'mouth', key: 'agiz_ummactually', name: 'Umm..',      price: 250, is_default: false },

            // === KAFA/ŞAPKA ===
            // Ücretsiz
            { category: 'head', key: 'kafa_tac',          name: 'Taç',        price: 0, is_default: false },
            { category: 'head', key: 'kafa_seytan',       name: 'Şeytan',     price: 0, is_default: false },
            { category: 'head', key: 'kafa_boynuz',       name: 'Boynuz',     price: 0, is_default: false },
            { category: 'head', key: 'kafa_gentleman',    name: 'Gentleman',  price: 0, is_default: false },
            { category: 'head', key: 'kafa_mohawk',       name: 'Mohawk',     price: 0, is_default: false },
            { category: 'head', key: 'kafa_kedi',         name: 'Kedi Kulak', price: 0, is_default: false },
            { category: 'head', key: 'kafa_ampul',        name: 'Ampul',      price: 0, is_default: false },
            { category: 'head', key: 'kafa_itsthejuuz',   name: 'Juice',      price: 0, is_default: false },
            { category: 'head', key: 'kafa_ratatuy',      name: 'Ratatuy',    price: 0, is_default: false },
            // Ücretli
            { category: 'head', key: 'kafa_halo',         name: 'Halo',       price: 400, is_default: false },
            { category: 'head', key: 'kafa_tavsankulak',  name: 'Tavşan',     price: 350, is_default: false },
            { category: 'head', key: 'kafa_broislivin',   name: 'Bro',        price: 300, is_default: false },
            { category: 'head', key: 'kafa_huni',         name: 'Huni',       price: 250, is_default: false },
            { category: 'head', key: 'kafa_kurdele',      name: 'Kurdele',     price: 300, is_default: false },
        ];

        for (const item of items) {
            await connection.query(
                `INSERT IGNORE INTO avatar_items (id, category, item_key, display_name, price, is_default) VALUES (?, ?, ?, ?, ?, ?)`,
                [crypto.randomUUID(), item.category, item.key, item.name, item.price, item.is_default]
            );
        }
        console.log(`✅ ${items.length} avatar parçası eklendi.`);

        // 5. Mevcut kullanıcıların avatar_url alanını JSON config'e dönüştür
        const defaultConfig = JSON.stringify({ skin: 1, eyes: 'goz_normal', mouth: 'agiz_mutlu', head: null });
        await connection.query(
            `UPDATE users SET avatar_url = ? WHERE avatar_url IS NULL OR avatar_url NOT LIKE '{%'`,
            [defaultConfig]
        );
        console.log('✅ Mevcut kullanıcıların avatarları default config ile güncellendi.');

        // 6. Mevcut kullanıcılara ücretsiz parçaları otomatik ver
        const [users] = await connection.query('SELECT id FROM users');
        const [freeItems] = await connection.query('SELECT item_key FROM avatar_items WHERE price = 0');
        
        for (const user of users) {
            for (const item of freeItems) {
                await connection.query(
                    `INSERT IGNORE INTO user_avatar_items (id, user_id, item_key) VALUES (?, ?, ?)`,
                    [crypto.randomUUID(), user.id, item.item_key]
                );
            }
        }
        console.log(`✅ ${users.length} kullanıcıya ${freeItems.length} ücretsiz parça verildi.`);

        await connection.commit();
        console.log('\n🎉 Migration tamamlandı!');
    } catch (error) {
        await connection.rollback();
        console.error('❌ Migration hatası:', error);
    } finally {
        connection.release();
        process.exit(0);
    }
}

migrate();
