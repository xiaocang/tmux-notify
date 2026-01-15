use crate::models::Notification;
use rusqlite::{Connection, Result};
use std::path::PathBuf;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

pub struct Database {
    conn: Connection,
}

impl Database {
    pub fn open(custom_path: Option<PathBuf>) -> Result<Self, Box<dyn std::error::Error>> {
        let db_path = match custom_path {
            Some(path) => path,
            None => get_default_db_path()?,
        };

        // Ensure parent directory exists
        if let Some(parent) = db_path.parent() {
            std::fs::create_dir_all(parent).ok();
        }

        let conn = Connection::open(&db_path)?;
        // Set busy timeout to handle concurrent access (5 seconds)
        conn.busy_timeout(Duration::from_secs(5))?;
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

        // Use ON CONFLICT to preserve state unless content actually changes
        // This prevents "resurrecting" a read notification when add is called again
        self.conn.execute(
            "INSERT INTO notifications (pane, title, message, state, created_at)
             VALUES (?1, ?2, ?3, 'unread', ?4)
             ON CONFLICT(pane) DO UPDATE SET
                 title = excluded.title,
                 message = excluded.message,
                 created_at = excluded.created_at,
                 state = CASE
                     WHEN notifications.title != excluded.title
                       OR notifications.message != excluded.message
                     THEN 'unread'
                     ELSE notifications.state
                 END",
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
        let deleted = self
            .conn
            .execute("DELETE FROM notifications WHERE pane = ?1", [pane])?;
        Ok(deleted)
    }

    pub fn cleanup(&self, retention_hours: i64) -> Result<usize> {
        let cutoff = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64
            - (retention_hours * 3600);

        let deleted = self
            .conn
            .execute("DELETE FROM notifications WHERE created_at < ?1", [cutoff])?;
        Ok(deleted)
    }

    pub fn prune(&self, valid_panes: &[String]) -> Result<usize> {
        if valid_panes.is_empty() {
            // If no valid panes provided, delete all notifications
            let deleted = self.conn.execute("DELETE FROM notifications", [])?;
            return Ok(deleted);
        }

        // Build placeholders for IN clause
        let placeholders: Vec<String> = (1..=valid_panes.len()).map(|i| format!("?{}", i)).collect();
        let sql = format!(
            "DELETE FROM notifications WHERE pane NOT IN ({})",
            placeholders.join(", ")
        );

        let params: Vec<&dyn rusqlite::ToSql> = valid_panes
            .iter()
            .map(|s| s as &dyn rusqlite::ToSql)
            .collect();

        let deleted = self.conn.execute(&sql, params.as_slice())?;
        Ok(deleted)
    }
}

pub fn get_default_db_path() -> Result<PathBuf, String> {
    // Try XDG_DATA_HOME first, then fallback to ~/.local/share
    if let Some(data_dir) = dirs::data_dir() {
        Ok(data_dir.join("tmux-notify").join("notifications.db"))
    } else if let Some(home) = dirs::home_dir() {
        Ok(home.join(".local/share/tmux-notify/notifications.db"))
    } else {
        Err("Could not determine home directory. Set HOME or use --db-path".to_string())
    }
}
