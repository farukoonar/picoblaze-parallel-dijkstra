`timescale 1ns / 1ps

module system_top_tb;

    // --- signals ---
    reg clk;
    reg reset;

    // --- unit under test (uut) connection ---
    // connecting the testbench to our main system
    system_top uut (
        .clk(clk),
        .reset(reset)
    );

    // --- clock generation ---
    // creates a 100 mhz clock (10ns period)
    always #5 clk = ~clk;

    // --- ram address helper function ---
    // converts (u, v) coordinates into a linear ram address
    // formula: address = (u * 10) + v
    function [7:0] addr;
        input integer u;
        input integer v;
        begin
            addr = (u * 10) + v;
        end
    endfunction

    // --- test scenario variables ---
    integer i;
    
initial begin
        // --- 1. initial setup ---
        clk = 0;
        reset = 1;
        
        // --- 2. reset the map (clean slate) ---
        // first, set all paths to infinity (ff)
        for (i=0; i<100; i=i+1) uut.main_ram.ram[i] = 8'hFF;

        // set distance to self (diagonals) to 0
        for (i=0; i<10; i=i+1) uut.main_ram.ram[addr(i,i)] = 8'h00;

        // --- 3. load map data (zigzag scenario) ---
        // this is a tricky map designed to make slaves pass data back and forth
        
        // --- paths from node 0 ---
        uut.main_ram.ram[addr(0,1)] = 8'h14; // 0->1 (cost 20)
        uut.main_ram.ram[addr(0,5)] = 8'h05; // 0->5 (cost 5) -> shortcut start
        uut.main_ram.ram[addr(0,9)] = 8'h64; // 0->9 (cost 100) -> trap!

        // --- paths from node 1 ---
        uut.main_ram.ram[addr(1,9)] = 8'h14; // 1->9 (cost 20)

        // --- paths from node 2 ---
        uut.main_ram.ram[addr(2,3)] = 8'h0A; // 2->3 (cost 10)
        uut.main_ram.ram[addr(2,7)] = 8'h05; // 2->7 (cost 5) -> zigzag continues

        // --- paths from node 3 ---
        uut.main_ram.ram[addr(3,4)] = 8'h02; // 3->4 (cost 2)

        // --- paths from node 4 ---
        uut.main_ram.ram[addr(4,9)] = 8'h32; // 4->9 (cost 50)

        // --- paths from node 5 ---
        uut.main_ram.ram[addr(5,2)] = 8'h05; // 5->2 (cost 5) -> zigzag (going back)
        uut.main_ram.ram[addr(5,6)] = 8'h0A; // 5->6 (cost 10)

        // --- paths from node 6 ---
        uut.main_ram.ram[addr(6,7)] = 8'h02; // 6->7 (cost 2)

        // --- paths from node 7 ---
        uut.main_ram.ram[addr(7,8)] = 8'h0A; // 7->8 (cost 10)
        uut.main_ram.ram[addr(7,9)] = 8'h05; // 7->9 (cost 5) -> zigzag final leg

        // --- paths from node 8 ---
        uut.main_ram.ram[addr(8,9)] = 8'h05; // 8->9 (cost 5)

        // --- node 9 (target) ---
        // no outgoing paths

        // --- 4. start simulation ---
        #100;
        reset = 0;
        $display("simulation started... (zigzag test)");
        
        // wait long enough for the algorithm to finish
        // we increased this time to make sure node 9 is reached
        #200000; 
        
        // --- 5. check results ---
        $display("-------------------------------------------");
        $display("--- final results (target node 9) ---");
        $display("-------------------------------------------");
        
        // check key steps in the path
        $display("node 0: %d (expected: 0)",  uut.main_ram.ram[100]);
        $display("node 5: %d (expected: 5)",  uut.main_ram.ram[105]); // step 1
        $display("node 2: %d (expected: 10)", uut.main_ram.ram[102]); // step 2 (5+5)
        $display("node 7: %d (expected: 15)", uut.main_ram.ram[107]); // step 3 (10+5)
        $display("node 9: %d (expected: 20)", uut.main_ram.ram[109]); // step 4 (15+5)
        
        $display("-------------------------------------------");

        if (uut.main_ram.ram[109] == 20) 
            $display(">>> SUCCESS! <<< shortest path (20) found.");
        else if (uut.main_ram.ram[109] == 40)
            $display(">>> WARNING! <<< system chose 'simple path' (40). zigzag failed.");
        else if (uut.main_ram.ram[109] == 100)
            $display(">>> FAILED! <<< system only saw the 'direct path' (100).");
        else
            $display(">>> ERROR! <<< unexpected result: %d", uut.main_ram.ram[109]);

        #200;  // wait a bit for registers to update
        
        $display("---- master register results (dist_reg) ----");
        $display("0->1 : %0d", uut.dist_reg[1]);
        $display("0->2 : %0d", uut.dist_reg[2]);
        $display("0->3 : %0d", uut.dist_reg[3]);
        $display("0->4 : %0d", uut.dist_reg[4]);
        $display("0->5 : %0d", uut.dist_reg[5]);
        $display("0->6 : %0d", uut.dist_reg[6]);
        $display("0->7 : %0d", uut.dist_reg[7]);
        $display("0->8 : %0d", uut.dist_reg[8]);
        $display("0->9 : %0d", uut.dist_reg[9]);

        $finish;
        
    end

endmodule