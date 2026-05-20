const express = require('express');
const db = require('../db');
const authMiddleware = require('../middleware/authMiddleware');

const router = express.Router();

router.get('/random', authMiddleware, async (req, res) => {
    try {
        const [tips] = await db.query('SELECT text FROM Tips WHERE is_active = TRUE ORDER BY RAND() LIMIT 1');
        if (tips.length > 0) {
            res.json({ tip: tips[0].text });
        } else {
            res.json({ tip: 'Düzenli egzersiz yapmak daha sağlıklı bir yaşama adım atmanı sağlar.' });
        }
    } catch (e) {
        console.error(e);
        res.status(500).json({ message: 'Server error' });
    }
});

module.exports = router;
