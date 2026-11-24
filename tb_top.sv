`timescale 1ns/1ps

module tb_top;

    //=========================================================
    // PARAMETERS
    //=========================================================

    parameter DATA_WIDTH = 8;
    parameter ADDR_WIDTH = 4;
    parameter DEPTH = 1 << ADDR_WIDTH;

    //=========================================================
    // CLOCK AND RESET SIGNALS
    //=========================================================

    reg wclk = 0;
    reg rclk = 0;

    reg wrst_n = 0;
    reg rrst_n = 0;

    //=========================================================
    // FIFO INPUTS
    //=========================================================

    reg winc = 0;
    reg rinc = 0;

    reg [DATA_WIDTH-1:0] wdata = 0;

    //=========================================================
    // FIFO OUTPUTS
    //=========================================================

    wire [DATA_WIDTH-1:0] rdata;
    wire wfull;
    wire rempty;

    //=========================================================
    // SCOREBOARD
    //=========================================================

    reg [DATA_WIDTH-1:0] expected_q[$];

    reg [DATA_WIDTH-1:0] received_data;

    integer errors = 0;
    integer writes = 0;
    integer reads = 0;
    integer overflow_count = 0;
    integer underflow_count = 0;

    //=========================================================
    // DUT INSTANTIATION
    //=========================================================

    async_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .wclk   (wclk),
        .wrst_n (wrst_n),
        .winc   (winc),
        .wdata  (wdata),
        .wfull  (wfull),

        .rclk   (rclk),
        .rrst_n (rrst_n),
        .rinc   (rinc),
        .rdata  (rdata),
        .rempty (rempty)
    );

    //=========================================================
    // INDEPENDENT CLOCK GENERATORS
    //=========================================================

    always #5 wclk = ~wclk;   // 10 ns period

    always #7 rclk = ~rclk;   // 14 ns period

    //=========================================================
    // RESET TASK
    //=========================================================

    task automatic apply_reset;

        begin

            wrst_n = 0;
            rrst_n = 0;

            winc = 0;
            rinc = 0;

            expected_q.delete();

            repeat (4) @(posedge wclk);
            repeat (4) @(posedge rclk);

            @(negedge wclk);
            wrst_n = 1;

            @(negedge rclk);
            rrst_n = 1;

            repeat (3) @(posedge wclk);
            repeat (3) @(posedge rclk);

            $display("%0t RESET COMPLETED", $time);

            if (wfull !== 0 || rempty !== 1) begin
                errors = errors + 1;
                $error("RESET CHECK FAILED");
            end
            else begin
                $display("RESET CHECK PASSED");
            end

        end

    endtask

    //=========================================================
    // WRITE TASK
    //=========================================================

    task automatic write_data(input reg [DATA_WIDTH-1:0] data);

        reg accepted;

        begin

            @(negedge wclk);

            winc = 1;
            wdata = data;

            @(posedge wclk);

            // Sample the flag before the DUT's NBA updates.

            accepted = !wfull;

            if (accepted) begin

                expected_q.push_back(data);
                writes = writes + 1;

            end
            else begin

                overflow_count = overflow_count + 1;

                $display("%0t WRITE BLOCKED: FIFO FULL", $time);

            end

            @(negedge wclk);

            winc = 0;

        end

    endtask

    //=========================================================
    // READ TASK
    //=========================================================

    task automatic read_data;

        reg accepted;

        begin

            @(negedge rclk);

            rinc = 1;

            @(posedge rclk);

            // Sample before the DUT updates the read pointer.

            accepted = !rempty;

            if (accepted) begin

                received_data = rdata;

                if (expected_q.size() == 0) begin

                    errors = errors + 1;

                    $error("SCOREBOARD ERROR: Unexpected FIFO data");

                end
                else begin

                    if (received_data !== expected_q[0]) begin

                        errors = errors + 1;

                        $error(
                            "DATA MISMATCH: Expected=%0h Received=%0h",
                            expected_q[0], received_data
                        );

                    end
                    else begin

                        $display(
                            "%0t READ SUCCESS: Data=%0h",
                            $time, received_data
                        );

                    end

                    expected_q.pop_front();

                end

                reads = reads + 1;

            end
            else begin

                underflow_count = underflow_count + 1;

                $display("%0t READ BLOCKED: FIFO EMPTY", $time);

            end

            @(negedge rclk);

            rinc = 0;

        end

    endtask

    //=========================================================
    // MAIN TEST SEQUENCE
    //=========================================================

    integer i;

    initial begin

        $dumpfile("async_fifo.vcd");
        $dumpvars(0, tb_top);

        $display("\n==================================");
        $display(" ASYNCHRONOUS FIFO VERIFICATION");
        $display("==================================");

        //=====================================================
        // T1: RESET
        //=====================================================

        $display("\nT1: RESET TEST");

        apply_reset();

        //=====================================================
        // T2: BASIC WRITE AND READ
        //=====================================================

        $display("\nT2: BASIC WRITE AND READ");

        write_data(8'h11);
        write_data(8'h22);
        write_data(8'h33);
        write_data(8'h44);

        repeat (4) @(posedge rclk);

        read_data();
        read_data();
        read_data();
        read_data();

        repeat (4) @(posedge wclk);

        if (rempty !== 1) begin
            errors = errors + 1;
            $error("FIFO SHOULD BE EMPTY");
        end

        //=====================================================
        // T3: BACK-TO-BACK WRITES
        //=====================================================

        $display("\nT3: BACK-TO-BACK WRITE TEST");

        for (i = 0; i < 8; i = i + 1)
            write_data(i + 8'h50);

        repeat (4) @(posedge rclk);

        for (i = 0; i < 8; i = i + 1)
            read_data();

        repeat (4) @(posedge wclk);

        //=====================================================
        // T4: FIFO FULL TEST
        //=====================================================

        $display("\nT4: FIFO FULL TEST");

        for (i = 0; i < DEPTH; i = i + 1)
            write_data(i + 8'h80);

        if (wfull !== 1) begin

            errors = errors + 1;
            $error("FULL FLAG NOT ASSERTED");

        end
        else begin

            $display("FULL FLAG CHECK PASSED");

        end

        //=====================================================
        // T5: OVERFLOW PROTECTION
        //=====================================================

        $display("\nT5: OVERFLOW PROTECTION TEST");

        for (i = 0; i < 5; i = i + 1)
            write_data(8'hAA);

        if (expected_q.size() != DEPTH) begin

            errors = errors + 1;
            $error("FIFO OVERFLOW PROTECTION FAILED");

        end
        else begin

            $display("OVERFLOW PROTECTION PASSED");

        end

        //=====================================================
        // T6: READ ALL DATA AND CHECK FIFO ORDER
        //=====================================================

        $display("\nT6: FIFO ORDERING TEST");

        repeat (4) @(posedge rclk);

        for (i = 0; i < DEPTH; i = i + 1)
            read_data();

        repeat (4) @(posedge wclk);

        //=====================================================
        // T7: UNDERFLOW PROTECTION
        //=====================================================

        $display("\nT7: UNDERFLOW PROTECTION TEST");

        for (i = 0; i < 5; i = i + 1)
            read_data();

        if (rempty !== 1) begin

            errors = errors + 1;
            $error("EMPTY FLAG NOT ASSERTED");

        end
        else begin

            $display("UNDERFLOW PROTECTION PASSED");

        end

        //=====================================================
        // T8: RANDOM DATA TEST
        //=====================================================

        $display("\nT8: RANDOM DATA TEST");

        for (i = 0; i < 12; i = i + 1)
            write_data($urandom);

        repeat (4) @(posedge rclk);

        for (i = 0; i < 12; i = i + 1)
            read_data();

        repeat (4) @(posedge wclk);

        //=====================================================
        // T9: RESET DURING OPERATION
        //=====================================================

        $display("\nT9: RESET DURING OPERATION");

        write_data(8'hA1);
        write_data(8'hB2);
        write_data(8'hC3);

        apply_reset();

        if (expected_q.size() != 0) begin

            errors = errors + 1;
            $error("SCOREBOARD RESET FAILED");

        end

        write_data(8'h55);
        write_data(8'h66);

        repeat (4) @(posedge rclk);

        read_data();
        read_data();

        repeat (4) @(posedge wclk);

        //=====================================================
        // FINAL SUMMARY
        //=====================================================

        $display("\n==================================");
        $display("       FIFO TEST SUMMARY");
        $display("==================================");

        $display("Accepted Writes  : %0d", writes);
        $display("Accepted Reads   : %0d", reads);
        $display("Overflow Attempts: %0d", overflow_count);
        $display("Underflow Attempts: %0d", underflow_count);
        $display("Pending Data     : %0d", expected_q.size());
        $display("Total Errors     : %0d", errors);

        if (errors == 0 && expected_q.size() == 0)
            $display("\n*** TEST PASSED ***");
        else
            $display("\n*** TEST FAILED ***");

        $display("==================================\n");

        #20;
        $finish;

    end

endmodule
