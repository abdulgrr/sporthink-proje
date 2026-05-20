-- Loglama sistemi için auditlogs tablosu
CREATE TABLE IF NOT EXISTS auditlogs (
    id VARCHAR(36) PRIMARY KEY,
    user_id VARCHAR(36),
    action VARCHAR(100) NOT NULL,
    details TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_user_id (user_id),
    INDEX idx_action (action),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Admin kullanıcısı oluşturma (Varsayılan admin: admin / admin123)
-- Not: Şifreyi bcrypt ile hash'lemeniz gerekiyor
-- Örnek hash: admin123 için bcrypt hash (10 salt)
INSERT INTO Users (id, username, first_name, last_name, email, password_hash, role, avatar_url)
VALUES (
    'admin-001',
    'admin',
    'Admin',
    'User',
    'admin@sporthink.com',
    '$2b$10$rOZJqZ8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8Z8',
    'admin',
    'https://api.dicebear.com/7.x/avataaars/svg?seed=admin'
)
ON DUPLICATE KEY UPDATE role = 'admin';

-- Not: Gerçek kullanım için şifreyi şu şekilde hash'leyin:
-- const bcrypt = require('bcrypt');
-- const hash = await bcrypt.hash('admin123', 10);
-- Sonra bu hash'i veritabanına ekleyin