use crate::api::db::ConnectionConfig;
use tokio_modbus::prelude::*;
use tokio::sync::Mutex;
use std::net::SocketAddr;
use std::time::Duration;

use tokio_modbus::client::rtu;

pub struct ModbusClient {
    // Context is wrapped in a Mutex so we can call mutable methods on it via an immutable reference
    context: Mutex<tokio_modbus::client::Context>,
}

impl ModbusClient {
    pub async fn connect(config: ConnectionConfig, slave_id: u8) -> anyhow::Result<ModbusClient> {
        let context = match config.protocol_type.as_str() {
            "TCP" => {
                let ip = config.ip.ok_or_else(|| anyhow::anyhow!("Missing IP address"))?;
                let port = config.port.unwrap_or(502);
                let addr: SocketAddr = format!("{}:{}", ip, port).parse()?;
                let connect_future = tcp::connect(addr);
                let ctx = tokio::time::timeout(Duration::from_secs(3), connect_future)
                    .await
                    .map_err(|_| anyhow::anyhow!("Connection timeout"))??;
                ctx
            }
            "RTU_TCP" => {
                let ip = config.ip.ok_or_else(|| anyhow::anyhow!("Missing IP address"))?;
                let port = config.port.unwrap_or(502);
                let addr: SocketAddr = format!("{}:{}", ip, port).parse()?;
                // Connect via TCP Stream and wrap in RTU slave transport (RTU over TCP encapsulated)
                let connect_future = tokio::net::TcpStream::connect(addr);
                let stream = tokio::time::timeout(Duration::from_secs(3), connect_future)
                    .await
                    .map_err(|_| anyhow::anyhow!("TCP Connection timeout"))??;
                let ctx = rtu::attach_slave(stream, Slave::from(slave_id));
                ctx
            }
            "SERIAL" => {
                let port_name = config.port_name.ok_or_else(|| anyhow::anyhow!("Missing Serial Port Name"))?;
                let baud_rate = config.baud_rate.unwrap_or(9600);
                let parity = config.parity.unwrap_or_else(|| "None".to_string());
                let data_bits = config.data_bits.unwrap_or(8);
                let stop_bits = config.stop_bits.unwrap_or(1);

                #[cfg(not(any(target_os = "ios", target_os = "android")))]
                {
                    use tokio_serial::SerialStream;
                    let builder = tokio_serial::new(port_name, baud_rate)
                        .data_bits(match data_bits {
                            7 => tokio_serial::DataBits::Seven,
                            _ => tokio_serial::DataBits::Eight,
                        })
                        .flow_control(tokio_serial::FlowControl::None)
                        .parity(match parity.as_str() {
                            "Even" => tokio_serial::Parity::Even,
                            "Odd" => tokio_serial::Parity::Odd,
                            _ => tokio_serial::Parity::None,
                        })
                        .stop_bits(match stop_bits {
                            2 => tokio_serial::StopBits::Two,
                            _ => tokio_serial::StopBits::One,
                        })
                        .timeout(Duration::from_secs(3));

                    let stream = SerialStream::open(&builder)?;
                    let ctx = rtu::attach_slave(stream, Slave::from(slave_id));
                    ctx
                }
                #[cfg(any(target_os = "ios", target_os = "android"))]
                {
                    let _ = (port_name, baud_rate, parity, data_bits, stop_bits);
                    return Err(anyhow::anyhow!("Serial USB on mobile requires native platform channels (USBDriverKit)"));
                }
            }
            _ => {
                return Err(anyhow::anyhow!("Unsupported or unimplemented Modbus protocol: {}", config.protocol_type));
            }
        };

        Ok(ModbusClient {
            context: Mutex::new(context),
        })
    }

    pub async fn read_coils(&self, address: u16, quantity: u16) -> anyhow::Result<Vec<bool>> {
        let mut ctx = self.context.lock().await;
        
        let read_future = ctx.read_coils(address, quantity);
        let response = tokio::time::timeout(Duration::from_secs(2), read_future)
            .await
            .map_err(|_| anyhow::anyhow!("Read timeout"))??;
            
        let data = response.map_err(|e| anyhow::anyhow!("Modbus Exception: {:?}", e))?;
        Ok(data)
    }

    pub async fn read_discrete_inputs(&self, address: u16, quantity: u16) -> anyhow::Result<Vec<bool>> {
        let mut ctx = self.context.lock().await;
        
        let read_future = ctx.read_discrete_inputs(address, quantity);
        let response = tokio::time::timeout(Duration::from_secs(2), read_future)
            .await
            .map_err(|_| anyhow::anyhow!("Read timeout"))??;
            
        let data = response.map_err(|e| anyhow::anyhow!("Modbus Exception: {:?}", e))?;
        Ok(data)
    }

    pub async fn read_holding_registers(&self, address: u16, quantity: u16) -> anyhow::Result<Vec<u16>> {
        let mut ctx = self.context.lock().await;
        
        let read_future = ctx.read_holding_registers(address, quantity);
        let response = tokio::time::timeout(Duration::from_secs(2), read_future)
            .await
            .map_err(|_| anyhow::anyhow!("Read timeout"))??;
            
        let data = response.map_err(|e| anyhow::anyhow!("Modbus Exception: {:?}", e))?;
        Ok(data)
    }

    pub async fn read_input_registers(&self, address: u16, quantity: u16) -> anyhow::Result<Vec<u16>> {
        let mut ctx = self.context.lock().await;
        
        let read_future = ctx.read_input_registers(address, quantity);
        let response = tokio::time::timeout(Duration::from_secs(2), read_future)
            .await
            .map_err(|_| anyhow::anyhow!("Read timeout"))??;
            
        let data = response.map_err(|e| anyhow::anyhow!("Modbus Exception: {:?}", e))?;
        Ok(data)
    }

    pub async fn write_single_coil(&self, address: u16, value: bool) -> anyhow::Result<()> {
        let mut ctx = self.context.lock().await;
        
        let write_future = ctx.write_single_coil(address, value);
        let response = tokio::time::timeout(Duration::from_secs(2), write_future)
            .await
            .map_err(|_| anyhow::anyhow!("Write timeout"))??;
            
        response.map_err(|e| anyhow::anyhow!("Modbus Exception: {:?}", e))?;
        Ok(())
    }

    pub async fn write_single_register(&self, address: u16, value: u16) -> anyhow::Result<()> {
        let mut ctx = self.context.lock().await;
        
        let write_future = ctx.write_single_register(address, value);
        let response = tokio::time::timeout(Duration::from_secs(2), write_future)
            .await
            .map_err(|_| anyhow::anyhow!("Write timeout"))??;
            
        response.map_err(|e| anyhow::anyhow!("Modbus Exception: {:?}", e))?;
        Ok(())
    }

    pub async fn disconnect(&self) -> anyhow::Result<()> {
        let mut ctx = self.context.lock().await;
        ctx.disconnect().await?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_connect_connection_refused() {
        let config = ConnectionConfig {
            protocol_type: "TCP".to_string(),
            ip: Some("127.0.0.1".to_string()),
            port: Some(9999),
            port_name: None,
            baud_rate: None,
            parity: None,
            data_bits: None,
            stop_bits: None,
        };
        let result = ModbusClient::connect(config, 1).await;
        
        // Ensure it returns an error
        assert!(result.is_err());
        
        let err_msg = result.err().unwrap().to_string();
        // The error message should indicate connection refused or similar TCP error
        assert!(err_msg.contains("Connection refused") || err_msg.contains("Connection reset by peer"));
    }
}
