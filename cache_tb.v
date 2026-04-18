`timescale 1ns / 1ps

module tb_cache_system();

    // --------------------------------------------------------
    // Signals
    // --------------------------------------------------------
    reg clk;
    reg reset;
    reg cpu_req;
    reg cpu_rw; // 0 = Read, 1 = Write
    reg [11:0] cpu_address;
    reg [7:0] cpu_data_in;

    wire [7:0] cpu_data_out;
    wire cpu_ready;
    wire cache_hit;

    // --------------------------------------------------------
    // Instantiate the Top Level DUT (Device Under Test)
    // --------------------------------------------------------
    top_level_cache_system DUT (
        .clk(clk),
        .reset(reset),
        .cpu_req(cpu_req),
        .cpu_rw(cpu_rw),
        .cpu_address(cpu_address),
        .cpu_data_in(cpu_data_in),
        .cpu_data_out(cpu_data_out),
        .cpu_ready(cpu_ready),
        .cache_hit(cache_hit)
    );

    // --------------------------------------------------------
    // Clock Generation (10ns period)
    // --------------------------------------------------------
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    
    
    // --------------------------------------------------------
    // Helper Tasks for Clean Code
    // --------------------------------------------------------
    
    // Task to simulate a CPU Write
    task cpu_write(input [11:0] addr, input [7:0] data);
        reg initial_hit_status; // NEW: Variable to hold the snapshot
        begin
            @(posedge clk);
            cpu_req = 1;
            cpu_rw = 1; // Write
            cpu_address = addr;
            cpu_data_in = data;
            
            // NEW: Wait exactly 1 cycle for FSM to enter COMPARE state
            @(posedge clk);
            initial_hit_status = cache_hit; // Take the snapshot right now!
            
            // Now wait for the FSM to actually finish the job
            wait(cpu_ready == 1'b1);
            @(posedge clk);
            cpu_req = 0; // De-assert after ready
            
            // Print the snapshot, not the final state
            $display("[WRITE] Wrote 0x%h to Address 0x%03h | Initial Cache Hit: %b", data, addr, initial_hit_status);
            #10;
        end
    endtask

    // Task to simulate a CPU Read and Auto-Check the result
    task cpu_read_and_check(input [11:0] addr, input [7:0] expected_data);
        reg initial_hit_status; // NEW: Variable to hold the snapshot
        begin
            @(posedge clk);
            cpu_req = 1;
            cpu_rw = 0; // Read
            cpu_address = addr;
            
            // NEW: Wait exactly 1 cycle for FSM to enter COMPARE state
            @(posedge clk);
            initial_hit_status = cache_hit; // Take the snapshot right now!
            
            wait(cpu_ready == 1'b1);
            @(posedge clk);
            cpu_req = 0; // De-assert after ready
            
            // Self-Checking Logic (Printing the snapshot)
            if (cpu_data_out === expected_data) begin
                $display("[READ ] SUCCESS: Address 0x%03h | Expected: 0x%h | Got: 0x%h | Initial Cache Hit: %b", 
                         addr, expected_data, cpu_data_out, initial_hit_status);
            end else begin
                $display("[ERROR] FAILURE: Address 0x%03h | Expected: 0x%h | Got: 0x%h | Initial Cache Hit: %b", 
                         addr, expected_data, cpu_data_out, initial_hit_status);
            end
            #10;
        end
    endtask

    // --------------------------------------------------------
    // The Main Test Sequence
    // --------------------------------------------------------
    initial begin
        $display("=================================================");
        $display("   STARTING CACHE WRITE-BACK SIMULATION");
        $display("=================================================");

        // 1. Initialize System
        reset = 1;
        cpu_req = 0;
        cpu_rw = 0;
        cpu_address = 0;
        cpu_data_in = 0;
        #20 reset = 0;
        $display("System Reset Complete.\n");

        // -------------------------------------------------------------
        // PHASE 1: Basic Write and Read
        // -------------------------------------------------------------
        $display("--- PHASE 1: Write to 0x000 (Expect Miss) ---");
        // Address 0x000 -> Tag 0, Index 0
        cpu_write(12'h000, 8'hAA); 
        
        $display("--- PHASE 1: Read from 0x000 (Expect Hit) ---");
        cpu_read_and_check(12'h000, 8'hAA);
        $display("");

        // -------------------------------------------------------------
        // PHASE 2: Force an Eviction (The Dirty Bit Test!)
        // -------------------------------------------------------------
        $display("--- PHASE 2: Read from 0x020 (Forces Eviction of 0x000) ---");
        // Address 0x020 -> Tag 1, Index 0 (Collides with 0x000!)
        // Since 0x000 is dirty (we just wrote 0xAA to it), the FSM must trigger
        // the WRITE_BACK state here to save 0xAA to Main Memory before fetching 0x020.
        cpu_read_and_check(12'h020, 8'h00); // Should be default 0x00 from memory
        $display("");

        // -------------------------------------------------------------
        // PHASE 3: Verify the Write-Back Succeeded
        // -------------------------------------------------------------
        $display("--- PHASE 3: Read back 0x000 (Verify Main Memory was updated) ---");
        // We fetch 0x000 again. If Write-Back failed, this will return 0x00.
        // If Write-Back succeeded, it will fetch the 0xAA we saved to memory!
        cpu_read_and_check(12'h000, 8'hAA);
        $display("");

        $display("=================================================");
        $display("   SIMULATION COMPLETE");
        $display("=================================================");
        $finish;
    end

endmodule
