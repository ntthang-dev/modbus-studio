use crate::api::client::ModbusClient;
use crate::api::db::DbClient;
use crate::frb_generated::StreamSink;
use std::time::Duration;
use tokio::time;

#[derive(Clone)]
pub struct HistorianData {
    pub registers: Vec<u16>,
    pub error: Option<String>,
}

#[derive(Clone)]
pub struct HistorianPoint {
    pub timestamp_ms: i64,
    pub address: u16,
    pub value: u16,
}

pub fn get_historical_data(
    db_path: String,
    ip: String,
    address: u16,
    limit: u32,
) -> anyhow::Result<Vec<HistorianPoint>> {
    let conn = rusqlite::Connection::open(db_path)?;
    
    // Convert SQLite CURRENT_TIMESTAMP to Unix epoch milliseconds
    let mut stmt = conn.prepare(
        "SELECT CAST(strftime('%s', timestamp) AS INTEGER) * 1000, value 
         FROM poll_logs 
         WHERE ip_address = ?1 AND address = ?2 
         ORDER BY id DESC LIMIT ?3"
    )?;
    
    let rows = stmt.query_map(rusqlite::params![ip, address, limit], |row| {
        Ok(HistorianPoint {
            timestamp_ms: row.get(0)?,
            address,
            value: row.get(1)?,
        })
    })?;

    let mut data = Vec::new();
    for row in rows {
        data.push(row?);
    }
    
    // Reverse so the chart draws from oldest to newest (left to right)
    data.reverse();
    
    Ok(data)
}

use crate::api::db::ConnectionConfig;

pub fn start_historian_loop(
    config: ConnectionConfig,
    slave_id: u8,
    db_path: String,
    function_code: u8,
    start_address: u16,
    quantity: u16,
    sink: StreamSink<HistorianData>
) -> anyhow::Result<()> {
    tokio::spawn(async move {
        // 1. Init DB
        let db = match DbClient::new(&db_path) {
            Ok(d) => d,
            Err(e) => {
                let _ = sink.add(HistorianData { registers: vec![], error: Some(format!("DB init error: {}", e)) });
                return;
            }
        };

        // Determine device key for SQL logging
        let device_key = if config.protocol_type == "TCP" || config.protocol_type == "RTU_TCP" {
            config.ip.clone().unwrap_or_default()
        } else {
            config.port_name.clone().unwrap_or_default()
        };

        // 2. Connect to Modbus initially
        let mut client_opt = ModbusClient::connect(config.clone(), slave_id).await.ok();
        
        if client_opt.is_none() {
             let _ = sink.add(HistorianData { registers: vec![], error: Some("Connection failed. Retrying...".to_string()) });
        }

        let mut interval = time::interval(Duration::from_secs(1));

        loop {
            interval.tick().await;

            // Try reconnecting if disconnected
            if client_opt.is_none() {
                client_opt = ModbusClient::connect(config.clone(), slave_id).await.ok();
            }

            if let Some(client) = &client_opt {
                let result = match function_code {
                    1 => match client.read_coils(start_address, quantity).await {
                        Ok(coils) => Ok(coils.into_iter().map(|b| if b { 1 } else { 0 }).collect()),
                        Err(e) => Err(e),
                    },
                    2 => match client.read_discrete_inputs(start_address, quantity).await {
                        Ok(inputs) => Ok(inputs.into_iter().map(|b| if b { 1 } else { 0 }).collect()),
                        Err(e) => Err(e),
                    },
                    3 => client.read_holding_registers(start_address, quantity).await,
                    4 => client.read_input_registers(start_address, quantity).await,
                    _ => Err(anyhow::anyhow!("Unsupported function code: {}", function_code)),
                };

                match result {
                    Ok(data) => {
                        // Log to DB
                        let address_prefix = match function_code {
                            1 => 1,
                            2 => 10001,
                            3 => 40001,
                            4 => 30001,
                            _ => 40001,
                        };
                        for (i, &val) in data.iter().enumerate() {
                            let _ = db.log_data(&device_key, address_prefix + start_address + i as u16, val);
                        }
                        
                        // Send to Flutter
                        if sink.add(HistorianData { registers: data, error: None }).is_err() {
                            // Flutter closed the stream
                            break;
                        }
                    }
                    Err(e) => {
                        let _ = sink.add(HistorianData { registers: vec![], error: Some(e.to_string()) });
                        // Drop client to force reconnect on next tick
                        client_opt = None;
                    }
                }
            } else {
                if sink.add(HistorianData { registers: vec![], error: Some("Disconnected. Retrying...".to_string()) }).is_err() {
                    break;
                }
            }
        }
    });

    Ok(())
}

pub fn get_telemetry_logs_by_range(
    db_path: String,
    start_ts: i64,
    end_ts: i64,
) -> anyhow::Result<Vec<HistorianPoint>> {
    let conn = rusqlite::Connection::open(db_path)?;
    
    let mut stmt = conn.prepare(
        "SELECT ip_address, address, value, CAST(strftime('%s', timestamp) AS INTEGER) * 1000 
         FROM poll_logs 
         WHERE timestamp >= datetime(?1 / 1000, 'unixepoch')
           AND timestamp <= datetime(?2 / 1000, 'unixepoch')
         ORDER BY id DESC"
    )?;
    
    let rows = stmt.query_map(rusqlite::params![start_ts, end_ts], |row| {
        let _ip: String = row.get(0)?;
        let address: u16 = row.get(1)?;
        let value: u16 = row.get(2)?;
        let timestamp_ms: i64 = row.get(3)?;
        Ok(HistorianPoint {
            timestamp_ms,
            address,
            value,
        })
    })?;

    let mut data = Vec::new();
    for row in rows {
        data.push(row?);
    }
    
    data.reverse();
    
    Ok(data)
}
