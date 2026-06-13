import argparse
import socket
import concurrent.futures
import ipaddress
import time
from pymodbus.client import ModbusTcpClient
from pymodbus.exceptions import ModbusException

def check_port(ip, port=502, timeout=1.0):
    """Kiểm tra xem cổng TCP có mở trên IP không."""
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(timeout)
            if s.connect_ex((str(ip), port)) == 0:
                return True
    except Exception:
        pass
    return False

def test_modbus_device(ip, port=502, full_scan=False):
    """Kết nối và quét Slave ID."""
    # Giảm timeout xuống thấp để quét full 255 ID không bị quá lâu nếu thiết bị không phản hồi
    client = ModbusTcpClient(str(ip), port=port, timeout=0.5)
    if not client.connect():
        return None
    
    found_units = []
    
    # Nếu chọn full_scan thì quét từ 1 đến 255, nếu không thì quét các ID phổ biến
    if full_scan:
        test_units = range(1, 256)
    else:
        test_units = [1, 2, 3, 254, 255]
    
    for unit in test_units:
        try:
            # Thử đọc 1 thanh ghi (Holding Register) ở địa chỉ 0
            result = client.read_holding_registers(0, 1, slave=unit)
            if not result.isError():
                found_units.append(str(unit))
            else:
                # Nếu nó ném ra exception của Modbus thì vẫn chứng tỏ ID này có tồn tại
                if hasattr(result, 'exception_code'):
                    found_units.append(f"{unit} (Mã lỗi: {result.exception_code})")
        except Exception:
            # Bỏ qua các ID timeout hoặc không phản hồi
            pass
            
    client.close()
    return found_units

def main():
    parser = argparse.ArgumentParser(description="Chương trình quét thiết bị Modbus TCP và dò tìm Slave ID")
    parser.add_argument("network", help="Dải IP cần quét dạng CIDR (ví dụ: 192.168.1.0/24)")
    parser.add_argument("-t", "--threads", type=int, default=100, help="Số lượng luồng quét song song (mặc định: 100)")
    parser.add_argument("-p", "--port", type=int, default=502, help="Cổng Modbus (mặc định: 502)")
    parser.add_argument("--full-slave", action="store_true", help="Bật chế độ quét toàn bộ Slave ID từ 1 đến 255 cho mỗi thiết bị tìm thấy")
    args = parser.parse_args()

    try:
        network = ipaddress.ip_network(args.network, strict=False)
        print(f"[*] Bắt đầu quét mạng {network} (tổng {network.num_addresses} IP)...")
        if args.full_slave:
            print("[*] Chế độ quét sâu: Quét TẤT CẢ Slave ID từ 1 đến 255.")
    except ValueError as e:
        print(f"[!] Dải IP không hợp lệ: {e}")
        return

    ips_to_scan = list(network.hosts())
    found_ips = []
    
    start_time = time.time()

    def scan_ip_worker(ip):
        if check_port(ip, args.port):
            print(f"[+] Tìm thấy cổng {args.port} đang mở tại IP: {ip}")
            units = test_modbus_device(ip, args.port, full_scan=args.full_slave)
            if units:
                print(f"    -> [Modbus OK] IP: {ip} - Các Slave ID đang hoạt động: {', '.join(units)}")
            else:
                print(f"    -> [?] IP: {ip} mở cổng {args.port} nhưng không có Slave ID nào phản hồi.")
            return str(ip)
        return None

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.threads) as executor:
        results = executor.map(scan_ip_worker, ips_to_scan)
        for res in results:
            if res:
                found_ips.append(res)
                
    elapsed_time = time.time() - start_time
    print("\n" + "="*50)
    print(f"[*] HOÀN TẤT QUÉT TRONG {elapsed_time:.2f} GIÂY.")
    if found_ips:
        print(f"[*] Đã tìm thấy {len(found_ips)} thiết bị Modbus.")
    else:
        print("[!] Không tìm thấy thiết bị nào.")

if __name__ == "__main__":
    main()
