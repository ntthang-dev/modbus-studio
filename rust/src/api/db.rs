use rusqlite::Connection;
use std::sync::Mutex;

#[derive(Clone, Debug, PartialEq)]
pub struct ConnectionConfig {
    pub protocol_type: String, // "TCP", "RTU_TCP", "SERIAL", "ASCII"
    pub ip: Option<String>,
    pub port: Option<u16>,
    pub port_name: Option<String>,
    pub baud_rate: Option<u32>,
    pub parity: Option<String>, // "None", "Even", "Odd"
    pub data_bits: Option<u8>,
    pub stop_bits: Option<u8>,
}

#[derive(Clone, Debug)]
pub struct ConnectionProfile {
    pub id: Option<i64>,
    pub name: String,
    pub config: ConnectionConfig,
    pub is_favorite: bool,
    pub last_used: i64, // Unix timestamp in milliseconds
}

#[derive(Clone, Debug, PartialEq)]
pub struct AlarmRule {
    pub id: Option<i64>,
    pub name: String,
    pub register_address: u16,
    pub condition: String, // ">", "<", "==", "!="
    pub threshold: u16,
    pub severity: String, // "Warning", "Critical"
    pub is_enabled: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub struct AlarmLog {
    pub id: Option<i64>,
    pub rule_id: Option<i64>,
    pub register_address: u16,
    pub value: u16,
    pub message: String,
    pub severity: String, // "Warning", "Critical"
    pub timestamp: i64, // Unix timestamp in milliseconds
}

#[derive(Clone, Debug, PartialEq)]
pub struct ScheduledWrite {
    pub id: Option<i64>,
    pub address: u16,
    pub value: u16,
    pub interval_secs: u32,
    pub is_coil: bool,
    pub is_enabled: bool,
}

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
        // Enable Write-Ahead Logging for concurrent read/write
        conn.execute_batch(
            "PRAGMA journal_mode = WAL;
             PRAGMA synchronous = NORMAL;",
        )?;

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

        conn.execute(
            "CREATE TABLE IF NOT EXISTS connection_profiles (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                protocol_type TEXT NOT NULL,
                host TEXT,
                port INTEGER,
                port_name TEXT,
                baud_rate INTEGER,
                parity TEXT,
                data_bits INTEGER,
                stop_bits INTEGER,
                is_favorite INTEGER NOT NULL DEFAULT 0,
                last_used INTEGER NOT NULL DEFAULT 0
            )",
            [],
        )?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS alarm_rules (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                name TEXT NOT NULL,
                register_address INTEGER NOT NULL,
                condition TEXT NOT NULL,
                threshold INTEGER NOT NULL,
                severity TEXT NOT NULL,
                is_enabled INTEGER NOT NULL DEFAULT 1
            )",
            [],
        )?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS alarm_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                rule_id INTEGER,
                register_address INTEGER NOT NULL,
                value INTEGER NOT NULL,
                message TEXT NOT NULL,
                severity TEXT NOT NULL,
                timestamp INTEGER NOT NULL
            )",
            [],
        )?;

        conn.execute(
            "CREATE TABLE IF NOT EXISTS scheduled_writes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                address INTEGER NOT NULL,
                value INTEGER NOT NULL,
                interval_secs INTEGER NOT NULL,
                is_coil INTEGER NOT NULL DEFAULT 0,
                is_enabled INTEGER NOT NULL DEFAULT 1
            )",
            [],
        )?;

        // Create indexes on timestamp columns for range query performance
        conn.execute("CREATE INDEX IF NOT EXISTS idx_poll_logs_timestamp ON poll_logs (timestamp)", [])?;
        conn.execute("CREATE INDEX IF NOT EXISTS idx_alarm_logs_timestamp ON alarm_logs (timestamp)", [])?;

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

    pub fn save_profile(&self, profile: ConnectionProfile) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        
        let port_i32 = profile.config.port.map(|v| v as i32);
        let baud_rate_i32 = profile.config.baud_rate.map(|v| v as i32);
        let data_bits_i32 = profile.config.data_bits.map(|v| v as i32);
        let stop_bits_i32 = profile.config.stop_bits.map(|v| v as i32);
        let is_favorite_int = if profile.is_favorite { 1 } else { 0 };

        if let Some(id) = profile.id {
            conn.execute(
                "UPDATE connection_profiles 
                 SET name = ?1, protocol_type = ?2, host = ?3, port = ?4, port_name = ?5, 
                     baud_rate = ?6, parity = ?7, data_bits = ?8, stop_bits = ?9, 
                     is_favorite = ?10, last_used = ?11 
                 WHERE id = ?12",
                (
                    &profile.name,
                    &profile.config.protocol_type,
                    &profile.config.ip,
                    port_i32,
                    &profile.config.port_name,
                    baud_rate_i32,
                    &profile.config.parity,
                    data_bits_i32,
                    stop_bits_i32,
                    is_favorite_int,
                    profile.last_used,
                    id,
                ),
            )?;
        } else {
            conn.execute(
                "INSERT INTO connection_profiles 
                 (name, protocol_type, host, port, port_name, baud_rate, parity, data_bits, stop_bits, is_favorite, last_used) 
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11)",
                (
                    &profile.name,
                    &profile.config.protocol_type,
                    &profile.config.ip,
                    port_i32,
                    &profile.config.port_name,
                    baud_rate_i32,
                    &profile.config.parity,
                    data_bits_i32,
                    stop_bits_i32,
                    is_favorite_int,
                    profile.last_used,
                ),
            )?;
        }
        Ok(())
    }

    pub fn get_profiles(&self) -> anyhow::Result<Vec<ConnectionProfile>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, name, protocol_type, host, port, port_name, baud_rate, parity, data_bits, stop_bits, is_favorite, last_used 
             FROM connection_profiles 
             ORDER BY is_favorite DESC, last_used DESC"
        )?;

        let rows = stmt.query_map([], |row| {
            let id: i64 = row.get(0)?;
            let name: String = row.get(1)?;
            let protocol_type: String = row.get(2)?;
            let host: Option<String> = row.get(3)?;
            let port: Option<i32> = row.get(4)?;
            let port_name: Option<String> = row.get(5)?;
            let baud_rate: Option<i32> = row.get(6)?;
            let parity: Option<String> = row.get(7)?;
            let data_bits: Option<i32> = row.get(8)?;
            let stop_bits: Option<i32> = row.get(9)?;
            let is_favorite_int: i32 = row.get(10)?;
            let last_used: i64 = row.get(11)?;

            let config = ConnectionConfig {
                protocol_type,
                ip: host,
                port: port.map(|v| v as u16),
                port_name,
                baud_rate: baud_rate.map(|v| v as u32),
                parity,
                data_bits: data_bits.map(|v| v as u8),
                stop_bits: stop_bits.map(|v| v as u8),
            };

            Ok(ConnectionProfile {
                id: Some(id),
                name,
                config,
                is_favorite: is_favorite_int == 1,
                last_used,
            })
        })?;

        let mut profiles = Vec::new();
        for row in rows {
            profiles.push(row?);
        }
        Ok(profiles)
    }

    pub fn delete_profile(&self, id: i64) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM connection_profiles WHERE id = ?1", [id])?;
        Ok(())
    }

    pub fn save_rule(&self, rule: AlarmRule) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        let is_enabled_int = if rule.is_enabled { 1 } else { 0 };

        if let Some(id) = rule.id {
            conn.execute(
                "UPDATE alarm_rules 
                 SET name = ?1, register_address = ?2, condition = ?3, threshold = ?4, severity = ?5, is_enabled = ?6 
                 WHERE id = ?7",
                (
                    &rule.name,
                    rule.register_address as i32,
                    &rule.condition,
                    rule.threshold as i32,
                    &rule.severity,
                    is_enabled_int,
                    id,
                ),
            )?;
        } else {
            conn.execute(
                "INSERT INTO alarm_rules (name, register_address, condition, threshold, severity, is_enabled) 
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
                (
                    &rule.name,
                    rule.register_address as i32,
                    &rule.condition,
                    rule.threshold as i32,
                    &rule.severity,
                    is_enabled_int,
                ),
            )?;
        }
        Ok(())
    }

    pub fn get_rules(&self) -> anyhow::Result<Vec<AlarmRule>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, name, register_address, condition, threshold, severity, is_enabled FROM alarm_rules"
        )?;

        let rows = stmt.query_map([], |row| {
            let id: i64 = row.get(0)?;
            let name: String = row.get(1)?;
            let register_address: i32 = row.get(2)?;
            let condition: String = row.get(3)?;
            let threshold: i32 = row.get(4)?;
            let severity: String = row.get(5)?;
            let is_enabled_int: i32 = row.get(6)?;

            Ok(AlarmRule {
                id: Some(id),
                name,
                register_address: register_address as u16,
                condition,
                threshold: threshold as u16,
                severity,
                is_enabled: is_enabled_int == 1,
            })
        })?;

        let mut rules = Vec::new();
        for row in rows {
            rules.push(row?);
        }
        Ok(rules)
    }

    pub fn delete_rule(&self, id: i64) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM alarm_rules WHERE id = ?1", [id])?;
        Ok(())
    }

    pub fn save_scheduled_write(&self, write: ScheduledWrite) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        let is_coil_int = if write.is_coil { 1 } else { 0 };
        let is_enabled_int = if write.is_enabled { 1 } else { 0 };

        if let Some(id) = write.id {
            conn.execute(
                "UPDATE scheduled_writes 
                 SET address = ?1, value = ?2, interval_secs = ?3, is_coil = ?4, is_enabled = ?5 
                 WHERE id = ?6",
                (
                    write.address as i32,
                    write.value as i32,
                    write.interval_secs as i32,
                    is_coil_int,
                    is_enabled_int,
                    id,
                ),
            )?;
        } else {
            conn.execute(
                "INSERT INTO scheduled_writes (address, value, interval_secs, is_coil, is_enabled) 
                 VALUES (?1, ?2, ?3, ?4, ?5)",
                (
                    write.address as i32,
                    write.value as i32,
                    write.interval_secs as i32,
                    is_coil_int,
                    is_enabled_int,
                ),
            )?;
        }
        Ok(())
    }

    pub fn get_scheduled_writes(&self) -> anyhow::Result<Vec<ScheduledWrite>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, address, value, interval_secs, is_coil, is_enabled FROM scheduled_writes"
        )?;

        let rows = stmt.query_map([], |row| {
            let id: i64 = row.get(0)?;
            let address: i32 = row.get(1)?;
            let value: i32 = row.get(2)?;
            let interval_secs: i32 = row.get(3)?;
            let is_coil_int: i32 = row.get(4)?;
            let is_enabled_int: i32 = row.get(5)?;

            Ok(ScheduledWrite {
                id: Some(id),
                address: address as u16,
                value: value as u16,
                interval_secs: interval_secs as u32,
                is_coil: is_coil_int == 1,
                is_enabled: is_enabled_int == 1,
            })
        })?;

        let mut list = Vec::new();
        for row in rows {
            list.push(row?);
        }
        Ok(list)
    }

    pub fn delete_scheduled_write(&self, id: i64) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM scheduled_writes WHERE id = ?1", [id])?;
        Ok(())
    }

    pub fn log_alarm(&self, log: AlarmLog) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "INSERT INTO alarm_logs (rule_id, register_address, value, message, severity, timestamp) 
             VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
            (
                log.rule_id,
                log.register_address as i32,
                log.value as i32,
                &log.message,
                &log.severity,
                log.timestamp,
            ),
        )?;
        Ok(())
    }

    pub fn get_alarm_logs(&self) -> anyhow::Result<Vec<AlarmLog>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, rule_id, register_address, value, message, severity, timestamp 
             FROM alarm_logs 
             ORDER BY timestamp DESC"
        )?;

        let rows = stmt.query_map([], |row| {
            let id: i64 = row.get(0)?;
            let rule_id: Option<i64> = row.get(1)?;
            let register_address: i32 = row.get(2)?;
            let value: i32 = row.get(3)?;
            let message: String = row.get(4)?;
            let severity: String = row.get(5)?;
            let timestamp: i64 = row.get(6)?;

            Ok(AlarmLog {
                id: Some(id),
                rule_id,
                register_address: register_address as u16,
                value: value as u16,
                message,
                severity,
                timestamp,
            })
        })?;

        let mut logs = Vec::new();
        for row in rows {
            logs.push(row?);
        }
        Ok(logs)
    }

    pub fn get_alarm_logs_by_range(&self, start_ts: i64, end_ts: i64) -> anyhow::Result<Vec<AlarmLog>> {
        let conn = self.conn.lock().unwrap();
        let mut stmt = conn.prepare(
            "SELECT id, rule_id, register_address, value, message, severity, timestamp 
             FROM alarm_logs 
             WHERE timestamp >= ?1 AND timestamp <= ?2 
             ORDER BY timestamp DESC"
        )?;

        let rows = stmt.query_map([start_ts, end_ts], |row| {
            let id: i64 = row.get(0)?;
            let rule_id: Option<i64> = row.get(1)?;
            let register_address: i32 = row.get(2)?;
            let value: i32 = row.get(3)?;
            let message: String = row.get(4)?;
            let severity: String = row.get(5)?;
            let timestamp: i64 = row.get(6)?;

            Ok(AlarmLog {
                id: Some(id),
                rule_id,
                register_address: register_address as u16,
                value: value as u16,
                message,
                severity,
                timestamp,
            })
        })?;

        let mut logs = Vec::new();
        for row in rows {
            logs.push(row?);
        }
        Ok(logs)
    }

    pub fn clear_alarm_logs(&self) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute("DELETE FROM alarm_logs", [])?;
        Ok(())
    }

    pub fn prune_poll_logs(&self, max_rows: i64) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "DELETE FROM poll_logs 
             WHERE id NOT IN (
                 SELECT id FROM poll_logs 
                 ORDER BY id DESC 
                 LIMIT ?1
             )",
            [max_rows],
        )?;
        Ok(())
    }

    pub fn prune_alarm_logs(&self, max_rows: i64) -> anyhow::Result<()> {
        let conn = self.conn.lock().unwrap();
        conn.execute(
            "DELETE FROM alarm_logs 
             WHERE id NOT IN (
                 SELECT id FROM alarm_logs 
                 ORDER BY id DESC 
                 LIMIT ?1
             )",
            [max_rows],
        )?;
        Ok(())
    }
}

// Global functions exposed to Dart/Flutter via flutter_rust_bridge
pub fn db_save_profile(db_path: String, profile: ConnectionProfile) -> anyhow::Result<()> {
    let client = DbClient::new(&db_path)?;
    client.save_profile(profile)
}

pub fn db_get_profiles(db_path: String) -> anyhow::Result<Vec<ConnectionProfile>> {
    let client = DbClient::new(&db_path)?;
    client.get_profiles()
}

pub fn db_delete_profile(db_path: String, id: i64) -> anyhow::Result<()> {
    let client = DbClient::new(&db_path)?;
    client.delete_profile(id)
}

pub fn db_save_rule(db_path: String, rule: AlarmRule) -> anyhow::Result<()> {
    let client = DbClient::new(&db_path)?;
    client.save_rule(rule)
}

pub fn db_get_rules(db_path: String) -> anyhow::Result<Vec<AlarmRule>> {
    let client = DbClient::new(&db_path)?;
    client.get_rules()
}

pub fn db_delete_rule(db_path: String, id: i64) -> anyhow::Result<()> {
    let client = DbClient::new(&db_path)?;
    client.delete_rule(id)
}

pub fn db_log_alarm(db_path: String, log: AlarmLog) -> anyhow::Result<()> {
    let client = DbClient::new(&db_path)?;
    client.log_alarm(log)
}

pub fn db_get_alarm_logs(db_path: String) -> anyhow::Result<Vec<AlarmLog>> {
    let client = DbClient::new(&db_path)?;
    client.get_alarm_logs()
}

pub fn db_get_alarm_logs_by_range(db_path: String, start_ts: i64, end_ts: i64) -> anyhow::Result<Vec<AlarmLog>> {
    let client = DbClient::new(&db_path)?;
    client.get_alarm_logs_by_range(start_ts, end_ts)
}

pub fn db_clear_alarm_logs(db_path: String) -> anyhow::Result<()> {
    let client = DbClient::new(&db_path)?;
    client.clear_alarm_logs()
}

pub fn db_prune_poll_logs(db_path: String, max_rows: i64) -> anyhow::Result<()> {
    let client = DbClient::new(&db_path)?;
    client.prune_poll_logs(max_rows)
}

pub fn db_prune_alarm_logs(db_path: String, max_rows: i64) -> anyhow::Result<()> {
    let client = DbClient::new(&db_path)?;
    client.prune_alarm_logs(max_rows)
}

pub fn db_save_scheduled_write(db_path: String, write: ScheduledWrite) -> anyhow::Result<()> {
    let client = DbClient::new(&db_path)?;
    client.save_scheduled_write(write)
}

pub fn db_get_scheduled_writes(db_path: String) -> anyhow::Result<Vec<ScheduledWrite>> {
    let client = DbClient::new(&db_path)?;
    client.get_scheduled_writes()
}

pub fn db_delete_scheduled_write(db_path: String, id: i64) -> anyhow::Result<()> {
    let client = DbClient::new(&db_path)?;
    client.delete_scheduled_write(id)
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn test_db_init_and_log() {
        let db_path = "test_modbus_log2.db";
        let _ = fs::remove_file(db_path);

        let client = DbClient::new(db_path).expect("Failed to create db client");
        let result = client.log_data("192.168.1.100", 40001, 1234);
        assert!(result.is_ok());

        // Cleanup
        let _ = fs::remove_file(db_path);
    }

    #[test]
    fn test_profile_crud() {
        let db_path = "test_modbus_profiles_flat.db";
        let _ = fs::remove_file(db_path);

        let client = DbClient::new(db_path).expect("Failed to create db client");
        
        // Test save TCP profile
        let tcp_profile = ConnectionProfile {
            id: None,
            name: "Test TCP Node".to_string(),
            config: ConnectionConfig {
                protocol_type: "TCP".to_string(),
                ip: Some("192.168.1.50".to_string()),
                port: Some(502),
                port_name: None,
                baud_rate: None,
                parity: None,
                data_bits: None,
                stop_bits: None,
            },
            is_favorite: true,
            last_used: 12345678,
        };
        client.save_profile(tcp_profile).unwrap();

        // Test save Serial profile
        let serial_profile = ConnectionProfile {
            id: None,
            name: "Test Serial Node".to_string(),
            config: ConnectionConfig {
                protocol_type: "SERIAL".to_string(),
                ip: None,
                port: None,
                port_name: Some("/dev/ttyUSB0".to_string()),
                baud_rate: Some(115200),
                parity: Some("Even".to_string()),
                data_bits: Some(8),
                stop_bits: Some(1),
            },
            is_favorite: false,
            last_used: 87654321,
        };
        client.save_profile(serial_profile).unwrap();

        // Get profiles
        let profiles = client.get_profiles().unwrap();
        assert_eq!(profiles.len(), 2);
        
        // Favorite profile should be first
        assert_eq!(profiles[0].name, "Test TCP Node");
        assert_eq!(profiles[0].is_favorite, true);
        
        assert_eq!(profiles[0].config.ip, Some("192.168.1.50".to_string()));
        assert_eq!(profiles[0].config.port, Some(502));

        // Test delete
        let profile_id = profiles[0].id.unwrap();
        client.delete_profile(profile_id).unwrap();

        let updated_profiles = client.get_profiles().unwrap();
        assert_eq!(updated_profiles.len(), 1);
        assert_eq!(updated_profiles[0].name, "Test Serial Node");

        // Cleanup
        let _ = fs::remove_file(db_path);
    }

    #[test]
    fn test_alarm_rules_and_logs() {
        let db_path = "test_modbus_alarms.db";
        let _ = fs::remove_file(db_path);

        let client = DbClient::new(db_path).expect("Failed to create db client");

        // Create a rule
        let rule = AlarmRule {
            id: None,
            name: "High Temp".to_string(),
            register_address: 40001,
            condition: ">".to_string(),
            threshold: 800,
            severity: "Critical".to_string(),
            is_enabled: true,
        };
        client.save_rule(rule).unwrap();

        // Get rules
        let rules = client.get_rules().unwrap();
        assert_eq!(rules.len(), 1);
        assert_eq!(rules[0].name, "High Temp");
        assert_eq!(rules[0].register_address, 40001);

        let rule_id = rules[0].id;

        // Log alarm
        let log = AlarmLog {
            id: None,
            rule_id,
            register_address: 40001,
            value: 850,
            message: "Temperature breached threshold: 850 > 800".to_string(),
            severity: "Critical".to_string(),
            timestamp: 1620000000000,
        };
        client.log_alarm(log).unwrap();

        // Get logs
        let logs = client.get_alarm_logs().unwrap();
        assert_eq!(logs.len(), 1);
        assert_eq!(logs[0].value, 850);
        assert_eq!(logs[0].severity, "Critical");

        // Delete rule
        client.delete_rule(rule_id.unwrap()).unwrap();
        let rules_after = client.get_rules().unwrap();
        assert_eq!(rules_after.len(), 0);

        // Clear logs
        client.clear_alarm_logs().unwrap();
        let logs_after = client.get_alarm_logs().unwrap();
        assert_eq!(logs_after.len(), 0);

        // Cleanup
        let _ = fs::remove_file(db_path);
    }

    #[test]
    fn test_db_pruning() {
        let db_path = "test_modbus_prune.db";
        let _ = fs::remove_file(db_path);

        let client = DbClient::new(db_path).expect("Failed to create db client");
        
        // Log 5 records
        for i in 1..=5 {
            client.log_data("192.168.1.100", 40001, i).unwrap();
        }

        // Cap to 3
        client.prune_poll_logs(3).unwrap();

        // Verify remaining logs is 3
        let conn = client.conn.lock().unwrap();
        let mut stmt = conn.prepare("SELECT value FROM poll_logs ORDER BY timestamp ASC").unwrap();
        let rows = stmt.query_map([], |row| {
            let val: u16 = row.get(0)?;
            Ok(val)
        }).unwrap();

        let mut values = Vec::new();
        for r in rows {
            values.push(r.unwrap());
        }

        assert_eq!(values.len(), 3);
        assert_eq!(values[0], 3);
        assert_eq!(values[1], 4);
        assert_eq!(values[2], 5);

        // Cleanup
        let _ = fs::remove_file(db_path);
    }

    #[test]
    fn test_scheduled_writes_crud() {
        let db_path = "test_modbus_scheduled_writes.db";
        let _ = fs::remove_file(db_path);

        let client = DbClient::new(db_path).expect("Failed to create db client");

        // Verify initial state is empty
        let initial = client.get_scheduled_writes().unwrap();
        assert_eq!(initial.len(), 0);

        // Save scheduled write
        let write = ScheduledWrite {
            id: None,
            address: 40005,
            value: 123,
            interval_secs: 10,
            is_coil: false,
            is_enabled: true,
        };
        client.save_scheduled_write(write).unwrap();

        // Get and verify
        let list = client.get_scheduled_writes().unwrap();
        assert_eq!(list.len(), 1);
        assert_eq!(list[0].address, 40005);
        assert_eq!(list[0].value, 123);
        assert_eq!(list[0].interval_secs, 10);
        assert_eq!(list[0].is_coil, false);
        assert_eq!(list[0].is_enabled, true);

        // Update
        let mut updated = list[0].clone();
        updated.value = 456;
        updated.is_enabled = false;
        client.save_scheduled_write(updated).unwrap();

        // Verify update
        let list_updated = client.get_scheduled_writes().unwrap();
        assert_eq!(list_updated.len(), 1);
        assert_eq!(list_updated[0].value, 456);
        assert_eq!(list_updated[0].is_enabled, false);

        // Delete
        let id = list_updated[0].id.unwrap();
        client.delete_scheduled_write(id).unwrap();

        // Verify empty
        let final_list = client.get_scheduled_writes().unwrap();
        assert_eq!(final_list.len(), 0);

        // Cleanup
        let _ = fs::remove_file(db_path);
    }

    #[test]
    fn test_alarm_and_telemetry_range_queries() {
        let db_path = "test_modbus_range_queries.db";
        let _ = fs::remove_file(db_path);

        let client = DbClient::new(db_path).expect("Failed to create db client");

        // Insert alarm logs with specific timestamps
        let alarm1 = AlarmLog {
            id: None,
            rule_id: Some(1),
            register_address: 40001,
            value: 100,
            message: "Test alarm 1".to_string(),
            severity: "Critical".to_string(),
            timestamp: 1000,
        };
        let alarm2 = AlarmLog {
            id: None,
            rule_id: Some(1),
            register_address: 40001,
            value: 105,
            message: "Test alarm 2".to_string(),
            severity: "Warning".to_string(),
            timestamp: 2000,
        };
        let alarm3 = AlarmLog {
            id: None,
            rule_id: Some(2),
            register_address: 40002,
            value: 50,
            message: "Test alarm 3".to_string(),
            severity: "Warning".to_string(),
            timestamp: 3000,
        };

        client.log_alarm(alarm1).unwrap();
        client.log_alarm(alarm2).unwrap();
        client.log_alarm(alarm3).unwrap();

        // Query alarm logs range
        let logs_all = client.get_alarm_logs_by_range(0, 4000).unwrap();
        assert_eq!(logs_all.len(), 3);

        let logs_partial = client.get_alarm_logs_by_range(1500, 3500).unwrap();
        assert_eq!(logs_partial.len(), 2);
        assert_eq!(logs_partial[0].timestamp, 3000);
        assert_eq!(logs_partial[1].timestamp, 2000);

        // Insert telemetry logs into poll_logs with offset timestamps relative to now
        {
            let conn = rusqlite::Connection::open(db_path).unwrap();
            conn.execute(
                "INSERT INTO poll_logs (ip_address, address, value, timestamp) 
                 VALUES ('127.0.0.1', 40001, 10, datetime('now', '-20 seconds'))", 
                []
            ).unwrap();
            conn.execute(
                "INSERT INTO poll_logs (ip_address, address, value, timestamp) 
                 VALUES ('127.0.0.1', 40001, 20, datetime('now', '-10 seconds'))", 
                []
            ).unwrap();
            conn.execute(
                "INSERT INTO poll_logs (ip_address, address, value, timestamp) 
                 VALUES ('127.0.0.1', 40001, 30, datetime('now', '-2 seconds'))", 
                []
            ).unwrap();
        }

        let now_sec = std::time::SystemTime::now()
            .duration_since(std::time::SystemTime::UNIX_EPOCH)
            .unwrap()
            .as_secs() as i64;

        use crate::api::historian::get_telemetry_logs_by_range;
        // Query last 30 seconds
        let t_all = get_telemetry_logs_by_range(db_path.to_string(), (now_sec - 35) * 1000, (now_sec + 5) * 1000).unwrap();
        assert_eq!(t_all.len(), 3);
        assert_eq!(t_all[0].value, 10);
        assert_eq!(t_all[1].value, 20);
        assert_eq!(t_all[2].value, 30);

        // Query last 15 seconds (should miss the -20 seconds record)
        let t_recent = get_telemetry_logs_by_range(db_path.to_string(), (now_sec - 15) * 1000, (now_sec + 5) * 1000).unwrap();
        assert_eq!(t_recent.len(), 2);
        assert_eq!(t_recent[0].value, 20);
        assert_eq!(t_recent[1].value, 30);

        // Cleanup
        let _ = fs::remove_file(db_path);
    }
}
