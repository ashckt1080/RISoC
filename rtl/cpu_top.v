`timescale 1ns / 1ps

module cpu_top(
    input clk,
    input raw_rst,
    output [3:0] debug_led
    );

    wire rst;

    reset_sync reset_sync_ (.clk(clk),
                            .raw_rst(raw_rst),
                            .rst(rst));

    //IF signals
    wire IF_pc_hold;
    wire [31:0] IF_pc_mux_out;
    wire [31:0] IF_pc_next;
    wire [31:0] IF_pc;
    wire [31:0] IF_pc_plus4;
    wire IF_fetch_valid;
    wire IF_ID_flush;
    wire IF_ID_enable;

    assign IF_fetch_valid = (IF_pc[1:0] == 2'b00) && (IF_pc[31:12] == 20'b0);

    //Branch Predictor / BTB signals
    wire [5:0] IF_pred_index;
    wire [5:0] ID_pred_index;
    wire [5:0] EX_pred_index;

    wire IF_pred_taken;
    wire [31:0] IF_pred_target;
    wire IF_pred_target_aligned;
    wire IF_pred_redirect;

    wire IF_spec_taken;
    wire ID_spec_taken;
    wire EX_spec_taken;

    assign IF_pred_target_aligned = (IF_pred_target[1:0] == 2'b00);
    assign IF_pred_redirect = IF_fetch_valid && IF_pred_taken && IF_pred_target_aligned;
    assign IF_spec_taken = IF_pred_redirect;

    //ID signals
    wire [31:0] ID_pc;
    wire [31:0] ID_pc_plus4;
    wire [31:0] ID_instr;
    wire ID_valid;
    wire [6:0] ID_opcode;
    wire [4:0] ID_rd_addr;
    wire [4:0] ID_rs1_addr;
    wire [4:0] ID_rs2_addr;
    wire [2:0] ID_funct3;
    wire [6:0] ID_funct7;
    wire ID_reg_write;
    wire ID_mem_write;
    wire ID_mem_read;
    wire ID_branch;
    wire ID_jump;
    wire [1:0] ID_alu_a_src;
    wire [1:0] ID_alu_b_src;
    wire [1:0] ID_wb_src;
    wire ID_opcode_invalid;
    wire [31:0] ID_immediate;
    wire [3:0] ID_alu_op;
    wire [31:0] ID_rs1_data;
    wire [31:0] ID_rs2_data;
    wire ID_EX_enable;
    wire ID_EX_flush;
    wire ID_rs1_used;
    wire ID_rs2_used;

    //EX signals
    wire [31:0] EX_branch_target;
    wire [31:0] EX_jump_target;
    wire EX_branch_taken;
    wire EX_jump_taken;
    wire [31:0] EX_pc;
    wire [31:0] EX_pc_plus4;
    wire [6:0] EX_opcode;
    wire [4:0] EX_rd_addr;
    wire [4:0] EX_rs1_addr;
    wire [4:0] EX_rs2_addr;
    wire [2:0] EX_funct3;
    wire [6:0] EX_funct7;
    wire EX_reg_write;
    wire EX_mem_write;
    wire EX_mem_read;
    wire EX_branch;
    wire EX_jump;
    wire [1:0] EX_alu_a_src;
    wire [1:0] EX_alu_b_src;
    wire [1:0] EX_wb_src;
    wire [31:0] EX_immediate;
    wire [31:0] EX_rs1_data;
    wire [31:0] EX_rs2_data;
    wire [3:0] EX_alu_op;
    wire [31:0] EX_alu_a_in;
    wire [31:0] EX_alu_b_in;
    wire [31:0] EX_alu_out;
    wire EX_z;
    wire EX_MEM_enable;
    wire EX_valid;

    wire [31:0] EX_alu_m_result;

    wire MEM_wait;

    wire EX_branch_target_aligned;
    wire EX_branch_mispredict;
    wire [31:0] EX_branch_recovery;
    wire EX_branch_recovery_redirect;
    wire EX_jump_target_aligned;

    assign EX_branch_target_aligned = (EX_branch_target[1:0] == 2'b00);
    assign EX_branch_mispredict = EX_valid && !MEM_wait && EX_branch && (EX_spec_taken != EX_branch_taken);
    assign EX_branch_recovery = EX_branch_taken ? EX_branch_target : EX_pc_plus4;
    assign EX_branch_recovery_redirect = EX_branch_mispredict && (!EX_branch_taken || EX_branch_target_aligned);

    //M unit
    wire EX_is_m_instr;
    wire EX_m_start;
    reg EX_m_started;
    wire EX_m_busy;
    wire EX_m_stall;
    wire EX_m_done;
    wire [31:0] EX_m_out;

    assign EX_is_m_instr = (EX_valid && EX_opcode == 7'b0110011 && EX_funct7 == 7'b0000001);
    assign EX_m_start = EX_is_m_instr && !MEM_wait && !EX_m_started && !EX_m_busy;
    assign EX_m_stall = EX_is_m_instr && !EX_m_done;

    //MEM signals
    wire [31:0] MEM_pc_plus4;
    wire [31:0] MEM_alu_out;
    wire [31:0] MEM_rs1_data;
    wire [31:0] MEM_rs2_data;
    wire [4:0] MEM_rd_addr;
    wire [2:0] MEM_funct3;
    wire MEM_reg_write;
    wire MEM_mem_write;
    wire MEM_mem_read;
    wire [1:0] MEM_wb_src;

    wire MEM_valid;

    //LSU signals
    wire lsu_request;
    wire lsu_write;
    wire [31:0] lsu_address;
    wire [31:0] lsu_write_data;
    wire [3:0] lsu_byte_sel;
    wire [31:0] lsu_load_result;
    wire lsu_misaligned;

    //Bus master signals
    wire master_request;
    wire master_write;
    wire [31:0] master_address;
    wire [31:0] master_write_data;
    wire [3:0] master_byte_sel;
    wire master_ack;
    wire master_err;
    wire [31:0] master_read_data;
    wire [31:0] bus_load_data;
    wire bus_fault;

    //RAM route signals
    wire ram_request;
    wire ram_write;
    wire [31:0] ram_address;
    wire [31:0] ram_write_data;
    wire [3:0] ram_byte_sel;
    wire ram_ack;
    wire ram_err;
    wire [31:0] ram_read_data;

    //UART route signals
    wire uart_request;
    wire uart_write;
    wire [31:0] uart_address;
    wire [31:0] uart_write_data;
    wire [3:0] uart_byte_sel;
    wire uart_ack;
    wire uart_err;
    wire [31:0] uart_read_data;

    //WB signals
    wire [31:0] WB_data;
    wire WB_reg_write;
    wire [4:0] WB_rd_addr;
    wire MEM_WB_enable;
    wire WB_valid;
    wire [31:0] WB_alu_out;
    wire [31:0] WB_data_mem;
    wire [31:0] WB_pc_plus4;
    wire [1:0] WB_wb_src;

    //Hazard signals
    wire EX_forward_a_mem;
    wire EX_forward_a_wb;
    wire EX_forward_b_mem;
    wire EX_forward_b_wb;
    wire [31:0] EX_forwarded_rs1_data;
    wire [31:0] EX_forwarded_rs2_data;

    wire ID_stall;
    wire EX_flush;

    wire EX_jump_redirect;
    wire EX_instr_addr_fault;

    assign EX_jump_target_aligned = (EX_jump_target[1:0] == 2'b00);
    assign EX_jump_redirect = EX_valid && !MEM_wait && EX_jump_taken && EX_jump_target_aligned;

    assign EX_instr_addr_fault = EX_valid && !MEM_wait &&((EX_branch_taken && !EX_branch_target_aligned) ||(EX_jump_taken && !EX_jump_target_aligned));

    assign IF_pc_plus4 = IF_pc + 32'd4;

    assign IF_pc_hold = MEM_wait || (!EX_flush && (ID_stall || EX_m_stall));
    assign IF_pc_next = IF_pc_hold ? IF_pc : IF_pc_mux_out;

    assign IF_ID_flush = !MEM_wait && (EX_flush | EX_instr_addr_fault);
    assign IF_ID_enable = (ID_stall | EX_m_stall | MEM_wait) ? 1'b0 : 1'b1;

    assign ID_EX_flush = !MEM_wait && (EX_flush | EX_instr_addr_fault);
    assign ID_EX_enable = (EX_m_stall | MEM_wait) ? 1'b0 : 1'b1;

    assign EX_MEM_enable = MEM_wait ? 1'b0 : 1'b1;

    assign MEM_WB_enable = 1'b1;

    always @(posedge clk) begin
        if(rst) begin
            EX_m_started <= 1'b0;
        end

        else if(EX_m_done) begin
            EX_m_started <= 1'b0;
        end

        else if(EX_m_start) begin
            EX_m_started <= 1'b1;
        end
    end

    pc pc_ (.clk(clk),
            .rst(rst),
            .pc_next(IF_pc_next),
            .pc(IF_pc));

    pc_mux pc_mux_ (.pc_plus4(IF_pc_plus4),
                    .pred_target(IF_pred_target),
                    .branch_recovery(EX_branch_recovery),
                    .jump_target(EX_jump_target),
                    .pred_redirect(IF_pred_redirect),
                    .branch_recovery_redirect(EX_branch_recovery_redirect),
                    .jump_redirect(EX_jump_redirect),
                    .pc_next(IF_pc_mux_out));

    instr_mem instr_mem_ (.clk(clk),
                          .read_en(IF_ID_enable),
                          .pc_in(IF_pc),
                          .instr_out(ID_instr));

    if_id_register if_id_register_ (.clk(clk),
                                    .rst(rst),
                                    .if_id_enable(IF_ID_enable),
                                    .flush(IF_ID_flush),
                                    .valid_in(IF_fetch_valid),
                                    .pc_in(IF_pc),
                                    .pc_plus4_in(IF_pc_plus4),
                                    .spec_taken_in(IF_spec_taken),
                                    .pred_index_in(IF_pred_index),
                                    .pc_out(ID_pc),
                                    .pc_plus4_out(ID_pc_plus4),
                                    .valid_out(ID_valid),
                                    .spec_taken_out(ID_spec_taken),
                                    .pred_index_out(ID_pred_index));

    //instr_mem and if_id_register are registered in parallel, instr_mem produces ID_instr,
    //if_id_register produces matching PC and prediction metadata

    instr_field_extractor instr_field_extractor_ (.instr(ID_instr),
                                                  .opcode(ID_opcode),
                                                  .rd_addr(ID_rd_addr),
                                                  .rs1_addr(ID_rs1_addr),
                                                  .rs2_addr(ID_rs2_addr),
                                                  .funct3(ID_funct3),
                                                  .funct7(ID_funct7));

    decoder decoder_ (.opcode(ID_opcode),
                      .reg_write(ID_reg_write),
                      .mem_write(ID_mem_write),
                      .mem_read(ID_mem_read),
                      .alu_a_src(ID_alu_a_src),
                      .alu_b_src(ID_alu_b_src),
                      .wb_src(ID_wb_src),
                      .opcode_invalid(ID_opcode_invalid),
                      .branch(ID_branch),
                      .jump(ID_jump),
                      .rs1_used(ID_rs1_used),
                      .rs2_used(ID_rs2_used));

    imm_gen imm_gen_ (.instr(ID_instr),
                      .immediate(ID_immediate));

    alu_decoder alu_decoder_ (.instr(ID_instr),
                              .alu_op(ID_alu_op));

    reg_file reg_file_ (.clk(clk),
                        .rst(rst),
                        .write_en(WB_reg_write),
                        .rs1_addr(ID_rs1_addr),
                        .rs2_addr(ID_rs2_addr),
                        .rd_addr(WB_rd_addr),
                        .rs1_data(ID_rs1_data),
                        .rs2_data(ID_rs2_data),
                        .wb_data(WB_data),
                        .valid(WB_valid));

    id_ex_register id_ex_register_ (.clk(clk),
                                    .rst(rst),
                                    .id_ex_enable(ID_EX_enable),
                                    .flush(ID_EX_flush),
                                    .valid_in(ID_stall ? 1'b0 : ID_valid),
                                    .pc_in(ID_pc),
                                    .pc_plus4_in(ID_pc_plus4),
                                    .opcode_in(ID_opcode),
                                    .rd_addr_in(ID_rd_addr),
                                    .rs1_addr_in(ID_rs1_addr),
                                    .rs2_addr_in(ID_rs2_addr),
                                    .funct3_in(ID_funct3),
                                    .funct7_in(ID_funct7),
                                    .immediate_in(ID_immediate),
                                    .rs1_data_in(ID_rs1_data),
                                    .rs2_data_in(ID_rs2_data),
                                    .alu_op_in(ID_alu_op),
                                    .reg_write_in(ID_reg_write),
                                    .mem_write_in(ID_mem_write),
                                    .mem_read_in(ID_mem_read),
                                    .branch_in(ID_branch),
                                    .jump_in(ID_jump),
                                    .alu_a_src_in(ID_alu_a_src),
                                    .alu_b_src_in(ID_alu_b_src),
                                    .wb_src_in(ID_wb_src),
                                    .spec_taken_in(ID_spec_taken),
                                    .pred_index_in(ID_pred_index),
                                    .valid_out(EX_valid),
                                    .pc_out(EX_pc),
                                    .pc_plus4_out(EX_pc_plus4),
                                    .opcode_out(EX_opcode),
                                    .rd_addr_out(EX_rd_addr),
                                    .rs1_addr_out(EX_rs1_addr),
                                    .rs2_addr_out(EX_rs2_addr),
                                    .funct3_out(EX_funct3),
                                    .funct7_out(EX_funct7),
                                    .immediate_out(EX_immediate),
                                    .rs1_data_out(EX_rs1_data),
                                    .rs2_data_out(EX_rs2_data),
                                    .alu_op_out(EX_alu_op),
                                    .reg_write_out(EX_reg_write),
                                    .mem_write_out(EX_mem_write),
                                    .mem_read_out(EX_mem_read),
                                    .branch_out(EX_branch),
                                    .jump_out(EX_jump),
                                    .alu_a_src_out(EX_alu_a_src),
                                    .alu_b_src_out(EX_alu_b_src),
                                    .wb_src_out(EX_wb_src),
                                    .spec_taken_out(EX_spec_taken),
                                    .pred_index_out(EX_pred_index));

    alu_mux alu_mux_ (.rs1_data(EX_forwarded_rs1_data),
                      .rs2_data(EX_forwarded_rs2_data),
                      .pc(EX_pc),
                      .immediate(EX_immediate),
                      .alu_a_src(EX_alu_a_src),
                      .alu_b_src(EX_alu_b_src),
                      .alu_a_out(EX_alu_a_in),
                      .alu_b_out(EX_alu_b_in));

    alu alu_ (.a(EX_alu_a_in),
              .b(EX_alu_b_in),
              .opcode(EX_alu_op),
              .result(EX_alu_out),
              .z(EX_z));

    branch_controller branch_controller_ (.pc(EX_pc),
                                          .immediate(EX_immediate),
                                          .funct3(EX_funct3),
                                          .forwarded_rs1(EX_forwarded_rs1_data),
                                          .forwarded_rs2(EX_forwarded_rs2_data),
                                          .branch(EX_branch),
                                          .branch_target(EX_branch_target),
                                          .branch_taken(EX_branch_taken),
                                          .valid(EX_valid && !MEM_wait));

    jump_controller jump_controller_ (.pc(EX_pc),
                                      .immediate(EX_immediate),
                                      .opcode(EX_opcode),
                                      .jump(EX_jump),
                                      .rs1_data(EX_forwarded_rs1_data),
                                      .jump_target(EX_jump_target),
                                      .jump_taken(EX_jump_taken),
                                      .valid(EX_valid && !MEM_wait));

    ex_mem_register ex_mem_register_ (.clk(clk),
                                      .rst(rst),
                                      .ex_mem_enable(EX_MEM_enable),
                                      .valid_in(EX_m_stall ? 1'b0 : EX_valid),
                                      .pc_plus4_in(EX_pc_plus4),
                                      .alu_result_in(EX_alu_m_result),
                                      .rs1_data_in(EX_forwarded_rs1_data),
                                      .rs2_data_in(EX_forwarded_rs2_data),
                                      .rd_addr_in(EX_rd_addr),
                                      .funct3_in(EX_funct3),
                                      .reg_write_in(EX_reg_write),
                                      .mem_write_in(EX_mem_write),
                                      .mem_read_in(EX_mem_read),
                                      .wb_src_in(EX_wb_src),
                                      .valid_out(MEM_valid),
                                      .pc_plus4_out(MEM_pc_plus4),
                                      .alu_result_out(MEM_alu_out),
                                      .rs1_data_out(MEM_rs1_data),
                                      .rs2_data_out(MEM_rs2_data),
                                      .rd_addr_out(MEM_rd_addr),
                                      .funct3_out(MEM_funct3),
                                      .reg_write_out(MEM_reg_write),
                                      .mem_read_out(MEM_mem_read),
                                      .mem_write_out(MEM_mem_write),
                                      .wb_src_out(MEM_wb_src));

    mem_wb_register mem_wb_register_ (.clk(clk),
                                      .rst(rst),
                                      .mem_wb_enable(MEM_WB_enable),
                                      .valid_in((MEM_wait || lsu_misaligned || bus_fault) ? 1'b0 : MEM_valid),
                                      .alu_result_in(MEM_alu_out),
                                      .data_mem_in(lsu_load_result),
                                      .pc_plus4_in(MEM_pc_plus4),
                                      .rd_addr_in(MEM_rd_addr),
                                      .reg_write_in(MEM_reg_write),
                                      .wb_src_in(MEM_wb_src),
                                      .valid_out(WB_valid),
                                      .alu_result_out(WB_alu_out),
                                      .data_mem_out(WB_data_mem),
                                      .pc_plus4_out(WB_pc_plus4),
                                      .rd_addr_out(WB_rd_addr),
                                      .reg_write_out(WB_reg_write),
                                      .wb_src_out(WB_wb_src));

    wb_mux wb_mux_ (.alu_result(WB_alu_out),
                    .pc_plus4(WB_pc_plus4),
                    .data_mem_out(WB_data_mem),
                    .wb_src(WB_wb_src),
                    .wb_data(WB_data));

    forwarding_controller forwarding_controller_ (.EX_rs1_addr(EX_rs1_addr),
                                                  .EX_rs2_addr(EX_rs2_addr),
                                                  .MEM_valid(MEM_valid),
                                                  .MEM_rd_addr(MEM_rd_addr),
                                                  .MEM_reg_write(MEM_reg_write),
                                                  .MEM_mem_read(MEM_mem_read),
                                                  .WB_rd_addr(WB_rd_addr),
                                                  .WB_reg_write(WB_reg_write),
                                                  .WB_valid(WB_valid),
                                                  .forward_a_mem(EX_forward_a_mem),
                                                  .forward_a_wb(EX_forward_a_wb),
                                                  .forward_b_mem(EX_forward_b_mem),
                                                  .forward_b_wb(EX_forward_b_wb));

    forwarding_mux forwarding_mux_ (.forward_a_mem(EX_forward_a_mem),
                                    .forward_a_wb(EX_forward_a_wb),
                                    .forward_b_mem(EX_forward_b_mem),
                                    .forward_b_wb(EX_forward_b_wb),
                                    .EX_rs1_data(EX_rs1_data),
                                    .EX_rs2_data(EX_rs2_data),
                                    .MEM_alu_out(MEM_alu_out),
                                    .MEM_pc_plus4(MEM_pc_plus4),
                                    .MEM_wb_src(MEM_wb_src),
                                    .WB_data(WB_data),
                                    .forwarded_data_a(EX_forwarded_rs1_data),
                                    .forwarded_data_b(EX_forwarded_rs2_data));

    stall_controller stall_controller_ (.EX_valid(EX_valid),
                                        .EX_mem_read(EX_mem_read),
                                        .EX_rd_addr(EX_rd_addr),
                                        .ID_valid(ID_valid),
                                        .ID_rs1_addr(ID_rs1_addr),
                                        .ID_rs2_addr(ID_rs2_addr),
                                        .ID_rs1_used(ID_rs1_used),
                                        .ID_rs2_used(ID_rs2_used),
                                        .stall(ID_stall));

    flush_controller flush_controller_ (.branch_mispredict(EX_branch_mispredict),
                                        .jump_taken(EX_valid && !MEM_wait && EX_jump_taken),
                                        .flush(EX_flush));

    m_unit m_unit_ (.clk(clk),
                    .rst(rst),
                    .start(EX_m_start),
                    .a_in(EX_forwarded_rs1_data),
                    .b_in(EX_forwarded_rs2_data),
                    .funct3(EX_funct3),
                    .result(EX_m_out),
                    .done(EX_m_done),
                    .busy(EX_m_busy));

    alu_m_result_mux alu_m_result_mux_ (.alu_out(EX_alu_out),
                                        .m_out(EX_m_out),
                                        .is_m_instr(EX_is_m_instr),
                                        .alu_m_result(EX_alu_m_result));

    branch_predictor branch_predictor_ (.clk(clk),
                                        .rst(rst),
                                        .IF_pc(IF_pc),
                                        .EX_pc(EX_pc),
                                        .EX_branch_target(EX_branch_target),
                                        .EX_pred_index(EX_pred_index),
                                        .EX_valid(EX_valid && !MEM_wait),
                                        .EX_branch(EX_branch),
                                        .EX_branch_taken(EX_branch_taken),
                                        .IF_pred_taken(IF_pred_taken),
                                        .IF_pred_target(IF_pred_target),
                                        .IF_pred_index(IF_pred_index));
                                        

    load_store_controller load_store_controller_ (.MEM_valid(MEM_valid),
                                                 .MEM_mem_read(MEM_mem_read),
                                                 .MEM_mem_write(MEM_mem_write),
                                                 .funct3(MEM_funct3),
                                                 .rs2_data(MEM_rs2_data),
                                                 .alu_addr_in(MEM_alu_out),
                                                 .raw_read_data(bus_load_data),
                                                 .request(lsu_request),
                                                 .write(lsu_write),
                                                 .address(lsu_address),
                                                 .write_data(lsu_write_data),
                                                 .byte_sel(lsu_byte_sel),
                                                 .load_result(lsu_load_result),
                                                 .misaligned(lsu_misaligned));

    cpu_bus_master cpu_bus_master_ (.request(lsu_request),
                                    .write(lsu_write),
                                    .address(lsu_address),
                                    .write_data(lsu_write_data),
                                    .byte_sel(lsu_byte_sel),
                                    .ack(master_ack),
                                    .err(master_err),
                                    .read_data(master_read_data),
                                    .MEM_wait(MEM_wait),
                                    .load_data(bus_load_data),
                                    .fault(bus_fault),
                                    .bus_request(master_request),
                                    .bus_write(master_write),
                                    .bus_address(master_address),
                                    .bus_write_data(master_write_data),
                                    .bus_byte_sel(master_byte_sel));

    bus_interconnect bus_interconnect_ (.master_request(master_request),
                                        .master_write(master_write),
                                        .master_address(master_address),
                                        .master_write_data(master_write_data),
                                        .master_byte_sel(master_byte_sel),
                                        .master_ack(master_ack),
                                        .master_err(master_err),
                                        .master_read_data(master_read_data),
                                        .ram_request(ram_request),
                                        .ram_write(ram_write),
                                        .ram_address(ram_address),
                                        .ram_write_data(ram_write_data),
                                        .ram_byte_sel(ram_byte_sel),
                                        .ram_ack(ram_ack),
                                        .ram_err(ram_err),
                                        .ram_read_data(ram_read_data),
                                        .uart_request(uart_request),
                                        .uart_write(uart_write),
                                        .uart_address(uart_address),
                                        .uart_write_data(uart_write_data),
                                        .uart_byte_sel(uart_byte_sel),
                                        .uart_ack(uart_ack),
                                        .uart_err(uart_err),
                                        .uart_read_data(uart_read_data));

    ram_wrapper ram_wrapper_ (.clk(clk),
                              .rst(rst),
                              .request(ram_request),
                              .write(ram_write),
                              .address(ram_address),
                              .write_data(ram_write_data),
                              .byte_sel(ram_byte_sel),
                              .ack(ram_ack),
                              .err(ram_err),
                              .read_data(ram_read_data));

    //temporary UART termination 
    assign uart_ack = 1'b0;
    assign uart_err = uart_request;
    assign uart_read_data = 32'b0;


    assign debug_led[0] = ^IF_pc;
    assign debug_led[1] = ^ID_instr;
    assign debug_led[2] = ^WB_data;
    assign debug_led[3] = ^lsu_load_result;

endmodule
