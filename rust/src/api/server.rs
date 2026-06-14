use std::future::Future;
use std::pin::Pin;
use std::sync::Arc;
use tokio::sync::{oneshot, RwLock};
use tokio::net::TcpListener;
use tokio_modbus::prelude::*;
use tokio_modbus::server::Service;

// In-memory register storage
pub struct SimulatorState {
    holding_registers: Arc<RwLock<Vec<u16>>>,
}

pub struct ModbusSimulator {
    state: Arc<SimulatorState>,
    stop_tx: Option<oneshot::Sender<()>>,
}

// We implement Service for our simulator
struct SimulatorService {
    holding_registers: Arc<RwLock<Vec<u16>>>,
}

impl Service for SimulatorService {
    type Request = Request<'static>;
    type Response = Response;
    type Exception = ExceptionCode;
    type Future = Pin<Box<dyn Future<Output = Result<Self::Response, Self::Exception>> + Send>>;

    fn call(&self, req: Self::Request) -> Self::Future {
        let registers = self.holding_registers.clone();
        Box::pin(async move {
            match req {
                Request::ReadHoldingRegisters(addr, cnt) => {
                    let regs = registers.read().await;
                    let start = addr as usize;
                    let end = start + cnt as usize;
                    if end <= regs.len() {
                        Ok(Response::ReadHoldingRegisters(regs[start..end].to_vec()))
                    } else {
                        Err(ExceptionCode::IllegalDataAddress)
                    }
                }
                Request::WriteSingleRegister(addr, val) => {
                    let mut regs = registers.write().await;
                    let idx = addr as usize;
                    if idx < regs.len() {
                        regs[idx] = val;
                        Ok(Response::WriteSingleRegister(addr, val))
                    } else {
                        Err(ExceptionCode::IllegalDataAddress)
                    }
                }
                Request::WriteMultipleRegisters(addr, values) => {
                    let mut regs = registers.write().await;
                    let start = addr as usize;
                    let len = values.len();
                    if start + len <= regs.len() {
                        for i in 0..len {
                            regs[start + i] = values[i];
                        }
                        Ok(Response::WriteMultipleRegisters(addr, len as u16))
                    } else {
                        Err(ExceptionCode::IllegalDataAddress)
                    }
                }
                _ => Err(ExceptionCode::IllegalFunction),
            }
        })
    }
}

impl ModbusSimulator {
    pub async fn start(port: u16) -> anyhow::Result<Self> {
        let addr = format!("127.0.0.1:{}", port).parse::<std::net::SocketAddr>()?;
        let listener = TcpListener::bind(addr).await?;
        
        let holding_registers = Arc::new(RwLock::new(vec![0u16; 1000]));
        let state = Arc::new(SimulatorState {
            holding_registers: holding_registers.clone(),
        });

        let (stop_tx, stop_rx) = oneshot::channel::<()>();

        // Spawn TCP Modbus Server in the background
        tokio::spawn(async move {
            let server = tokio_modbus::server::tcp::Server::new(listener);
            let service = SimulatorService {
                holding_registers,
            };

            let on_connected = move |stream, _socket_addr| {
                let service = service.clone();
                async move {
                    Ok(Some((service, stream)))
                }
            };

            let on_process_error = |err| {
                eprintln!("Process error: {:?}", err);
            };

            let abort_signal = async move {
                let _ = stop_rx.await;
            };

            let _ = server.serve_until(&on_connected, on_process_error, abort_signal).await;
        });

        Ok(ModbusSimulator {
            state,
            stop_tx: Some(stop_tx),
        })
    }

    pub async fn stop(&mut self) -> anyhow::Result<()> {
        if let Some(stop_tx) = self.stop_tx.take() {
            let _ = stop_tx.send(());
        }
        Ok(())
    }

    pub async fn read_register(&self, addr: u16) -> anyhow::Result<u16> {
        let regs = self.state.holding_registers.read().await;
        let idx = addr as usize;
        if idx < regs.len() {
            Ok(regs[idx])
        } else {
            Err(anyhow::anyhow!("Address out of range"))
        }
    }

    pub async fn write_register(&self, addr: u16, val: u16) -> anyhow::Result<()> {
        let mut regs = self.state.holding_registers.write().await;
        let idx = addr as usize;
        if idx < regs.len() {
            regs[idx] = val;
            Ok(())
        } else {
            Err(anyhow::anyhow!("Address out of range"))
        }
    }
}

// We need to implement Clone for SimulatorService because multiple connections will share it
impl Clone for SimulatorService {
    fn clone(&self) -> Self {
        SimulatorService {
            holding_registers: self.holding_registers.clone(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::api::client::ModbusClient;
    use crate::api::db::ConnectionConfig;

    #[tokio::test]
    async fn test_simulator_server_read_write() {
        // Start simulator on a custom test port
        let port = 5502;
        let mut simulator = ModbusSimulator::start(port).await.expect("Failed to start simulator");

        // Create client connection config
        let config = ConnectionConfig {
            protocol_type: "TCP".to_string(),
            ip: Some("127.0.0.1".to_string()),
            port: Some(port),
            port_name: None,
            baud_rate: None,
            parity: None,
            data_bits: None,
            stop_bits: None,
        };

        // Connect client to the simulator
        let client = ModbusClient::connect(config, 1).await.expect("Failed to connect client");

        // Read holding register 40001 (address 0)
        let initial_regs = client.read_holding_registers(0, 1).await.expect("Failed to read register");
        assert_eq!(initial_regs[0], 0);

        // Write to holding register 40001
        client.write_single_register(0, 456).await.expect("Failed to write register");

        // Read back from client
        let final_regs = client.read_holding_registers(0, 1).await.expect("Failed to read back register");
        assert_eq!(final_regs[0], 456);

        // Read back directly from simulator state API
        let direct_val = simulator.read_register(0).await.expect("Failed direct read");
        assert_eq!(direct_val, 456);

        // Modify register directly from simulator state API
        simulator.write_register(0, 789).await.expect("Failed direct write");

        // Read back from client to verify it changed
        let updated_regs = client.read_holding_registers(0, 1).await.expect("Failed client read after direct change");
        assert_eq!(updated_regs[0], 789);

        // Stop simulator
        simulator.stop().await.expect("Failed to stop simulator");
    }
}
