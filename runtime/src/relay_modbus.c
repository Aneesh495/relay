#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "relay_modbus.h"

uint16_t modbus_crc16(const uint8_t *buffer, size_t length) {
    uint16_t crc = 0xFFFF;
    for (size_t pos = 0; pos < length; pos++) {
        crc ^= (uint16_t)buffer[pos];
        for (int i = 8; i != 0; i--) {
            if ((crc & 0x0001) != 0) {
                crc >>= 1;
                crc ^= 0xA001;
            } else {
                crc >>= 1;
            }
        }
    }
    return crc;
}

bool modbus_parse_tcp_frame(const uint8_t *raw_buf, size_t len, ModbusTcpFrame *out_frame) {
    if (!raw_buf || len < 8 || !out_frame) {
        return false;
    }

    out_frame->transaction_id = (uint16_t)((raw_buf[0] << 8) | raw_buf[1]);
    out_frame->protocol_id = (uint16_t)((raw_buf[2] << 8) | raw_buf[3]);
    out_frame->length = (uint16_t)((raw_buf[4] << 8) | raw_buf[5]);
    out_frame->unit_id = raw_buf[6];
    out_frame->function_code = raw_buf[7];

    if (out_frame->protocol_id != 0) {
        return false;
    }

    size_t payload_len = len - 8;
    if (payload_len > 254) {
        payload_len = 254;
    }
    out_frame->data_len = payload_len;
    if (payload_len > 0) {
        memcpy(out_frame->data, &raw_buf[8], payload_len);
    }
    return true;
}

size_t modbus_serialize_tcp_frame(const ModbusTcpFrame *frame, uint8_t *out_buf, size_t max_len) {
    if (!frame || !out_buf || max_len < (size_t)(8 + frame->data_len)) {
        return 0;
    }

    uint16_t pdu_len = (uint16_t)(2 + frame->data_len);
    out_buf[0] = (uint8_t)((frame->transaction_id >> 8) & 0xFF);
    out_buf[1] = (uint8_t)(frame->transaction_id & 0xFF);
    out_buf[2] = 0;
    out_buf[3] = 0;
    out_buf[4] = (uint8_t)((pdu_len >> 8) & 0xFF);
    out_buf[5] = (uint8_t)(pdu_len & 0xFF);
    out_buf[6] = frame->unit_id;
    out_buf[7] = frame->function_code;

    if (frame->data_len > 0) {
        memcpy(&out_buf[8], frame->data, frame->data_len);
    }
    return 8 + frame->data_len;
}

int modbus_handle_request(ModbusDataStore *store, const ModbusTcpFrame *req, ModbusTcpFrame *resp) {
    if (!store || !req || !resp) {
        return -1;
    }

    resp->transaction_id = req->transaction_id;
    resp->protocol_id = 0;
    resp->unit_id = req->unit_id;

    switch (req->function_code) {
        case MODBUS_FC_READ_HOLDING_REGS: {
            if (req->data_len < 4) return -1;
            uint16_t start_addr = (uint16_t)((req->data[0] << 8) | req->data[1]);
            uint16_t reg_count = (uint16_t)((req->data[2] << 8) | req->data[3]);

            if (reg_count < 1 || reg_count > 125 || (start_addr + reg_count) > MODBUS_HOLDING_REGS_MAX) {
                resp->function_code = req->function_code | 0x80;
                resp->data[0] = MODBUS_EX_ILLEGAL_DATA_ADDRESS;
                resp->data_len = 1;
                return 0;
            }

            resp->function_code = req->function_code;
            uint8_t byte_count = (uint8_t)(reg_count * 2);
            resp->data[0] = byte_count;
            size_t pos = 1;

            for (uint16_t i = 0; i < reg_count; ++i) {
                uint16_t val = store->holding_registers[start_addr + i];
                resp->data[pos++] = (uint8_t)((val >> 8) & 0xFF);
                resp->data[pos++] = (uint8_t)(val & 0xFF);
            }
            resp->data_len = pos;
            return 0;
        }

        case MODBUS_FC_READ_COILS: {
            if (req->data_len < 4) return -1;
            uint16_t start_addr = (uint16_t)((req->data[0] << 8) | req->data[1]);
            uint16_t coil_count = (uint16_t)((req->data[2] << 8) | req->data[3]);

            if (coil_count < 1 || coil_count > 2000 || (start_addr + coil_count) > MODBUS_COILS_MAX) {
                resp->function_code = req->function_code | 0x80;
                resp->data[0] = MODBUS_EX_ILLEGAL_DATA_ADDRESS;
                resp->data_len = 1;
                return 0;
            }

            resp->function_code = req->function_code;
            uint8_t byte_count = (uint8_t)((coil_count + 7) / 8);
            resp->data[0] = byte_count;
            memset(&resp->data[1], 0, byte_count);

            for (uint16_t i = 0; i < coil_count; ++i) {
                uint16_t addr = start_addr + i;
                bool bit = (store->coils[addr / 8] & (1 << (addr % 8))) != 0;
                if (bit) {
                    resp->data[1 + (i / 8)] |= (1 << (i % 8));
                }
            }
            resp->data_len = 1 + byte_count;
            return 0;
        }

        case MODBUS_FC_WRITE_SINGLE_REG: {
            if (req->data_len < 4) return -1;
            uint16_t addr = (uint16_t)((req->data[0] << 8) | req->data[1]);
            uint16_t val = (uint16_t)((req->data[2] << 8) | req->data[3]);

            if (addr >= MODBUS_HOLDING_REGS_MAX) {
                resp->function_code = req->function_code | 0x80;
                resp->data[0] = MODBUS_EX_ILLEGAL_DATA_ADDRESS;
                resp->data_len = 1;
                return 0;
            }

            store->holding_registers[addr] = val;
            resp->function_code = req->function_code;
            memcpy(resp->data, req->data, 4);
            resp->data_len = 4;
            return 0;
        }

        case MODBUS_FC_WRITE_SINGLE_COIL: {
            if (req->data_len < 4) return -1;
            uint16_t addr = (uint16_t)((req->data[0] << 8) | req->data[1]);
            uint16_t val = (uint16_t)((req->data[2] << 8) | req->data[3]);

            if (addr >= MODBUS_COILS_MAX) {
                resp->function_code = req->function_code | 0x80;
                resp->data[0] = MODBUS_EX_ILLEGAL_DATA_ADDRESS;
                resp->data_len = 1;
                return 0;
            }

            if (val == 0xFF00) {
                store->coils[addr / 8] |= (1 << (addr % 8));
            } else if (val == 0x0000) {
                store->coils[addr / 8] &= ~(1 << (addr % 8));
            } else {
                resp->function_code = req->function_code | 0x80;
                resp->data[0] = MODBUS_EX_ILLEGAL_DATA_VALUE;
                resp->data_len = 1;
                return 0;
            }

            resp->function_code = req->function_code;
            memcpy(resp->data, req->data, 4);
            resp->data_len = 4;
            return 0;
        }

        default:
            resp->function_code = req->function_code | 0x80;
            resp->data[0] = MODBUS_EX_ILLEGAL_FUNCTION;
            resp->data_len = 1;
            return 0;
    }
}
