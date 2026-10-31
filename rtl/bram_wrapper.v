`timescale 1ns / 1ps

module axi4_lite_bram_slave (
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

    output reg [1:0] s_axi_bresp,
    output reg s_axi_bvalid,
    input s_axi_bready,

    input [31:0] s_axi_araddr,
    input [2:0] s_axi_arprot,
    input s_axi_arvalid,
    output s_axi_arready,

    output reg [31:0] s_axi_rdata,
    output reg [1:0] s_axi_rresp,
    output reg s_axi_rvalid,
    input s_axi_rready
);
    localparam [1:0] OKAY = 2'b00, SLVERR = 2'b10;

    (* ram_style = "block" *) reg [31:0] memory [0:1023];

    reg [31:0] awaddr_reg, wdata_reg;
    reg [3:0] wstrb_reg;
    reg have_aw, have_w;
    integer i;

    assign s_axi_awready = !rst && !have_aw && !s_axi_bvalid;
    assign s_axi_wready = !rst && !have_w && !s_axi_bvalid;
    assign s_axi_arready = !rst && !s_axi_rvalid;

    always @(posedge clk) begin
        if (rst) begin
            have_aw <= 1'b0;
            have_w <= 1'b0;
            awaddr_reg <= 32'b0;
            wdata_reg <= 32'b0;
            wstrb_reg <= 4'b0;
            s_axi_bvalid <= 1'b0;
            s_axi_bresp <= OKAY;
            s_axi_rvalid <= 1'b0;
            s_axi_rresp <= OKAY;
            s_axi_rdata <= 32'b0;
        end else begin
            if (s_axi_awvalid && s_axi_awready) begin
                awaddr_reg <= s_axi_awaddr;
                have_aw <= 1'b1;
            end
            if (s_axi_wvalid && s_axi_wready) begin
                wdata_reg <= s_axi_wdata;
                wstrb_reg <= s_axi_wstrb;
                have_w <= 1'b1;
            end

            if (have_aw && have_w) begin
                if (awaddr_reg[31:12] != 20'h00000 || awaddr_reg[1:0] != 2'b00) begin
                    s_axi_bresp <= SLVERR;
                end else begin
                    for (i = 0; i < 4; i = i + 1)
                        if (wstrb_reg[i])
                            memory[awaddr_reg[11:2]][8*i +: 8] <= wdata_reg[8*i +: 8];
                    s_axi_bresp <= OKAY;
                end
                have_aw <= 1'b0;
                have_w <= 1'b0;
                s_axi_bvalid <= 1'b1;
            end else if (s_axi_bvalid && s_axi_bready) begin
                s_axi_bvalid <= 1'b0;
            end

            if (s_axi_arvalid && s_axi_arready) begin
                if (s_axi_araddr[31:12] != 20'h00000 || s_axi_araddr[1:0] != 2'b00) begin
                    s_axi_rdata <= 32'b0;
                    s_axi_rresp <= SLVERR;
                end else begin
                    s_axi_rdata <= memory[s_axi_araddr[11:2]];
                    s_axi_rresp <= OKAY;
                end
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rvalid && s_axi_rready) begin
                s_axi_rvalid <= 1'b0;
            end
        end
    end
endmodule
