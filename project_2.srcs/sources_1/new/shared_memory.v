`timescale 1ns / 1ps

module shared_memory (
    input wire clk,

    // --- slave 1 interface (port a) ---
    // slave 1 uses these signals to access memory
    input wire [7:0] s1_port_id,
    input wire [7:0] s1_data_out,
    input wire s1_write_strobe,
    input wire s1_read_strobe,
    output wire [7:0] s1_data_in,

    // --- slave 2 interface (port b) ---
    // slave 2 uses these signals to access memory
    input wire [7:0] s2_port_id,
    input wire [7:0] s2_data_out,
    input wire s2_write_strobe,
    input wire s2_read_strobe,
    output wire [7:0] s2_data_in,

    // --- debug / master read port ---
    // this allows the master or testbench to peek into memory directly
    input  wire [7:0] dbg_addr,
    output wire [7:0] dbg_data
);

    // main memory storage (256 bytes)
    reg [7:0] ram [0:255];

    // address pointers for indirect addressing
    // slaves first set the address here, then read/write data
    reg [7:0] s1_addr_ptr;
    reg [7:0] s2_addr_ptr;

    // =========================================================================
    // 1. write operations (synchronous)
    // =========================================================================

    // --- slave 1 write logic ---
    always @(posedge clk) begin
        // if writing to port f0, update the address pointer
        if (s1_write_strobe && s1_port_id == 8'hF0)
            s1_addr_ptr <= s1_data_out;

        // if writing to port f1, write data to the stored address
        if (s1_write_strobe && s1_port_id == 8'hF1)
            ram[s1_addr_ptr] <= s1_data_out;
    end

    // --- slave 2 write logic ---
    always @(posedge clk) begin
        // if writing to port f0, update the address pointer
        if (s2_write_strobe && s2_port_id == 8'hF0)
            s2_addr_ptr <= s2_data_out;

        // if writing to port f1, write data to the stored address
        if (s2_write_strobe && s2_port_id == 8'hF1)
            ram[s2_addr_ptr] <= s2_data_out;
    end

    // =========================================================================
    // 2. read operations (asynchronous / combinational)
    // =========================================================================

    // fast read logic for slaves
    // if port f2 is selected, output the data at the current pointer address
    // otherwise output 0 (necessary for the OR logic in the top module)
    assign s1_data_in = (s1_port_id == 8'hF2) ? ram[s1_addr_ptr] : 8'h00;
    assign s2_data_in = (s2_port_id == 8'hF2) ? ram[s2_addr_ptr] : 8'h00;

    // debug read output
    // continuously outputs data at the debug address
    assign dbg_data = ram[dbg_addr];

    // =========================================================================
    // 3. initialization
    // =========================================================================
    integer i;
    initial begin
        // fill memory with 0xff (infinity) for dijkstra algorithm
        for (i=0; i<256; i=i+1) ram[i] = 8'hFF;
    end

endmodule