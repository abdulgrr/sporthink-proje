const jwt = require('jsonwebtoken');

module.exports = (req, res, next) => {
    // 1. İsteğin başlığında (header) token var mı diye bakıyoruz
    const token = req.header('Authorization');
    if (!token) {
        return res.status(401).json({ message: 'Erişim reddedildi. Token bulunamadı.' });
    }

    try {
        // 2. Token geçerli mi, bizim .env'deki mühürle mi mühürlenmiş kontrol et
        const verified = jwt.verify(token.replace('Bearer ', ''), process.env.JWT_SECRET);
        req.user = verified; // Kullanıcı bilgilerini (id, role) req.user içine koy
        next(); // Geçişe izin ver, sonraki koda ilerle
    } catch (error) {
        res.status(400).json({ message: 'Geçersiz token.' });
    }
};