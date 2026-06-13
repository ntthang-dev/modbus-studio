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

pub fn start_historian_loop(
    ip: String,
    port: u16,
    db_path: String,
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

        // 2. Connect to Modbus initially
        let mut client_opt = ModbusClient::connect(ip.clone(), port).await.ok();
        
        if client_opt.is_none() {
             let _ = sink.add(HistorianData { registers: vec![], error: Some("Connection failed. Retrying...".to_string()) });
        }

        let mut interval = time::interval(Duration::from_secs(1));

        loop {
            interval.tick().await;

            // Try reconnecting if disconnected
            if client_opt.is_none() {
                client_opt = ModbusClient::connect(ip.clone(), port).await.ok();
            }

            if let Some(client) = &client_opt {
                match client.read_holding_registers(0, 10).await {
                    Ok(data) => {
                        // Log to DB
                        // Note: Using loop for 10 items is fine since it's synchronous SQLite on a tokio thread.
                        // Ideally we'd use a transaction or spawn_blocking if it were large, but 10 rows is ~0.1ms.
                        for (i, &val) in data.iter().enumerate() {
                            let _ = db.log_data(&ip, 40000 + i as u16 + 1, val);
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
