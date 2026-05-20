const express = require('express');
const crypto = require('crypto');
const db = require('../db');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

// GET /api/avatar/items — Tüm avatar parçalarını getir (kullanıcının sahiplik durumuyla)
router.get('/items', authMiddleware, async (req, res) => {
    try {
        const userId = req.user.id;

        const [items] = await db.query(`
            SELECT 
                ai.item_key,
                ai.category,
                ai.display_name,
                ai.price,
                ai.is_default,
                CASE WHEN uai.id IS NOT NULL THEN TRUE ELSE FALSE END AS owned
            FROM avatar_items ai
            LEFT JOIN user_avatar_items uai ON ai.item_key = uai.item_key AND uai.user_id = ?
            WHERE ai.is_active = TRUE
            ORDER BY ai.category, ai.price ASC, ai.display_name ASC
        `, [userId]);

        // Kategorilere böl
        const grouped = { eyes: [], mouth: [], head: [] };
        items.forEach(item => {
            if (grouped[item.category]) {
                grouped[item.category].push({
                    item_key: item.item_key,
                    display_name: item.display_name,
                    price: item.price,
                    is_default: item.is_default === 1,
                    owned: item.owned === 1
                });
            }
        });

        // Kullanıcının mevcut avatar config'ini de gönder
        const [user] = await db.query('SELECT avatar_url FROM users WHERE id = ?', [userId]);
        let avatarConfig = { skin: 1, eyes: 'goz_normal', mouth: 'agiz_mutlu', head: null };
        try {
            if (user[0] && user[0].avatar_url) {
                avatarConfig = JSON.parse(user[0].avatar_url);
            }
        } catch (e) { /* default kalır */ }

        res.status(200).json({
            items: grouped,
            current_config: avatarConfig
        });
    } catch (error) {
        console.error('Avatar items hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// POST /api/avatar/save — Avatar config'ini kaydet
router.post('/save', authMiddleware, async (req, res) => {
    try {
        const userId = req.user.id;
        const { skin, eyes, mouth, head } = req.body;

        // Sahiplik kontrolü - kullanıcı bu parçalara sahip mi?
        const partsToCheck = [eyes, mouth];
        if (head) partsToCheck.push(head);

        const placeholders = partsToCheck.map(() => '?').join(',');
        const [owned] = await db.query(
            `SELECT item_key FROM user_avatar_items WHERE user_id = ? AND item_key IN (${placeholders})`,
            [userId, ...partsToCheck]
        );

        const ownedKeys = owned.map(o => o.item_key);
        for (const part of partsToCheck) {
            if (!ownedKeys.includes(part)) {
                return res.status(403).json({ message: `Bu parçaya sahip değilsin: ${part}` });
            }
        }

        const config = JSON.stringify({ skin, eyes, mouth, head: head || null });
        await db.query('UPDATE users SET avatar_url = ? WHERE id = ?', [config, userId]);

        res.status(200).json({ message: 'Avatar kaydedildi.', config: { skin, eyes, mouth, head: head || null } });
    } catch (error) {
        console.error('Avatar save hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// POST /api/avatar/buy — Avatar parçası satın al
router.post('/buy', authMiddleware, async (req, res) => {
    const connection = await db.getConnection();
    try {
        const userId = req.user.id;
        const { item_key } = req.body;

        await connection.beginTransaction();

        // Parça var mı ve aktif mi?
        const [items] = await connection.query(
            'SELECT * FROM avatar_items WHERE item_key = ? AND is_active = TRUE',
            [item_key]
        );
        if (items.length === 0) {
            await connection.rollback();
            return res.status(404).json({ message: 'Parça bulunamadı.' });
        }
        const item = items[0];

        // Zaten sahip mi?
        const [existing] = await connection.query(
            'SELECT id FROM user_avatar_items WHERE user_id = ? AND item_key = ?',
            [userId, item_key]
        );
        if (existing.length > 0) {
            await connection.rollback();
            return res.status(400).json({ message: 'Bu parçaya zaten sahipsin.' });
        }

        // Ücretsiz mi?
        if (item.price === 0) {
            await connection.query(
                'INSERT INTO user_avatar_items (id, user_id, item_key) VALUES (?, ?, ?)',
                [crypto.randomUUID(), userId, item_key]
            );
            await connection.commit();
            return res.status(200).json({ message: 'Parça eklendi.', price: 0 });
        }

        // Puan yeterli mi?
        const [user] = await connection.query('SELECT total_points FROM users WHERE id = ? FOR UPDATE', [userId]);
        if (user[0].total_points < item.price) {
            await connection.rollback();
            return res.status(400).json({ message: 'Yeterli puanın yok.', required: item.price, current: user[0].total_points });
        }

        // Puan düş + sahiplik ekle
        await connection.query('UPDATE users SET total_points = total_points - ? WHERE id = ?', [item.price, userId]);
        await connection.query(
            'INSERT INTO user_avatar_items (id, user_id, item_key) VALUES (?, ?, ?)',
            [crypto.randomUUID(), userId, item_key]
        );
        await connection.query(
            'INSERT INTO PointsLedger (id, user_id, type, points, source, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            [crypto.randomUUID(), userId, 'spend', item.price, 'avatar_purchase', item_key]
        );

        await connection.commit();
        res.status(200).json({
            message: `${item.display_name} satın alındı!`,
            price: item.price,
            remaining_points: user[0].total_points - item.price
        });
    } catch (error) {
        await connection.rollback();
        console.error('Avatar buy hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    } finally {
        connection.release();
    }
});

module.exports = router;
