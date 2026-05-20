const db = require('../db');

// Seviye hesaplama (sınırsız seviye sistemi)
async function calculateLevel(xp) {
    const [settingsRows] = await db.query("SELECT key_name, value FROM settings WHERE key_name = 'xp_difficulty_modifier'");
    const xpDiffModifier = settingsRows.length > 0 ? parseInt(settingsRows[0].value) : 250;
    
    const level = Math.floor(Math.sqrt(xp / xpDiffModifier)) + 1;
    const minXp = Math.pow(level - 1, 2) * xpDiffModifier;
    const nextXp = Math.pow(level, 2) * xpDiffModifier;
    return { level, minXp, nextXp };
}

async function checkAndAwardBadges(userId) {
    const newBadgesAwarded = [];
    
    try {
        const [users] = await db.query('SELECT total_points, xp, COALESCE(current_streak, 0) as current_streak FROM users WHERE id = ?', [userId]);
        if (users.length === 0) return newBadgesAwarded;
        const user = users[0];

        const [allBadges] = await db.query('SELECT * FROM badges');
        if (allBadges.length === 0) return newBadgesAwarded;

        const [earnedBadges] = await db.query('SELECT badge_id FROM user_badges WHERE user_id = ?', [userId]);
        const earnedBadgeIds = new Set(earnedBadges.map(b => b.badge_id));

        for (const badge of allBadges) {
            if (earnedBadgeIds.has(badge.id)) continue;

            let earned = false;
            if (badge.requirement_type === 'streak_days') {
                earned = user.current_streak >= badge.requirement_value;
            } else if (badge.requirement_type === 'total_points') {
                // Hayat boyu kazanılan toplam puanları hesapla (harcananları düşme)
                const [lifetimePoints] = await db.query("SELECT SUM(points) as total FROM pointsledger WHERE user_id = ? AND type = 'earn'", [userId]);
                earned = (lifetimePoints[0].total || 0) >= badge.requirement_value;
            } else if (badge.requirement_type === 'chests_opened') {
                const [chests] = await db.query("SELECT COUNT(*) as count FROM pointsledger WHERE user_id = ? AND source = 'chest_open'", [userId]);
                earned = chests[0].count >= badge.requirement_value;
            } else if (badge.requirement_type === 'weekly_steps') {
                // Haftalık atılan toplam adım (İçinde bulunulan hafta)
                const [weekly] = await db.query("SELECT SUM(step_count) as total FROM steps WHERE user_id = ? AND YEARWEEK(day, 1) = YEARWEEK(CURDATE(), 1)", [userId]);
                earned = (weekly[0].total || 0) >= badge.requirement_value;
            } else if (badge.requirement_type === 'follower_count') {
                const [followerCount] = await db.query('SELECT COUNT(*) as count FROM follows WHERE following_id = ?', [userId]);
                earned = followerCount[0].count >= badge.requirement_value;
            } else if (badge.requirement_type === 'weekly_rank') {
                const [lastWeekLeaderboard] = await db.query(`
                    SELECT user_id, SUM(points) as total_score,
                           RANK() OVER (ORDER BY SUM(points) DESC) as rank_pos
                    FROM pointsledger 
                    WHERE type = 'earn' AND source = 'steps' AND YEARWEEK(created_at, 1) = YEARWEEK(CURDATE() - INTERVAL 1 WEEK, 1)
                    GROUP BY user_id
                `);
                const myLastWeekRank = lastWeekLeaderboard.find(r => r.user_id === userId);
                if (myLastWeekRank) {
                    earned = myLastWeekRank.rank_pos <= badge.requirement_value;
                }
            } else if (badge.requirement_type === 'daily_steps') {
                const [maxStepsRow] = await db.query(`
                    SELECT SUM(step_count) as total_steps 
                    FROM steps 
                    WHERE user_id = ? 
                    GROUP BY day 
                    ORDER BY total_steps DESC 
                    LIMIT 1
                `, [userId]);
                const maxDailySteps = maxStepsRow.length > 0 ? maxStepsRow[0].total_steps : 0;
                earned = maxDailySteps >= badge.requirement_value;
            } else if (badge.requirement_type === 'xp_level') {
                const levelInfo = await calculateLevel(user.xp || 0);
                earned = levelInfo.level >= badge.requirement_value;
            } else if (badge.requirement_type === 'quests_completed') {
                const [questsRow] = await db.query('SELECT COUNT(*) as count FROM user_quest_progress WHERE user_id = ? AND is_completed = TRUE', [userId]);
                earned = (questsRow[0].count || 0) >= badge.requirement_value;
            } else if (badge.requirement_type === 'total_likes_received') {
                const [likesRow] = await db.query('SELECT COUNT(*) as count FROM social_likes sl JOIN social_feed sf ON sl.feed_id = sf.id WHERE sf.user_id = ?', [userId]);
                earned = (likesRow[0].count || 0) >= badge.requirement_value;
            } else if (badge.requirement_type === 'total_comments_made') {
                const [commentsRow] = await db.query('SELECT COUNT(*) as count FROM social_comments WHERE user_id = ?', [userId]);
                earned = (commentsRow[0].count || 0) >= badge.requirement_value;
            }

            if (earned) {
                const [result] = await db.query('INSERT IGNORE INTO user_badges (user_id, badge_id) VALUES (?, ?)', [userId, badge.id]);
                if (result.affectedRows > 0) {
                    newBadgesAwarded.push(badge.name);
                    // Add to social feed
                    const crypto = require('crypto');
                    await db.query(`
                        INSERT INTO social_feed (id, user_id, event_type, event_data)
                        VALUES (?, ?, 'badge', ?)
                    `, [crypto.randomUUID(), userId, JSON.stringify({ badge_id: badge.id, badge_name: badge.name, iconUrl: badge.image_url })]);
                }
            }
        }
    } catch (e) {
        console.error("checkAndAwardBadges error:", e);
    }

    return newBadgesAwarded;
}

module.exports = { checkAndAwardBadges };
