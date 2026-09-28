`timescale 1ns / 1ps

module bus_interconnect(

    //master route
    input master_request,
    input master_write,
    input [31:0] master_address,
    input [31:0] master_write_data,
    input [3:0] master_byte_sel,

    output reg master_ack,
    output reg master_err,
    output reg [31:0] master_read_data,

    //ram route
    output reg ram_request,
    output reg ram_write,
    output reg [31:0] ram_address,
    output reg [31:0] ram_write_data,
    output reg [3:0] ram_byte_sel,

    input ram_ack,
    input ram_err,
    input [31:0] ram_read_data,

    //uart route
    output reg uart_request,
    output reg uart_write,
    output reg [31:0] uart_address,
    output reg [31:0] uart_write_data,
    output reg [3:0] uart_byte_sel,

    input uart_ack,
    input uart_err,
    input [31:0] uart_read_data
    
    );

    wire ram_selected;
    wire uart_selected;

    assign ram_selected = (master_address >= 32'h00000000) && (master_address <= 32'h00000FFF);
    assign uart_selected = (master_address >= 32'h10000000) && (master_address <= 32'h10000FFF);

    always@(*) begin

        ram_request = 1'b0;
        ram_write = 1'b0;
        ram_address = 32'b0;
        ram_write_data = 32'b0;
        ram_byte_sel = 4'b0;

        uart_request = 1'b0;
        uart_write = 1'b0;
        uart_address = 32'b0;
        uart_write_data = 32'b0;
        uart_byte_sel = 4'b0;

        master_ack = 1'b0;
        master_err = 1'b0;
        master_read_data = 32'b0;

        if(ram_selected) begin
            ram_request = master_request;
            ram_write = master_write;
            ram_address = master_address;
            ram_write_data = master_write_data;
            ram_byte_sel = master_byte_sel;

            master_ack = ram_ack;
            master_err = ram_err;
            master_read_data = ram_read_data;
        end

        else if(uart_selected) begin
            uart_request = master_request;
            uart_write = master_write;
            uart_address = master_address;
            uart_write_data = master_write_data;
            uart_byte_sel = master_byte_sel;

            master_ack = uart_ack;
            master_err = uart_err;
            master_read_data = uart_read_data;
        end

        else if(master_request) begin
            master_err = 1'b1;
        end

    end

endmodule