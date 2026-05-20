const jwt = require('jsonwebtoken');

module.exports = (req, res, next) => {
    // 1. Session'da admin token var mı kontrol et
    const adminToken = req.session.adminToken;

    if (!adminToken) {
        // Eğer admin login sayfasına değilse, login'e yönlendir
        if (req.path !== '/admin/login') {
            return res.redirect('/admin/login');
        }
        return next();
    }

    try {
        // 2. Token'ı doğrula
        const decoded = jwt.verify(adminToken, process.env.JWT_SECRET);

        // 3. Admin rolü kontrolü
        if (decoded.role !== 'admin') {
            req.session.destroy();
            return res.redirect('/admin/login');
        }

        // 4. Admin bilgilerini req'e ekle
        req.admin = decoded;
        next();
    } catch (error) {
        // Token geçersizse session'ı temizle
        req.session.destroy();
        return res.redirect('/admin/login');
    }
};