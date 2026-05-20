const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const multer = require('multer');
const path = require('path');
const session = require('express-session');
require('dotenv').config();
const db = require('./db');

const app = express();

const storage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, 'public/uploads'),
    filename: (req, file, cb) => cb(null, crypto.randomUUID() + path.extname(file.originalname))
});
const upload = multer({ storage });

// --- MIDDLEWARE ---
// CORS ayarlarını kısıtla
const allowedOrigins = [
    'http://localhost:3000',
    'http://localhost:8080',
    'http://10.0.2.2:3000',
    'http://10.0.2.2:8080',
    'http://127.0.0.1:3000',
    'http://127.0.0.1:8080'
];

app.use(cors({
    origin: function (origin, callback) {
        // Origin yoksa (örn: mobil uygulamalar) izin ver
        if (!origin) return callback(null, true);

        if (allowedOrigins.indexOf(origin) !== -1) {
            callback(null, true);
        } else {
            callback(new Error('CORS policy: Origin not allowed'));
        }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization']
}));

app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use('/public', express.static('public'));
app.use('/uploads', express.static(path.join(__dirname, 'public', 'uploads')));
app.use('/avatar-assets', express.static(path.join(__dirname, '..', 'sporthink_app', 'assets', 'avatar')));

// Session ayarları
app.use(session({
    secret: process.env.JWT_SECRET || 'sporthink_secret_key',
    resave: false,
    saveUninitialized: false,
    cookie: {
        secure: false, // HTTPS kullanıyorsanız true yapın
        maxAge: 24 * 60 * 60 * 1000 // 24 saat
    }
}));

// --- EJS AYARLARI ---
app.set('view engine', 'ejs');
app.set('views', './views');

// --- API ROTALARI (MOBİL UYGULAMA İÇİN) ---
const authRoutes = require('./routes/auth');
const stepRoutes = require('./routes/steps');
const rewardRoutes = require('./routes/rewards');
const leaderboardRoutes = require('./routes/leaderboard');
const shopRoutes = require('./routes/shop');
const profileRoutes = require('./routes/profile');
const questRoutes = require('./routes/quests');
const notificationRoutes = require('./routes/notifications');
const tipsRoutes = require('./routes/tips');
const socialRoutes = require('./routes/social');
const avatarRoutes = require('./routes/avatar');

app.use('/api/auth', authRoutes);
app.use('/api/steps', stepRoutes);
app.use('/api/rewards', rewardRoutes);
app.use('/api/leaderboard', leaderboardRoutes);
app.use('/api/shop', shopRoutes);
app.use('/api/profile', profileRoutes);
app.use('/api/quests', questRoutes);
app.use('/api/notifications', notificationRoutes);
app.use('/api/tips', tipsRoutes);
app.use('/api/social', socialRoutes);
app.use('/api/avatar', avatarRoutes);

// --- ADMIN AUTH MIDDLEWARE ---
const adminAuthMiddleware = require('./middleware/adminAuthMiddleware');

// --- WEB PANEL ROTALARI (ADMİN İÇİN) ---

// Admin Giriş Sayfası
app.get('/admin/login', (req, res) => {
    res.render('admin_login', { error: null });
});

// Admin Giriş İşlemi
app.post('/admin/login', async (req, res) => {
    const { username, password } = req.body;

    try {
        // Admin kullanıcısını kontrol et
        const [adminUsers] = await db.query(
            'SELECT * FROM Users WHERE username = ? AND role = ?',
            [username, 'admin']
        );

        if (adminUsers.length === 0) {
            return res.render('admin_login', {
                error: 'Geçersiz kullanıcı adı veya şifre'
            });
        }

        const admin = adminUsers[0];

        // Şifre kontrolü (bcrypt kullanıyorsanız)
        const bcrypt = require('bcrypt');
        const isPasswordValid = await bcrypt.compare(password, admin.password_hash);

        if (!isPasswordValid) {
            return res.render('admin_login', {
                error: 'Geçersiz kullanıcı adı veya şifre'
            });
        }

        // JWT token oluştur
        const jwt = require('jsonwebtoken');
        const token = jwt.sign(
            { id: admin.id, username: admin.username, role: 'admin' },
            process.env.JWT_SECRET,
            { expiresIn: '24h' }
        );

        // Session'a kaydet
        req.session.adminToken = token;
        req.session.adminId = admin.id;
        req.session.adminUsername = admin.username;

        // Log kaydı
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), admin.id, 'admin_login', 'Admin paneline giriş yapıldı']
        );

        res.redirect('/admin');

    } catch (error) {
        console.error('Admin login hatası:', error);
        res.render('admin_login', {
            error: 'Giriş sırasında bir hata oluştu'
        });
    }
});

// Admin Çıkış
app.get('/admin/logout', (req, res) => {
    const adminId = req.session.adminId;

    // Log kaydı
    if (adminId) {
        db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'admin_logout', 'Admin panelinden çıkış yapıldı']
        ).catch(console.error);
    }

    req.session.destroy();
    res.redirect('/admin/login');
});

// Admin panel route'ları (authentication middleware ile)
app.get('/admin', adminAuthMiddleware, async (req, res) => {
    try {
        const [[{total_users}]] = await db.query("SELECT COUNT(*) as total_users FROM users WHERE role != 'admin'");
        const [[{active_today}]] = await db.query("SELECT COUNT(DISTINCT user_id) as active_today FROM steps WHERE DATE(created_at) = CURDATE()");
        const [[{new_this_week}]] = await db.query("SELECT COUNT(*) as new_this_week FROM users WHERE role != 'admin' AND created_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)");
        const [[{steps_today}]] = await db.query("SELECT COALESCE(SUM(step_count), 0) as steps_today FROM steps WHERE DATE(created_at) = CURDATE()");
        const [[{badges_this_week}]] = await db.query("SELECT COUNT(*) as badges_this_week FROM user_badges WHERE earned_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)");
        const [[{total_feed}]] = await db.query("SELECT COUNT(*) as total_feed FROM social_feed");

        // Admin adını al
        const [adminRow] = await db.query('SELECT first_name, last_name FROM users WHERE id = ?', [req.session.adminId]);
        const adminName = adminRow.length > 0 ? `${adminRow[0].first_name} ${adminRow[0].last_name}` : req.session.adminUsername;

        res.render('dashboard', {
            adminUsername: req.session.adminUsername,
            adminName,
            stats: { total_users, active_today, new_this_week, steps_today, badges_this_week, total_feed }
        });
    } catch (error) {
        console.error('Dashboard hatası:', error);
        res.render('dashboard', { adminUsername: req.session.adminUsername, adminName: req.session.adminUsername, stats: {} });
    }
});

app.get('/admin/products', adminAuthMiddleware, async (req, res) => {
    try {
        const [products] = await db.execute('SELECT * FROM products ORDER BY id DESC');
        res.render('products', { products });
    } catch (error) {
        console.error('Ürünler çekilirken hata:', error);
        res.status(500).send('Sunucu hatası.');
    }
});

app.get('/admin/products/add', adminAuthMiddleware, (req, res) => {
    res.render('add_product');
});

app.post('/admin/products/add', adminAuthMiddleware, upload.single('productImage'), async (req, res) => {
    const { name, description, price_points } = req.body;
    const adminId = req.session.adminId;
    let image_url = null;

    if (req.file) {
        image_url = `/uploads/${req.file.filename}`;
    }

    try {
        await db.execute(
            'INSERT INTO products (name, description, price_points, image_url) VALUES (?, ?, ?, ?)',
            [name, description, price_points, image_url]
        );

        // Log kaydı
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'product_add', `Ürün eklendi: ${name}`]
        );

        res.redirect('/admin/products');
    } catch (error) {
        console.error('Ürün ekleme hatası:', error);
        res.status(500).send('Ürün kaydedilirken bir hata oluştu.');
    }
});

app.post('/admin/products/edit/:id', adminAuthMiddleware, upload.single('productImage'), async (req, res) => {
    const { id } = req.params;
    const { name, description, price_points } = req.body;
    const adminId = req.session.adminId;

    try {
        let updateQuery = 'UPDATE products SET name = ?, description = ?, price_points = ?';
        let queryParams = [name, description, price_points];

        if (req.file) {
            updateQuery += ', image_url = ?';
            queryParams.push(`/uploads/${req.file.filename}`);
        }

        updateQuery += ' WHERE id = ?';
        queryParams.push(id);

        await db.execute(updateQuery, queryParams);

        // Log kaydı
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'product_edit', `Ürün güncellendi: ${name} (ID: ${id})`]
        );

        res.redirect('/admin/products');
    } catch (error) {
        console.error('Ürün güncelleme hatası:', error);
        res.status(500).send('Ürün güncellenirken bir hata oluştu.');
    }
});

app.post('/admin/products/delete/:id', adminAuthMiddleware, async (req, res) => {
    const { id } = req.params;
    const adminId = req.session.adminId;

    try {
        await db.execute('DELETE FROM products WHERE id = ?', [id]);

        // Log kaydı
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'product_delete', `Ürün silindi (ID: ${id})`]
        );

        res.redirect('/admin/products');
    } catch (error) {
        console.error('Ürün silme hatası:', error);
        res.status(500).send('Ürün silinirken bir hata oluştu.');
    }
});

// --- AVATAR PARÇALARI YÖNETİMİ ---
app.get('/admin/avatar-items', adminAuthMiddleware, async (req, res) => {
    try {
        const [items] = await db.execute('SELECT * FROM avatar_items ORDER BY category, price ASC, display_name ASC');
        res.render('avatar_items', { items });
    } catch (error) {
        console.error('Avatar items çekilirken hata:', error);
        res.status(500).send('Sunucu hatası.');
    }
});

const avatarStorage = multer.diskStorage({
    destination: (req, file, cb) => cb(null, path.join(__dirname, '..', 'sporthink_app', 'assets', 'avatar')),
    filename: (req, file, cb) => {
        // Kategori prefix'ine göre dosya adını oluştur
        const category = req.body.category;
        const prefix = category === 'eyes' ? 'goz' : category === 'mouth' ? 'agiz' : 'kafa';
        // Dosya adını display_name'den türet (Türkçe karakterleri dönüştür)
        const safeName = (req.body.display_name || 'item')
            .toLowerCase()
            .replace(/ş/g, 's').replace(/ç/g, 'c').replace(/ğ/g, 'g')
            .replace(/ü/g, 'u').replace(/ö/g, 'o').replace(/ı/g, 'i')
            .replace(/[^a-z0-9]/g, '_').replace(/_+/g, '_').replace(/^_|_$/g, '');
        const finalName = `${prefix}_${safeName}.png`;
        req.generatedItemKey = `${prefix}_${safeName}`;
        cb(null, finalName);
    }
});
const avatarUpload = multer({ 
    storage: avatarStorage,
    fileFilter: (req, file, cb) => {
        if (file.mimetype === 'image/png') cb(null, true);
        else cb(new Error('Sadece PNG dosyaları kabul edilir'), false);
    },
    limits: { fileSize: 2 * 1024 * 1024 } // 2MB
});

app.post('/admin/avatar-items/add', adminAuthMiddleware, avatarUpload.single('avatar_file'), async (req, res) => {
    const { category, display_name, price } = req.body;
    const item_key = req.generatedItemKey;
    const adminId = req.session.adminId;

    try {
        await db.execute(
            'INSERT INTO avatar_items (id, category, item_key, display_name, price, is_default, is_active) VALUES (?, ?, ?, ?, ?, FALSE, TRUE)',
            [crypto.randomUUID(), category, item_key, display_name, parseInt(price) || 0]
        );

        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'avatar_item_add', `Avatar parçası eklendi: ${display_name} (${item_key})`]
        );

        res.redirect('/admin/avatar-items');
    } catch (error) {
        console.error('Avatar item ekleme hatası:', error);
        res.status(500).send('Avatar parçası eklenirken bir hata oluştu.');
    }
});

app.post('/admin/avatar-items/edit/:id', adminAuthMiddleware, async (req, res) => {
    const { id } = req.params;
    const { display_name, price, is_active } = req.body;
    const adminId = req.session.adminId;

    try {
        await db.execute(
            'UPDATE avatar_items SET display_name = ?, price = ?, is_active = ? WHERE id = ?',
            [display_name, parseInt(price) || 0, is_active === 'on' ? 1 : 0, id]
        );

        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'avatar_item_edit', `Avatar parçası düzenlendi: ${display_name}`]
        );

        res.redirect('/admin/avatar-items');
    } catch (error) {
        console.error('Avatar item düzenleme hatası:', error);
        res.status(500).send('Avatar parçası güncellenirken bir hata oluştu.');
    }
});

app.post('/admin/avatar-items/delete/:id', adminAuthMiddleware, async (req, res) => {
    const { id } = req.params;
    const adminId = req.session.adminId;

    try {
        await db.execute('DELETE FROM avatar_items WHERE id = ?', [id]);

        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'avatar_item_delete', `Avatar parçası silindi (ID: ${id})`]
        );

        res.redirect('/admin/avatar-items');
    } catch (error) {
        console.error('Avatar item silme hatası:', error);
        res.status(500).send('Avatar parçası silinirken bir hata oluştu.');
    }
});

app.get('/admin/chests', adminAuthMiddleware, async (req, res) => {
    res.render('chests', { type: null, drops: [] });
});

app.get('/admin/chests/:type', adminAuthMiddleware, async (req, res) => {
    const { type } = req.params;
    try {
        const [drops] = await db.execute('SELECT * FROM chest_drops WHERE chest_name = ? ORDER BY probability_percent DESC', [type]);
        res.render('chests', { type: type, drops: drops });
    } catch (error) {
        console.error('Sandık detayları çekilirken hata:', error);
        res.status(500).send('Sunucu hatası.');
    }
});

app.post('/admin/chests/drops', adminAuthMiddleware, async (req, res) => {
    const { chest_name, reward_type, reward_value, probability_percent } = req.body;
    const adminId = req.session.adminId;

    try {
        await db.execute(
            'INSERT INTO chest_drops (chest_name, reward_type, reward_value, probability_percent) VALUES (?, ?, ?, ?)',
            [chest_name, reward_type, reward_value, probability_percent]
        );

        // Log kaydı
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'chest_drop_add', `Sandık içeriği eklendi: ${chest_name}`]
        );

        res.redirect(`/admin/chests/${chest_name}`);
    } catch (error) {
        console.error('Sandık içeriği ekleme hatası:', error);
        res.status(500).send('İçerik eklenirken bir hata oluştu.');
    }
});

app.post('/admin/chests/drops/delete/:id', adminAuthMiddleware, async (req, res) => {
    const { id } = req.params;
    const { chest_name } = req.body;
    const adminId = req.session.adminId;

    try {
        await db.execute('DELETE FROM chest_drops WHERE id = ?', [id]);

        // Log kaydı
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'chest_drop_delete', `Sandık içeriği silindi (ID: ${id})`]
        );

        res.redirect(`/admin/chests/${chest_name}`);
    } catch (error) {
        console.error('Sandık içeriği silme hatası:', error);
        res.status(500).send('İçerik silinirken bir hata oluştu.');
    }
});

app.post('/admin/chests/drops/edit', adminAuthMiddleware, async (req, res) => {
    const { id, chest_name, reward_type, reward_value, probability_percent } = req.body;
    const adminId = req.session.adminId;

    try {
        await db.execute(
            'UPDATE chest_drops SET reward_type = ?, reward_value = ?, probability_percent = ? WHERE id = ?',
            [reward_type, reward_value, probability_percent, id]
        );

        // Log kaydı
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'chest_drop_edit', `Sandık içeriği güncellendi: ${chest_name} (ID: ${id})`]
        );

        res.redirect(`/admin/chests/${chest_name}`);
    } catch (error) {
        console.error('Sandık içeriği güncelleme hatası:', error);
        res.status(500).send('Güncelleme işlemi başarısız oldu.');
    }
});

const maskText = (text) => {
    if (!text) return '-';
    return String(text).charAt(0) + '***';
};

const maskEmail = (email) => {
    if (!email) return '-';
    const parts = String(email).split('@');
    if (parts.length !== 2) return email;
    const namePart = parts[0];
    const domainPart = parts[1];
    const maskedName = namePart.substring(0, 2) + '***';
    return `${maskedName}@${domainPart}`;
};

const maskPhone = (phone) => {
    if (!phone) return '-';
    const phoneStr = String(phone);
    if (phoneStr.length < 5) return '-';
    const firstDigit = phoneStr.charAt(0);
    const lastFourDigits = phoneStr.slice(-4);
    const middleAsterisks = '*'.repeat(phoneStr.length - 5);
    return `${firstDigit}${middleAsterisks}${lastFourDigits}`;
};

app.get('/admin/users', adminAuthMiddleware, async (req, res) => {
    try {
        const [users] = await db.execute("SELECT id, username, first_name, last_name, email, phone_number, total_points, is_banned, ban_reason, ban_until, created_at FROM users WHERE role != 'admin' ORDER BY total_points DESC");
        const maskedUsers = users.map(user => ({
            ...user,
            username: user.username,
            first_name: maskText(user.first_name),
            last_name: maskText(user.last_name),
            email: maskEmail(user.email),
            phone: maskPhone(user.phone_number),
        }));
        res.render('users', { users: maskedUsers });
    } catch (error) {
        console.error('Kullanıcıları çekerken hata:', error);
        res.status(500).send('Sunucu hatası.');
    }
});

// Kullanıcı Banlama
app.post('/admin/users/ban', adminAuthMiddleware, async (req, res) => {
    const { user_id, reason, duration } = req.body;
    const adminId = req.session.adminId;
    try {
        let banUntil = null;
        if (duration === '1') banUntil = new Date(Date.now() + 86400000);
        else if (duration === '7') banUntil = new Date(Date.now() + 7 * 86400000);
        else if (duration === '30') banUntil = new Date(Date.now() + 30 * 86400000);
        // duration === 'permanent' → banUntil null = kalıcı

        await db.query('UPDATE users SET is_banned = 1, ban_reason = ?, ban_until = ? WHERE id = ?', [reason, banUntil, user_id]);
        await db.query('INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'user_ban', `Kullanıcı banlandı: ${user_id} - Sebep: ${reason} - Süre: ${duration} gün`]);
        res.redirect('/admin/users');
    } catch (error) {
        console.error('Ban hatası:', error);
        res.status(500).send('Hata.');
    }
});

// Ban Kaldırma
app.post('/admin/users/unban', adminAuthMiddleware, async (req, res) => {
    const { user_id } = req.body;
    const adminId = req.session.adminId;
    try {
        await db.query('UPDATE users SET is_banned = 0, ban_reason = NULL, ban_until = NULL WHERE id = ?', [user_id]);
        await db.query('INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'user_unban', `Kullanıcı banı kaldırıldı: ${user_id}`]);
        res.redirect('/admin/users');
    } catch (error) {
        res.status(500).send('Hata.');
    }
});

// Kullanıcı Logları (AJAX)
app.get('/admin/users/logs/:id', adminAuthMiddleware, async (req, res) => {
    const userId = req.params.id;
    try {
        const [steps] = await db.query('SELECT day, step_count, is_valid, is_suspicious, created_at FROM steps WHERE user_id = ? ORDER BY day DESC LIMIT 30', [userId]);
        const [points] = await db.query('SELECT type, points, source, ref_id, created_at FROM pointsledger WHERE user_id = ? ORDER BY created_at DESC LIMIT 50', [userId]);
        const [badges] = await db.query('SELECT b.name, ub.earned_at FROM user_badges ub JOIN badges b ON ub.badge_id = b.id WHERE ub.user_id = ? ORDER BY ub.earned_at DESC', [userId]);
        const [userInfo] = await db.query('SELECT first_name, last_name, username, email, total_points, xp, current_streak, created_at, is_banned, ban_reason FROM users WHERE id = ?', [userId]);

        res.json({ user: userInfo[0] || null, steps, points, badges });
    } catch (error) {
        console.error('Kullanıcı logları hatası:', error);
        res.status(500).json({ message: 'Sunucu hatası.' });
    }
});

// Kullanıcı Silme
app.post('/admin/users/delete', adminAuthMiddleware, async (req, res) => {
    const { user_id } = req.body;
    const adminId = req.session.adminId;
    try {
        // İlişkili verileri sil
        await db.query('DELETE FROM follows WHERE follower_id = ? OR following_id = ?', [user_id, user_id]);
        await db.query('DELETE FROM notifications WHERE user_id = ?', [user_id]);
        await db.query('DELETE FROM social_reactions WHERE user_id = ?', [user_id]);
        await db.query('DELETE FROM social_likes WHERE user_id = ?', [user_id]);
        await db.query('DELETE FROM social_comments WHERE user_id = ?', [user_id]);
        await db.query('DELETE FROM social_feed WHERE user_id = ?', [user_id]);
        await db.query('DELETE FROM steps WHERE user_id = ?', [user_id]);
        await db.query('DELETE FROM pointsledger WHERE user_id = ?', [user_id]);
        await db.query('DELETE FROM user_badges WHERE user_id = ?', [user_id]);
        await db.query('DELETE FROM user_quest_progress WHERE user_id = ?', [user_id]);
        await db.query('DELETE FROM user_avatar_items WHERE user_id = ?', [user_id]);
        await db.query('DELETE FROM user_devices WHERE user_id = ?', [user_id]);
        await db.query('DELETE FROM refresh_tokens WHERE user_id = ?', [user_id]);
        await db.query('DELETE FROM users WHERE id = ?', [user_id]);

        await db.query('INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'user_delete', `Kullanıcı silindi: ${user_id}`]);
        res.redirect('/admin/users');
    } catch (error) {
        console.error('Silme hatası:', error);
        res.status(500).send('Hata.');
    }
});

// Admin Yönetimi Sayfası
app.get('/admin/admins', adminAuthMiddleware, async (req, res) => {
    try {
        const [admins] = await db.query("SELECT id, first_name, last_name, username, created_at FROM users WHERE role = 'admin'");
        res.render('admins', { admins, currentAdminId: req.session.adminId });
    } catch (error) {
        res.status(500).send('Hata.');
    }
});

// Yeni Admin Oluştur
app.post('/admin/admins/create', adminAuthMiddleware, async (req, res) => {
    const { first_name, last_name, username, password } = req.body;
    const adminId = req.session.adminId;
    try {
        const bcrypt = require('bcrypt');
        const hash = await bcrypt.hash(password, 10);
        await db.query(
            'INSERT INTO users (id, first_name, last_name, username, password_hash, role, email) VALUES (?, ?, ?, ?, ?, ?, ?)',
            [crypto.randomUUID(), first_name, last_name, username, hash, 'admin', `${username}@admin.local`]
        );
        await db.query('INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'admin_create', `Yeni admin oluşturuldu: ${username}`]);
        res.redirect('/admin/admins');
    } catch (error) {
        console.error('Admin oluşturma hatası:', error);
        res.redirect('/admin/admins');
    }
});

// Admin Sil
app.post('/admin/admins/delete', adminAuthMiddleware, async (req, res) => {
    const { admin_id } = req.body;
    const adminId = req.session.adminId;
    if (admin_id === adminId) return res.redirect('/admin/admins'); // Kendini silemez
    try {
        await db.query('DELETE FROM users WHERE id = ? AND role = ?', [admin_id, 'admin']);
        await db.query('INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'admin_delete', `Admin silindi: ${admin_id}`]);
        res.redirect('/admin/admins');
    } catch (error) {
        res.redirect('/admin/admins');
    }
});

app.get('/admin/settings', adminAuthMiddleware, async (req, res) => {
    try {
        const [settingsDB] = await db.execute('SELECT key_name, value FROM settings');
        const settings = {};
        settingsDB.forEach(s => settings[s.key_name] = s.value);
        res.render('settings', { settings });
    } catch (error) {
        console.error('Ayarlar çekilirken hata:', error);
        res.status(500).send('Sunucu hatası.');
    }
});

app.post('/admin/settings/update', adminAuthMiddleware, async (req, res) => {
    const { steps_per_point, max_steps_per_day, daily_chest_price_points, weekly_chest_price_points, streak_min_steps, xp_difficulty_modifier, level_up_points_reward, anticheat_enabled } = req.body;
    const adminId = req.session.adminId;

    try {
        const updates = {
            steps_per_point,
            max_steps_per_day,
            daily_chest_price_points,
            weekly_chest_price_points,
            streak_min_steps,
            xp_difficulty_modifier,
            level_up_points_reward,
            anticheat_enabled
        };
        for (const [key, val] of Object.entries(updates)) {
            if (val !== undefined) {
                // INSERT ... ON DUPLICATE KEY UPDATE ile hem yeni hem mevcut kayıtları destekle
                await db.execute(
                    'INSERT INTO settings (key_name, value) VALUES (?, ?) ON DUPLICATE KEY UPDATE value = ?',
                    [key, val, val]
                );
            }
        }

        // Log kaydı
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'settings_update', 'Sistem ayarları güncellendi']
        );

        res.redirect('/admin/settings');
    } catch (error) {
        console.error('Ayarlar güncellenirken hata:', error);
        res.status(500).send('Ayarlar güncellenirken hata oluştu.');
    }
});

// --- CİHAZ KİLİTLERİNİ TEMİZLE ---
app.get('/admin/settings/clear-device-locks', adminAuthMiddleware, async (req, res) => {
    try {
        const [result] = await db.query('DELETE FROM user_devices');
        const adminId = req.session.adminId;
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'clear_device_locks', `${result.affectedRows} cihaz kilidi temizlendi`]
        );
        res.redirect('/admin/settings');
    } catch (error) {
        console.error('Cihaz kilitleri temizlenirken hata:', error);
        res.status(500).send('Hata oluştu.');
    }
});

// --- ADMIN NOTIFICATIONS ROTALARI ---
app.get('/admin/notifications', adminAuthMiddleware, async (req, res) => {
    try {
        const [notifications] = await db.execute("SELECT title, message, MAX(created_at) as created_at FROM notifications WHERE type = 'system' GROUP BY title, message ORDER BY created_at DESC LIMIT 50");
        res.render('notifications', { notifications });
    } catch (error) {
        console.error('Bildirimler çekilirken hata:', error);
        res.status(500).send('Sunucu hatası.');
    }
});

app.post('/admin/notifications/send', adminAuthMiddleware, async (req, res) => {
    const { title, message } = req.body;
    const adminId = req.session.adminId;

    try {
        // Tüm mevcut kullanıcılara ayrı bildirim oluştur
        const [users] = await db.query('SELECT id FROM users');
        for (const user of users) {
            await db.execute(
                'INSERT INTO notifications (id, user_id, title, message, type) VALUES (?, ?, ?, ?, ?)',
                [crypto.randomUUID(), user.id, title, message, 'system']
            );
        }

        // Log kaydı
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'notification_send', `Global bildirim gönderildi: ${title}`]
        );

        res.redirect('/admin/notifications');
    } catch (error) {
        console.error('Bildirim gönderme hatası:', error);
        res.status(500).send('Bildirim gönderilirken hata oluştu.');
    }
});

app.post('/admin/notifications/delete', adminAuthMiddleware, async (req, res) => {
    const { title, message } = req.body;
    const adminId = req.session.adminId;

    try {
        await db.execute(
            'DELETE FROM notifications WHERE type = "system" AND title = ? AND message = ?',
            [title, message]
        );

        // Log kaydı
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'notification_delete', `Global bildirim silindi: ${title}`]
        );

        res.redirect('/admin/notifications');
    } catch (error) {
        console.error('Bildirim silme hatası:', error);
        res.status(500).send('Bildirim silinirken hata oluştu.');
    }
});

// --- ADMIN BADGES ROTALARI ---
app.get('/admin/badges', adminAuthMiddleware, async (req, res) => {
    try {
        const [badges] = await db.execute('SELECT * FROM badges ORDER BY created_at DESC');
        res.render('badges', { badges });
    } catch (error) {
        res.status(500).send('Sunucu hatası.');
    }
});

app.post('/admin/badges/add', adminAuthMiddleware, upload.single('badgeImage'), async (req, res) => {
    const { name, description, requirement_type, requirement_value } = req.body;
    const adminId = req.session.adminId;
    const imageUrl = req.file ? `/public/uploads/${req.file.filename}` : null;

    if (!imageUrl) return res.status(400).send('Resim zorunludur!');

    try {
        await db.execute(
            'INSERT INTO badges (name, description, image_url, requirement_type, requirement_value) VALUES (?, ?, ?, ?, ?)',
            [name, description, imageUrl, requirement_type, parseInt(requirement_value)]
        );

        // Log kaydı
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'badge_add', `Rozet eklendi: ${name}`]
        );

        res.redirect('/admin/badges');
    } catch (error) {
        console.error(error);
        res.status(500).send('Rozet kaydedilirken hata oluştu.');
    }
});

app.post('/admin/badges/delete/:id', adminAuthMiddleware, async (req, res) => {
    const adminId = req.session.adminId;

    try {
        await db.execute('DELETE FROM badges WHERE id = ?', [req.params.id]);

        // Log kaydı
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'badge_delete', `Rozet silindi (ID: ${req.params.id})`]
        );

        res.redirect('/admin/badges');
    } catch (error) {
        res.status(500).send('Sunucu hatası.');
    }
});

// --- ADMIN TIPS ROTALARI ---
app.get('/admin/tips', adminAuthMiddleware, async (req, res) => {
    try {
        const [tips] = await db.execute('SELECT * FROM Tips ORDER BY created_at DESC');
        res.render('tips', { tips });
    } catch (error) {
        res.status(500).send('Sunucu hatası.');
    }
});

app.post('/admin/tips/add', adminAuthMiddleware, async (req, res) => {
    const { text } = req.body;
    const adminId = req.session.adminId;

    try {
        await db.execute('INSERT INTO Tips (text) VALUES (?)', [text]);

        // Log kaydı
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'tip_add', 'İpucu eklendi']
        );

        res.redirect('/admin/tips');
    } catch (error) {
        res.status(500).send('Hata oluştu.');
    }
});

app.post('/admin/tips/toggle/:id', adminAuthMiddleware, async (req, res) => {
    try {
        await db.execute('UPDATE Tips SET is_active = NOT is_active WHERE id = ?', [req.params.id]);
        res.redirect('/admin/tips');
    } catch (error) {
        res.status(500).send('Hata oluştu.');
    }
});

app.post('/admin/tips/delete/:id', adminAuthMiddleware, async (req, res) => {
    const adminId = req.session.adminId;

    try {
        await db.execute('DELETE FROM Tips WHERE id = ?', [req.params.id]);

        // Log kaydı
        await db.query(
            'INSERT INTO auditlogs (id, user_id, action, details) VALUES (?, ?, ?, ?)',
            [crypto.randomUUID(), adminId, 'tip_delete', `İpucu silindi (ID: ${req.params.id})`]
        );

        res.redirect('/admin/tips');
    } catch (error) {
        res.status(500).send('Hata oluştu.');
    }
});

app.get('/admin/stats', adminAuthMiddleware, async (req, res) => {
    try {
        // Loglar - admin adı ile birlikte
        const [logs] = await db.execute(`
            SELECT a.id, a.user_id, a.action, a.details, a.created_at,
                   CONCAT(u.first_name, ' ', u.last_name) as admin_name
            FROM auditlogs a
            LEFT JOIN users u ON a.user_id = u.id
            ORDER BY a.created_at DESC LIMIT 50
        `);
        const [userCount] = await db.execute("SELECT COUNT(*) as count FROM users WHERE role != 'admin'");
        const [productCount] = await db.execute('SELECT COUNT(*) as count FROM products');
        const [stepData] = await db.execute('SELECT day, SUM(step_count) as total_steps FROM steps GROUP BY day ORDER BY day DESC LIMIT 7');
        
        // Yeni Kayıt Grafiği için veriler
        const [regData] = await db.execute('SELECT DATE(created_at) as day, COUNT(*) as new_users FROM users WHERE role != "admin" GROUP BY DATE(created_at) ORDER BY day DESC LIMIT 7');

        // Ek istatistikler
        const [topUsers] = await db.execute("SELECT first_name, last_name, total_points, xp FROM users WHERE role != 'admin' ORDER BY total_points DESC LIMIT 5");
        const [popularBadges] = await db.execute(`
            SELECT b.name, b.image_url, COUNT(ub.id) as earn_count
            FROM badges b LEFT JOIN user_badges ub ON b.id = ub.badge_id
            GROUP BY b.id ORDER BY earn_count DESC LIMIT 5
        `);
        const [chestStats] = await db.execute("SELECT COUNT(*) as count FROM pointsledger WHERE source = 'chest_open'");

        res.render('stats', {
            logs,
            totalUsers: userCount[0].count,
            totalProducts: productCount[0].count,
            chartData: stepData.reverse(),
            regChartData: regData.reverse(),
            topUsers,
            popularBadges,
            totalChests: chestStats[0].count
        });
    } catch (error) {
        console.error('İstatistikler çekilirken hata:', error);
        res.status(500).send('Sunucu hatası.');
    }
});

app.get('/admin/avatar', adminAuthMiddleware, async (req, res) => {
    try {
        const [items] = await db.query('SELECT * FROM avatar_items ORDER BY category, price ASC, display_name ASC');
        res.render('avatar_items', { items, error: null, success: null });
    } catch (error) {
        console.error('Avatar öğeleri yüklenemedi:', error);
        res.status(500).send('Sunucu hatası');
    }
});

app.post('/admin/avatar/add', adminAuthMiddleware, async (req, res) => {
    try {
        const { category, item_key, display_name, price, is_default } = req.body;
        const crypto = require('crypto');
        
        await db.query(
            'INSERT INTO avatar_items (id, category, item_key, display_name, price, is_default) VALUES (?, ?, ?, ?, ?, ?)',
            [crypto.randomUUID(), category, item_key, display_name, parseInt(price) || 0, is_default === 'on' ? 1 : 0]
        );
        res.redirect('/admin/avatar');
    } catch (error) {
        console.error('Avatar öğesi eklenemedi:', error);
        const [items] = await db.query('SELECT * FROM avatar_items ORDER BY category, price ASC, display_name ASC');
        res.render('avatar_items', { items, error: 'Kayıt başarısız. Anahtar benzersiz olmalı.', success: null });
    }
});

app.post('/admin/avatar/toggle', adminAuthMiddleware, async (req, res) => {
    try {
        const { id, is_active } = req.body;
        await db.query('UPDATE avatar_items SET is_active = ? WHERE id = ?', [is_active === 'true' ? 1 : 0, id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.post('/admin/avatar/delete', adminAuthMiddleware, async (req, res) => {
    try {
        const { id } = req.body;
        await db.query('DELETE FROM avatar_items WHERE id = ?', [id]);
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ success: false, error: error.message });
    }
});

app.get('/', (req, res) => {
    res.send('Sporthink Gamification API Çalışıyor! 🚀');
});

// --- GLOBAL ERROR HANDLER ---
app.use((err, req, res, next) => {
    console.error('Global Error:', err);

    // JWT hataları
    if (err.name === 'JsonWebTokenError') {
        return res.status(401).json({ message: 'Geçersiz token.' });
    }

    if (err.name === 'TokenExpiredError') {
        return res.status(401).json({ message: 'Token süresi doldu.' });
    }

    // CORS hataları
    if (err.message && err.message.includes('CORS')) {
        return res.status(403).json({ message: 'CORS hatası: Bu origin izin verilmiyor.' });
    }

    // Veritabanı hataları
    if (err.code && err.code.startsWith('ER_')) {
        return res.status(500).json({ message: 'Veritabanı hatası.' });
    }

    // Diğer hatalar
    res.status(500).json({
        message: 'Sunucu hatası.',
        error: process.env.NODE_ENV === 'development' ? err.message : undefined
    });
});

// --- 404 HANDLER ---
app.use((req, res) => {
    res.status(404).json({ message: 'İstenen endpoint bulunamadı.' });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Sunucu http://localhost:${PORT} adresinde çalışıyor.`);
});

// Cron job'ları başlat
require('./cron');