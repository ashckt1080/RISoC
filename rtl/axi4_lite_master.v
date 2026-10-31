`timescale 1ns / 1ps

module axi4_lite_master (
    input clk,
    input rst,

    input req_valid,
    output req_ready,
    input req_write,
    input [31:0] req_addr,
    input [31:0] req_wdata,
    input [3:0] req_wstrb,

    output resp_valid,
    input resp_ready,
    output reg [31:0] resp_rdata,
    output reg [1:0] resp_status,

    output [31:0] m_axi_awaddr,
    output [2:0] m_axi_awprot,
    output m_axi_awvalid,
    input m_axi_awready,

    output [31:0] m_axi_wdata,
    output [3:0] m_axi_wstrb,
    output m_axi_wvalid,
    input m_axi_wready,

    input [1:0] m_axi_bresp,
    input m_axi_bvalid,
    output m_axi_bready,

    output [31:0] m_axi_araddr,
    output [2:0] m_axi_arprot,
    output m_axi_arvalid,
    input m_axi_arready,

    input [31:0] m_axi_rdata,
    input [1:0] m_axi_rresp,
    input m_axi_rvalid,
    output m_axi_rready
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] READ_ADDR = 3'd1;
    localparam [2:0] READ_RESP = 3'd2;
    localparam [2:0] WRITE_SEND = 3'd3;
    localparam [2:0] WRITE_RESP = 3'd4;
    localparam [2:0] RESP_HOLD = 3'd5;

    reg [2:0] state;
    reg [31:0] addr_reg;
    reg [31:0] wdata_reg;
    reg [3:0] wstrb_reg;
    reg aw_sent;
    reg w_sent;

    assign req_ready = (state == IDLE);
    assign resp_valid = (state == RESP_HOLD);

    assign m_axi_awaddr = addr_reg;
    assign m_axi_araddr = addr_reg;
    assign m_axi_wdata = wdata_reg;
    assign m_axi_wstrb = wstrb_reg;

    assign m_axi_awprot = 3'b000;
    assign m_axi_arprot = 3'b000;

    assign m_axi_arvalid = (state == READ_ADDR);
    assign m_axi_rready = (state == READ_RESP);

    assign m_axi_awvalid = (state == WRITE_SEND) && !aw_sent;
    assign m_axi_wvalid = (state == WRITE_SEND) && !w_sent;
    assign m_axi_bready = (state == WRITE_RESP);

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            addr_reg <= 32'b0;
            wdata_reg <= 32'b0;
            wstrb_reg <= 4'b0;
            aw_sent <= 1'b0;
            w_sent <= 1'b0;
            resp_rdata <= 32'b0;
            resp_status <= 2'b00;
        end else begin
            case (state)
                IDLE: begin
                    if (req_valid && req_ready) begin
                        addr_reg <= req_addr;
                        wdata_reg <= req_wdata;
                        wstrb_reg <= req_wstrb;
                        aw_sent <= 1'b0;
                        w_sent <= 1'b0;
                        if (req_write)
                            state <= WRITE_SEND;
                        else
                            state <= READ_ADDR;
                    end
                end

                READ_ADDR: begin
                    if (m_axi_arvalid && m_axi_arready)
                        state <= READ_RESP;
                end

                READ_RESP: begin
                    if (m_axi_rvalid && m_axi_rready) begin
                        resp_rdata <= m_axi_rdata;
                        resp_status <= m_axi_rresp;
                        state <= RESP_HOLD;
                    end
                end

                WRITE_SEND: begin
                    if (m_axi_awvalid && m_axi_awready)
                        aw_sent <= 1'b1;
                    if (m_axi_wvalid && m_axi_wready)
                        w_sent <= 1'b1;

                    if ((aw_sent || (m_axi_awvalid && m_axi_awready)) &&
                        (w_sent || (m_axi_wvalid && m_axi_wready)))
                        state <= WRITE_RESP;
                end

                WRITE_RESP: begin
                    if (m_axi_bvalid && m_axi_bready) begin
                        resp_rdata <= 32'b0;
                        resp_status <= m_axi_bresp;
                        state <= RESP_HOLD;
                    end
                end

                RESP_HOLD: begin
                    if (resp_valid && resp_ready)
                        state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
