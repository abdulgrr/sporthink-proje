const express = require('express');
const crypto = require('crypto');
const db = require('../db');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

// Post sahibine bildirim gönder (kendine değil)
async function notifyPostOwner(feedId, actorId, type, title, message) {
    try {
        const [feed] = await db.query('SELECT user_id FROM social_feed WHERE id = ?', [feedId]);
        if (feed.length === 0 || feed[0].user_id === actorId) return; // kendine bildirim yok
        await db.query(
            'INSERT INTO notifications (id, user_id, title, message, type) VALUES (?, ?, ?, ?, ?)',
            [crypto.randomUUID(), feed[0].user_id, title, message, type]
        );
    } catch (e) { console.error('Bildirim hatası:', e); }
}

// GET /api/social/feed
router.get('/feed', authMiddleware, async (req, res) => {
    try {
        const userId = req.user.id;
        const page = parseInt(req.query.page) || 1;
        const limit = 30;
        const offset = (page - 1) * limit;

        const query = `
            SELECT 
                sf.id, 
                sf.user_id,
                sf.event_type, 
                sf.event_data, 
                sf.created_at,
                u.first_name, 
                CONCAT(SUBSTRING(u.last_name, 1, 1), '.') AS last_initial, 
                u.avatar_url,
                (SELECT COUNT(*) FROM social_likes sl WHERE sl.feed_id = sf.id) AS likes_count,
                (SELECT COUNT(*) FROM social_likes sl WHERE sl.feed_id = sf.id AND sl.user_id = ?) AS is_liked,
                (SELECT COUNT(*) FROM social_comments sc WHERE sc.feed_id = sf.id) AS comments_count,
                (SELECT COUNT(*) FROM social_reactions sr WHERE sr.feed_id = sf.id) AS total_reactions,
                (SELECT reaction_type FROM social_reactions sr WHERE sr.feed_id = sf.id AND sr.user_id = ?) AS my_reaction
            FROM social_feed sf
            JOIN users u ON sf.user_id = u.id
            WHERE sf.user_id = ? OR sf.user_id IN (SELECT following_id FROM follows WHERE follower_id = ?)
            ORDER BY sf.created_at DESC
            LIMIT ? OFFSET ?
        `;

        const [feed] = await db.query(query, [userId, userId, userId, userId, limit, offset]);

        // Her post için tepki dağılımını ve son 2 yorumu çek
        const parsedFeed = [];
        for (const item of feed) {
            let avatarConfig = null;
            try { avatarConfig = JSON.parse(item.avatar_url); } catch(e) {}

            // Tepki dağılımı (hangi emoji kaç kez)
            const [reactionBreakdown] = await db.query(
                'SELECT reaction_type, COUNT(*) as count FROM social_reactions WHERE feed_id = ? GROUP BY reaction_type ORDER BY count DESC',
                [item.id]
            );

            // Son 2 yorum
            const [recentComments] = await db.query(
                `SELECT sc.id, sc.user_id, sc.content, sc.created_at, 
                        u.first_name, CONCAT(SUBSTRING(u.last_name, 1, 1), '.') AS last_initial,
                        u.avatar_url
                 FROM social_comments sc 
                 JOIN users u ON sc.user_id = u.id 
                 WHERE sc.feed_id = ? 
                 ORDER BY sc.created_at DESC LIMIT 2`,
                [item.id]
            );

            // Yorumlardaki avatar parse
            const parsedComments = recentComments.map(c => {
                let cAvatar = null;
                try { cAvatar = JSON.parse(c.avatar_url); } catch(e) {}
                return { ...c, avatar_config: cAvatar };
            });

            parsedFeed.push({
                ...item,
                avatar_config: avatarConfig,
                event_data: typeof item.event_data === 'string' ? JSON.parse(item.event_data) : item.event_data,
                is_liked: item.is_liked > 0,
                reaction_breakdown: reactionBreakdown,
                recent_comments: parsedComments
            });
        }

        res.status(200).json({
            message: 'Sosyal akış başarıyla getirildi.',
            data: parsedFeed
        });
    } catch (error) {
        console.error('Sosyal Akış Hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// POST /api/social/like — Beğeni toggle
router.post('/like', authMiddleware, async (req, res) => {
    try {
        const userId = req.user.id;
        const { feed_id } = req.body;

        if (!feed_id) {
            return res.status(400).json({ message: 'feed_id gerekli.' });
        }

        // Mevcut beğeniyi kontrol et
        const [existing] = await db.query(
            'SELECT id FROM social_likes WHERE feed_id = ? AND user_id = ?',
            [feed_id, userId]
        );

        if (existing.length > 0) {
            // Beğeniyi kaldır
            await db.query('DELETE FROM social_likes WHERE id = ?', [existing[0].id]);
            const [countResult] = await db.query('SELECT COUNT(*) as count FROM social_likes WHERE feed_id = ?', [feed_id]);
            return res.status(200).json({ action: 'unliked', likes_count: countResult[0].count });
        }

        // Yeni beğeni
        await db.query(
            'INSERT INTO social_likes (id, feed_id, user_id) VALUES (?, ?, ?)',
            [crypto.randomUUID(), feed_id, userId]
        );

        const [countResult] = await db.query('SELECT COUNT(*) as count FROM social_likes WHERE feed_id = ?', [feed_id]);

        // Post sahibine bildirim
        const [actor] = await db.query('SELECT first_name FROM users WHERE id = ?', [userId]);
        const actorName = actor[0]?.first_name || 'Biri';
        notifyPostOwner(feed_id, userId, 'like', '❤️ Beğeni', `${actorName} gönderini beğendi.`);

        res.status(200).json({ action: 'liked', likes_count: countResult[0].count });
    } catch (error) {
        console.error('Beğeni hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// POST /api/social/react — Feed ögesine tepki ver/kaldır
router.post('/react', authMiddleware, async (req, res) => {
    try {
        const userId = req.user.id;
        const { feed_id, reaction_type } = req.body;

        if (!feed_id || !reaction_type) {
            return res.status(400).json({ message: 'feed_id ve reaction_type gerekli.' });
        }

        const validTypes = ['fire', 'party', 'muscle', 'clap', 'wow'];
        if (!validTypes.includes(reaction_type)) {
            return res.status(400).json({ message: 'Geçersiz tepki türü.' });
        }

        // Mevcut tepkiyi kontrol et
        const [existing] = await db.query(
            'SELECT id, reaction_type FROM social_reactions WHERE feed_id = ? AND user_id = ?',
            [feed_id, userId]
        );

        if (existing.length > 0) {
            if (existing[0].reaction_type === reaction_type) {
                // Aynı tepki → kaldır (toggle)
                await db.query('DELETE FROM social_reactions WHERE id = ?', [existing[0].id]);
                return res.status(200).json({ message: 'Tepki kaldırıldı.', action: 'removed' });
            } else {
                // Farklı tepki → güncelle
                await db.query('UPDATE social_reactions SET reaction_type = ? WHERE id = ?', [reaction_type, existing[0].id]);
                return res.status(200).json({ message: 'Tepki güncellendi.', action: 'updated', reaction_type });
            }
        }

        // Yeni tepki ekle
        await db.query(
            'INSERT INTO social_reactions (id, feed_id, user_id, reaction_type) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), feed_id, userId, reaction_type]
        );

        const emojiMap = {fire:'🔥',muscle:'💪',party:'🎉',clap:'👏',wow:'😮'};
        const [actor] = await db.query('SELECT first_name FROM users WHERE id = ?', [userId]);
        const actorName = actor[0]?.first_name || 'Biri';
        notifyPostOwner(feed_id, userId, 'reaction', `${emojiMap[reaction_type] || '😊'} Tepki`, `${actorName} gönderine tepki verdi.`);

        res.status(200).json({ message: 'Tepki eklendi.', action: 'added', reaction_type });
    } catch (error) {
        console.error('Tepki hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// POST /api/social/comment — Yorum ekle
router.post('/comment', authMiddleware, async (req, res) => {
    try {
        const userId = req.user.id;
        const { feed_id, content } = req.body;

        if (!feed_id || !content || content.trim().length === 0) {
            return res.status(400).json({ message: 'feed_id ve content gerekli.' });
        }

        // Ayarlardan limitleri oku
        const [settingsRows] = await db.query("SELECT key_name, value FROM settings WHERE key_name IN ('max_comment_length', 'max_daily_comments')");
        const settingsMap = {};
        settingsRows.forEach(r => settingsMap[r.key_name] = parseInt(r.value));
        const maxLen = settingsMap.max_comment_length || 100;
        const maxDaily = settingsMap.max_daily_comments || 50;

        if (content.length > maxLen) {
            return res.status(400).json({ message: `Yorum en fazla ${maxLen} karakter olabilir.` });
        }

        // Günlük yorum limiti (spam önleme)
        const [dailyCount] = await db.query('SELECT COUNT(*) as count FROM social_comments WHERE user_id = ? AND DATE(created_at) = CURDATE()', [userId]);
        if (dailyCount[0].count >= maxDaily) {
            return res.status(429).json({ message: `Günlük yorum limitine ulaştınız (${maxDaily}).` });
        }

        const commentId = crypto.randomUUID();
        await db.query(
            'INSERT INTO social_comments (id, feed_id, user_id, content) VALUES (?, ?, ?, ?)',
            [commentId, feed_id, userId, content.trim()]
        );

        // Kullanıcı bilgilerini döndür
        const [user] = await db.query('SELECT first_name, last_name, avatar_url FROM users WHERE id = ?', [userId]);
        let avatarConfig = null;
        try { avatarConfig = JSON.parse(user[0].avatar_url); } catch(e) {}

        const [countResult] = await db.query('SELECT COUNT(*) as count FROM social_comments WHERE feed_id = ?', [feed_id]);

        res.status(200).json({
            message: 'Yorum eklendi.',
            comment: {
                id: commentId,
                content: content.trim(),
                created_at: new Date().toISOString(),
                first_name: user[0].first_name,
                last_initial: user[0].last_name ? user[0].last_name[0] + '.' : '',
                avatar_config: avatarConfig
            },
            comments_count: countResult[0].count
        });

        // Post sahibine bildirim
        notifyPostOwner(feed_id, userId, 'comment', '💬 Yorum', `${user[0].first_name} gönderine yorum yaptı.`);
    } catch (error) {
        console.error('Yorum hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// GET /api/social/comments/:feedId — Tüm yorumları getir
router.get('/comments/:feedId', authMiddleware, async (req, res) => {
    try {
        const feedId = req.params.feedId;

        const [comments] = await db.query(
            `SELECT sc.id, sc.content, sc.created_at, sc.user_id,
                    u.first_name, CONCAT(SUBSTRING(u.last_name, 1, 1), '.') AS last_initial,
                    u.avatar_url
             FROM social_comments sc
             JOIN users u ON sc.user_id = u.id
             WHERE sc.feed_id = ?
             ORDER BY sc.created_at ASC`,
            [feedId]
        );

        const parsed = comments.map(c => {
            let avatar = null;
            try { avatar = JSON.parse(c.avatar_url); } catch(e) {}
            return { ...c, avatar_config: avatar };
        });

        res.status(200).json({ comments: parsed });
    } catch (error) {
        console.error('Yorumlar hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// DELETE /api/social/comment/:id — Yorum sil (post sahibi veya yorum sahibi)
router.delete('/comment/:id', authMiddleware, async (req, res) => {
    try {
        const userId = req.user.id;
        const commentId = req.params.id;

        // Yorumu bul
        const [comment] = await db.query('SELECT sc.*, sf.user_id as post_owner_id FROM social_comments sc JOIN social_feed sf ON sc.feed_id = sf.id WHERE sc.id = ?', [commentId]);
        if (comment.length === 0) return res.status(404).json({ message: 'Yorum bulunamadı.' });

        const isPostOwner = comment[0].post_owner_id === userId;
        const isCommentOwner = comment[0].user_id === userId;

        if (!isPostOwner && !isCommentOwner) {
            return res.status(403).json({ message: 'Bu yorumu silme yetkin yok.' });
        }

        await db.query('DELETE FROM social_comments WHERE id = ?', [commentId]);
        res.status(200).json({ message: 'Yorum silindi.' });
    } catch (error) {
        console.error('Yorum silme hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

module.exports = router;
