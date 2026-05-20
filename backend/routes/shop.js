const express = require('express');
const crypto = require('crypto');
const db = require('../db');
const authMiddleware = require('../middleware/authMiddleware');
const { progressQuest } = require('../utils/questHelper');

const router = express.Router();

// 1. Dükkan Listesi (Ürünler ve Sandık Fiyatları + Kullanıcı Puanı)
router.get('/', authMiddleware, async (req, res) => {
    const userId = req.user.id;
    try {
        const [products] = await db.query('SELECT * FROM products WHERE is_active = TRUE ORDER BY id DESC');
        
        const [settingsDB] = await db.query("SELECT key_name, value FROM settings WHERE key_name IN ('daily_chest_price_points', 'weekly_chest_price_points')");
        let chestPrices = { daily: 0, weekly: 500 };
        settingsDB.forEach(s => {
            if (s.key_name === 'daily_chest_price_points') chestPrices.daily = parseInt(s.value);
            if (s.key_name === 'weekly_chest_price_points') chestPrices.weekly = parseInt(s.value);
        });

        const [users] = await db.query('SELECT total_points FROM users WHERE id = ?', [userId]);
        const userPoints = users[0] ? users[0].total_points : 0;

        // Sandık bekleme süreleri
        const [dailyLedger] = await db.query(
            "SELECT created_at FROM pointsledger WHERE user_id = ? AND source = 'chest_open' AND ref_id = 'daily' ORDER BY created_at DESC LIMIT 1",
            [userId]
        );
        const [weeklyLedger] = await db.query(
            "SELECT created_at FROM pointsledger WHERE user_id = ? AND source = 'chest_open' AND ref_id = 'weekly' ORDER BY created_at DESC LIMIT 1",
            [userId]
        );

        res.status(200).json({
            user_points: userPoints,
            products: products,
            chest_prices: chestPrices,
            chest_cooldowns: {
                daily: dailyLedger[0] ? dailyLedger[0].created_at : null,
                weekly: weeklyLedger[0] ? weeklyLedger[0].created_at : null
            }
        });
    } catch (error) {
        console.error('Shop fetch error:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// 2. Ürün / Kupon Satın Alma
router.post('/buy_product', authMiddleware, async (req, res) => {
    const userId = req.user.id;
    const { product_id } = req.body;
    const connection = await db.getConnection();

    try {
        await connection.beginTransaction();

        const [products] = await connection.query('SELECT * FROM products WHERE id = ? AND is_active = TRUE FOR UPDATE', [product_id]);
        if (products.length === 0) {
            await connection.rollback();
            return res.status(404).json({ message: 'Ürün bulunamadı veya aktif değil.' });
        }
        const product = products[0];

        const [users] = await connection.query('SELECT total_points FROM users WHERE id = ? FOR UPDATE', [userId]);
        const user = users[0];

        if (!user || user.total_points < product.price_points) {
            await connection.rollback();
            return res.status(400).json({ message: 'Bu ürün için puanınız yetersiz.' });
        }

        // Puanı düş
        await connection.query('UPDATE users SET total_points = total_points - ? WHERE id = ?', [product.price_points, userId]);
        
        // Ledger a yaz
        await connection.query(
            'INSERT INTO pointsledger (id, user_id, type, points, source, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            [crypto.randomUUID(), userId, 'spend', product.price_points, 'shop_purchase', String(product.id)]
        );
        
        // Envantere ekle
        await connection.query(
            'INSERT INTO userrewards (id, user_id, reward_id, points_spent, status, title) VALUES (?, ?, ?, ?, ?, ?)',
            [crypto.randomUUID(), userId, `product_${product.id}`, product.price_points, 'issued', product.name]
        );

        await connection.commit();

        // Görev ilerlemesi
        progressQuest(userId, 'shop_buy').catch(console.error);

        res.status(200).json({ message: 'Ürün başarıyla satın alındı!', new_balance: user.total_points - product.price_points });
    } catch (error) {
        await connection.rollback();
        console.error('Buy product err:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    } finally {
        connection.release();
    }
});

// 3. Sandık Açma (RNG Mantığı)
router.post('/open_chest', authMiddleware, async (req, res) => {
    const userId = req.user.id;
    const { chest_type } = req.body; // 'daily' veya 'weekly'
    const connection = await db.getConnection();

    try {
        await connection.beginTransaction();

        // 1. Sandık fiyatını al
        const priceKey = chest_type === 'daily' ? 'daily_chest_price_points' : 'weekly_chest_price_points';
        const [settingsDB] = await connection.query('SELECT value FROM settings WHERE key_name = ?', [priceKey]);
        const chestPrice = settingsDB[0] ? parseInt(settingsDB[0].value) : (chest_type === 'daily' ? 0 : 500);

        // 2. Kullanıcının puanını kontrol et
        const [users] = await connection.query('SELECT total_points FROM users WHERE id = ? FOR UPDATE', [userId]);
        const user = users[0];

        if (!user || user.total_points < chestPrice) {
            await connection.rollback();
            return res.status(400).json({ message: 'Bu sandığı açmak için yeterli puanınız yok.' });
        }

        // 3. İhtimalleri al
        const [drops] = await connection.query('SELECT * FROM chest_drops WHERE chest_name = ?', [chest_type]);
        if (drops.length === 0) {
            await connection.rollback();
            return res.status(400).json({ message: 'Sandık içeriği ayarlanmamış.' });
        }

        // 3.5. COOLDOWN KONTROLÜ (Günlük 24 saat, Haftalık 7 gün)
        const cooldownDays = chest_type === 'daily' ? 1 : 7;
        const [recentOpens] = await connection.query(
            "SELECT id FROM pointsledger WHERE user_id = ? AND source = 'chest_open' AND ref_id = ? AND created_at >= NOW() - INTERVAL ? DAY", 
            [userId, chest_type, cooldownDays]
        );
        if (recentOpens.length > 0) {
            await connection.rollback();
            const message = chest_type === 'daily' 
                ? 'Günlük sandığını son 24 saat içerisinde zaten açtınız.' 
                : 'Haftalık sandığını son 7 gün içerisinde zaten açtınız.';
            return res.status(400).json({ message });
        }


        // 4. Puan kesintisi ve Loglama
        if (chestPrice > 0) {
            await connection.query('UPDATE users SET total_points = total_points - ? WHERE id = ?', [chestPrice, userId]);
        }
        
        // Bedava bile olsa açılışı kaydet ki cooldown çalışsın
        await connection.query(
            'INSERT INTO pointsledger (id, user_id, type, points, source, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            [crypto.randomUUID(), userId, 'spend', chestPrice, 'chest_open', chest_type]
        );

        // 5. RNG Zar atma (0.00 ile 100.00 arası)
        const randomRoll = Math.random() * 100;
        let cumulative = 0;
        let selectedDrop = null;

        for (const drop of drops) {
            cumulative += parseFloat(drop.probability_percent);
            if (randomRoll <= cumulative) {
                selectedDrop = drop;
                break;
            }
        }
        
        // Eğer hiçbirine düşmezse (toplam yüzdeler 100 değilse), boş geçmemesi için sonuncuyu al veya şanssız de
        if (!selectedDrop) {
            // Şanssızlık veya konfig eksikliği durumu
            await connection.commit();
            return res.status(200).json({ drop_type: 'empty', message: 'Sandıktan hiçbir şey çıkmadı :(' });
        }

        // 6. Ödülü Ver
        if (selectedDrop.reward_type === 'points') {
            const pointsToGive = parseInt(selectedDrop.reward_value);
            await connection.query('UPDATE users SET total_points = total_points + ?, xp = xp + ? WHERE id = ?', [pointsToGive, pointsToGive, userId]);
            await connection.query(
                'INSERT INTO pointsledger (id, user_id, type, points, source, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
                [crypto.randomUUID(), userId, 'earn', pointsToGive, 'chest_reward', String(selectedDrop.id)]
            );
            await connection.commit();
            progressQuest(userId, 'open_chest').catch(console.error);
            return res.status(200).json({ drop_type: 'points', message: `Tebrikler! ${pointsToGive} Puan Çıktı!`, value: pointsToGive });
        } else {
            // product, raffle, coupon etc.
            await connection.query(
                'INSERT INTO userrewards (id, user_id, reward_id, points_spent, status, title) VALUES (?, ?, ?, ?, ?, ?)',
                [crypto.randomUUID(), userId, `chest_${selectedDrop.id}`, chestPrice, 'issued', selectedDrop.reward_value]
            );
            await connection.commit();
            progressQuest(userId, 'open_chest').catch(console.error);
            return res.status(200).json({ drop_type: 'item', message: `Tebrikler! ${selectedDrop.reward_value} Çıktı!`, value: selectedDrop.reward_value });
        }
    } catch (error) {
        await connection.rollback();
        console.error('Chest open err:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    } finally {
        connection.release();
    }
});

// 4. Envanter (Kullanıcının Sahip Oldukları)
router.get('/inventory', authMiddleware, async (req, res) => {
    const userId = req.user.id;
    try {
        const [inventory] = await db.query(`
            SELECT id, title as name, status, coupon_code, created_at 
            FROM userrewards 
            WHERE user_id = ? 
            ORDER BY created_at DESC
        `, [userId]);
        
        res.status(200).json(inventory);
    } catch (error) {
        console.error('Inventory list err:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// 5. Kupon Kullan (Göstermelik Kupon Kodu Verir)
router.post('/use_item', authMiddleware, async (req, res) => {
    const userId = req.user.id;
    const { inventory_id } = req.body;
    
    try {
        const [items] = await db.query('SELECT * FROM userrewards WHERE id = ? AND user_id = ?', [inventory_id, userId]);
        if (items.length === 0) return res.status(404).json({ message: 'Eşya bulunamadı.' });
        
        const item = items[0];
        if (item.status === 'used') {
            return res.status(400).json({ message: 'Bu eşya daha önce kullanılmış.', coupon_code: item.coupon_code });
        }

        // Rastgele Göstermelik Kod (Örn: SPOR-1A2B3C)
        const fakeCode = 'SPOR-' + crypto.randomUUID().substring(0,6).toUpperCase();

        await db.query('UPDATE userrewards SET status = ?, used_at = NOW(), coupon_code = ? WHERE id = ?', ['used', fakeCode, inventory_id]);

        progressQuest(userId, 'inventory_use').catch(console.error);

        res.status(200).json({ message: 'Kupon kodu başarıyla oluşturuldu!', coupon_code: fakeCode });
    } catch (error) {
        console.error('Use item err:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

module.exports = router;
