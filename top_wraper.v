`timescale 1ns / 1ps

module top_level_cache_system (
    input wire clk,
    input wire reset,
    
    // Unified CPU Interface
    input wire cpu_req,           
    input wire cpu_rw,            // 0 = Read, 1 = Write
    input wire [11:0] cpu_address,
    input wire [7:0] cpu_data_in,
    
    output wire [7:0] cpu_data_out,
    output wire cpu_ready,        
    output wire cache_hit         
);

    wire fsm_cache_we;
    wire fsm_update_tag;
    wire fsm_mem_req;
    wire fsm_mem_rw;
    wire mem_ready_signal;
    wire datapath_hit;
    wire mem_to_cache_mux;
    
    // NEW: The real wire that will connect the Datapath's dirty bit to the FSM
    wire real_dirty_bit_signal; 

    assign cache_hit = datapath_hit;
    
    // REMOVED: assign dirty_bit_signal = 1'b0; 
    
    assign mem_to_cache_mux = (fsm_mem_req && !fsm_mem_rw);

    cache_controller_fsm FSM (
        .clk(clk),
        .reset(reset),
        .cpu_req(cpu_req),
        .cpu_rw(cpu_rw),
        .cpu_ready(cpu_ready),
        .cache_hit(datapath_hit),
        .cache_dirty(real_dirty_bit_signal), // NEW: Plugged in the real wire
        .cache_we(fsm_cache_we),
        .update_tag(fsm_update_tag),
        .mem_ready(mem_ready_signal),
        .mem_req(fsm_mem_req),
        .mem_rw(fsm_mem_rw)
    );

    cache_datapath DATAPATH (
        .clock(clk),
        .reset(reset),
        .cpu_address(cpu_address),
        .cpu_data_in(cpu_data_in),
        .cpu_data_out(cpu_data_out),
        .hit(datapath_hit),
        .dirty_bit(real_dirty_bit_signal),   // NEW: Plugged in the real wire
        .cache_we(fsm_cache_we),
        .mem_to_cache(mem_to_cache_mux),
        .mem_req(fsm_mem_req),
        .mem_rw(fsm_mem_rw),
        .mem_ready(mem_ready_signal)
    );

endmodule