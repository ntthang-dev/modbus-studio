use crate::frb_generated::StreamSink;
use std::time::Duration;
use tokio::net::TcpStream;
use tokio::time::timeout;

pub struct RadarDevice {
    pub ip: String,
    pub latency_ms: u16,
    pub status: String,
}

pub async fn start_radar_scan(subnet: String, sink: StreamSink<RadarDevice>) {
    // We will spawn 254 tasks to scan the subnet concurrently
    let mut handles = vec![];

    for i in 1..=254 {
        let ip = format!("{}.{}", subnet, i);
        let sink_clone = sink.clone();
        
        let handle = tokio::spawn(async move {
            let start = std::time::Instant::now();
            let addr = format!("{}:502", ip);
            
            // Very short timeout for scanning local networks
            if let Ok(Ok(_)) = timeout(Duration::from_millis(300), TcpStream::connect(&addr)).await {
                let latency = start.elapsed().as_millis() as u16;
                
                let status = if latency < 50 {
                    "Online (Fast)".to_string()
                } else if latency < 100 {
                    "Online (Moderate)".to_string()
                } else {
                    "Online (Slow)".to_string()
                };

                let device = RadarDevice {
                    ip,
                    latency_ms: latency,
                    status,
                };
                
                let _ = sink_clone.add(device);
            }
        });
        handles.push(handle);
    }

    // Wait for all scan tasks to finish
    for handle in handles {
        let _ = handle.await;
    }
}
