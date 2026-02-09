`timescale 1ns / 1ps

module comm_buffer #(
    // unique id for this buffer
    // 0 for slave 1, 1 for slave 2
    parameter [3:0] SLAVE_ID = 4'h0
)(
    input wire clk,
    input wire reset,
    
    // --- master side connections ---
    // master writes here to send orders
    input wire [7:0] m_data_out,
    input wire [7:0] m_port_id,
    input wire m_write_strobe,
    output reg [7:0] m_data_in,
    
    // --- slave side connections ---
    // slave writes here to send results
    input wire [7:0] s_data_out,
    input wire [7:0] s_port_id,
    input wire s_write_strobe,
    output reg [7:0] s_data_in
);

    // storage registers (the mailbox slots)
    
    // data from master -> slave
    reg [7:0] reg_cmd;      // command (start, find, relax)
    reg [7:0] reg_u;        // current node u
    reg [7:0] reg_dist_l;   // current distance
    
    // data from slave -> master
    reg [7:0] reg_status;   // status (done or busy)
    reg [7:0] reg_res_node; // found node
    reg [7:0] reg_res_dist; // found distance

    // =========================================================================
    // 1. master writing to buffer
    // =========================================================================
    always @(posedge clk) begin
        if (reset) begin
            reg_cmd <= 0; reg_u <= 0; reg_dist_l <= 0;
        end else if (m_write_strobe) begin
            // check if the master is talking to this specific slave
            // we look at the top 4 bits of the address
            // for example: address hex 11 means slave id 1, register 1
            if (m_port_id[7:4] == SLAVE_ID) begin
                case (m_port_id[3:0]) // check the bottom 4 bits for register number
                    4'h1: reg_cmd    <= m_data_out;
                    4'h2: reg_u      <= m_data_out;
                    4'h3: reg_dist_l <= m_data_out;
                endcase
            end
        end
    end

    // =========================================================================
    // 2. slave writing to buffer
    // =========================================================================
    always @(posedge clk) begin
        if (reset) begin
            reg_status <= 0; reg_res_node <= 0; reg_res_dist <= 0;
        end else if (s_write_strobe) begin
            // slave writes its results to these addresses
            case (s_port_id)
                8'h04: reg_status   <= s_data_out;
                8'h05: reg_res_node <= s_data_out;
                8'h06: reg_res_dist <= s_data_out;
            endcase
        end
    end

    // =========================================================================
    // 3. master reading from buffer
    // =========================================================================
    always @(*) begin
        // again, only answer if the master is addressing this slave id
        if (m_port_id[7:4] == SLAVE_ID) begin
            case (m_port_id[3:0])
                4'h4: m_data_in = reg_status;
                4'h5: m_data_in = reg_res_node;
                4'h6: m_data_in = reg_res_dist;
                default: m_data_in = 8'h00;
            endcase
        end else begin
            // if not selected, output 0 so we don't interfere with other buffers
            // this is important for the OR logic in the top module
            m_data_in = 8'h00; 
        end
    end

    // =========================================================================
    // 4. slave reading from buffer
    // =========================================================================
    always @(*) begin
        // slave reads the commands sent by master
        case (s_port_id)
            8'h01: s_data_in = reg_cmd;
            8'h02: s_data_in = reg_u;
            8'h03: s_data_in = reg_dist_l;
            default: s_data_in = 8'h00;
        endcase
    end

endmodule