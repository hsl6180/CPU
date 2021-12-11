`include "lib/defines.vh"
module ID(
    input wire clk,
    input wire rst,
    // input wire flush,
    input wire [`StallBus-1:0] stall,
    
    output wire stallreq_from_id,

    input wire [`IF_TO_ID_WD-1:0] if_to_id_bus,

    input wire [31:0] inst_sram_rdata,

    input wire [`WB_TO_RF_WD-1:0] wb_to_rf_bus,

    output wire [`ID_TO_EX_WD-1:0] id_to_ex_bus,

    output wire [`BR_WD-1:0] br_bus,
    ////新增
    input wire [`EX_TO_ID_WD-1:0] ex_to_id_bus,
    input wire [`MEM_TO_ID_WD-1:0] mem_to_id_bus,
    input wire [`WB_TO_ID_WD-1:0] wb_to_id_bus,
    //12-10
    input wire isLS
);

    reg [`IF_TO_ID_WD-1:0] if_to_id_bus_r;
    //12-9
    //reg delayslot;//延迟槽
    
    wire [31:0] inst;
    wire [31:0] id_pc;
    wire ce;

    wire wb_rf_we;
    wire [4:0] wb_rf_waddr;
    wire [31:0] wb_rf_wdata;
    //新增
    wire ex_id_wreg;
    wire [4:0] ex_id_waddr;
    wire [31:0] ex_id_wdata;
    
    wire mem_id_wreg;
    wire [4:0] mem_id_waddr;
    wire [31:0] mem_id_wdata;
    
    wire wb_id_wreg;
    wire [4:0] wb_id_waddr;
    wire [31:0] wb_id_wdata;
    
    //
    always @ (posedge clk) begin
        if (rst) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;        
        end
        // else if (flush) begin
        //     ic_to_id_bus <= `IC_TO_ID_WD'b0;
        // end
        else if (stall[1]==`Stop && stall[2]==`NoStop) begin
            if_to_id_bus_r <= `IF_TO_ID_WD'b0;
        end
        else if (stall[1]==`NoStop) begin
            if_to_id_bus_r <= if_to_id_bus;
        end
    end
    
    //12-10
    reg stop;
    always @ (posedge clk) begin
        if(rst) begin
            stop<=1'b0;
        end else if(stall[2]==`Stop)begin
            stop<=1'b1;
        end else begin
            stop<=1'b0;
        end
    end
    assign stallreq_from_id=(isLS&((rs==ex_id_waddr)|(rt==ex_id_waddr)));
    assign inst = stop?inst:inst_sram_rdata;
    
    assign {
        ce,
        id_pc
    } = if_to_id_bus_r;
    assign {
        wb_rf_we,
        wb_rf_waddr,
        wb_rf_wdata
    } = wb_to_rf_bus;
    //新增
    assign {
        ex_id_wreg,
        ex_id_waddr,
        ex_id_wdata
    }=ex_to_id_bus;
    assign {
        mem_id_wreg,
        mem_id_waddr,
        mem_id_wdata
    }=mem_to_id_bus;
   
    assign {
        wb_id_wreg,
        wb_id_waddr,
        wb_id_wdata
    }=wb_to_id_bus;
    
    //

    wire [5:0] opcode;
    wire [4:0] rs,rt,rd,sa;
    wire [5:0] func;
    wire [15:0] imm;
    wire [25:0] instr_index;
    wire [19:0] code;
    wire [4:0] base;
    wire [15:0] offset;
    wire [2:0] sel;

    wire [63:0] op_d, func_d;
    wire [31:0] rs_d, rt_d, rd_d, sa_d;

    wire [2:0] sel_alu_src1;
    wire [3:0] sel_alu_src2;
    wire [11:0] alu_op;

    wire data_ram_en;
    wire [3:0] data_ram_wen;
    
    wire rf_we;
    wire [4:0] rf_waddr;
    wire sel_rf_res;
    wire [2:0] sel_rf_dst;

    wire [31:0] rdata1, rdata2;

    regfile u_regfile(
    	.clk    (clk    ),
        .raddr1 (rs ),
        .rdata1 (rdata1 ),
        .raddr2 (rt ),
        .rdata2 (rdata2 ),
        .we     (wb_rf_we     ),
        .waddr  (wb_rf_waddr  ),
        .wdata  (wb_rf_wdata  ),
        //新增
        .ex_id_wreg  (ex_id_wreg  ),
        .ex_id_waddr (ex_id_waddr ),
        .ex_id_wdata (ex_id_wdata ),
        .mem_id_wreg (mem_id_wreg ),
        .mem_id_waddr(mem_id_waddr),
        .mem_id_wdata(mem_id_wdata),
        .wb_id_wreg  (wb_id_wreg  ),
        .wb_id_waddr (wb_id_waddr ),
        .wb_id_wdata (wb_id_wdata )
    );
    
    //译码
    assign opcode = inst[31:26];//运算操作
    assign rs = inst[25:21];//源寄存器
    assign rt = inst[20:16];//目的寄存器
    assign rd = inst[15:11];
    assign sa = inst[10:6];
    assign func = inst[5:0];
    assign imm = inst[15:0];//立即数
    assign instr_index = inst[25:0];
    assign code = inst[25:6];
    assign base = inst[25:21];
    assign offset = inst[15:0];
    assign sel = inst[2:0];

    wire inst_ori, inst_lui, inst_addiu, inst_beq;
    //新增
    wire inst_and,inst_or,inst_nor,inst_xor;
    wire inst_andi,inst_xori;
    wire inst_sll,inst_sllv,inst_sra,inst_srav,inst_srl,inst_srlv;
    wire inst_subu,inst_slt,inst_sltu;
    //12-10
    wire inst_slti,inst_sltiu;
    wire inst_j,inst_bne;
    
    
    wire inst_jal,inst_jr;
    wire inst_addu;
    wire inst_lw,inst_sw;
    wire inst_movn,inst_movz,inst_mfhi,inst_mflo,inst_mthi,inst_mtlo;

    wire op_add, op_sub, op_slt, op_sltu;
    wire op_and, op_nor, op_or, op_xor;
    wire op_sll, op_srl, op_sra, op_lui;
    

    decoder_6_64 u0_decoder_6_64(
    	.in  (opcode  ),
        .out (op_d )
    );

    decoder_6_64 u1_decoder_6_64(
    	.in  (func  ),
        .out (func_d )
    );
    
    decoder_5_32 u0_decoder_5_32(
    	.in  (rs  ),
        .out (rs_d )
    );

    decoder_5_32 u1_decoder_5_32(
    	.in  (rt  ),
        .out (rt_d )
    );

    
    assign inst_ori     = op_d[6'b00_1101];
    assign inst_lui     = op_d[6'b00_1111];
    assign inst_addiu   = op_d[6'b00_1001];
    assign inst_beq     = op_d[6'b00_0100];
    //新增
    assign inst_and     = op_d[6'b00_0000]&(sa==5'b00000)&func_d[6'b10_0100];
    assign inst_or      = op_d[6'b00_0000]&(sa==5'b00000)&func_d[6'b10_0101];
    assign inst_nor     = op_d[6'b00_0000]&(sa==5'b00000)&func_d[6'b10_0111];
    assign inst_xor     = op_d[6'b00_0000]&(sa==5'b00000)&func_d[6'b10_0110];
    
    assign inst_andi    = op_d[6'b00_1100];
    assign inst_xori    = op_d[6'b00_1110];
    
    assign inst_sll     = op_d[6'b00_0000]&rs_d[5'b00000]&func_d[6'b00_0000];
    assign inst_sllv    = op_d[6'b00_0000]&sa==5'b00000&func_d[6'b00_0100];
    assign inst_sra     = op_d[6'b00_0000]&rs_d[5'b00000]&func_d[6'b00_0011];
    assign inst_srav    = op_d[6'b00_0000]&sa==5'b00000&func_d[6'b00_0111];
    assign inst_srl     = op_d[6'b00_0000]&rs_d[5'b00000]&func_d[6'b00_0010];
    assign inst_srlv    = op_d[6'b00_0000]&sa==5'b00000&func_d[6'b00_0110];
    
    assign inst_subu    = op_d[6'b00_0000]&sa==5'b00000&func_d[6'b10_0011];
    assign inst_slt     = op_d[6'b00_0000]&sa==5'b00000&func_d[6'b10_1010];
    assign inst_sltu    = op_d[6'b00_0000]&sa==5'b00000&func_d[6'b10_1011];
    assign inst_slti    = op_d[6'b00_1010];
    assign inst_sltiu   = op_d[6'b00_1011];
    
    assign inst_jal     = op_d[6'b00_0011];
    assign inst_jr      = op_d[6'b00_0000]&inst[20:11]==10'b00000_00000&sa==5'b00000&func_d[6'b00_1000];
    assign inst_bne     = op_d[6'b00_0101];
    assign inst_j       = op_d[6'b00_0010];
    
    assign inst_addu    = op_d[6'b00_0000]&sa==5'b00000&func_d[6'b10_0001];
    assign inst_lw      = op_d[6'b10_0011];
    assign inst_sw      = op_d[6'b10_1011];
    
    assign inst_movn    = op_d[6'b00_0000]&sa==5'b00000&func_d[6'b00_1011];
    assign inst_movz    = op_d[6'b00_0000]&sa==5'b00000&func_d[6'b00_1010];
    assign inst_mfhi    = op_d[6'b00_0000]&inst[25:16]==10'b00000_00000&sa==5'b00000&func_d[6'b01_0000];
    assign inst_mflo    = op_d[6'b00_0000]&inst[25:16]==10'b00000_00000&sa==5'b00000&func_d[6'b00_0010];
    assign inst_mthi    = op_d[6'b00_0000]&inst[20:11]==10'b00000_00000&sa==5'b00000&func_d[6'b01_0001];
    assign inst_mtlo    = op_d[6'b00_0000]&inst[20:11]==10'b00000_00000&sa==5'b00000&func_d[6'b01_0011];
    
    // rs to reg1
    assign sel_alu_src1[0] = inst_srlv | inst_srav | inst_sllv |
                              inst_xori | inst_ori | inst_addiu | inst_subu | 
                              inst_andi | inst_and | inst_slt | 
                              inst_sltu | inst_nor | inst_xor | inst_or|
                              inst_addu | inst_lw | inst_sw |inst_slti|
                              inst_sltiu;

    // pc to reg1
    assign sel_alu_src1[1] = inst_jal;

    // sa_zero_extend to reg1
    assign sel_alu_src1[2] = inst_sll | inst_srl | inst_sra;

    
    // rt to reg2
    assign sel_alu_src2[0] = inst_srlv | inst_srav | inst_sllv | inst_subu | 
                              inst_and | inst_slt | inst_sltu | inst_nor | inst_xor | 
                              inst_sll | inst_srl | inst_sra | inst_or | inst_addu;
    
    // imm_sign_extend to reg2
    assign sel_alu_src2[1] = inst_lui | inst_addiu | inst_lw |inst_sw|inst_slti|
                              inst_sltiu;

    // 32'b8 to reg2
    assign sel_alu_src2[2] = inst_jal;

    // imm_zero_extend to reg2
    assign sel_alu_src2[3] = inst_xori | inst_ori | inst_andi;



    assign op_add = inst_addiu | inst_jal|inst_addu|inst_lw|inst_sw;
    assign op_sub = inst_subu;
    assign op_slt = inst_slt|inst_slti;
    assign op_sltu = inst_sltu|inst_sltiu;
    assign op_and = inst_andi | inst_and;
    assign op_nor = inst_nor;
    assign op_or = inst_ori | inst_or;
    assign op_xor = inst_xor | inst_xori;
    assign op_sll = inst_sll | inst_sllv;
    assign op_srl = inst_srl | inst_srlv;
    assign op_sra = inst_sra | inst_srav;
    assign op_lui = inst_lui;

    assign alu_op = {op_add, op_sub, op_slt, op_sltu,
                     op_and, op_nor, op_or, op_xor,
                     op_sll, op_srl, op_sra, op_lui};



    // load and store enable
    assign data_ram_en = inst_lw|inst_sw;
    //12-9
    assign stallreq_from_id= isLS;
    // write enable
    assign data_ram_wen = inst_sw?4'b1111:4'b0000;

    // regfile store enable
    assign rf_we = inst_srlv | inst_srav | inst_sllv | inst_xori | 
                    inst_or | inst_ori | inst_lui | inst_addiu | inst_subu | 
                    inst_andi | inst_and | inst_slt | inst_sltu | inst_nor | 
                    inst_xor | inst_sll | inst_srl | inst_sra | inst_jal|
                    inst_addu|inst_lw|inst_slti|inst_sltiu;

    // store in [rd]
    assign sel_rf_dst[0] = inst_srlv | inst_srav | inst_sllv | inst_subu | 
                            inst_and | inst_slt | inst_sltu | inst_nor | inst_xor | 
                            inst_sll | inst_srl | inst_sra|inst_addu|inst_or;
    // store in [rt] 
    assign sel_rf_dst[1] = inst_xori | inst_ori | inst_lui | inst_addiu | inst_andi 
                            | inst_lw|inst_slti|inst_sltiu;
    // store in [31]
    assign sel_rf_dst[2] = inst_jal;

    // sel for regfile address 可以选出rd或者rt
    assign rf_waddr = {5{sel_rf_dst[0]}} & rd 
                    | {5{sel_rf_dst[1]}} & rt
                    | {5{sel_rf_dst[2]}} & 32'd31;

    // 0 from alu_res ; 1 from ld_res
    assign sel_rf_res = inst_lw; 

    assign id_to_ex_bus = {
        id_pc,          // 158:127
        inst,           // 126:95
        alu_op,         // 94:83
        sel_alu_src1,   // 82:80
        sel_alu_src2,   // 79:76
        data_ram_en,    // 75
        data_ram_wen,   // 74:71
        rf_we,          // 70
        rf_waddr,       // 69:65
        sel_rf_res,     // 64
        rdata1,         // 63:32
        rdata2          // 31:0
    };


    wire br_e;
    wire [31:0] br_addr;
    wire rs_eq_rt;
    wire rs_ge_z;
    wire rs_gt_z;
    wire rs_le_z;
    wire rs_lt_z;
    wire [31:0] pc_plus_4;
    
    assign pc_plus_4 = id_pc + 32'h4;
        
    assign rs_eq_rt = (rdata1 == rdata2);

    assign br_e = (inst_beq & rs_eq_rt) | (inst_bne&~rs_eq_rt) | inst_jal|inst_jr|inst_j;
    assign br_addr = inst_beq ? (pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}) : 
                      inst_bne?(pc_plus_4 + {{14{inst[15]}},inst[15:0],2'b0}):
                      inst_jal?({pc_plus_4[31:28],inst[25:0],2'b0}):
                      inst_jr?(rdata1):
                      inst_j?({pc_plus_4[31:28],inst[25:0],2'b0}):
                      32'b0;

    assign br_bus = {
        br_e,
        br_addr
    };
    

endmodule