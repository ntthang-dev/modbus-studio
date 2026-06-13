use rusqlite::Connection;
use std::sync::Mutex;

pub struct DbClient {
    conn: Mutex<Connection>,
}

impl DbClient {
    pub fn new(db_path: &str) -> anyhow::Result<DbClient> {
        let conn = Connection::open(db_path)?;
        
        let client = DbClient {
            conn: Mutex::new(conn),
        };
        client.init_db()?;
        
        Ok(client)
    }

    fn init_db(&self) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "CREATE TABLE IF NOT EXISTS poll_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                ip_address TEXT NOT NULL,
                address INTEGER NOT NULL,
                value INTEGER NOT NULL,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )",
            [],
        )?;
        Ok(())
    }

    pub fn log_data(&self, ip_address: &str, address: u16, value: u16) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO poll_logs (ip_address, address, value) VALUES (?1, ?2, ?3)",
            (ip_address, address, value),
        )?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn test_db_init_and_log() {
        let db_path = "test_modbus.db";
        
        // Ensure clean state
        let _ = fs::remove_file(db_path);

        let client = DbClient::new(db_path).expect("Failed to create db client");
        
        // Test logging
        let result = client.log_data("192.168.1.100", 40001, 1234);
        assert!(result.is_ok());

        // Verify data was inserted
        let conn = client.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT ip_address, address, value FROM poll_logs").unwrap();
        let mut rows = stmt.query([]).unwrap();
        
        let row = rows.next().unwrap().expect("Should have one row");
        let ip: String = row.get(0).unwrap();
        let addr: u16 = row.get(1).unwrap();
        let val: u16 = row.get(2).unwrap();
        
        assert_eq!(ip, "192.168.1.100");
        assert_eq!(addr, 40001);
        assert_eq!(val, 1234);

        // Cleanup
        let _ = fs::remove_file(db_path);
    }
}
