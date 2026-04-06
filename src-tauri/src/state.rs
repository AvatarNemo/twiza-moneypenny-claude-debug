// TWIZA Moneypenny — Application State

use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AppState {
    pub setup_complete: bool,
    pub gateway_running: bool,
    pub gateway_starting: bool,
}

impl Default for AppState {
    fn default() -> Self {
        Self {
            setup_complete: false,
            gateway_running: false,
            gateway_starting: false,
        }
    }
}
