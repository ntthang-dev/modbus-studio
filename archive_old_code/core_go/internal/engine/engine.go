package engine

import (
	"fmt"
	"time"

	"github.com/simonvetter/modbus"
)

type ModbusRequest struct {
	Target  string
	Type    string
	Address uint16
	Count   uint16
	Value   uint16
	SlaveID uint8
	IsRTU   bool
	Baud    uint
}

type ModbusResponse struct {
	Data    []uint16
	Latency int64
	Error   error
}

func ExecuteRead(req ModbusRequest) ModbusResponse {
	start := time.Now()
	var url string
	if req.IsRTU {
		url = fmt.Sprintf("rtu://%s:%d", req.Target, req.Baud)
	} else {
		url = "tcp://" + req.Target
	}

	client, err := modbus.NewClient(&modbus.ClientConfiguration{
		URL:     url,
		Timeout: 2 * time.Second,
	})
	if err != nil {
		return ModbusResponse{Error: err}
	}
	if err = client.Open(); err != nil {
		return ModbusResponse{Error: err}
	}
	defer client.Close()

	if req.SlaveID > 0 {
		client.SetUnitId(req.SlaveID)
	}

	var results []uint16
	if req.Type == "holding" {
		results, err = client.ReadRegisters(req.Address, req.Count, modbus.HOLDING_REGISTER)
	} else if req.Type == "input" {
		results, err = client.ReadRegisters(req.Address, req.Count, modbus.INPUT_REGISTER)
	} else if req.Type == "coil" {
		coils, err2 := client.ReadCoils(req.Address, req.Count)
		err = err2
		if err == nil {
			results = make([]uint16, len(coils))
			for i, c := range coils {
				if c {
					results[i] = 1
				} else {
					results[i] = 0
				}
			}
		}
	} else if req.Type == "discrete" {
		inputs, err2 := client.ReadDiscreteInputs(req.Address, req.Count)
		err = err2
		if err == nil {
			results = make([]uint16, len(inputs))
			for i, in := range inputs {
				if in {
					results[i] = 1
				} else {
					results[i] = 0
				}
			}
		}
	} else {
		err = fmt.Errorf("unknown register type")
	}

	return ModbusResponse{
		Data:    results,
		Latency: time.Since(start).Milliseconds(),
		Error:   err,
	}
}

func ExecuteWrite(req ModbusRequest) ModbusResponse {
	start := time.Now()
	var url string
	if req.IsRTU {
		url = fmt.Sprintf("rtu://%s:%d", req.Target, req.Baud)
	} else {
		url = "tcp://" + req.Target
	}

	client, err := modbus.NewClient(&modbus.ClientConfiguration{
		URL:     url,
		Timeout: 2 * time.Second,
	})
	if err != nil {
		return ModbusResponse{Error: err}
	}
	if err = client.Open(); err != nil {
		return ModbusResponse{Error: err}
	}
	defer client.Close()

	if req.SlaveID > 0 {
		client.SetUnitId(req.SlaveID)
	}

	if req.Type == "holding" {
		err = client.WriteRegister(req.Address, req.Value)
	} else if req.Type == "coil" {
		err = client.WriteCoil(req.Address, req.Value > 0)
	} else {
		err = fmt.Errorf("invalid type for write")
	}

	return ModbusResponse{
		Latency: time.Since(start).Milliseconds(),
		Error:   err,
	}
}
