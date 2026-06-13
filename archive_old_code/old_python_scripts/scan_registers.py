import argparse
import concurrent.futures
import time
import sys
from pymodbus.client import ModbusTcpClient

def scan_single_register(ip, port, unit, address, function_code):
    """Đọc 1 thanh ghi duy nhất, trả về (address, value) nếu thành công."""
    # Timeout cực ngắn để quét siêu tốc, nếu có thiết bị nó sẽ đáp ngay lập tức
    client = ModbusTcpClient(ip, port=port, timeout=0.5)
    try:
        # Tắt logging lỗi khó chịu của pymodbus
        import logging
        logging.getLogger('pymodbus').setLevel(logging.CRITICAL)
        
        client.connect()
        if function_code == 3:
            result = client.read_holding_registers(address, 1, slave=unit)
        elif function_code == 4:
            result = client.read_input_registers(address, 1, slave=unit)
        elif function_code == 1:
            result = client.read_coils(address, 1, slave=unit)
        elif function_code == 2:
            result = client.read_discrete_inputs(address, 1, slave=unit)
        else:
            return None
            
        if not result.isError() and hasattr(result, 'registers'):
            return (address, result.registers[0])
        elif not result.isError() and hasattr(result, 'bits'):
            return (address, result.bits[0])
    except Exception:
        pass
    finally:
        client.close()
    return None

def main():
    parser = argparse.ArgumentParser(description="Chương trình quét siêu tốc dò tìm địa chỉ thanh ghi hợp lệ (0-65535)")
    parser.add_argument("ip", help="Địa chỉ IP của thiết bị (VD: 192.168.1.10)")
    parser.add_argument("-u", "--unit", type=int, default=0, help="Slave ID / Unit ID (mặc định: 0)")
    parser.add_argument("-p", "--port", type=int, default=502, help="Cổng Modbus (mặc định: 502)")
    parser.add_argument("-fc", "--function", type=int, default=3, choices=[1, 2, 3, 4], help="Function Code: 1(Coils), 2(Discrete), 3(Holding), 4(Input) (mặc định: 3)")
    parser.add_argument("-s", "--start", type=int, default=0, help="Địa chỉ bắt đầu quét (mặc định: 0)")
    parser.add_argument("-e", "--end", type=int, default=65535, help="Địa chỉ kết thúc quét (mặc định: 65535)")
    parser.add_argument("-t", "--threads", type=int, default=100, help="Số luồng song song (mặc định: 100)")
    
    args = parser.parse_args()
    
    print(f"[*] Bắt đầu dò từng địa chỉ từ {args.start} đến {args.end}...")
    print(f"[*] Mục tiêu: {args.ip}:{args.port} | Slave ID: {args.unit} | Function Code: {args.function}")
    print(f"[*] Vui lòng đợi, quá trình chạy {args.end - args.start + 1} địa chỉ sẽ mất một chút thời gian...")
    
    start_time = time.time()
    valid_registers = []
    
    def worker(addr):
        return scan_single_register(args.ip, args.port, args.unit, addr, args.function)
        
    addresses_to_scan = range(args.start, args.end + 1)
    
    # In tiến trình chạy đơn giản
    count = 0
    total = len(addresses_to_scan)
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=args.threads) as executor:
        results = executor.map(worker, addresses_to_scan)
        for res in results:
            count += 1
            if res is not None:
                addr, val = res
                # Xóa dòng tiến trình hiện tại để in kết quả đẹp hơn
                sys.stdout.write("\r\033[K")
                print(f"[+] Tìm thấy! Địa chỉ: {addr} => Giá trị: {val}")
                valid_registers.append(res)
            
            # Cập nhật phần trăm
            if count % 1000 == 0 or count == total:
                percent = (count / total) * 100
                sys.stdout.write(f"\r[*] Đang quét: {percent:.1f}% ({count}/{total})")
                sys.stdout.flush()
                
    print("\n" + "=" * 50)
    elapsed = time.time() - start_time
    print(f"[*] Quét hoàn tất trong {elapsed:.2f} giây.")
    print(f"[*] Tổng cộng tìm thấy {len(valid_registers)} địa chỉ có chứa dữ liệu thực.")

if __name__ == "__main__":
    main()
