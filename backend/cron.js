const cron = require('node-cron');
const crypto = require('crypto');
const db = require('./db');

// Her gece Türkiye saati (UTC+3) 00:05'te çalışır
// Cron formatı: dakika(5) saat(0) * * * | timezone: Europe/Istanbul
cron.schedule('5 0 * * *', async () => {
    console.log('[CRON] Streak sıfırlama başladı:', new Date().toISOString());

    try {
        // 1. Minimum adım sayısını ayarlardan çek
        const [streakSetting] = await db.query("SELECT value FROM settings WHERE key_name = 'streak_min_steps'");
        const streakMinSteps = streakSetting.length > 0 ? parseInt(streakSetting[0].value) : 5000;

        // 2. Dün yeterli adım ATMAMIŞ kullanıcıları bul ve streak'lerini sıfırla
        // Dün = CURDATE() - INTERVAL 1 DAY (Türkiye saatine göre)
        const [result] = await db.query(`
            UPDATE users
            SET current_streak = 0
            WHERE current_streak > 0
            AND id NOT IN (
                SELECT user_id FROM steps
                WHERE day = DATE_SUB(CURDATE(), INTERVAL 1 DAY)
                GROUP BY user_id
                HAVING SUM(step_count) >= ?
            )
        `, [streakMinSteps]);

        console.log(`[CRON] ${result.affectedRows} kullanıcının streak'i sıfırlandı.`);

    } catch (error) {
        console.error('[CRON] Streak sıfırlama hatası:', error);
    }
}, {
    timezone: 'Europe/Istanbul'
});

// 7 GÜNLÜK ADIM TEMİZLEME CRON JOB'U
// Her gece Türkiye saati (UTC+3) 01:00'te çalışır
cron.schedule('0 1 * * *', async () => {
    console.log('[CRON] 7 günlük adım temizleme başladı:', new Date().toISOString());

    try {
        // 7 günden eski adım kayıtlarını sil
        const cutoffDate = new Date();
        cutoffDate.setDate(cutoffDate.getDate() - 7);

        const [result] = await db.query(
            'DELETE FROM steps WHERE day < ?',
            [cutoffDate.toISOString().split('T')[0]]
        );

        console.log(`[CRON] ${result.affectedRows} eski adım kaydı temizlendi.`);

    } catch (error) {
        console.error('[CRON] Adım temizleme hatası:', error);
    }
}, {
    timezone: 'Europe/Istanbul'
});

// Günlük görev ilerlemelerini gece yarısı sıfırla (yeni gün için temiz başlangıç)
// Bu aslında gerekli değil çünkü her gün için ayrı kayıt oluşturuluyor, ama loglamak iyi
cron.schedule('1 0 * * *', () => {
    console.log('[CRON] Yeni gün başladı (TR saati). Günlük görevler sıfırlandı.');
}, {
    timezone: 'Europe/Istanbul'
});

// --- ZAMANLANMIŞ BİLDİRİMLER (CRON JOBS) ---

// 1. Pazar Günü Saat 20:00 - Adımları dönüştürme hatırlatması (Global Bildirim)
cron.schedule('0 20 * * 0', async () => {
    try {
        await db.query(
            'INSERT INTO notifications (id, user_id, title, message, type) VALUES (?, NULL, ?, ?, ?)',
            [crypto.randomUUID(), 'Hafta Bitiyor! ⏳', 'Pazar akşamına girdik. Adımlarını sıfırlanmadan önce puana çevirmeyi unutma!', 'system']
        );
        console.log('[CRON] Pazar 20:00 bildirimi gönderildi.');
    } catch (e) {
        console.error('[CRON] Bildirim hatası:', e);
    }
}, { timezone: 'Europe/Istanbul' });

// 2. Hergün Saat 13:00 - Öğle molası motivasyonu (Global Bildirim)
cron.schedule('0 13 * * *', async () => {
    try {
        await db.query(
            'INSERT INTO notifications (id, user_id, title, message, type) VALUES (?, NULL, ?, ?, ?)',
            [crypto.randomUUID(), 'Öğle Molası! 🚶‍♂️', 'Öğle molasında biraz yürüyüş yapmaya ne dersin? Hem sindirime yardımcı olur hem de yeni görevleri tamamlarsın!', 'system']
        );
        console.log('[CRON] Günlük 13:00 bildirimi gönderildi.');
    } catch (e) {
        console.error('[CRON] Bildirim hatası:', e);
    }
}, { timezone: 'Europe/Istanbul' });

// 3. Cuma Günü Saat 12:00 - Liderlik Tablosu Rekabeti (Özel Bildirimler)
cron.schedule('0 12 * * 5', async () => {
    try {
        console.log('[CRON] Cuma 12:00 liderlik tablosu bildirimleri hesaplanıyor...');
        // O haftaki toplam puanlara göre sıralama çekiliyor
        const [leaderboard] = await db.query(`
            SELECT u.id, SUM(p.points) AS total_score
            FROM users u
            JOIN pointsledger p ON u.id = p.user_id
            WHERE p.type = 'earn' AND p.source = 'steps' AND YEARWEEK(p.created_at, 1) = YEARWEEK(CURDATE(), 1)
            GROUP BY u.id
            ORDER BY total_score DESC
            LIMIT 10
        `);

        if (leaderboard.length > 0) {
            for (let i = 0; i < leaderboard.length; i++) {
                const user = leaderboard[i];
                let title = 'Sıralama Rekabeti 🔥';
                let message = '';

                if (i === 0) {
                    const diff = leaderboard.length > 1 ? user.total_score - leaderboard[1].total_score : 0;
                    message = `Şu an 1. sıradasın! Harika gidiyorsun. İkinciyle aranda ${diff} puan fark var, yerini koru!`;
                } else if (i > 0 && i < 3) {
                    const diff = leaderboard[0].total_score - user.total_score;
                    message = `Şu an ${i + 1}. sıradasın! Birinci olmana sadece ${diff} puan kaldı. Hadi biraz daha gayret!`;
                } else {
                    const diffToThird = leaderboard.length >= 3 ? leaderboard[2].total_score - user.total_score : 50;
                    message = `Şu an ${i + 1}. sıradasın. İlk 3'e girmene sadece ${diffToThird > 0 ? diffToThird : 'birkaç'} puan kaldı. Tempoyu artır!`;
                }

                await db.query(
                    'INSERT INTO notifications (id, user_id, title, message, type) VALUES (?, ?, ?, ?, ?)',
                    [crypto.randomUUID(), user.id, title, message, 'leaderboard']
                );
            }
        }
    } catch (e) {
        console.error('[CRON] Cuma bildirimi hatası:', e);
    }
}, { timezone: 'Europe/Istanbul' });

// 4. Pazar Günü Saat 23:59 - Haftalık Liderlik Tablosu Ödül Dağıtımı
cron.schedule('59 23 * * 0', async () => {
    console.log('[CRON] Haftalık liderlik tablosu ödülleri dağıtılıyor...');
    const connection = await db.getConnection();
    try {
        await connection.beginTransaction();

        // O haftaki (YEARWEEK) toplam adımlardan kazanılan puanlara göre ilk 10'u çek
        const [leaderboard] = await connection.query(`
            SELECT u.id, SUM(p.points) AS total_score
            FROM users u
            JOIN pointsledger p ON u.id = p.user_id
            WHERE p.type = 'earn' AND p.source = 'steps' AND YEARWEEK(p.created_at, 1) = YEARWEEK(CURDATE(), 1)
            GROUP BY u.id
            ORDER BY total_score DESC
            LIMIT 10
        `);

        const rewards = [1000, 800, 600, 400, 200, 100, 100, 100, 100, 100];

        for (let i = 0; i < leaderboard.length; i++) {
            const user = leaderboard[i];
            const rewardPoints = rewards[i] || 0;

            if (rewardPoints > 0) {
                // Puanları ver
                await connection.query(
                    'UPDATE users SET total_points = total_points + ?, xp = xp + ? WHERE id = ?',
                    [rewardPoints, rewardPoints, user.id]
                );

                // Deftere yaz
                await connection.query(
                    'INSERT INTO pointsledger (id, user_id, type, points, source, ref_id) VALUES (?, ?, ?, ?, ?, ?)',
                    [crypto.randomUUID(), user.id, 'earn', rewardPoints, 'leaderboard_reward', 'week_' + new Date().getTime()]
                );

                // Bildirim gönder
                await connection.query(
                    'INSERT INTO notifications (id, user_id, title, message, type) VALUES (?, ?, ?, ?, ?)',
                    [crypto.randomUUID(), user.id, '🏆 Haftalık Sıralama Ödülü!', `Haftalık sıralamayı ${i + 1}. bitirdin! Başarın için sana ${rewardPoints} XP ve Puan hediye ediyoruz. Tebrikler!`, 'reward']
                );
            }
        }

        await connection.commit();
        console.log(`[CRON] ${leaderboard.length} kullanıcıya haftalık ödülleri dağıtıldı.`);
    } catch (e) {
        await connection.rollback();
        console.error('[CRON] Ödül dağıtımı hatası:', e);
    } finally {
        connection.release();
    }
}, { timezone: 'Europe/Istanbul' });

// 5. Her Pazar'ı Pazartesiye bağlayan gece (00:01) geçen haftanın sıralamasını hesapla ve sosyal akışa ekle
cron.schedule('1 0 * * 1', async () => {
    console.log("[CRON] Haftalık sıralama analizi (Sosyal Akış) başlatılıyor...");
    try {
        const query = `
            SELECT 
                u.id, 
                SUM(s.step_count) AS total_score,
                RANK() OVER (ORDER BY SUM(s.step_count) DESC) as rank_pos
            FROM users u
            JOIN steps s ON u.id = s.user_id
            WHERE YEARWEEK(s.day, 1) = YEARWEEK(CURDATE() - INTERVAL 1 WEEK, 1)
            GROUP BY u.id
            ORDER BY total_score DESC
            LIMIT 10
        `;
        const [lastWeekLeaderboard] = await db.query(query);

        for (const user of lastWeekLeaderboard) {
            let rankText = "";
            if (user.rank_pos === 1) rankText = "1. oldu!";
            else if (user.rank_pos === 2) rankText = "2. oldu!";
            else if (user.rank_pos === 3) rankText = "3. oldu!";
            else if (user.rank_pos <= 5) rankText = "ilk 5'e girdi!";
            else if (user.rank_pos <= 10) rankText = "ilk 10'a girdi!";

            if (rankText) {
                const crypto = require('crypto');
                await db.query(`
                    INSERT INTO social_feed (id, user_id, event_type, event_data)
                    VALUES (?, ?, 'weekly_rank', ?)
                `, [crypto.randomUUID(), user.id, JSON.stringify({ rank: user.rank_pos, rank_text: rankText })]);
            }
        }
        console.log("[CRON] Haftalık sıralama analizi (Sosyal Akış) tamamlandı.");
    } catch (e) {
        console.error("[CRON] Haftalık Sıralama Hatası:", e);
    }
}, { timezone: 'Europe/Istanbul' });

console.log('🚀 Cron job\'lar başlatıldı (Timezone: Europe/Istanbul)');
