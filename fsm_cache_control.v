
`timescale 1ns / 1ps

module cache_controller_fsm (
    input wire clk,
    input wire reset,
    
    // CPU Interface
    input wire cpu_req,       
    input wire cpu_rw,        // 0 = Read, 1 = Write
    output reg cpu_ready,     
    
    // Cache Datapath Interface
    input wire cache_hit,     
    input wire cache_dirty,   
    output reg cache_we,      
    output reg update_tag,    
    
    // Main Memory Interface
    input wire mem_ready,     
    output reg mem_req,       
    output reg mem_rw         // 0 = Read Mem, 1 = Write Mem
);

    localparam [1:0] 
        IDLE       = 2'b00,
        COMPARE    = 2'b01,
        ALLOCATE   = 2'b10,
        WRITE_BACK = 2'b11;

    reg [1:0] current_state, next_state;

    // State Register
    always @(posedge clk or posedge reset) begin
        if (reset) current_state <= IDLE;
        else       current_state <= next_state;
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state; 
        case (current_state)
            IDLE: if (cpu_req) next_state = COMPARE;
            COMPARE: begin
                if (cache_hit)           next_state = IDLE; 
                else if (cache_dirty)    next_state = WRITE_BACK;
                else                     next_state = ALLOCATE; 
            end
            ALLOCATE:   if (mem_ready) next_state = COMPARE; 
            WRITE_BACK: if (mem_ready) next_state = ALLOCATE; 
            default: next_state = IDLE;
        endcase
    end

    // Output Logic
    always @(*) begin
        cpu_ready  = 1'b0;
        cache_we   = 1'b0;
        update_tag = 1'b0;
        mem_req    = 1'b0;
        mem_rw     = 1'b0;

        case (current_state)
            COMPARE: begin
                if (cache_hit) begin
                    cpu_ready = 1'b1;         
                    if (cpu_rw) begin
                        cache_we = 1'b1;      
                        update_tag = 1'b1;    
                    end
                end
            end
            ALLOCATE: begin
                mem_req = 1'b1;               
                mem_rw  = 1'b0;               
                if (mem_ready) begin
                    cache_we   = 1'b1;        
                    update_tag = 1'b1;        
                end
            end
            WRITE_BACK: begin
                mem_req = 1'b1;               
                mem_rw  = 1'b1;               
            end
        endcase
    end
endmodule

