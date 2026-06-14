import socket
import struct
import math
import time
import random
import threading

# Simulated Database / Memory
holding_registers = [0] * 1000
input_registers = [0] * 1000
coils = [False] * 1000
discrete_inputs = [False] * 1000

# Pre-populate some values
# Address 10-16: String "ModbusStudio!"
# Modbus registers are 16-bit. Each register holds 2 ASCII characters.
# "Mo", "db", "us", "St", "ud", "io", "!\0"
holding_registers[10] = (77 << 8) | 111
holding_registers[11] = (100 << 8) | 98
holding_registers[12] = (117 << 8) | 115
holding_registers[13] = (83 << 8) | 116
holding_registers[14] = (117 << 8) | 100
holding_registers[15] = (105 << 8) | 111
holding_registers[16] = (33 << 8) | 0

# Fill the same in input_registers
for i in range(10, 17):
    input_registers[i] = holding_registers[i]

def update_simulated_values():
    start_time = time.time()
    while True:
        elapsed = time.time() - start_time
        # Address 0: Sine wave (scaling sine from -1 to 1 into 0 to 1000)
        val_sine = int((math.sin(elapsed * 0.5) + 1.0) * 500)
        holding_registers[0] = val_sine
        input_registers[0] = val_sine

        # Address 1: Square wave toggles every 5s between 100 and 900
        val_square = 900 if int(elapsed / 5.0) % 2 == 0 else 100
        holding_registers[1] = val_square
        input_registers[1] = val_square

        # Address 2: Random noise
        val_noise = random.randint(200, 300)
        holding_registers[2] = val_noise
        input_registers[2] = val_noise

        # Address 20: Bitfield status word (toggle bits over time)
        bit0 = int(elapsed) % 2
        bit1 = int(elapsed / 2.0) % 2
        bit2 = int(elapsed / 4.0) % 2
        bitfield = (bit2 << 2) | (bit1 << 1) | bit0
        holding_registers[20] = bitfield
        input_registers[20] = bitfield

        # Address 30-31: 32-bit Unix epoch timestamp (seconds)
        now_sec = int(time.time())
        holding_registers[30] = (now_sec >> 16) & 0xFFFF
        holding_registers[31] = now_sec & 0xFFFF
        input_registers[30] = holding_registers[30]
        input_registers[31] = holding_registers[31]

        # Coils & Discrete Inputs
        coils[0] = (int(elapsed) % 2 == 0)
        coils[1] = True
        coils[2] = False
        discrete_inputs[0] = coils[0]
        discrete_inputs[1] = True
        discrete_inputs[2] = False

        time.sleep(0.5)

# Thread for simulation updates
sim_thread = threading.Thread(target=update_simulated_values, daemon=True)
sim_thread.start()

def handle_client(conn, addr):
    print(f"[{addr}] New client connection")
    try:
        while True:
            # Read MBAP header (7 bytes)
            header = conn.recv(7)
            if not header or len(header) < 7:
                break

            # Parse MBAP
            transaction_id, protocol_id, length, unit_id = struct.unpack(">HHHB", header)
            
            # Read remaining PDU data (length - 1 bytes)
            pdu_len = length - 1
            pdu = conn.recv(pdu_len)
            if not pdu or len(pdu) < pdu_len:
                break

            function_code = pdu[0]
            
            response_pdu = b""
            if function_code in (1, 2):  # Read Coils or Discrete Inputs
                start_addr, quantity = struct.unpack(">HH", pdu[1:5])
                byte_count = (quantity + 7) // 8
                data_bytes = bytearray(byte_count)
                
                source = coils if function_code == 1 else discrete_inputs
                for i in range(quantity):
                    addr_idx = start_addr + i
                    if addr_idx < len(source) and source[addr_idx]:
                        byte_idx = i // 8
                        bit_idx = i % 8
                        data_bytes[byte_idx] |= (1 << bit_idx)
                response_pdu = struct.pack(">BB", function_code, byte_count) + bytes(data_bytes)

            elif function_code in (3, 4):  # Read Holding or Input Registers
                start_addr, quantity = struct.unpack(">HH", pdu[1:5])
                byte_count = quantity * 2
                data_bytes = bytearray(byte_count)
                
                source = holding_registers if function_code == 3 else input_registers
                for i in range(quantity):
                    addr_idx = start_addr + i
                    val = source[addr_idx] if addr_idx < len(source) else 0
                    struct.pack_into(">H", data_bytes, i * 2, val)
                response_pdu = struct.pack(">BB", function_code, byte_count) + bytes(data_bytes)

            elif function_code == 5:  # Write Single Coil
                write_addr, value = struct.unpack(">HH", pdu[1:5])
                if write_addr < len(coils):
                    coils[write_addr] = (value == 0xFF00)
                response_pdu = pdu  # Echo request as success response

            elif function_code == 6:  # Write Single Register
                write_addr, value = struct.unpack(">HH", pdu[1:5])
                if write_addr < len(holding_registers):
                    holding_registers[write_addr] = value
                response_pdu = pdu  # Echo request as success response

            else:
                response_pdu = struct.pack(">BB", function_code | 0x80, 1)  # Exception code 1: Illegal Function

            # Construct MBAP response header
            resp_len = len(response_pdu) + 1  # PDU + unit_id byte
            response_header = struct.pack(">HHHB", transaction_id, protocol_id, resp_len, unit_id)
            conn.sendall(response_header + response_pdu)
    except ConnectionResetError:
        pass
    except Exception as e:
        print(f"[{addr}] Error: {e}")
    finally:
        conn.close()
        print(f"[{addr}] Connection closed")

def start_server():
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    port = 5020
    server.bind(("127.0.0.1", port))
    server.listen(5)
    print(f"Modbus TCP Simulation Server listening on 127.0.0.1:{port}")
    try:
        while True:
            conn, addr = server.accept()
            client_thread = threading.Thread(target=handle_client, args=(conn, addr), daemon=True)
            client_thread.start()
    except KeyboardInterrupt:
        print("Stopping server...")
    finally:
        server.close()

if __name__ == "__main__":
    start_server()
