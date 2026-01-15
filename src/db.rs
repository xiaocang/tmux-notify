use crate::models::Notification;
use rusqlite::{Connection, Result};
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

pub struct Database {
    conn: Connection,
}

impl Database {
    pub fn open(custom_path: Option<PathBuf>) -> Result<Self> {
        let db_path = custom_path.unwrap_or_else(get_default_db_path);

        // Ensure parent directory exists
        if let Some(parent) = db_path.parent() {
            std::fs::create_dir_all(parent).ok();
        }

        let conn = Connection::open(&db_path)?;
        let db = Database { conn };
        db.init_schema()?;
        Ok(db)
    }

    fn init_schema(&self) -> Result<()> {
        self.conn.execute_batch(
            "CREATE TABLE IF NOT EXISTS notifications (
                pane TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                message TEXT NOT NULL,
                state TEXT DEFAULT 'unread',
                created_at INTEGER DEFAULT (strftime('%s', 'now'))
            );
            CREATE INDEX IF NOT EXISTS idx_state ON notifications(state);",
        )?;
        Ok(())
    }

    pub fn add(&self, pane: &str, title: &str, message: &str) -> Result<()> {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;

        self.conn.execute(
            "INSERT OR REPLACE INTO notifications (pane, title, message, state, created_at)
             VALUES (?1, ?2, ?3, 'unread', ?4)",
            (pane, title, message, now),
        )?;
        Ok(())
    }

    pub fn query(&self) -> Result<Vec<Notification>> {
        let mut stmt = self.conn.prepare(
            "SELECT pane, title, message, state, created_at
             FROM notifications
             ORDER BY created_at DESC",
        )?;

        let notifications = stmt
            .query_map([], |row| {
                Ok(Notification {
                    pane: row.get(0)?,
                    title: row.get(1)?,
                    message: row.get(2)?,
                    state: row.get(3)?,
                    created_at: row.get(4)?,
                })
            })?
            .collect::<Result<Vec<_>>>()?;

        Ok(notifications)
    }

    pub fn count_unread(&self) -> Result<i64> {
        self.conn.query_row(
            "SELECT COUNT(*) FROM notifications WHERE state = 'unread'",
            [],
            |row| row.get(0),
        )
    }

    pub fn mark_read(&self, pane: &str) -> Result<usize> {
        let updated = self.conn.execute(
            "UPDATE notifications SET state = 'read' WHERE pane = ?1",
            [pane],
        )?;
        Ok(updated)
    }

    pub fn dismiss(&self, pane: &str) -> Result<usize> {
        let deleted = self.conn.execute(
            "DELETE FROM notifications WHERE pane = ?1",
            [pane],
        )?;
        Ok(deleted)
    }

    pub fn cleanup(&self, retention_hours: i64) -> Result<usize> {
        let cutoff = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64
            - (retention_hours * 3600);

        let deleted = self.conn.execute(
            "DELETE FROM notifications WHERE created_at < ?1",
            [cutoff],
        )?;
        Ok(deleted)
    }
}

pub fn get_default_db_path() -> PathBuf {
    // Try XDG_DATA_HOME first, then fallback to ~/.local/share
    if let Some(data_dir) = dirs::data_dir() {
        data_dir.join("tmux-notify").join("notifications.db")
    } else {
        let home = dirs::home_dir().unwrap_or_else(|| PathBuf::from("."));
        home.join(".local/share/tmux-notify/notifications.db")
    }
}
