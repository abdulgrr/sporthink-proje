const express = require('express');
const crypto = require('crypto');
const db = require('../db');
const authMiddleware = require('../middleware/authMiddleware');
const { checkAndAwardBadges } = require('../utils/badgeHelper');

const router = express.Router();

router.post('/sync', authMiddleware, async (req, res) => {
    const connection = await db.getConnection();

    try {
        const userId = req.user.id;
        const { client_batch_id, source, period_start, period_end, steps_array, device_id, device_model } = req.body;

        await connection.beginTransaction();

        // ========== ANTI-CHEAT KONTROLLER ==========

        // Anti-cheat ayarlarını çek
        const [acSettings] = await connection.query(
            "SELECT key_name, value FROM settings WHERE key_name IN ('anticheat_enabled', 'max_steps_per_day')"
        );
        const getAC = (key, def) => { const r = acSettings.find(s => s.key_name === key); return r ? parseInt(r.value) : def; };
        const anticheatEnabled = getAC('anticheat_enabled', 1);
        const maxStepsPerDay = getAC('max_steps_per_day', 50000);

        // Bu haftanın Pazartesi tarihini hesapla
        const todayStr = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
        const todayDate = new Date(todayStr + 'T12:00:00Z');
        const dayOfWeek = todayDate.getUTCDay();
        const diffToMonday = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
        const monday = new Date(todayDate);
        monday.setUTCDate(todayDate.getUTCDate() + diffToMonday);
        const weekStart = monday.toISOString().split('T')[0]; // YYYY-MM-DD

        // Pazar gecesi kaç gün kaldığını hesapla (hata mesajı için)
        const sunday = new Date(monday);
        sunday.setUTCDate(monday.getUTCDate() + 6);
        const sundayStr = sunday.toISOString().split('T')[0];
        const msUntilReset = sunday.getTime() + 86400000 - Date.now(); // Pazar 23:59'a kadar
        const daysUntilReset = Math.max(1, Math.ceil(msUntilReset / 86400000));

        if (anticheatEnabled && device_id) {
            // 1. HAFTALIK CİHAZ KİLİDİ — Aynı cihazda farklı hesap engelleme
            const [deviceThisWeek] = await connection.query(
                'SELECT user_id, device_model FROM user_devices WHERE device_id = ? AND week_start = ?',
                [device_id, weekStart]
            );

            if (deviceThisWeek.length > 0 && deviceThisWeek[0].user_id !== userId) {
                await connection.rollback();
                return res.status(403).json({ 
                    message: `Bu cihaz bu hafta başka bir hesaba bağlı. Haftalık sıfırlama sonrası (${sundayStr} Pazar gecesi) tekrar deneyebilirsiniz. Kalan süre: yaklaşık ${daysUntilReset} gün.`,
                    error_code: 'DEVICE_LOCKED_THIS_WEEK'
                });
            }

            // 2. HAFTALIK HESAP KİLİDİ — Aynı hesabı farklı telefondan kullanmayı engelleme
            const [accountThisWeek] = await connection.query(
                'SELECT device_id, device_model FROM user_devices WHERE user_id = ? AND week_start = ?',
                [userId, weekStart]
            );

            if (accountThisWeek.length > 0 && accountThisWeek[0].device_id !== device_id) {
                const boundDevice = accountThisWeek[0].device_model || 'bilinmeyen cihaz';
                await connection.rollback();
                return res.status(403).json({ 
                    message: `Hesabınız bu hafta "${boundDevice}" cihazına bağlı. Farklı bir cihazdan adım senkronize edemezsiniz. Haftalık sıfırlama: ${sundayStr} Pazar gecesi (yaklaşık ${daysUntilReset} gün).`,
                    error_code: 'ACCOUNT_LOCKED_THIS_WEEK'
                });
            }

            // Cihaz-hesap eşleşmesini kaydet (bu hafta için, yoksa)
            if (deviceThisWeek.length === 0 && accountThisWeek.length === 0) {
                await connection.query(
                    'INSERT IGNORE INTO user_devices (id, user_id, device_id, device_model, week_start) VALUES (?, ?, ?, ?, ?)',
                    [crypto.randomUUID(), userId, device_id, device_model || 'unknown', weekStart]
                );
            }

            // 3. ZAMAN DOĞRULAMA — Gelecek tarihli veri engelleme
            if (period_end) {
                const clientEnd = new Date(period_end);
                const serverNow = new Date();
                const diffMs = clientEnd.getTime() - serverNow.getTime();
                if (diffMs > 3600000) { // 1 saatten fazla ilerideyse
                    await connection.rollback();
                    return res.status(400).json({ 
                        message: 'Geçersiz zaman aralığı. Cihaz saatinizi kontrol edin.',
                        error_code: 'TIME_INVALID'
                    });
                }
            }
        }

        // ========== MEVCUT BATCH KONTROLÜ ==========
        const [existingBatch] = await connection.query('SELECT id FROM StepSync WHERE client_batch_id = ?', [client_batch_id]);
        if (existingBatch.length > 0) {
            await connection.rollback();
            return res.status(200).json({ message: 'Bu adım paketi zaten işlenmiş.' });
        }

        const syncId = crypto.randomUUID();
        await connection.query(
            'INSERT INTO StepSync (id, user_id, client_batch_id, source, period_start, period_end, status, device_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
            [syncId, userId, client_batch_id, source, period_start, period_end, 'processed', device_id || null]
        );

        // Puan hesaplama oranını veritabanından çek (Örn: 1000 adıma 1 puan)
        const [settingsResult] = await connection.query("SELECT value FROM settings WHERE key_name = 'steps_per_point'");
        const stepPointRatio = settingsResult.length > 0 ? parseInt(settingsResult[0].value) : 1000;

        let totalEarnedPoints = 0;
        let totalValidSteps = 0;
        let suspiciousFlag = false;

        for (const stepData of steps_array) {
            const stepId = crypto.randomUUID();
            const frontendTotalSteps = parseInt(stepData.step_count) || 0;
            const targetDay = stepData.day;

            // ========== ANOMALİ ALGILAMA ==========
            let isSuspicious = false;
            if (anticheatEnabled) {
                // 4a. GÜNLÜK LİMİT — Bir günde max adım kontrolü
                if (frontendTotalSteps > maxStepsPerDay) {
                    isSuspicious = true;
                    suspiciousFlag = true;
                    console.warn(`⚠️ Anti-cheat: Kullanıcı ${userId}, gün ${targetDay}: ${frontendTotalSteps} adım (günlük limit: ${maxStepsPerDay})`);
                }

                // 4b. Gelecek tarihli gün kontrolü
                const stepDate = new Date(targetDay + 'T23:59:59');
                const today = new Date();
                if (stepDate > new Date(today.getTime() + 86400000)) { // Yarından sonrası
                    isSuspicious = true;
                    suspiciousFlag = true;
                }
            }

            // ========== CİHAZ BAZLI DEDUP ==========
            // Aynı gün + aynı cihaz, farklı hesapla zaten sync edilmiş mi?
            if (anticheatEnabled && device_id) {
                const [deviceDayCheck] = await connection.query(
                    `SELECT ss.user_id FROM StepSync ss 
                     INNER JOIN Steps st ON st.sync_id = ss.id 
                     WHERE ss.device_id = ? AND st.day = ? AND ss.user_id != ?
                     LIMIT 1`,
                    [device_id, targetDay, userId]
                );
                if (deviceDayCheck.length > 0) {
                    isSuspicious = true;
                    suspiciousFlag = true;
                    console.warn(`⚠️ Anti-cheat DEDUP: Cihaz ${device_id}, gün ${targetDay} zaten başka hesapla (${deviceDayCheck[0].user_id}) senkronize edilmiş.`);
                }
            }

            // Veritabanında o gün için halihazırda ne kadar adım kaydedilmiş bul
            const [existingSteps] = await connection.query(
                "SELECT COALESCE(SUM(step_count), 0) as total FROM Steps WHERE user_id = ? AND day = ?",
                [userId, targetDay]
            );
            const savedSteps = parseInt(existingSteps[0].total);

            const deltaSteps = frontendTotalSteps - savedSteps;

            if (deltaSteps > 0) {
                // Şüpheli adımları kaydet ama puan VERME
                const shouldGivePoints = !isSuspicious;

                await connection.query(
                    'INSERT INTO Steps (id, user_id, sync_id, day, step_count, is_valid, is_suspicious) VALUES (?, ?, ?, ?, ?, ?, ?)',
                    [stepId, userId, syncId, targetDay, deltaSteps, shouldGivePoints, isSuspicious]
                );
                
                totalValidSteps += deltaSteps;

                if (shouldGivePoints) {
                    // Puanı hesaplarken küsurat kaybını önlemek için toplam üzerinden hesaplayıp farkı alıyoruz
                    const oldPoints = Math.floor(savedSteps / stepPointRatio);
                    const newPoints = Math.floor(frontendTotalSteps / stepPointRatio);
                    const pointsToGive = newPoints - oldPoints;

                    if (pointsToGive > 0) {
                        totalEarnedPoints += pointsToGive;
                    }
                }
            }
        }

        // --- STREAK MOTORU (DÜZELTİLMİŞ) ---
        const [streakSetting] = await connection.query("SELECT value FROM settings WHERE key_name = 'streak_min_steps'");
        const streakMinSteps = streakSetting.length > 0 ? parseInt(streakSetting[0].value) : 5000;

        const [todaySteps] = await connection.query("SELECT SUM(step_count) as total FROM Steps WHERE user_id = ? AND day = CURDATE()", [userId]);
        const stepsToday = todaySteps[0].total || 0;

        let streakExtended = false;

        if (stepsToday >= streakMinSteps) {
            const [userStats] = await connection.query('SELECT current_streak, last_step_date FROM Users WHERE id = ?', [userId]);
            const lastDate = userStats[0].last_step_date;
            
            const [dateDiff] = await connection.query('SELECT DATEDIFF(CURDATE(), COALESCE(?, "2000-01-01")) as diff', [lastDate]);
            const diff = dateDiff[0].diff;

            if (diff === 1) {
                // Dün de hedefi tutturmuş, seriyi artır
                await connection.query('UPDATE Users SET current_streak = current_streak + 1, last_step_date = CURDATE() WHERE id = ?', [userId]);
                streakExtended = true;
            } else if (diff > 1 || lastDate === null) {
                // Seri bozulmuş veya ilk kez, 1'den başla
                await connection.query('UPDATE Users SET current_streak = 1, last_step_date = CURDATE() WHERE id = ?', [userId]);
                streakExtended = true;
            }
            // diff === 0 ise bugün zaten güncellenmiş, atla
        }
        // Hedef tutmadıysa streak'e dokunma, cron job gece sıfırlayacak
        // ----------------------

        // --- LEVEL-UP ve STREAK MILESTONE KONTROLLERI ---
        // Önce mevcut kullanıcı verisini çek (puanlar artırılmadan ÖNCE)
        const [userBeforeUpdate] = await connection.query('SELECT xp, current_streak FROM Users WHERE id = ?', [userId]);
        const [settingsRows] = await connection.query("SELECT key_name, value FROM settings WHERE key_name IN ('xp_difficulty_modifier', 'level_up_points_reward')");
        const getSetting = (key, defaultVal) => {
            const row = settingsRows.find(s => s.key_name === key);
            return row ? parseInt(row.value) : defaultVal;
        };
        const xpDiffModifier = getSetting('xp_difficulty_modifier', 250);
        const levelUpReward = getSetting('level_up_points_reward', 100);
        const oldXp = userBeforeUpdate[0].xp || 0;

        if (totalEarnedPoints > 0) {
            // SADECE Puan artır, Adım senkronizasyonu artık XP VERMİYOR!
            await connection.query(
                'UPDATE Users SET total_points = total_points + ? WHERE id = ?',
                [totalEarnedPoints, userId]
            );
            await connection.query(
                'INSERT INTO PointsLedger (id, user_id, type, points, source, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
                [crypto.randomUUID(), userId, 'earn', totalEarnedPoints, 'steps', syncId]
            );
        }

        // Streak milestone kontrolü
        const [userAfterStreak] = await connection.query('SELECT current_streak FROM Users WHERE id = ?', [userId]);
        const currentStreak = userAfterStreak[0].current_streak || 0;

        const streakMilestones = [3, 7, 14, 25, 50, 75, 100];
        // 100'den sonra her 50'nin katı da milestone
        const isStreakMilestone = streakMilestones.includes(currentStreak) ||
            (currentStreak >= 100 && currentStreak % 50 === 0);

        let streakMilestoneData = null;
        let streakEarnedXp = 0;
        
        // streakExtended = true demek, seri BUGÜN uzatıldı demek. Sadece bugün uzadıysa ödül ver.
        if (isStreakMilestone && currentStreak > 0 && streakExtended) {
            const streakBonusPoints = currentStreak * 10; // Dinamik: 7 gün = 70, 100 gün = 1000
            streakEarnedXp = streakBonusPoints; // Streak'ten XP gelsin
            await connection.query(
                'UPDATE Users SET total_points = total_points + ?, xp = xp + ? WHERE id = ?',
                [streakBonusPoints, streakEarnedXp, userId]
            );
            await connection.query(
                'INSERT INTO PointsLedger (id, user_id, type, points, source, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
                [crypto.randomUUID(), userId, 'earn', streakBonusPoints, 'streak_milestone', `streak_${currentStreak}`]
            );
            
            // Sosyal akışa ekle
            await connection.query(`
                INSERT INTO social_feed (id, user_id, event_type, event_data)
                VALUES (?, ?, 'streak', ?)
            `, [crypto.randomUUID(), userId, JSON.stringify({ streak: currentStreak })]);

            streakMilestoneData = { streak: currentStreak, bonus_points: streakBonusPoints, bonus_xp: streakEarnedXp };
        }

        // Level-up kontrolü (sınırsız seviye sistemi)
        const getLevel = (xp) => {
            const level = Math.floor(Math.sqrt(xp / xpDiffModifier)) + 1;
            const minXp = Math.pow(level - 1, 2) * xpDiffModifier;
            const nextXp = Math.pow(level, 2) * xpDiffModifier;
            return { level, minXp, nextXp };
        };

        const newXp = oldXp + streakEarnedXp;
        const oldLevel = getLevel(oldXp);
        const newLevel = getLevel(newXp);

        let levelUpData = null;
        if (newLevel.level > oldLevel.level) {
            await connection.query(
                'UPDATE Users SET total_points = total_points + ? WHERE id = ?',
                [levelUpReward, userId]
            );
            await connection.query(
                'INSERT INTO PointsLedger (id, user_id, type, points, source, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
                [crypto.randomUUID(), userId, 'earn', levelUpReward, 'level_up', `level_${newLevel.level}`]
            );
            
            // Seviye akışı (5, 10, 25, 50, 100 ve katları)
            const lvl = newLevel.level;
            const isMilestoneLevel = [5, 10, 25, 50, 100].includes(lvl) || (lvl > 100 && lvl % 50 === 0);
            if (isMilestoneLevel) {
                await connection.query(`
                    INSERT INTO social_feed (id, user_id, event_type, event_data)
                    VALUES (?, ?, 'level', ?)
                `, [crypto.randomUUID(), userId, JSON.stringify({ level: lvl })]);
            }

            levelUpData = { new_level: newLevel.level, bonus_points: levelUpReward };
        }

        await connection.commit();

        const responseData = {
            message: 'Adım paketi başarıyla işlendi.',
            total_steps_logged: totalValidSteps,
            total_points_earned: totalEarnedPoints,
        };
        if (suspiciousFlag) responseData.suspicious = true;
        if (streakExtended) responseData.streak_extended = true;
        if (levelUpData) responseData.level_up = levelUpData;
        if (streakMilestoneData) responseData.streak_milestone = streakMilestoneData;

        // Check for new badges using JIT check (after commit so it sees new stats)
        const newBadges = await checkAndAwardBadges(userId);
        if (newBadges.length > 0) responseData.new_badges = newBadges;

        res.status(200).json(responseData);
    } catch (error) {
        await connection.rollback();
        console.error('StepSync hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    } finally {
        connection.release();
    }
});

// Bu haftanın Pazartesi ve Pazar tarihlerini hesapla (yardımcı fonksiyon)
function getWeekRange() {
    // Türkiye saatine göre bugünün tarihini YYYY-MM-DD olarak al
    const todayStr = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
    
    // Saat dilimi sorunlarını önlemek için UTC 12:00 olarak parse et
    const now = new Date(todayStr + 'T12:00:00Z');
    
    const dayOfWeek = now.getUTCDay(); // 0=Pazar, 1=Pazartesi, ..., 6=Cumartesi
    const diffToMonday = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
    
    const monday = new Date(now);
    monday.setUTCDate(now.getUTCDate() + diffToMonday);
    
    const sunday = new Date(monday);
    sunday.setUTCDate(monday.getUTCDate() + 6);

    const mondayStr = monday.toISOString().split('T')[0];
    const sundayStr = sunday.toISOString().split('T')[0];

    return { mondayStr, sundayStr, todayStr };
}

// Bu haftanın toplam adımlarını getir
router.get('/total', authMiddleware, async (req, res) => {
    try {
        const userId = req.user.id;
        const { mondayStr, sundayStr, todayStr } = getWeekRange();

        // Bu haftanın toplam adımları (tüm Steps - is_valid fark etmez)
        const [weekTotal] = await db.query(`
            SELECT COALESCE(SUM(step_count), 0) as total
            FROM Steps
            WHERE user_id = ? AND day >= ? AND day <= ?
        `, [userId, mondayStr, sundayStr]);

        // Bugünkü adımlar
        const [todayTotal] = await db.query(`
            SELECT COALESCE(SUM(step_count), 0) as total
            FROM Steps
            WHERE user_id = ? AND day = ?
        `, [userId, todayStr]);

        // Mevcut Seri (Streak)
        const [userRow] = await db.query('SELECT COALESCE(current_streak, 0) as current_streak FROM users WHERE id = ?', [userId]);

        // Streak için gereken minimum adım
        const [settingsDB] = await db.query("SELECT value FROM settings WHERE key_name = 'streak_min_steps'");
        const streakMinSteps = settingsDB[0] ? parseInt(settingsDB[0].value) : 5000;

        res.status(200).json({
            total_steps: parseInt(weekTotal[0].total),
            today_steps: parseInt(todayTotal[0].total),
            week_start: mondayStr,
            week_end: sundayStr,
            current_streak: parseInt(userRow[0]?.current_streak || 0),
            streak_min_steps: streakMinSteps
        });
    } catch (error) {
        console.error('Total steps hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

router.get('/pending', authMiddleware, async (req, res) => {
    try {
        const userId = req.user.id;
        const { mondayStr, sundayStr } = getWeekRange();

        // Kullanıcının BU HAFTAKİ puana çevrilmemiş adımlarını getir
        const [pendingSteps] = await db.query(`
            SELECT day, SUM(step_count) as total_steps
            FROM Steps
            WHERE user_id = ? AND is_valid = true AND day >= ? AND day <= ?
            GROUP BY day
            ORDER BY day DESC
        `, [userId, mondayStr, sundayStr]);

        res.status(200).json({
            pending_steps: pendingSteps.map(step => ({
                day: step.day,
                total_steps: step.total_steps
            }))
        });
    } catch (error) {
        console.error('Pending steps hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

router.post('/convert', authMiddleware, async (req, res) => {
    const connection = await db.getConnection();

    try {
        const userId = req.user.id;
        const { mondayStr, sundayStr } = getWeekRange();

        await connection.beginTransaction();

        // Puan hesaplama oranını veritabanından çek
        const [settingsResult] = await connection.query("SELECT value FROM settings WHERE key_name = 'steps_per_point'");
        const stepPointRatio = settingsResult.length > 0 ? parseInt(settingsResult[0].value) : 1000;

        // Kullanıcının BU HAFTAKİ puana çevrilmemiş adımlarını bul
        const [pendingSteps] = await connection.query(`
            SELECT id, day, step_count
            FROM Steps
            WHERE user_id = ? AND is_valid = true AND day >= ? AND day <= ?
        `, [userId, mondayStr, sundayStr]);

        let totalEarnedPoints = 0;
        let totalConvertedSteps = 0;

        for (const step of pendingSteps) {
            const pointsToGive = Math.floor(step.step_count / stepPointRatio);

            if (pointsToGive > 0) {
                totalEarnedPoints += pointsToGive;
                totalConvertedSteps += step.step_count;

                // Adımı puana çevrildi olarak işaretle
                await connection.query(
                    'UPDATE Steps SET is_valid = false WHERE id = ?',
                    [step.id]
                );
            }
        }

        if (totalEarnedPoints > 0) {
            // Puan VE XP birlikte artır
            await connection.query(
                'UPDATE Users SET total_points = total_points + ?, xp = xp + ? WHERE id = ?',
                [totalEarnedPoints, totalEarnedPoints, userId]
            );
            await connection.query(
                'INSERT INTO PointsLedger (id, user_id, type, points, source, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
                [crypto.randomUUID(), userId, 'earn', totalEarnedPoints, 'steps_convert', crypto.randomUUID()]
            );
        }

        await connection.commit();

        res.status(200).json({
            message: 'Adımlar başarıyla puana çevrildi.',
            total_steps_converted: totalConvertedSteps,
            total_points_earned: totalEarnedPoints
        });
    } catch (error) {
        await connection.rollback();
        console.error('Steps convert hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    } finally {
        connection.release();
    }
});

module.exports = router;