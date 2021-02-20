#ifndef RELAY_MODBUS_H
#define RELAY_MODBUS_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

#define MODBUS_TCP_PORT 502
#define MODBUS_MAX_ADU_LEN 260
#define MODBUS_HOLDING_REGS_MAX 10000
#define MODBUS_COILS_MAX 10000

typedef enum {
    MODBUS_FC_READ_COILS            = 0x01,
    MODBUS_FC_READ_DISCRETE_INPUTS  = 0x02,
    MODBUS_FC_READ_HOLDING_REGS     = 0x03,
    MODBUS_FC_READ_INPUT_REGS       = 0x04,
    MODBUS_FC_WRITE_SINGLE_COIL     = 0x05,
    MODBUS_FC_WRITE_SINGLE_REG      = 0x06,
    MODBUS_FC_WRITE_MULTIPLE_COILS  = 0x0F,
    MODBUS_FC_WRITE_MULTIPLE_REGS   = 0x10
} ModbusFunctionCode;

typedef enum {
    MODBUS_EX_ILLEGAL_FUNCTION      = 0x01,
    MODBUS_EX_ILLEGAL_DATA_ADDRESS  = 0x02,
    MODBUS_EX_ILLEGAL_DATA_VALUE    = 0x03,
    MODBUS_EX_SLAVE_DEVICE_FAILURE  = 0x04,
    MODBUS_EX_ACKNOWLEDGE           = 0x05,
    MODBUS_EX_SLAVE_DEVICE_BUSY     = 0x06
} ModbusException;

typedef struct {
    uint16_t transaction_id;
    uint16_t protocol_id;
    uint16_t length;
    uint8_t unit_id;
    uint8_t function_code;
    uint8_t data[254];
    size_t data_len;
} ModbusTcpFrame;

typedef struct {
    uint16_t holding_registers[MODBUS_HOLDING_REGS_MAX];
    uint8_t coils[MODBUS_COILS_MAX / 8];
    uint16_t input_registers[MODBUS_HOLDING_REGS_MAX];
    uint8_t discrete_inputs[MODBUS_COILS_MAX / 8];
} ModbusDataStore;

uint16_t modbus_crc16(const uint8_t *buffer, size_t length);
bool modbus_parse_tcp_frame(const uint8_t *raw_buf, size_t len, ModbusTcpFrame *out_frame);
size_t modbus_serialize_tcp_frame(const ModbusTcpFrame *frame, uint8_t *out_buf, size_t max_len);

int modbus_handle_request(ModbusDataStore *store, const ModbusTcpFrame *req, ModbusTcpFrame *resp);

#endif /* RELAY_MODBUS_H */
