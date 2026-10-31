`timescale 1ns / 1ps

module axi4_lite_interconnect (
    input clk,
    input rst,

    input [31:0] s_axi_awaddr,
    input [2:0] s_axi_awprot,
    input s_axi_awvalid,
    output s_axi_awready,
    input [31:0] s_axi_wdata,
    input [3:0] s_axi_wstrb,
    input s_axi_wvalid,
    output s_axi_wready,
    output [1:0] s_axi_bresp,
    output s_axi_bvalid,
    input s_axi_bready,
    input [31:0] s_axi_araddr,
    input [2:0] s_axi_arprot,
    input s_axi_arvalid,
    output s_axi_arready,
    output [31:0] s_axi_rdata,
    output [1:0] s_axi_rresp,
    output s_axi_rvalid,
    input s_axi_rready,

    output [31:0] m0_axi_awaddr,
    output [2:0] m0_axi_awprot,
    output m0_axi_awvalid,
    input m0_axi_awready,
    output [31:0] m0_axi_wdata,
    output [3:0] m0_axi_wstrb,
    output m0_axi_wvalid,
    input m0_axi_wready,
    input [1:0] m0_axi_bresp,
    input m0_axi_bvalid,
    output m0_axi_bready,
    output [31:0] m0_axi_araddr,
    output [2:0] m0_axi_arprot,
    output m0_axi_arvalid,
    input m0_axi_arready,
    input [31:0] m0_axi_rdata,
    input [1:0] m0_axi_rresp,
    input m0_axi_rvalid,
    output m0_axi_rready
);
    localparam [2:0] IDLE = 3'd0,
                     WR_COLLECT = 3'd1,
                     WR_SEND = 3'd2,
                     WR_RESP = 3'd3,
                     RD_ADDR = 3'd4,
                     RD_RESP = 3'd5;
    localparam [1:0] DECERR = 2'b11;

    reg [2:0] state;
    reg [31:0] awaddr_reg, wdata_reg, araddr_reg;
    reg [2:0] awprot_reg, arprot_reg;
    reg [3:0] wstrb_reg;
    reg have_aw, have_w, aw_sent, w_sent;

    wire write_offer = s_axi_awvalid || s_axi_wvalid;
    wire wr_in_range = (awaddr_reg[31:12] == 20'h00000);
    wire rd_in_range = (araddr_reg[31:12] == 20'h00000);

    assign s_axi_awready = !rst && (((state == IDLE) && write_offer) || ((state == WR_COLLECT) && !have_aw));
    assign s_axi_wready = !rst && (((state == IDLE) && write_offer) || ((state == WR_COLLECT) && !have_w));
    assign s_axi_arready = !rst && (state == IDLE) && !write_offer;

    assign m0_axi_awaddr = awaddr_reg;
    assign m0_axi_awprot = awprot_reg;
    assign m0_axi_wdata = wdata_reg;
    assign m0_axi_wstrb = wstrb_reg;
    assign m0_axi_araddr = araddr_reg;
    assign m0_axi_arprot = arprot_reg;

    assign m0_axi_awvalid = (state == WR_SEND) && wr_in_range && !aw_sent;
    assign m0_axi_wvalid = (state == WR_SEND) && wr_in_range && !w_sent;
    wire aw_fire = m0_axi_awvalid && m0_axi_awready;
    wire w_fire = m0_axi_wvalid && m0_axi_wready;

    assign m0_axi_bready = (state == WR_RESP) && wr_in_range && s_axi_bready;
    assign s_axi_bvalid = (state == WR_RESP) && (wr_in_range ? m0_axi_bvalid : 1'b1);
    assign s_axi_bresp = wr_in_range ? m0_axi_bresp : DECERR;

    assign m0_axi_arvalid = (state == RD_ADDR) && rd_in_range;
    assign m0_axi_rready = (state == RD_RESP) && rd_in_range && s_axi_rready;
    assign s_axi_rvalid = (state == RD_RESP) && (rd_in_range ? m0_axi_rvalid : 1'b1);
    assign s_axi_rdata = rd_in_range ? m0_axi_rdata : 32'b0;
    assign s_axi_rresp = rd_in_range ? m0_axi_rresp : DECERR;

    always @(posedge clk) begin
        if (rst) begin
            state <= IDLE;
            awaddr_reg <= 32'b0;
            awprot_reg <= 3'b0;
            wdata_reg <= 32'b0;
            wstrb_reg <= 4'b0;
            araddr_reg <= 32'b0;
            arprot_reg <= 3'b0;
            have_aw <= 1'b0;
            have_w <= 1'b0;
            aw_sent <= 1'b0;
            w_sent <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (write_offer) begin
                        have_aw <= 1'b0;
                        have_w <= 1'b0;
                        aw_sent <= 1'b0;
                        w_sent <= 1'b0;
                        if (s_axi_awvalid && s_axi_awready) begin
                            awaddr_reg <= s_axi_awaddr;
                            awprot_reg <= s_axi_awprot;
                            have_aw <= 1'b1;
                        end
                        if (s_axi_wvalid && s_axi_wready) begin
                            wdata_reg <= s_axi_wdata;
                            wstrb_reg <= s_axi_wstrb;
                            have_w <= 1'b1;
                        end
                        state <= WR_COLLECT;
                    end else if (s_axi_arvalid && s_axi_arready) begin
                        araddr_reg <= s_axi_araddr;
                        arprot_reg <= s_axi_arprot;
                        state <= RD_ADDR;
                    end
                end

                WR_COLLECT: begin
                    if (s_axi_awvalid && s_axi_awready) begin
                        awaddr_reg <= s_axi_awaddr;
                        awprot_reg <= s_axi_awprot;
                        have_aw <= 1'b1;
                    end
                    if (s_axi_wvalid && s_axi_wready) begin
                        wdata_reg <= s_axi_wdata;
                        wstrb_reg <= s_axi_wstrb;
                        have_w <= 1'b1;
                    end
                    if (have_aw && have_w)
                        state <= WR_SEND;
                end

                WR_SEND: begin
                    if (!wr_in_range) begin
                        state <= WR_RESP;
                    end else begin
                        if (aw_fire) aw_sent <= 1'b1;
                        if (w_fire) w_sent <= 1'b1;
                        if ((aw_sent || aw_fire) && (w_sent || w_fire))
                            state <= WR_RESP;
                    end
                end

                WR_RESP: begin
                    if (s_axi_bvalid && s_axi_bready)
                        state <= IDLE;
                end

                RD_ADDR: begin
                    if (!rd_in_range || (m0_axi_arvalid && m0_axi_arready))
                        state <= RD_RESP;
                end

                RD_RESP: begin
                    if (s_axi_rvalid && s_axi_rready)
                        state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule
