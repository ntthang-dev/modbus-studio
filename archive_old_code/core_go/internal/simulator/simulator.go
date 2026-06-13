package simulator

import (
	"fmt"
	"log"
	"sync"

	"github.com/simonvetter/modbus"
)

type VirtualSlave struct {
	Server  *modbus.ModbusServer
	Handler *SimpleHandler
}

var (
	slaves     = make(map[string]*VirtualSlave)
	slavesLock sync.Mutex
)

type SimpleHandler struct {
	registers map[uint16]uint16
	sync.Mutex
}

func (h *SimpleHandler) HandleCoils(req *modbus.CoilsRequest) (res []bool, err error) {
	return make([]bool, req.Quantity), nil
}
func (h *SimpleHandler) HandleDiscreteInputs(req *modbus.DiscreteInputsRequest) (res []bool, err error) {
	return make([]bool, req.Quantity), nil
}
func (h *SimpleHandler) HandleHoldingRegisters(req *modbus.HoldingRegistersRequest) (res []uint16, err error) {
	h.Lock()
	defer h.Unlock()
	if h.registers == nil {
		h.registers = make(map[uint16]uint16)
	}
	res = make([]uint16, req.Quantity)
	if req.IsWrite {
		for i := 0; i < int(req.Quantity); i++ {
			h.registers[req.Addr+uint16(i)] = req.Args[i]
		}
	} else {
		for i := 0; i < int(req.Quantity); i++ {
			res[i] = h.registers[req.Addr+uint16(i)]
		}
	}
	return res, nil
}
func (h *SimpleHandler) HandleInputRegisters(req *modbus.InputRegistersRequest) (res []uint16, err error) {
	return make([]uint16, req.Quantity), nil
}

func StartSlave(port string) error {
	slavesLock.Lock()
	defer slavesLock.Unlock()
	if _, exists := slaves[port]; exists {
		return fmt.Errorf("slave already running on this port")
	}

	handler := &SimpleHandler{}
	server, err := modbus.NewServer(&modbus.ServerConfiguration{
		URL: "tcp://0.0.0.0:" + port,
	}, handler)
	if err != nil {
		return err
	}

	err = server.Start()
	if err != nil {
		return err
	}

	slaves[port] = &VirtualSlave{
		Server:  server,
		Handler: handler,
	}
	log.Println("Started virtual slave on port", port)
	return nil
}

func StopSlave(port string) error {
	slavesLock.Lock()
	defer slavesLock.Unlock()
	if slave, exists := slaves[port]; exists {
		slave.Server.Stop()
		delete(slaves, port)
		log.Println("Stopped virtual slave on port", port)
		return nil
	}
	return fmt.Errorf("no slave running on this port")
}

func ListSlaves() []string {
	slavesLock.Lock()
	defer slavesLock.Unlock()
	var list []string
	for p := range slaves {
		list = append(list, p)
	}
	return list
}

func SetVirtualRegister(port string, addr uint16, value uint16) error {
	slavesLock.Lock()
	defer slavesLock.Unlock()
	if slave, exists := slaves[port]; exists {
		slave.Handler.Lock()
		defer slave.Handler.Unlock()
		if slave.Handler.registers == nil {
			slave.Handler.registers = make(map[uint16]uint16)
		}
		slave.Handler.registers[addr] = value
		return nil
	}
	return fmt.Errorf("slave not found")
}
