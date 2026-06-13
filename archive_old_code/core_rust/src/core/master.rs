use anyhow::Result;
use tracing::{info, error};
use tokio_modbus::prelude::*;
use std::time::Duration;

pub async fn run_master(protocol: String, target: String, slave_id: u8, action: String, address: u16, arg: u16) -> Result<()> {
    if protocol.to_lowercase() == "tcp" {
        let socket_addr = target.parse()?;
        let mut ctx = tokio::time::timeout(
            Duration::from_secs(2),
            tcp::connect(socket_addr)
        ).await??;
        
        ctx.set_slave(Slave(slave_id));

        tokio::time::timeout(Duration::from_secs(2), async {
            match action.as_str() {
                "read_holding" => {
                    let response = ctx.read_holding_registers(address, arg).await?;
                    info!("Response: {:?}", response);
                }
                "read_input" => {
                    let response = ctx.read_input_registers(address, arg).await?;
                    info!("Response: {:?}", response);
                }
                "write_holding" => {
                    ctx.write_single_register(address, arg).await?;
                    info!("Successfully wrote {} to {}", arg, address);
                }
                _ => {
                    error!("Unknown action: {}", action);
                }
            }
            Ok::<(), anyhow::Error>(())
        }).await??;
    } else if protocol.to_lowercase() == "rtu" {
        use tokio_serial::SerialPortBuilderExt;
        let builder = tokio_serial::new(&target, 9600);
        let port = tokio_serial::SerialStream::open(&builder)?;
        
        let mut ctx = rtu::attach_slave(port, Slave(slave_id));
        match action.as_str() {
            "read_holding" => {
                let response = ctx.read_holding_registers(address, arg).await?;
                info!("Response: {:?}", response);
            }
            "write_holding" => {
                ctx.write_single_register(address, arg).await?;
                info!("Successfully wrote {} to {}", arg, address);
            }
            _ => {
                error!("Action {} not fully implemented for RTU yet", action);
            }
        }
    } else {
        error!("Unknown protocol: {}", protocol);
    }

    Ok(())
}
