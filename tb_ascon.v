`include "ascon.v"
`timescale 1ns / 1ps

`define assert(signal, value) \
        if (signal !== value) begin \
            $display("ASSERTION FAILED in %m: signal != value"); \
            $finish; \
        end
module tb_ascon();
    reg clk;
    reg rst;
    reg mode;

    reg  [63:0] block_in;
    reg         block_in_valid;
    reg         block_in_last;
    wire        block_in_ready;
    wire [63:0] block_out;        
    wire        block_out_valid;
    wire        block_out_last;

    // Use named parameters because there are so many <.<
    ascon ascon_ip(
        .clk(clk),
        .mode(mode),
        .block_in(block_in),
        .block_in_valid(block_in_valid),
        .block_in_last(block_in_last),
        .block_in_ready(block_in_ready),
        .block_out(block_out),
        .block_out_valid(block_out_valid),
        .block_out_last(block_out_last)
    );

    initial begin
        forever begin
            #5 clk = ~clk;
        end
    end

    initial begin
        clk = 0;
        rst = 0;
        mode = `MODE_ENC;
        block_in = 0;
        block_in_valid = 0;
        block_in_last = 0;

        #25
        block_in_valid = 1;
        #10
        block_in = 64'hD000000DC000000C;
        #10
        block_in = 64'hB000000BA000000A;
        #10
        block_in = 64'h4000000430000003;
        #10
        block_in = 64'h2000000210000001;
        #20
        block_in_valid = 0;
        #140
        block_in = 64'hffff << 48;
        block_in_valid = 1;
        #80
        block_in = 64'h1 << (7 * 8) + 4;
        block_in_last = 1;
    end
endmodule