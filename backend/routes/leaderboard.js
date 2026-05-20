const express = require('express');
const db = require('../db');
const authMiddleware = require('../middleware/authMiddleware');
const { progressQuest } = require('../utils/questHelper');

const router = express.Router();

// HAFTALIK LİDERLİK TABLOSU (GET /api/leaderboard)
router.get('/', authMiddleware, async (req, res) => {
    try {
        const userId = req.user.id;
        const filter = req.query.filter || 'global'; // 'global' veya 'friends'

        let whereClause = `WHERE YEARWEEK(s.day, 1) = YEARWEEK(CURDATE(), 1)`;
        let queryParams = [];

        if (filter === 'friends') {
            whereClause += ` AND (u.id IN (SELECT following_id FROM follows WHERE follower_id = ?) OR u.id = ?)`;
            queryParams = [userId, userId];
        }

        const query = `
            SELECT 
                u.id, 
                u.first_name, 
                CONCAT(SUBSTRING(u.last_name, 1, 1), '.') AS last_initial, 
                u.avatar_url,
                SUM(s.step_count) AS total_score
            FROM users u
            JOIN steps s ON u.id = s.user_id
            ${whereClause}
            GROUP BY u.id
            ORDER BY total_score DESC
            LIMIT 50
        `;

        const [leaderboard] = await db.query(query, queryParams);

        // Leaderboard görüntüleme görevi ilerlemesi
        progressQuest(req.user.id, 'leaderboard').catch(console.error);

        res.status(200).json({
            message: 'Haftalık liderlik tablosu başarıyla getirildi.',
            week: 'current',
            data: leaderboard
        });

    } catch (error) {
        console.error('Liderlik Tablosu Hatası:', error);
        res.status(500).json({ message: 'Sunucu tarafında bir hata oluştu.' });
    }
});

module.exports = router;