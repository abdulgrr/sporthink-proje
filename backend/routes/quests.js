const express = require('express');
const crypto = require('crypto');
const db = require('../db');
const authMiddleware = require('../middleware/authMiddleware');
const { checkDailyBonus } = require('../utils/questHelper');

const router = express.Router();

// Seviye hesaplama (sınırsız seviye sistemi)
function calculateLevel(xp) {
    const level = Math.floor(Math.sqrt(xp / 250)) + 1;
    const minXp = Math.pow(level - 1, 2) * 250;
    const nextXp = Math.pow(level, 2) * 250;
    return { level, minXp, nextXp };
}

// 1. Kullanıcı için bugünün görevleri yoksa havuzdan seç
async function ensureDailyQuests(userId, today) {
    const [progress] = await db.query(
        'SELECT id FROM user_quest_progress WHERE user_id = ? AND quest_date = ?',
        [userId, today]
    );

    if (progress.length === 0) {
        // Rastgele 1 Kolay, 1 Orta, 1 Zor
        const [easy] = await db.query("SELECT id FROM daily_quests WHERE difficulty = 'easy' AND is_active = TRUE ORDER BY RAND() LIMIT 1");
        const [medium] = await db.query("SELECT id FROM daily_quests WHERE difficulty = 'medium' AND is_active = TRUE ORDER BY RAND() LIMIT 1");
        const [hard] = await db.query("SELECT id FROM daily_quests WHERE difficulty = 'hard' AND is_active = TRUE ORDER BY RAND() LIMIT 1");

        const assignedIds = [easy[0]?.id, medium[0]?.id, hard[0]?.id].filter(Boolean);

        for (const qid of assignedIds) {
            await db.query(
                'INSERT INTO user_quest_progress (id, user_id, quest_id, quest_date, current_value, is_completed) VALUES (?, ?, ?, ?, ?, ?)',
                [crypto.randomUUID(), userId, qid, today, 0, false]
            );
        }
    }
}

// 2. Bugünün atanan görevleri + ilerlemesi
router.get('/today', authMiddleware, async (req, res) => {
    const userId = req.user.id;

    try {
        const today = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });

        await ensureDailyQuests(userId, today);

        // Kullanıcıya atanmış görevleri ve ilerlemelerini getir
        const [quests] = await db.query(`
            SELECT q.*, p.current_value, p.is_completed, p.completed_at 
            FROM daily_quests q
            JOIN user_quest_progress p ON q.id = p.quest_id
            WHERE p.user_id = ? AND p.quest_date = ?
            ORDER BY q.difficulty ASC
        `, [userId, today]);

        // Adım görevlerini dinamik güncellemek için toplam adımı al
        const [todaySteps] = await db.query(
            'SELECT COALESCE(SUM(step_count), 0) as total FROM steps WHERE user_id = ? AND day = ?',
            [userId, today]
        );
        const totalStepsToday = todaySteps[0].total;

        const mappedQuests = quests.map(q => {
            let currentValue = q.current_value;

            // Eğer adım göreviyse dinamik olarak o anki adımı baz al
            if (q.quest_type === 'steps') {
                currentValue = Math.min(totalStepsToday, q.target_value);
            }

            return {
                id: q.id,
                quest_key: q.quest_key,
                quest_type: q.quest_type,
                difficulty: q.difficulty,
                title: q.title,
                description: q.description,
                target_value: q.target_value,
                reward_points: q.reward_points,
                reward_xp: q.reward_xp,
                current_value: currentValue,
                is_completed: !!q.is_completed,
            };
        });

        // XP ve seviye
        const [userXp] = await db.query('SELECT xp FROM users WHERE id = ?', [userId]);
        const xp = userXp[0]?.xp || 0;
        const levelInfo = calculateLevel(xp);

        res.status(200).json({
            date: today,
            total_steps_today: totalStepsToday,
            xp: xp,
            level: levelInfo,
            quests: mappedQuests,
        });
    } catch (error) {
        console.error('Günlük görev hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// 3. Adım Sync veya diğer eylemler sonrası görev tamamlama kontrolü
router.post('/check', authMiddleware, async (req, res) => {
    const userId = req.user.id;

    try {
        const today = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });

        await ensureDailyQuests(userId, today);

        // Kullanıcının atanan görevlerini getir
        const [quests] = await db.query(`
            SELECT q.*, p.id as progress_id, p.current_value, p.is_completed 
            FROM daily_quests q
            JOIN user_quest_progress p ON q.id = p.quest_id
            WHERE p.user_id = ? AND p.quest_date = ?
        `, [userId, today]);

        const [todaySteps] = await db.query(
            'SELECT COALESCE(SUM(step_count), 0) as total FROM steps WHERE user_id = ? AND day = ?',
            [userId, today]
        );
        const totalStepsToday = todaySteps[0].total;

        const newlyCompleted = [];

        for (const quest of quests) {
            if (quest.is_completed) continue; // Zaten bitmiş

            let currentValue = quest.current_value;
            let shouldComplete = false;

            // Sadece steps ve sync görevlerini otomatik kontrol et
            // (open_chest ve follow gibi görevler anlık eylem sırasında tetiklenecek)
            if (quest.quest_type === 'steps') {
                currentValue = totalStepsToday;
                shouldComplete = totalStepsToday >= quest.target_value;
            } else if (quest.quest_type === 'sync') {
                currentValue = 1;
                shouldComplete = true; // Sync atıldığında buraya gelir, o yüzden 1.
            }

            // Sadece bu iki tipi burada ilerletiyoruz veya kontrol ediyoruz
            if (quest.quest_type === 'steps' || quest.quest_type === 'sync') {
                currentValue = Math.min(currentValue, quest.target_value);

                await db.query(
                    'UPDATE user_quest_progress SET current_value = ?, is_completed = ?, completed_at = ? WHERE id = ?',
                    [currentValue, shouldComplete, shouldComplete ? new Date() : null, quest.progress_id]
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
        }

        if (newlyCompleted.length > 0) {
            const bonusMessage = await checkDailyBonus(userId, today);
            if (bonusMessage) newlyCompleted.push(bonusMessage);
        }

        res.status(200).json({
            message: newlyCompleted.length > 0 ? 'Görevler tamamlandı!' : 'Görevler kontrol edildi.',
            newly_completed: newlyCompleted,
        });
    } catch (error) {
        console.error('Görev kontrol hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// 4. Genel amaçlı eylem ilerletici (shop_buy, open_chest, follow) - Diğer route'lardan çağrılır
router.post('/progress_action', authMiddleware, async (req, res) => {
    const userId = req.user.id;
    const { action_type } = req.body; // 'open_chest', 'shop_buy', 'follow'

    try {
        const today = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
        await ensureDailyQuests(userId, today);

        const [quests] = await db.query(`
            SELECT q.*, p.id as progress_id, p.current_value, p.is_completed 
            FROM daily_quests q
            JOIN user_quest_progress p ON q.id = p.quest_id
            WHERE p.user_id = ? AND p.quest_date = ? AND q.quest_type = ? AND p.is_completed = FALSE
        `, [userId, today, action_type]);

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

        res.status(200).json({ message: 'Görev ilerletildi', newly_completed: newlyCompleted });
    } catch (error) {
        console.error('Progress action error:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

module.exports = router;
