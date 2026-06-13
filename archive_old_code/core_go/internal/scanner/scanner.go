package scanner

import (
	"fmt"
	"sync"
	"time"

	"github.com/simonvetter/modbus"
)

type DeviceScanResult struct {
	SlaveID uint8  `json:"slave_id"`
	Latency int64  `json:"latency_ms"`
	Status  string `json:"status"`
}

func ScanDevices(target string, isRTU bool, baud uint, fromID, toID uint8) []DeviceScanResult {
	var url string
	if isRTU {
		url = fmt.Sprintf("rtu://%s:%d", target, baud)
	} else {
		url = "tcp://" + target
	}

	client, err := modbus.NewClient(&modbus.ClientConfiguration{
		URL:     url,
		Timeout: 200 * time.Millisecond,
	})
	if err != nil || client.Open() != nil {
		return nil
	}
	defer client.Close()

	var results []DeviceScanResult
	var mu sync.Mutex
	var wg sync.WaitGroup

	// For RTU, we cannot scan concurrently reliably on the same bus, must do sequentially.
	// For TCP, we can concurrent. We'll do sequential to be safe for Modbus standard.
	for id := fromID; id <= toID; id++ {
		start := time.Now()
		client.SetUnitId(id)
		// We try to read holding register 0 as a ping. Even if it returns exception (illegal data address), it means device is ALIVE.
		// If it times out, device is dead.
		_, err := client.ReadRegisters(0, 1, modbus.HOLDING_REGISTER)
		latency := time.Since(start).Milliseconds()

		if err == nil || err == modbus.ErrIllegalFunction || err == modbus.ErrIllegalDataAddress || err == modbus.ErrIllegalDataValue {
			mu.Lock()
			results = append(results, DeviceScanResult{
				SlaveID: id,
				Latency: latency,
				Status:  "Alive",
			})
			mu.Unlock()
		}
	}
	wg.Wait()
	return results
}

type RegisterScanResult struct {
	Address uint16 `json:"address"`
	Value   uint16 `json:"value"`
}

func ScanRegisters(target string, slaveID uint8, isRTU bool, baud uint, fromAddr, toAddr uint16) []RegisterScanResult {
	var url string
	if isRTU {
		url = fmt.Sprintf("rtu://%s:%d", target, baud)
	} else {
		url = "tcp://" + target
	}

	client, err := modbus.NewClient(&modbus.ClientConfiguration{
		URL:     url,
		Timeout: 1 * time.Second,
	})
	if err != nil || client.Open() != nil {
		return nil
	}
	defer client.Close()
	client.SetUnitId(slaveID)

	var results []RegisterScanResult
	// Read in chunks of 100
	for addr := fromAddr; addr <= toAddr; {
		count := uint16(100)
		if addr+count-1 > toAddr {
			count = toAddr - addr + 1
		}
		data, err := client.ReadRegisters(addr, count, modbus.HOLDING_REGISTER)
		if err == nil {
			for i, v := range data {
				if v != 0 {
					results = append(results, RegisterScanResult{
						Address: addr + uint16(i),
						Value:   v,
					})
				}
			}
		}
		addr += count
	}
	return results
}
