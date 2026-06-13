use crate::frb_generated::StreamSink;
use rand::RngExt;
use tokio::time::{sleep, Duration};

pub struct RadarDevice {
    pub ip: String,
    pub latency_ms: u16,
    pub status: String,
}

pub async fn start_mock_radar_scan(sink: StreamSink<RadarDevice>) {
    // Ping 255 IP addresses (mock)
    for i in 1..=254 {
        // Simulate non-blocking ping delay (very fast)
        let delay_ms = {
            let mut rng = rand::rng();
            rng.random_range(2..10)
        };
        sleep(Duration::from_millis(delay_ms)).await;

        // Roughly 10% chance to "find" a device to simulate real-world scatter
        let (is_found, latency) = {
            let mut rng = rand::rng();
            (rng.random_bool(0.10), rng.random_range(1..150))
        };

        if is_found {
            let status = if latency < 50 {
                "Online (Fast)".to_string()
            } else if latency < 100 {
                "Online (Moderate)".to_string()
            } else {
                "Online (Slow)".to_string()
            };

            let device = RadarDevice {
                ip: format!("192.168.1.{}", i),
                latency_ms: latency,
                status,
            };
            
            let _ = sink.add(device);
        }
    }
}
