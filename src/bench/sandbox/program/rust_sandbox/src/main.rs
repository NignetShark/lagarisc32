#![no_main]
#![no_std]

mod uart { pub mod uart; }
pub mod rust_core;

use uart::uart::Uart;


#[no_mangle]
extern "C" fn main() {
    Uart::global_init();

    println!("Hello World from RISC-V !");
    println!("Main ended. Ctrl+A X to terminate.");
}
