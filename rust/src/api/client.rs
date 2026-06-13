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

    pub async fn disconnect(&self) -> anyhow::Result<()> {
        let mut ctx = self.context.lock().await;
        ctx.disconnect().await?;
        Ok(())
    }
}
