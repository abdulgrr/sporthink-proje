const express = require('express');
const bcrypt = require('bcrypt');
const crypto = require('crypto');
const jwt = require('jsonwebtoken'); 
const db = require('../db');

const router = express.Router();

// --- KULLANICI KAYIT (REGISTER) ENDPOINT'İ ---
router.post('/register', async (req, res) => {
    try {
        const { username, first_name, last_name, phone_number, email, password, avatar_url, device_id, device_model } = req.body;

        // ========== ANTI-CHEAT: CİHAZ KİLİDİ (REGISTER) ==========
        if (device_id) {
            const [acRows] = await db.query("SELECT value FROM settings WHERE key_name = 'anticheat_enabled'");
            const anticheatEnabled = acRows.length > 0 ? parseInt(acRows[0].value) : 1;

            if (anticheatEnabled) {
                const todayStr = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
                const todayDate = new Date(todayStr + 'T12:00:00Z');
                const dayOfWeek = todayDate.getUTCDay();
                const diffToMonday = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
                const monday = new Date(todayDate);
                monday.setUTCDate(todayDate.getUTCDate() + diffToMonday);
                const weekStart = monday.toISOString().split('T')[0];

                const sunday = new Date(monday);
                sunday.setUTCDate(monday.getUTCDate() + 6);
                const sundayStr = sunday.toISOString().split('T')[0];
                const msUntilReset = sunday.getTime() + 86400000 - Date.now();
                const daysUntilReset = Math.max(1, Math.ceil(msUntilReset / 86400000));

                // Bu cihaz bu hafta başka bir hesaba bağlı mı?
                const [deviceThisWeek] = await db.query(
                    'SELECT user_id FROM user_devices WHERE device_id = ? AND week_start = ?',
                    [device_id, weekStart]
                );

                if (deviceThisWeek.length > 0) {
                    return res.status(403).json({ 
                        message: `Bu cihaz bu hafta başka bir hesaba bağlı. Yeni hesap oluşturmak için ${sundayStr} Pazar gecesini bekleyin (yaklaşık ${daysUntilReset} gün).`,
                        error_code: 'DEVICE_LOCKED_THIS_WEEK'
                    });
                }
            }
        }
        // ========== ANTI-CHEAT SONU ==========

        // 1. Input validation
        if (!username || !first_name || !last_name || !email || !password) {
            return res.status(400).json({ message: 'Tüm zorunlu alanları doldurunuz.' });
        }

        // 2. Şifre karmaşıklığı kontrolü
        if (password.length < 8) {
            return res.status(400).json({ message: 'Şifre en az 8 karakter olmalıdır.' });
        }

        const hasUpperCase = /[A-Z]/.test(password);
        const hasLowerCase = /[a-z]/.test(password);
        const hasNumbers = /\d/.test(password);
        const hasSpecialChar = /[!@#$%^&*(),.?":{}|<>]/.test(password);

        if (!hasUpperCase || !hasLowerCase || !hasNumbers || !hasSpecialChar) {
            return res.status(400).json({
                message: 'Şifre en az 1 büyük harf, 1 küçük harf, 1 sayı ve 1 özel karakter içermelidir.'
            });
        }

        // 3. E-posta format kontrolü
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (!emailRegex.test(email)) {
            return res.status(400).json({ message: 'Geçerli bir e-posta adresi giriniz.' });
        }

        // 4. Telefon format kontrolü
        if (phone_number) {
            const phoneRegex = /^05\d{9}$/;
            if (!phoneRegex.test(phone_number.replace(/\s/g, ''))) {
                return res.status(400).json({ message: 'Geçerli bir telefon numarası giriniz (05XX XXX XX XX).' });
            }
        }

        // 5. Kullanıcı adı format kontrolü
        const usernameRegex = /^[a-zA-Z0-9_]{3,20}$/;
        if (!usernameRegex.test(username)) {
            return res.status(400).json({ message: 'Kullanıcı adı 3-20 karakter olmalı ve sadece harf, rakam, alt çizgi içerebilir.' });
        }

        // 6. E-posta zaten sistemde var mı kontrolü
        const [existingUsers] = await db.query('SELECT * FROM Users WHERE email = ?', [email]);
        if (existingUsers.length > 0) {
            return res.status(400).json({ message: 'Bu e-posta adresi zaten kullanılıyor.' });
        }

        // 7. Şifreyi Hash'leme (KVKK Güvenliği)
        const salt = await bcrypt.genSalt(10);
        const hashedPassword = await bcrypt.hash(password, salt);

        // 8. Kullanıcıya benzersiz bir ID oluşturma
        const userId = crypto.randomUUID();

        // 9. Kullanıcı adı zaten var mı kontrolü
        const [existingUsername] = await db.query('SELECT * FROM Users WHERE username = ?', [username]);
        if (existingUsername.length > 0) {
            return res.status(400).json({ message: 'Bu kullanıcı adı zaten kullanılıyor.' });
        }

        // Default avatar config (JSON)
        const defaultConfig = JSON.stringify({ skin: 1, eyes: 'goz_normal', mouth: 'agiz_mutlu', head: null });

        const insertQuery = `
            INSERT INTO Users (id, username, first_name, last_name, phone_number, email, password_hash, avatar_url)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        `;
        await db.query(insertQuery, [userId, username, first_name, last_name, phone_number, email, hashedPassword, defaultConfig]);

        // Yeni kullanıcıya ücretsiz avatar parçalarını ver
        const [freeItems] = await db.query('SELECT item_key FROM avatar_items WHERE price = 0 AND is_active = TRUE');
        for (const item of freeItems) {
            await db.query(
                'INSERT IGNORE INTO user_avatar_items (id, user_id, item_key) VALUES (?, ?, ?)',
                [crypto.randomUUID(), userId, item.item_key]
            );
        }

        // JWT oluştur (2 adımlı kayıt için - avatar setup'a geçebilsin)
        const accessToken = jwt.sign(
            { id: userId, role: 'user' },
            process.env.JWT_SECRET,
            { expiresIn: '30d' }
        );
        const refreshToken = jwt.sign(
            { id: userId, role: 'user', type: 'refresh' },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );
        const refreshTokenId = crypto.randomUUID();
        await db.query(
            'INSERT INTO refresh_tokens (id, user_id, token, expires_at) VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 7 DAY))',
            [refreshTokenId, userId, refreshToken]
        );
        // Cihaz-hesap eşleşmesini kaydet (kayıt anında)
        if (device_id) {
            const todayStr = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
            const todayDate = new Date(todayStr + 'T12:00:00Z');
            const dayOfWeek = todayDate.getUTCDay();
            const diffToMonday = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
            const monday = new Date(todayDate);
            monday.setUTCDate(todayDate.getUTCDate() + diffToMonday);
            const weekStart = monday.toISOString().split('T')[0];

            await db.query(
                'INSERT IGNORE INTO user_devices (id, user_id, device_id, device_model, week_start) VALUES (?, ?, ?, ?, ?)',
                [crypto.randomUUID(), userId, device_id, device_model || 'unknown', weekStart]
            );
        }

        res.status(201).json({
            message: 'Kullanıcı başarıyla oluşturuldu!',
            userId: userId,
            accessToken: accessToken,
            refreshToken: refreshToken
        });

    } catch (error) {
        console.error('Kayıt Hatası:', error);
        res.status(500).json({ message: 'Sunucu tarafında bir hata oluştu.' });
    }
});

// --- KULLANICI GİRİŞ (LOGIN) ENDPOINT'İ ---
router.post('/login', async (req, res) => {
    try {
        const { email, password, device_id, device_model } = req.body;

        // 1. Input validation
        if (!email || !password) {
            return res.status(400).json({ message: 'E-posta ve şifre gereklidir.' });
        }

        // 2. Veritabanında bu e-posta VEYA kullanıcı adı var mı?
        const [users] = await db.query('SELECT * FROM Users WHERE email = ? OR username = ?', [email, email]);
        if (users.length === 0) {
            return res.status(401).json({ message: 'Hatalı e-posta/kullanıcı adı veya şifre.' });
        }

        const user = users[0]; // Kullanıcıyı bulduk

        // 3. Şifre eşleşiyor mu? (Yazılan şifreyi hash ile karşılaştır)
        const isPasswordValid = await bcrypt.compare(password, user.password_hash);
        if (!isPasswordValid) {
            return res.status(401).json({ message: 'Hatalı e-posta/kullanıcı adı veya şifre.' });
        }

        // Ban kontrolü
        if (user.is_banned) {
            // Süreli ban: süre dolmuşsa otomatik kaldır
            if (user.ban_until && new Date(user.ban_until) < new Date()) {
                await db.query('UPDATE users SET is_banned = 0, ban_reason = NULL, ban_until = NULL WHERE id = ?', [user.id]);
            } else {
                const banUntilStr = user.ban_until ? new Date(user.ban_until).toLocaleDateString('tr-TR') : 'Süresiz';
                return res.status(403).json({
                    message: `Hesabınız ${banUntilStr !== 'Süresiz' ? banUntilStr + ' tarihine kadar' : 'kalıcı olarak'} askıya alınmıştır.\n\nSebep: ${user.ban_reason || 'Belirtilmedi'}`,
                    error_code: 'ACCOUNT_BANNED'
                });
            }
        }

        // ========== ANTI-CHEAT: HAFTALIK CİHAZ KİLİDİ (LOGIN) ==========
        if (device_id) {
            // Anti-cheat ayarını kontrol et
            const [acRows] = await db.query("SELECT value FROM settings WHERE key_name = 'anticheat_enabled'");
            const anticheatEnabled = acRows.length > 0 ? parseInt(acRows[0].value) : 1;

            if (anticheatEnabled) {
                // Bu haftanın Pazartesi tarihini hesapla
                const todayStr = new Date().toLocaleDateString('sv-SE', { timeZone: 'Europe/Istanbul' });
                const todayDate = new Date(todayStr + 'T12:00:00Z');
                const dayOfWeek = todayDate.getUTCDay();
                const diffToMonday = dayOfWeek === 0 ? -6 : 1 - dayOfWeek;
                const monday = new Date(todayDate);
                monday.setUTCDate(todayDate.getUTCDate() + diffToMonday);
                const weekStart = monday.toISOString().split('T')[0];

                const sunday = new Date(monday);
                sunday.setUTCDate(monday.getUTCDate() + 6);
                const sundayStr = sunday.toISOString().split('T')[0];
                const msUntilReset = sunday.getTime() + 86400000 - Date.now();
                const daysUntilReset = Math.max(1, Math.ceil(msUntilReset / 86400000));

                // Bu cihaz bu hafta başka bir hesaba bağlı mı?
                const [deviceThisWeek] = await db.query(
                    'SELECT user_id FROM user_devices WHERE device_id = ? AND week_start = ?',
                    [device_id, weekStart]
                );

                if (deviceThisWeek.length > 0 && deviceThisWeek[0].user_id !== user.id) {
                    return res.status(403).json({ 
                        message: `Bu cihaz bu hafta başka bir hesaba bağlı. ${sundayStr} Pazar gecesi sıfırlanacak (yaklaşık ${daysUntilReset} gün).`,
                        error_code: 'DEVICE_LOCKED_THIS_WEEK'
                    });
                }

                // Bu hesap bu hafta başka bir cihaza bağlı mı?
                const [accountThisWeek] = await db.query(
                    'SELECT device_id, device_model FROM user_devices WHERE user_id = ? AND week_start = ?',
                    [user.id, weekStart]
                );

                if (accountThisWeek.length > 0 && accountThisWeek[0].device_id !== device_id) {
                    const boundDevice = accountThisWeek[0].device_model || 'bilinmeyen cihaz';
                    return res.status(403).json({ 
                        message: `Bu hesap bu hafta "${boundDevice}" cihazına bağlı. Farklı cihazdan giriş yapamazsınız. ${sundayStr} Pazar gecesi sıfırlanacak (yaklaşık ${daysUntilReset} gün).`,
                        error_code: 'ACCOUNT_LOCKED_THIS_WEEK'
                    });
                }

                // Cihaz-hesap eşleşmesini kaydet (bu hafta için, yoksa)
                if (deviceThisWeek.length === 0 && accountThisWeek.length === 0) {
                    await db.query(
                        'INSERT IGNORE INTO user_devices (id, user_id, device_id, device_model, week_start) VALUES (?, ?, ?, ?, ?)',
                        [crypto.randomUUID(), user.id, device_id, device_model || 'unknown', weekStart]
                    );
                }
            }
        }
        // ========== ANTI-CHEAT SONU ==========

        // 4. Access Token oluştur (30 dakika geçerli)
        const accessToken = jwt.sign(
            { id: user.id, role: user.role },
            process.env.JWT_SECRET,
            { expiresIn: '30d' }
        );

        // 5. Refresh Token oluştur (7 gün geçerli)
        const refreshToken = jwt.sign(
            { id: user.id, role: user.role, type: 'refresh' },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );

        // 6. Refresh token'ı veritabanına kaydet
        const refreshTokenId = crypto.randomUUID();
        await db.query(
            'INSERT INTO refresh_tokens (id, user_id, token, expires_at) VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 7 DAY))',
            [refreshTokenId, user.id, refreshToken]
        );

        // 7. Başarılı giriş yanıtını gönder
        res.status(200).json({
            message: 'Başarıyla giriş yapıldı!',
            accessToken: accessToken,
            refreshToken: refreshToken,
            user: {
                first_name: user.first_name,
                last_name: user.last_name,
                role: user.role
            }
        });

    } catch (error) {
        console.error('Giriş Hatası:', error);
        res.status(500).json({ message: 'Sunucu tarafında bir hata oluştu.' });
    }
});

// --- REFRESH TOKEN ENDPOINT'İ ---
router.post('/refresh', async (req, res) => {
    try {
        const { refreshToken } = req.body;

        if (!refreshToken) {
            return res.status(400).json({ message: 'Refresh token gereklidir.' });
        }

        // 1. Refresh token'ı doğrula
        const decoded = jwt.verify(refreshToken, process.env.JWT_SECRET);

        if (decoded.type !== 'refresh') {
            return res.status(401).json({ message: 'Geçersiz refresh token.' });
        }

        // 2. Veritabanında refresh token'ı kontrol et
        const [tokenRecords] = await db.query(
            'SELECT * FROM refresh_tokens WHERE user_id = ? AND token = ? AND expires_at > NOW()',
            [decoded.id, refreshToken]
        );

        if (tokenRecords.length === 0) {
            return res.status(401).json({ message: 'Geçersiz veya süresi dolmuş refresh token.' });
        }

        // 3. Yeni access token oluştur
        const newAccessToken = jwt.sign(
            { id: decoded.id, role: decoded.role },
            process.env.JWT_SECRET,
            { expiresIn: '30d' }
        );

        // 4. Yeni refresh token oluştur (eskiyi iptal et)
        const newRefreshToken = jwt.sign(
            { id: decoded.id, role: decoded.role, type: 'refresh' },
            process.env.JWT_SECRET,
            { expiresIn: '7d' }
        );

        // 5. Eski refresh token'ı iptal et, yenisini kaydet
        await db.query('DELETE FROM refresh_tokens WHERE token = ?', [refreshToken]);

        const newRefreshTokenId = crypto.randomUUID();
        await db.query(
            'INSERT INTO refresh_tokens (id, user_id, token, expires_at) VALUES (?, ?, ?, DATE_ADD(NOW(), INTERVAL 7 DAY))',
            [newRefreshTokenId, decoded.id, newRefreshToken]
        );

        res.status(200).json({
            accessToken: newAccessToken,
            refreshToken: newRefreshToken
        });

    } catch (error) {
        console.error('Refresh Token Hatası:', error);
        res.status(401).json({ message: 'Geçersiz refresh token.' });
    }
});

// --- LOGOUT ENDPOINT'İ ---
router.post('/logout', async (req, res) => {
    try {
        const { refreshToken } = req.body;

        if (refreshToken) {
            // Refresh token'ı veritabanından sil
            await db.query('DELETE FROM refresh_tokens WHERE token = ?', [refreshToken]);
        }

        res.status(200).json({ message: 'Başarıyla çıkış yapıldı.' });

    } catch (error) {
        console.error('Logout Hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

module.exports = router;