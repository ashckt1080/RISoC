`timescale 1ns / 1ps

module ram_wrapper(

    input clk,
    input rst,
    
    input request,
    input write,
    input [31:0] address,
    input [31:0] write_data,
    input [3:0] byte_sel,

    output reg ack,
    output reg err,
    output reg [31:0] read_data
    );
    
    (* ram_style = "block" *)
    reg [31:0] memory [0:1023];
    
    wire [9:0] local_address = address[11:2];
    
    reg busy;
    
    always @ (posedge clk) begin
    
        if(rst) begin
            busy <= 1'b0;
            ack <= 1'b0;
            err <= 1'b0;
            read_data <= 32'b0; 
        end
        
        else if(busy) begin
            busy <= 1'b0;
            ack <= 1'b0;
            err <= 1'b0;
        end
        
        else if(request) begin
        
            busy <= 1'b1;
            ack <= 1'b1;
            err <= 1'b0;
            
            if(write) begin
            
                if(byte_sel[0]) begin
                    memory[local_address][7:0] <= write_data[7:0];
                end

                if(byte_sel[1]) begin
                    memory[local_address][15:8] <= write_data[15:8];
                end

                if(byte_sel[2]) begin
                    memory[local_address][23:16] <= write_data[23:16];
                end
                
                if(byte_sel[3]) begin
                    memory[local_address][31:24] <= write_data[31:24];
                end
                 
            end
            
            else begin
                read_data <= memory[local_address];
            end
             
        end
        
    end
    
endmodule