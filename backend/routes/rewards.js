const express = require('express');
const crypto = require('crypto');
const db = require('../db');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.get('/', authMiddleware, async (req, res) => {
    try {
        const [rewards] = await db.query('SELECT id, title, type, required_points, stock FROM Rewards WHERE is_active = TRUE');
        res.status(200).json(rewards);
    } catch (error) {
        console.error('Ödül listeleme hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

router.post('/redeem', authMiddleware, async (req, res) => {
    const userId = req.user.id;
    const { reward_id } = req.body;
    const connection = await db.getConnection();

    try {
        await connection.beginTransaction();

        const [rewards] = await connection.query('SELECT * FROM Rewards WHERE id = ? AND is_active = TRUE FOR UPDATE', [reward_id]);
        if (rewards.length === 0) {
            await connection.rollback();
            return res.status(404).json({ message: 'Ödül bulunamadı veya aktif değil.' });
        }

        const reward = rewards[0];
        const [users] = await connection.query('SELECT total_points FROM Users WHERE id = ? FOR UPDATE', [userId]);
        const user = users[0];

        if (!user || user.total_points < reward.required_points) {
            await connection.rollback();
            return res.status(400).json({ message: 'Bu ödül için puanınız yetersiz.' });
        }

        if (reward.stock !== null && reward.stock <= 0) {
            await connection.rollback();
            return res.status(400).json({ message: 'Maalesef bu ödülün stoğu tükenmiş.' });
        }

        await connection.query('UPDATE Users SET total_points = total_points - ? WHERE id = ?', [reward.required_points, userId]);
        await connection.query(
            'INSERT INTO PointsLedger (id, user_id, type, points, source, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
            [crypto.randomUUID(), userId, 'spend', reward.required_points, 'reward', reward.id]
        );
        await connection.query(
            'INSERT INTO UserRewards (id, user_id, reward_id, points_spent, status) VALUES (?, ?, ?, ?, ?)',
            [crypto.randomUUID(), userId, reward.id, reward.required_points, 'issued']
        );

        if (reward.stock !== null) {
            await connection.query('UPDATE Rewards SET stock = stock - 1 WHERE id = ?', [reward.id]);
        }

        await connection.commit();
        res.status(200).json({ message: 'Ödül başarıyla alındı!', points_spent: reward.required_points });
    } catch (error) {
        await connection.rollback();
        console.error('Ödül alma hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    } finally {
        connection.release();
    }
});

module.exports = router;