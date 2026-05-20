const express = require('express');
const crypto = require('crypto');
const db = require('../db');
const authMiddleware = require('../middleware/authMiddleware');
const { progressQuest } = require('../utils/questHelper');
const { checkAndAwardBadges } = require('../utils/badgeHelper');

const router = express.Router();

// Seviye hesaplama (sınırsız seviye sistemi)
// Seviye N için gereken minimum XP = (N-1)^2 * 50
function calculateLevel(xp) {
    const level = Math.floor(Math.sqrt(xp / 250)) + 1;
    const minXp = Math.pow(level - 1, 2) * 250;
    const nextXp = Math.pow(level, 2) * 250;
    return { level, minXp, nextXp };
}

// 1. Kendi Profil Şöyle Göster
router.get('/', authMiddleware, async (req, res) => {
    const userId = req.user.id;
    try {
        const [users] = await db.query('SELECT id, username, first_name, last_name, avatar_url, COALESCE(current_streak, 0) as current_streak, last_step_date, total_points, xp, created_at FROM users WHERE id = ?', [userId]);
        if (users.length === 0) return res.status(404).json({ message: 'Kullanıcı bulunamadı.' });
        
        const user = users[0];

        // Takipçi sayıları
        const [followerCount] = await db.query('SELECT COUNT(*) as count FROM follows WHERE following_id = ?', [userId]);
        const [followingCount] = await db.query('SELECT COUNT(*) as count FROM follows WHERE follower_id = ?', [userId]);

        // JIT (Just-in-Time) ROZET KONTROLÜ
        await checkAndAwardBadges(userId);

        // Kazanılmış rozetleri çek formata uygun
        const [finalBadges] = await db.query(`
            SELECT b.id, b.name as title, b.image_url as iconUrl, b.description 
            FROM badges b
            JOIN user_badges ub ON b.id = ub.badge_id
            WHERE ub.user_id = ?
        `, [userId]);

        // Streak doğrulaması: last_step_date bugün veya dün değilse streak 0
        let validStreak = user.current_streak || 0;
        if (user.last_step_date) {
            const lastDate = new Date(user.last_step_date);
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            lastDate.setHours(0, 0, 0, 0);
            const diffDays = Math.floor((today - lastDate) / (1000 * 60 * 60 * 24));
            if (diffDays > 1) validStreak = 0;
        } else {
            validStreak = 0;
        }

        res.status(200).json({
            ...user,
            current_streak: validStreak,
            followers_count: followerCount[0].count,
            following_count: followingCount[0].count,
            xp: user.xp || 0,
            level_info: calculateLevel(user.xp || 0),
            badges: finalBadges 
        });
    } catch (error) {
        console.error('Profil yükleme hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// 2. Profili Güncelle
router.post('/update', authMiddleware, async (req, res) => {
    const userId = req.user.id;
    const { username, first_name, last_name, avatar_url } = req.body;
    try {
        await db.query(
            'UPDATE users SET username = ?, first_name = ?, last_name = ?, avatar_url = ? WHERE id = ?',
            [username, first_name, last_name, avatar_url, userId]
        );
        res.status(200).json({ message: 'Profil güncellendi.' });
    } catch (error) {
        if (error.code === 'ER_DUP_ENTRY') {
            return res.status(400).json({ message: 'Bu kullanıcı adı zaten alınmış!' });
        }
        console.error('Profil güncelleme hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// 3. Kullanıcı Arama
router.get('/search', authMiddleware, async (req, res) => {
    const userId = req.user.id;
    const query = req.query.q || '';
    if (query.length < 2) return res.status(200).json([]);

    try {
        const searchTerm = `%${query}%`;
        const [results] = await db.query(`
            SELECT u.id, u.username, u.first_name, u.last_name, u.avatar_url,
                   EXISTS(SELECT 1 FROM follows WHERE follower_id = ? AND following_id = u.id) as is_following
            FROM users u
            WHERE (u.username LIKE ? OR u.first_name LIKE ? OR u.last_name LIKE ?) AND u.id != ?
            LIMIT 20
        `, [userId, searchTerm, searchTerm, searchTerm, userId]);

        // Convert boolean 1/0 to true/false for JSON
        const data = results.map(r => ({
            ...r,
            is_following: r.is_following === 1
        }));
        
        res.status(200).json(data);
    } catch (error) {
        console.error('Arama hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// 4. Takip Et
router.post('/follow', authMiddleware, async (req, res) => {
    const userId = req.user.id;
    const { target_id } = req.body;
    try {
        await db.query('INSERT IGNORE INTO follows (id, follower_id, following_id) VALUES (?, ?, ?)', [crypto.randomUUID(), userId, target_id]);
        
        progressQuest(userId, 'follow').catch(console.error);

        // Takipçi milestone kontrolü (5, 10, 25, 50, 100)
        const [followerCount] = await db.query('SELECT COUNT(*) as count FROM follows WHERE following_id = ?', [target_id]);
        const count = followerCount[0].count;
        const followerMilestones = [5, 10, 25, 50, 100];
        if (followerMilestones.includes(count)) {
            await db.query(
                `INSERT INTO social_feed (id, user_id, event_type, event_data) VALUES (?, ?, 'follower_milestone', ?)`,
                [crypto.randomUUID(), target_id, JSON.stringify({ followers: count })]
            );
        }

        res.status(200).json({ message: 'Takip edildi.' });
    } catch (error) {
        res.status(500).json({ message: 'Hata.' });
    }
});

// 5. Takipten Çık
router.post('/unfollow', authMiddleware, async (req, res) => {
    const userId = req.user.id;
    const { target_id } = req.body;
    try {
        await db.query('DELETE FROM follows WHERE follower_id = ? AND following_id = ?', [userId, target_id]);
        res.status(200).json({ message: 'Takipten çıkıldı.' });
    } catch (error) {
        res.status(500).json({ message: 'Hata.' });
    }
});

// 6. Senin Takip Ettiklerin (Following)
router.get('/following', authMiddleware, async (req, res) => {
    const userId = req.user.id;
    try {
        const [results] = await db.query(`
            SELECT u.id, u.first_name, u.last_name, u.avatar_url
            FROM users u
            JOIN follows f ON u.id = f.following_id
            WHERE f.follower_id = ?
        `, [userId]);
        res.status(200).json(results);
    } catch (error) {
        res.status(500).json({ message: 'Hata.' });
    }
});

// 7. Seni Takip Edenler (Followers)
router.get('/followers', authMiddleware, async (req, res) => {
    const userId = req.user.id;
    try {
        const [results] = await db.query(`
            SELECT u.id, u.first_name, u.last_name, u.avatar_url,
                   EXISTS(SELECT 1 FROM follows f2 WHERE f2.follower_id = ? AND f2.following_id = u.id) as is_following
            FROM users u
            JOIN follows f ON u.id = f.follower_id
            WHERE f.following_id = ?
        `, [userId, userId]);
        
        const data = results.map(r => ({ ...r, is_following: r.is_following === 1 }));
        res.status(200).json(data);
    } catch (error) {
        res.status(500).json({ message: 'Hata.' });
    }
});

// 8. Başkasının Profilini (Özet) Görüntüleme
router.get('/public/:id', authMiddleware, async (req, res) => {
    const targetUserId = req.params.id;
    const myUserId = req.user.id;

    try {
        const [users] = await db.query('SELECT id, username, first_name, last_name, avatar_url, COALESCE(current_streak, 0) as current_streak, last_step_date, total_points, xp, created_at FROM users WHERE id = ?', [targetUserId]);
        if (users.length === 0) return res.status(404).json({ message: 'Kullanıcı bulunamadı.' });
        
        const targetUser = users[0];

        const [followerCount] = await db.query('SELECT COUNT(*) as count FROM follows WHERE following_id = ?', [targetUserId]);
        const [followingCount] = await db.query('SELECT COUNT(*) as count FROM follows WHERE follower_id = ?', [targetUserId]);
        
        const [followCheck] = await db.query('SELECT 1 FROM follows WHERE follower_id = ? AND following_id = ?', [myUserId, targetUserId]);
        const isFollowing = followCheck.length > 0;

        const [finalBadges] = await db.query(`
            SELECT b.id, b.name as title, b.image_url as iconUrl, b.description 
            FROM badges b
            JOIN user_badges ub ON b.id = ub.badge_id
            WHERE ub.user_id = ?
        `, [targetUserId]);

        // Streak doğrulaması
        let validStreak = targetUser.current_streak || 0;
        if (targetUser.last_step_date) {
            const lastDate = new Date(targetUser.last_step_date);
            const today = new Date();
            today.setHours(0, 0, 0, 0);
            lastDate.setHours(0, 0, 0, 0);
            const diffDays = Math.floor((today - lastDate) / (1000 * 60 * 60 * 24));
            if (diffDays > 1) validStreak = 0;
        } else {
            validStreak = 0;
        }

        res.status(200).json({
            ...targetUser,
            current_streak: validStreak,
            followers_count: followerCount[0].count,
            following_count: followingCount[0].count,
            is_following: isFollowing,
            xp: targetUser.xp || 0,
            level_info: calculateLevel(targetUser.xp || 0),
            badges: finalBadges 
        });
    } catch (error) {
        console.error('Public profil çekilirken hata:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

module.exports = router;
