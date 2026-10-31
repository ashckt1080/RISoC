`timescale 1ns / 1ps

module load_store_unit (
    input clk,
    input rst,

    input MEM_valid,
    input MEM_mem_read,
    input MEM_mem_write,
    input [2:0] MEM_funct3,
    input [31:0] MEM_alu_addr,
    input [31:0] MEM_rs2_data,
    input MEM_advance,

    output req_valid,
    input req_ready,
    output req_write,
    output [31:0] req_addr,
    output [31:0] req_wdata,
    output reg [3:0] req_wstrb,

    input resp_valid,
    output resp_ready,
    input [31:0] resp_rdata,
    input [1:0] resp_status,

    output mem_stall,
    output mem_done,
    output reg [31:0] mem_load_result,
    output reg mem_misaligned,
    output reg mem_access_fault
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] WAIT_ACCEPT = 2'd1;
    localparam [1:0] WAIT_RESPONSE = 2'd2;
    localparam [1:0] COMPLETE = 2'd3;

    reg [1:0] state;

    wire mem_op = MEM_valid && (MEM_mem_read || MEM_mem_write);
    wire valid_load = (MEM_funct3 == 3'b000) || (MEM_funct3 == 3'b001) ||
                      (MEM_funct3 == 3'b010) || (MEM_funct3 == 3'b100) ||
                      (MEM_funct3 == 3'b101);
    wire valid_store = (MEM_funct3 == 3'b000) || (MEM_funct3 == 3'b001) ||
                       (MEM_funct3 == 3'b010);
    wire invalid_op = (MEM_mem_read && MEM_mem_write) ||
                      (MEM_mem_read && !valid_load) ||
                      (MEM_mem_write && !valid_store);

    wire half_access = (MEM_funct3 == 3'b001) ||
                       (MEM_mem_read && MEM_funct3 == 3'b101);
    wire word_access = (MEM_funct3 == 3'b010);
    wire bad_alignment = (half_access && MEM_alu_addr[0]) ||
                         (word_access && (MEM_alu_addr[1:0] != 2'b00));

    wire [4:0] shift_bits = {MEM_alu_addr[1:0], 3'b000};
    assign req_addr = {MEM_alu_addr[31:2], 2'b00};
    assign req_write = MEM_mem_write;
    assign req_wdata = MEM_rs2_data << shift_bits;

    always @(*) begin
        req_wstrb = 4'b0000;
        if (MEM_mem_write) begin
            case (MEM_funct3)
                3'b000: req_wstrb = 4'b0001 << MEM_alu_addr[1:0];
                3'b001: req_wstrb = 4'b0011 << MEM_alu_addr[1:0];
                3'b010: req_wstrb = 4'b1111;
                default: req_wstrb = 4'b0000;
            endcase
        end
    end

    wire [31:0] shifted_read = resp_rdata >> shift_bits;
    reg [31:0] formatted_read;

    always @(*) begin
        case (MEM_funct3)
            3'b000: formatted_read = {{24{shifted_read[7]}}, shifted_read[7:0]};
            3'b001: formatted_read = {{16{shifted_read[15]}}, shifted_read[15:0]};
            3'b010: formatted_read = resp_rdata;
            3'b100: formatted_read = {24'b0, shifted_read[7:0]};
            3'b101: formatted_read = {16'b0, shifted_read[15:0]};
            default: formatted_read = 32'b0;
        endcase
    end

    assign req_valid = (state == WAIT_ACCEPT);
    assign resp_ready = (state == WAIT_RESPONSE);
    assign mem_done = (state == COMPLETE);
    assign mem_stall = (state == WAIT_ACCEPT) ||
                        (state == WAIT_RESPONSE) ||
                        ((state == IDLE) && mem_op);

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            mem_load_result <= 32'b0;
            mem_misaligned <= 1'b0;
            mem_access_fault <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (mem_op) begin
                        mem_load_result <= 32'b0;
                        mem_misaligned <= 1'b0;
                        mem_access_fault <= 1'b0;

                        if (invalid_op) begin

                            mem_access_fault <= 1'b1;
                            state <= COMPLETE;
                        end else if (bad_alignment) begin
                            mem_misaligned <= 1'b1;
                            state <= COMPLETE;
                        end else begin
                            state <= WAIT_ACCEPT;
                        end
                    end
                end

                WAIT_ACCEPT: begin
                    if (req_ready)
                        state <= WAIT_RESPONSE;
                end

                WAIT_RESPONSE: begin
                    if (resp_valid) begin
                        if (resp_status != 2'b00)
                            mem_access_fault <= 1'b1;
                        else if (MEM_mem_read)
                            mem_load_result <= formatted_read;
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    if (MEM_advance) begin

                        state <= IDLE;
                        mem_misaligned <= 1'b0;
                        mem_access_fault <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
