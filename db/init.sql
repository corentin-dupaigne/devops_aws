-- Pomodoro database schema
CREATE TABLE IF NOT EXISTS sessions (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    session_type  ENUM('work', 'short_break', 'long_break') NOT NULL DEFAULT 'work',
    duration_sec  INT NOT NULL,
    label         VARCHAR(255) DEFAULT NULL,
    completed_at  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_completed_at (completed_at),
    INDEX idx_type (session_type)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
