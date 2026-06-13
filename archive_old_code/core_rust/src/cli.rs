use clap::{Parser, Subcommand};

#[derive(Parser, Debug)]
#[command(author, version, about = "Modbus Studio CLI", long_about = None)]
pub struct Cli {
    #[command(subcommand)]
    pub command: Option<Commands>,
}

#[derive(Subcommand, Debug)]
pub enum Commands {
    /// Read registers/coils from Modbus
    Read {
        #[arg(long, default_value = "tcp")]
        protocol: String, // tcp or rtu
        
        #[arg(long, default_value = "127.0.0.1:502")]
        target: String, // IP:port or /dev/ttyUSB0
        
        #[arg(long, default_value_t = 1)]
        slave_id: u8,
        
        #[arg(long, default_value = "holding")]
        func: String, // holding, input, coil, discrete
        
        #[arg(long, default_value_t = 0)]
        addr: u16,
        
        #[arg(long, default_value_t = 1)]
        count: u16,
    },
    
    /// Write value to Modbus register/coil
    Write {
        #[arg(long, default_value = "tcp")]
        protocol: String,
        
        #[arg(long, default_value = "127.0.0.1:502")]
        target: String,
        
        #[arg(long, default_value_t = 1)]
        slave_id: u8,

        #[arg(long, default_value = "holding")]
        func: String,
        
        #[arg(long, default_value_t = 0)]
        addr: u16,
        
        #[arg(long, default_value_t = 0)]
        value: u16,
    },

    /// Scan for active Modbus devices
    Scan {
        #[arg(long, default_value = "tcp")]
        protocol: String,
        
        #[arg(long, default_value = "127.0.0.1:502")]
        target: String,
        
        #[arg(long, default_value_t = 1)]
        from: u8,
        
        #[arg(long, default_value_t = 247)]
        to: u8,
    }
}
