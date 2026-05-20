const crypto = require('crypto');
const db = require('../db');

// Eğer o günkü 3 görev de bittiyse ve daha önce 100 puanlık bonus alınmadıysa bonus verir.
async function checkDailyBonus(userId, today) {
    try {
        const [bonusLedger] = await db.query(
            'SELECT id FROM pointsledger WHERE user_id = ? AND source = "daily_quest_bonus" AND DATE(created_at) = ?',
            [userId, today]
        );

        if (bonusLedger.length > 0) return null; // Zaten bonus alınmış

        const [progress] = await db.query(
            'SELECT is_completed FROM user_quest_progress WHERE user_id = ? AND quest_date = ?',
            [userId, today]
        );

        // 3 görev de atanmış ve hepsi tamamlanmış olmalı
        if (progress.length === 3 && progress.every(p => p.is_completed)) {
            await db.query('UPDATE users SET total_points = total_points + 100, xp = xp + 100 WHERE id = ?', [userId]);
            await db.query(
                'INSERT INTO pointsledger (id, user_id, type, points, source, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
                [crypto.randomUUID(), userId, 'earn', 100, 'daily_quest_bonus', today]
            );
            return 'Tüm görevler tamamlandı bonusu! (+100 Puan)';
        }
        return null;
    } catch (e) {
        console.error('Check daily bonus err:', e);
        return null;
    }
}

async function progressQuest(userId, actionType) {
    try {
        const today = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
        
        const [quests] = await db.query(`
            SELECT q.*, p.id as progress_id, p.current_value, p.is_completed 
            FROM daily_quests q
            JOIN user_quest_progress p ON q.id = p.quest_id
            WHERE p.user_id = ? AND p.quest_date = ? AND q.quest_type = ? AND p.is_completed = FALSE
        `, [userId, today, actionType]);

        const newlyCompleted = [];

        for (const quest of quests) {
            let newVal = quest.current_value + 1;
            let shouldComplete = newVal >= quest.target_value;

            await db.query(
                'UPDATE user_quest_progress SET current_value = ?, is_completed = ?, completed_at = ? WHERE id = ?',
                [Math.min(newVal, quest.target_value), shouldComplete, shouldComplete ? new Date() : null, quest.progress_id]
            );

            if (shouldComplete) {
                await db.query('UPDATE users SET total_points = total_points + ?, xp = xp + ? WHERE id = ?', [quest.reward_points, quest.reward_xp, userId]);
                await db.query(
                    'INSERT INTO pointsledger (id, user_id, type, points, source, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
                    [crypto.randomUUID(), userId, 'earn', quest.reward_points, 'quest', String(quest.id)]
                );
                newlyCompleted.push(quest.title);
            }
        }

        if (newlyCompleted.length > 0) {
            const bonusMessage = await checkDailyBonus(userId, today);
            if (bonusMessage) newlyCompleted.push(bonusMessage);
        }

        return newlyCompleted;
    } catch (e) {
        console.error('Quest progress err:', e);
        return [];
    }
}

module.exports = { progressQuest, checkDailyBonus };
