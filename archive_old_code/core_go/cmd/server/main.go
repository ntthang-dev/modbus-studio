package main

import (
	"encoding/json"
	"log"
	"net/http"

	"github.com/gorilla/websocket"
	"go.bug.st/serial"
	"modbus_core/internal/engine"
	"modbus_core/internal/gateway"
	"modbus_core/internal/scanner"
	"modbus_core/internal/simulator"
)

var upgrader = websocket.Upgrader{
	CheckOrigin: func(r *http.Request) bool { return true },
}

type Request struct {
	Cmd      string `json:"cmd"`
	Target   string `json:"target"`
	Type     string `json:"type"`
	Address  uint16 `json:"address"`
	Count    uint16 `json:"count"`
	Value    uint16 `json:"value"`
	Port     string `json:"port"`
	SlaveID  uint8  `json:"slave_id"`
	FromID   uint8  `json:"from_id"`
	ToID     uint8  `json:"to_id"`
	FromAddr uint16 `json:"from_addr"`
	ToAddr   uint16 `json:"to_addr"`
	IsRTU    bool   `json:"is_rtu"`
	Baud     uint   `json:"baud"`
}

type Response struct {
	Cmd      string      `json:"cmd"`
	Status   string      `json:"status"`
	Data     interface{} `json:"data,omitempty"`
	Latency  int64       `json:"latency_ms,omitempty"`
	Error    string      `json:"error,omitempty"`
}

func handleWebSocket(w http.ResponseWriter, r *http.Request) {
	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Println("Upgrade error:", err)
		return
	}
	defer conn.Close()

	log.Println("Frontend connected via WebSocket")

	for {
		_, msg, err := conn.ReadMessage()
		if err != nil {
			log.Println("Read error:", err)
			break
		}

		var req Request
		if err := json.Unmarshal(msg, &req); err != nil {
			conn.WriteJSON(Response{Status: "error", Error: "Invalid JSON format"})
			continue
		}

		go processCommand(conn, req)
	}
}

func processCommand(conn *websocket.Conn, req Request) {
	resp := Response{Cmd: req.Cmd, Status: "success"}

	switch req.Cmd {
	case "read":
		res := engine.ExecuteRead(engine.ModbusRequest{
			Target:  req.Target,
			Type:    req.Type,
			Address: req.Address,
			Count:   req.Count,
			SlaveID: req.SlaveID,
			IsRTU:   req.IsRTU,
			Baud:    req.Baud,
		})
		if res.Error != nil {
			resp.Status = "error"
			resp.Error = res.Error.Error()
		} else {
			resp.Data = res.Data
			resp.Latency = res.Latency
		}

	case "write":
		res := engine.ExecuteWrite(engine.ModbusRequest{
			Target:  req.Target,
			Type:    req.Type,
			Address: req.Address,
			Value:   req.Value,
			SlaveID: req.SlaveID,
			IsRTU:   req.IsRTU,
			Baud:    req.Baud,
		})
		if res.Error != nil {
			resp.Status = "error"
			resp.Error = res.Error.Error()
		} else {
			resp.Latency = res.Latency
		}

	case "scan_devices":
		results := scanner.ScanDevices(req.Target, req.IsRTU, req.Baud, req.FromID, req.ToID)
		resp.Data = results

	case "scan_registers":
		results := scanner.ScanRegisters(req.Target, req.SlaveID, req.IsRTU, req.Baud, req.FromAddr, req.ToAddr)
		resp.Data = results

	case "start_slave":
		err := simulator.StartSlave(req.Port)
		if err != nil {
			resp.Status = "error"
			resp.Error = err.Error()
		}

	case "stop_slave":
		err := simulator.StopSlave(req.Port)
		if err != nil {
			resp.Status = "error"
			resp.Error = err.Error()
		}

	case "list_slaves":
		resp.Data = simulator.ListSlaves()

	case "set_virtual_register":
		err := simulator.SetVirtualRegister(req.Port, req.Address, req.Value)
		if err != nil {
			resp.Status = "error"
			resp.Error = err.Error()
		}

	case "start_gateway":
		err := gateway.StartGateway(req.Port, req.Target, req.Baud)
		if err != nil {
			resp.Status = "error"
			resp.Error = err.Error()
		}

	case "stop_gateway":
		err := gateway.StopGateway(req.Port)
		if err != nil {
			resp.Status = "error"
			resp.Error = err.Error()
		}

	case "list_gateways":
		resp.Data = gateway.ListGateways()

	case "list_serial_ports":
		ports, err := serial.GetPortsList()
		if err != nil {
			resp.Status = "error"
			resp.Error = err.Error()
		} else {
			resp.Data = ports
		}

	default:
		resp.Status = "error"
		resp.Error = "Unknown command"
	}

	conn.WriteJSON(resp)
}

func main() {
	log.Println("Starting Modbus Core Go Server on :8080")
	http.HandleFunc("/ws", handleWebSocket)
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal("Server failed:", err)
	}
}
