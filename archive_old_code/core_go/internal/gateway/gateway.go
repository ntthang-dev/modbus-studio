package gateway

import (
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/simonvetter/modbus"
)

var (
	gateways     = make(map[string]*GatewayServer)
	gatewaysLock sync.Mutex
)

type GatewayServer struct {
	TCPServer *modbus.ModbusServer
	RTUClient *modbus.ModbusClient
}

type GatewayHandler struct {
	RTUClient *modbus.ModbusClient
	mu        sync.Mutex
}

func (h *GatewayHandler) HandleCoils(req *modbus.CoilsRequest) (res []bool, err error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.RTUClient.SetUnitId(req.UnitId)
	if req.IsWrite {
		if req.Quantity == 1 {
			err = h.RTUClient.WriteCoil(req.Addr, req.Args[0])
		} else {
			err = h.RTUClient.WriteCoils(req.Addr, req.Args)
		}
		return req.Args, err
	}
	return h.RTUClient.ReadCoils(req.Addr, req.Quantity)
}

func (h *GatewayHandler) HandleDiscreteInputs(req *modbus.DiscreteInputsRequest) (res []bool, err error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.RTUClient.SetUnitId(req.UnitId)
	return h.RTUClient.ReadDiscreteInputs(req.Addr, req.Quantity)
}

func (h *GatewayHandler) HandleHoldingRegisters(req *modbus.HoldingRegistersRequest) (res []uint16, err error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.RTUClient.SetUnitId(req.UnitId)
	if req.IsWrite {
		if req.Quantity == 1 {
			err = h.RTUClient.WriteRegister(req.Addr, req.Args[0])
		} else {
			err = h.RTUClient.WriteRegisters(req.Addr, req.Args)
		}
		return req.Args, err
	}
	return h.RTUClient.ReadRegisters(req.Addr, req.Quantity, modbus.HOLDING_REGISTER)
}

func (h *GatewayHandler) HandleInputRegisters(req *modbus.InputRegistersRequest) (res []uint16, err error) {
	h.mu.Lock()
	defer h.mu.Unlock()
	h.RTUClient.SetUnitId(req.UnitId)
	return h.RTUClient.ReadRegisters(req.Addr, req.Quantity, modbus.INPUT_REGISTER)
}

func StartGateway(tcpPort string, rtuPort string, baud uint) error {
	gatewaysLock.Lock()
	defer gatewaysLock.Unlock()

	if _, exists := gateways[tcpPort]; exists {
		return fmt.Errorf("gateway already running on port %s", tcpPort)
	}

	// 1. Start RTU Client
	rtuClient, err := modbus.NewClient(&modbus.ClientConfiguration{
		URL:      "rtu://" + rtuPort,
		Speed:    baud,
		DataBits: 8,
		Parity:   modbus.PARITY_NONE,
		StopBits: 1,
		Timeout:  1 * time.Second,
	})
	if err != nil {
		return fmt.Errorf("failed to create RTU client: %v", err)
	}
	err = rtuClient.Open()
	if err != nil {
		return fmt.Errorf("failed to open RTU port %s: %v", rtuPort, err)
	}

	// 2. Start TCP Server
	handler := &GatewayHandler{RTUClient: rtuClient}
	tcpServer, err := modbus.NewServer(&modbus.ServerConfiguration{
		URL: "tcp://0.0.0.0:" + tcpPort,
	}, handler)
	if err != nil {
		rtuClient.Close()
		return fmt.Errorf("failed to create TCP server: %v", err)
	}

	err = tcpServer.Start()
	if err != nil {
		rtuClient.Close()
		return fmt.Errorf("failed to start TCP server: %v", err)
	}

	gateways[tcpPort] = &GatewayServer{
		TCPServer: tcpServer,
		RTUClient: rtuClient,
	}

	log.Printf("Started Gateway: TCP :%s <-> RTU %s (baud %d)", tcpPort, rtuPort, baud)
	return nil
}

func StopGateway(tcpPort string) error {
	gatewaysLock.Lock()
	defer gatewaysLock.Unlock()

	if gw, exists := gateways[tcpPort]; exists {
		gw.TCPServer.Stop()
		gw.RTUClient.Close()
		delete(gateways, tcpPort)
		log.Println("Stopped Gateway on port", tcpPort)
		return nil
	}
	return fmt.Errorf("no gateway running on port %s", tcpPort)
}

func ListGateways() []map[string]interface{} {
	gatewaysLock.Lock()
	defer gatewaysLock.Unlock()
	var list []map[string]interface{}
	for port := range gateways {
		list = append(list, map[string]interface{}{
			"tcp_port": port,
		})
	}
	return list
}
