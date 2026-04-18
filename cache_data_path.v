`timescale 1ns / 1ps

module cache_datapath (
    input clock, 
    input reset,
    
    // CPU Interface
    input [11:0] cpu_address,
    input [7:0] cpu_data_in,
    output [7:0] cpu_data_out,
    output hit,
    
    // Output to Top Module (New: sending dirty status out)
    output dirty_bit,       
    
    // Control Signals (Coming from FSM)
    input cache_we,         // Write Enable for Cache SRAM
    input mem_to_cache,     // MUX control: 1 = write from Mem, 0 = write from CPU
    input mem_req,          // Request memory access
    input mem_rw,           // 0 = Read Mem, 1 = Write Mem
    
    // Output to FSM
    output mem_ready        // Main memory has finished transaction
);

    // Decoded Address Wires
    wire [1:0] offset;
    wire [2:0] index;
    wire [6:0] tag;
    
    // Internal Cache Wires
    wire [6:0] tag_out;
    wire valid_bit;
    wire [31:0] cache_line_out;      // Full 4-byte line from cache
    wire [31:0] main_memory_block;   // Full 4-byte block from memory
    wire [31:0] cache_write_data;    // Data to write into cache

    // 1. Address Decoding
    assign offset = cpu_address[1:0];
    assign index  = cpu_address[4:2];
    assign tag    = cpu_address[11:5];

    // 2. Hit Logic (Combinational)
    assign hit = (tag == tag_out) && valid_bit;

    // 3. CPU Data Out MUX (Select specific byte from the 32-bit cache line)
    assign cpu_data_out = (offset == 2'b00) ? cache_line_out[7:0]   :
                          (offset == 2'b01) ? cache_line_out[15:8]  :
                          (offset == 2'b10) ? cache_line_out[23:16] :
                                              cache_line_out[31:24] ;

    // 4. Cache Write Data MUX
    assign cache_write_data = mem_to_cache ? main_memory_block :
                              (offset == 2'b00) ? {cache_line_out[31:8], cpu_data_in} :
                              (offset == 2'b01) ? {cache_line_out[31:16], cpu_data_in, cache_line_out[7:0]} :
                              (offset == 2'b10) ? {cache_line_out[31:24], cpu_data_in, cache_line_out[15:0]} :
                                                  {cpu_data_in, cache_line_out[23:0]};

// NEW: Write-Back Address MUX
    wire [11:0] mem_address;
    
    // If Write-Back (mem_rw=1), reconstruct old address: {Old Tag, Index, 2'b00}
    // If Fetch (mem_rw=0), use requested CPU address: {CPU Tag, Index, 2'b00}
    assign mem_address = mem_rw ? {tag_out, index, 2'b00} : {cpu_address[11:2], 2'b00};

    // Sub-module Instantiations
    cache_sram CSRAM (
        .clock(clock),
        .reset(reset),
        .index(index),
        .we(cache_we),
        .mem_to_cache(mem_to_cache),  
        .tag_in(tag),
        .data_in(cache_write_data),
        .tag_out(tag_out),
        .data_out(cache_line_out),
        .valid_out(valid_bit),
        .dirty_out(dirty_bit)         
    );

    main_memory MM (
        .clock(clock),
        .mem_req(mem_req),
        .mem_rw(mem_rw),
        .address(mem_address),       // NEW: Use the MUXed address wire!
        .data_in(cache_line_out),             
        .data_out(main_memory_block),
        .mem_ready(mem_ready)
    );

endmodule


// ==========================================
// Sub-Module: Cache SRAM Array
// ==========================================
module cache_sram(
    input clock,
    input reset,
    input [2:0] index,
    input we,
    input mem_to_cache,            // NEW: Tells SRAM where data is coming from
    input [6:0] tag_in,
    input [31:0] data_in,          // 4-byte block
    output [6:0] tag_out,
    output [31:0] data_out,
    output valid_out,
    output dirty_out               // NEW: Exposes dirty status
);
    // Arrays
    reg [31:0] data_array [0:7]; // 8 lines of 32 bits
    reg [6:0]  tag_array  [0:7];
    reg        valid_array[0:7];
    reg        dirty_array[0:7]; // NEW: Physical storage for the dirty bit
    
    integer i;

    // Synchronous Write
    always @(posedge clock) begin
        if (reset) begin
            for(i = 0; i < 8; i = i + 1) begin
                data_array[i]  <= 32'b0;
                tag_array[i]   <= 7'b0;
                valid_array[i] <= 1'b0;
                dirty_array[i] <= 1'b0; // Wipe dirty bits on reset
            end
        end else if (we) begin
            data_array[index]  <= data_in;
            tag_array[index]   <= tag_in;
            valid_array[index] <= 1'b1;
            
            // NEW: The Dirty Bit Logic
            // If data comes from Memory (mem_to_cache = 1), it's a clean fetch (0).
            // If data comes from CPU (mem_to_cache = 0), it's a dirty write (1).
            dirty_array[index] <= !mem_to_cache; 
        end
    end

    // Asynchronous Read (Continuous Assignment)
    assign data_out  = data_array[index];
    assign tag_out   = tag_array[index];
    assign valid_out = valid_array[index];
    assign dirty_out = dirty_array[index]; // Send it out!

endmodule


// ==========================================
// Sub-Module: Main Memory
// ==========================================
module main_memory(
    input clock,
    input mem_req,
    input mem_rw,          // 0 = Read, 1 = Write
    input [11:0] address,  // Block aligned address
    input [31:0] data_in,
    output reg [31:0] data_out,
    output reg mem_ready
);

    // 1024 blocks of 32 bits (matches 4096 bytes)
    reg [31:0] memory [0:1023]; 
    wire [9:0] block_addr;
    
    assign block_addr = address[11:2]; // Ignore byte offset
    
    integer i;
    initial begin
        for(i = 0; i < 1024; i = i + 1) begin
            memory[i] = 32'h00000000;
        end
    end

    // Simulate simple memory access
    always @(posedge clock) begin
        mem_ready <= 1'b0; // Default state
        
        if (mem_req) begin
            if (mem_rw == 1'b0) begin // Read
                data_out <= memory[block_addr];
            end else begin            // Write
                memory[block_addr] <= data_in;
            end
            mem_ready <= 1'b1; // Signal completion (1 cycle latency for simplicity)
        end
    end

endmodule