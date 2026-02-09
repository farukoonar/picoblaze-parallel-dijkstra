`timescale 1ns / 1ps

module system_top (
    // main clock signal for the whole system
    input wire clk,
    // reset signal to restart the processors
    input wire reset
);

    // =========================================================================
    // 1. wires and connection signals
    // =========================================================================

    // --- master picoblaze signals ---
    // these wires connect the master processor to its rom and peripherals
    wire [11:0] m_address;        // address line for program memory
    wire [17:0] m_instruction;    // instruction coming from rom
    wire [7:0]  m_port_id;        // port address (where to write/read)
    wire [7:0]  m_out_port;       // data going out from master
    wire [7:0]  m_in_port;        // data coming into master
    wire        m_write_strobe;   // signal that says "i am writing now"
    wire        m_read_strobe;    // signal that says "i want to read now"
    wire        m_interrupt = 1'b0; // we don't use interrupts here
    wire        m_sleep     = 1'b0; // we don't use sleep mode
    // data coming back from the buffers
    wire [7:0]  m_data_from_buf1;
    wire [7:0]  m_data_from_buf2;

    // --- slave 1 picoblaze signals ---
    // wires for the first worker processor (handles nodes 0-4)
    wire [11:0] s1_address;
    wire [17:0] s1_instruction;
    wire [7:0]  s1_port_id;
    wire [7:0]  s1_out_port;
    wire [7:0]  s1_in_port;
    wire        s1_write_strobe;
    wire        s1_read_strobe;
    wire [7:0]  s1_data_from_buf; // command data from master
    wire [7:0]  s1_data_from_mem; // map data from ram

    // --- slave 2 picoblaze signals ---
    // wires for the second worker processor (handles nodes 5-9)
    wire [11:0] s2_address;
    wire [17:0] s2_instruction;
    wire [7:0]  s2_port_id;
    wire [7:0]  s2_out_port;
    wire [7:0]  s2_in_port;
    wire        s2_write_strobe;
    wire        s2_read_strobe;
    wire [7:0]  s2_data_from_buf;
    wire [7:0]  s2_data_from_mem;

    // --- debug signals ---
    // these are used to peek into the memory to see the results
    wire [7:0] dbg_data;
    reg  [7:0] dbg_addr;

    // =========================================================================
    // 2. processor setup (creating the chips)
    // =========================================================================

    // create the master processor
    // this is the "boss" that controls the algorithm
    kcpsm6 #(
        .interrupt_vector(12'h3FF),
        .scratch_pad_memory_size(64),
        .hwbuild(8'h00)
    ) processor_master (
        .address(m_address),
        .instruction(m_instruction),
        .bram_enable(),
        .port_id(m_port_id),
        .write_strobe(m_write_strobe),
        .k_write_strobe(),
        .out_port(m_out_port),
        .read_strobe(m_read_strobe),
        .in_port(m_in_port),
        .interrupt(m_interrupt),
        .interrupt_ack(),
        .sleep(m_sleep),
        .reset(reset),
        .clk(clk)
    );

    // attach the program code (rom) to the master
    master program_rom_master (
        .enable(1'b1),
        .address(m_address),
        .instruction(m_instruction),
        .clk(clk)
    );

    // create slave 1 processor
    // this worker looks at the first half of the map
    kcpsm6 #(
        .interrupt_vector(12'h3FF),
        .scratch_pad_memory_size(64),
        .hwbuild(8'h00)
    ) processor_slave1 (
        .address(s1_address),
        .instruction(s1_instruction),
        .bram_enable(),
        .port_id(s1_port_id),
        .write_strobe(s1_write_strobe),
        .k_write_strobe(),
        .out_port(s1_out_port),
        .read_strobe(s1_read_strobe),
        .in_port(s1_in_port), // inputs are combined at the bottom
        .interrupt(1'b0),
        .interrupt_ack(),
        .sleep(1'b0),
        .reset(reset),
        .clk(clk)
    );

    // attach the program code to slave 1
    slave1 program_rom_slave1 (
        .enable(1'b1),
        .address(s1_address),
        .instruction(s1_instruction),
        .clk(clk)
    );

    // create slave 2 processor
    // this worker looks at the second half of the map
    kcpsm6 #(
        .interrupt_vector(12'h3FF),
        .scratch_pad_memory_size(64),
        .hwbuild(8'h00)
    ) processor_slave2 (
        .address(s2_address),
        .instruction(s2_instruction),
        .bram_enable(),
        .port_id(s2_port_id),
        .write_strobe(s2_write_strobe),
        .k_write_strobe(),
        .out_port(s2_out_port),
        .read_strobe(s2_read_strobe),
        .in_port(s2_in_port), // inputs are combined at the bottom
        .interrupt(1'b0),
        .interrupt_ack(),
        .sleep(1'b0),
        .reset(reset),
        .clk(clk)
    );

    // attach the program code to slave 2
    slave2 program_rom_slave2 (
        .enable(1'b1),
        .address(s2_address),
        .instruction(s2_instruction),
        .clk(clk)
    );

    // =========================================================================
    // 3. communication modules 
    // =========================================================================

    // this buffer sits between master and slave 1
    // master puts commands here, slave 1 reads them
    // slave_id is 0 because this is for the first slave
    comm_buffer #(.SLAVE_ID(4'h0)) buffer_inst_1 (
        .clk(clk),
        .reset(reset),
        // master connections
        .m_data_out(m_out_port),
        .m_port_id(m_port_id),
        .m_write_strobe(m_write_strobe),
        .m_data_in(m_data_from_buf1),
        // slave connections
        .s_data_out(s1_out_port),
        .s_port_id(s1_port_id),
        .s_write_strobe(s1_write_strobe),
        .s_data_in(s1_data_from_buf)
    );

    // this buffer sits between master and slave 2
    // slave_id is 1 because this is for the second slave
    comm_buffer #(.SLAVE_ID(4'h1)) buffer_inst_2 (
        .clk(clk),
        .reset(reset),
        // master connections
        .m_data_out(m_out_port),
        .m_port_id(m_port_id),
        .m_write_strobe(m_write_strobe),
        .m_data_in(m_data_from_buf2),
        // slave connections
        .s_data_out(s2_out_port),
        .s_port_id(s2_port_id),
        .s_write_strobe(s2_write_strobe),
        .s_data_in(s2_data_from_buf)
    );

    // this is the main memory (ram) where the map is stored
    // both slaves are connected to this memory
    shared_memory main_ram (
        .clk(clk),

        // slave 1 connection (port a)
        .s1_port_id(s1_port_id),
        .s1_data_out(s1_out_port),
        .s1_write_strobe(s1_write_strobe),
        .s1_read_strobe(s1_read_strobe),
        .s1_data_in(s1_data_from_mem),

        // slave 2 connection (port b)
        .s2_port_id(s2_port_id),
        .s2_data_out(s2_out_port),
        .s2_write_strobe(s2_write_strobe),
        .s2_read_strobe(s2_read_strobe),
        .s2_data_in(s2_data_from_mem),

        // debug port to check results
        .dbg_addr(dbg_addr),
        .dbg_data(dbg_data)
    );

    // =========================================================================
    // 4. combine inputs (using OR logic)
    // =========================================================================
    // picoblaze has only one input port
    // we use OR logic to combine data from buffer and memory
    // this works because the inactive source sends 0
    assign m_in_port  = m_data_from_buf1 | m_data_from_buf2;
    assign s1_in_port = s1_data_from_buf | s1_data_from_mem;
    assign s2_in_port = s2_data_from_buf | s2_data_from_mem;

    // =========================================================================
    // 5. result checker (copies ram to registers)
    // =========================================================================
    // this part is purely for viewing results in simulation
    // it copies distances from ram addresses 100-109 to these registers
    reg [15:0] dist_reg [0:9];
    reg [3:0]  idx;

    integer k;
    always @(posedge clk) begin
        if (reset) begin
            // clear everything on reset
            idx      <= 4'd0;
            dbg_addr <= 8'd100; // start reading from address 100
            for (k=0; k<10; k=k+1)
                dist_reg[k] <= 16'hFFFF; // set initial distance to infinity
            dist_reg[0] <= 16'h0000;     // source is 0
        end else begin
            // read one node's distance in every clock cycle
            if (idx < 10)
                dist_reg[idx] <= {8'h00, dbg_data};

            // loop through nodes 0 to 9 continuously
            if (idx == 9) begin
                idx      <= 0;
                dbg_addr <= 8'd100;
            end else begin
                idx      <= idx + 1;
                dbg_addr <= 8'd100 + (idx + 1);
            end
        end
    end

endmodule