use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Notification {
    pub pane: String,
    pub title: String,
    pub message: String,
    pub state: String,
    pub created_at: i64,
}

#[derive(Debug, Serialize)]
pub struct QueryResponse {
    pub ok: bool,
    pub notifications: Vec<Notification>,
}

#[derive(Debug, Serialize)]
pub struct ErrorResponse {
    pub ok: bool,
    pub error: String,
}
