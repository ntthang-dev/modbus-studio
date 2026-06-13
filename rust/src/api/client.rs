use tokio_modbus::prelude::*;
use tokio::sync::Mutex;
use std::net::SocketAddr;
use std::time::Duration;

pub struct ModbusClient {
    // Context is wrapped in a Mutex so we can call mutable methods on it via an immutable reference
    context: Mutex<tokio_modbus::client::Context>,
}

impl ModbusClient {
    pub async fn connect(ip: String, port: u16) -> anyhow::Result<ModbusClient> {
        let addr: SocketAddr = format!("{}:{}", ip, port).parse()?;
        
        // We can add timeout around connect
        let connect_future = tcp::connect(addr);
        let context = tokio::time::timeout(Duration::from_secs(3), connect_future)
            .await
            .map_err(|_| anyhow::anyhow!("Connection timeout"))??;

        Ok(ModbusClient {
            context: Mutex::new(context),
        })
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
        // Try connecting to a local port that is highly likely closed (9999)
        let result = ModbusClient::connect("127.0.0.1".to_string(), 9999).await;
        
        // Ensure it returns an error
        assert!(result.is_err());
        
        let err_msg = result.err().unwrap().to_string();
        // The error message should indicate connection refused or similar TCP error
        assert!(err_msg.contains("Connection refused") || err_msg.contains("Connection reset by peer"));
    }
}
