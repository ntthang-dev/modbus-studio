import argparse
import sys
from pymodbus.client import ModbusTcpClient
from pymodbus.exceptions import ModbusException

def scan_modbus(ip, port, unit_id, start_addr, count, function_code):
    print(f"[*] Đang kết nối tới {ip}:{port} (Unit ID: {unit_id})...")
    client = ModbusTcpClient(ip, port=port)
    
    if not client.connect():
        print(f"[!] Không thể kết nối tới {ip}:{port}")
        return

    print("[+] Kết nối thành công!")
    
    try:
        print(f"[*] Đang đọc {count} giá trị từ địa chỉ {start_addr} bằng Function Code {function_code}...")
        
        if function_code == 1:
            result = client.read_coils(start_addr, count, slave=unit_id)
            if not result.isError():
                print(f"[+] Kết quả (Coils): {result.bits[:count]}")
            else:
                print(f"[!] Lỗi đọc dữ liệu: {result}")
                
        elif function_code == 2:
            result = client.read_discrete_inputs(start_addr, count, slave=unit_id)
            if not result.isError():
                print(f"[+] Kết quả (Discrete Inputs): {result.bits[:count]}")
            else:
                print(f"[!] Lỗi đọc dữ liệu: {result}")
                
        elif function_code == 3:
            result = client.read_holding_registers(start_addr, count, slave=unit_id)
            if not result.isError():
                print(f"[+] Kết quả (Holding Registers): {result.registers}")
            else:
                print(f"[!] Lỗi đọc dữ liệu: {result}")
                
        elif function_code == 4:
            result = client.read_input_registers(start_addr, count, slave=unit_id)
            if not result.isError():
                print(f"[+] Kết quả (Input Registers): {result.registers}")
            else:
                print(f"[!] Lỗi đọc dữ liệu: {result}")
                
        else:
            print("[!] Function code không được hỗ trợ!")
            
    except ModbusException as e:
        print(f"[!] Lỗi Modbus: {e}")
    except Exception as e:
        print(f"[!] Lỗi không xác định: {e}")
    finally:
        client.close()
        print("[*] Đã đóng kết nối.")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Modbus TCP Scanner")
    parser.add_argument("ip", help="Địa chỉ IP của Modbus Server (ví dụ: 192.168.1.10)")
    parser.add_argument("-p", "--port", type=int, default=502, help="Cổng kết nối (mặc định: 502)")
    parser.add_argument("-u", "--unit", type=int, default=1, help="Unit ID / Slave ID (mặc định: 1)")
    parser.add_argument("-a", "--address", type=int, default=0, help="Địa chỉ bắt đầu đọc (mặc định: 0)")
    parser.add_argument("-c", "--count", type=int, default=10, help="Số lượng thanh ghi cần đọc (mặc định: 10)")
    parser.add_argument("-fc", "--function", type=int, choices=[1, 2, 3, 4], default=3, 
                        help="Function Code (1: Coils, 2: Discrete Inputs, 3: Holding Regs, 4: Input Regs) (mặc định: 3)")
    
    args = parser.parse_args()
    
    scan_modbus(args.ip, args.port, args.unit, args.address, args.count, args.function)
