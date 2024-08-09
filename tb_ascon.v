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

    reg  [31:0] key_in;
    reg         key_valid;
    wire        key_ready;
    reg  [31:0] nonce_in;
    reg         nonce_valid;
    wire        nonce_ready;
    reg  [31:0] assoc_in;
    reg         assoc_valid;
    wire        assoc_ready;
    reg  [31:0] data_in;
    reg         data_in_valid;
    reg         data_in_last;
    wire        data_in_ready;
    wire [31:0] data_out;        
    wire        data_out_valid;
    wire        data_out_last;
    wire [127:0] tag;
    wire        tag_valid;

    // Use named parameters because there are so many <.<
    ascon ascon_ip(
        .clk(clk),
        .rst(rst),
        .mode(mode),
        .key_in(key_in),
        .key_valid(key_valid),
        .key_ready(key_ready),
        .nonce_in(nonce_in),
        .nonce_valid(nonce_valid),
        .nonce_ready(nonce_ready),
        .assoc_in(assoc_in),
        .assoc_valid(assoc_valid),
        .assoc_ready(assoc_ready),
        .data_in(data_in),
        .data_in_valid(data_in_valid),
        .data_in_last(data_in_last),
        .data_in_ready(data_in_ready),
        .data_out(data_out),
        .data_out_valid(data_out_valid),
        .data_out_last(data_out_last),
        .tag(tag),
        .tag_valid(tag_valid)
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
        key_in = 0;
        key_valid = 0;
        nonce_in = 0;
        nonce_valid = 0;
        assoc_in = 0;
        assoc_valid = 0;
        data_in = 0;
        data_in_valid = 0;
        data_in_last = 0;

        #15
        key_valid = 1;
        #10
        // wait for key ready
        #10
        key_in = 32'h0;
        #10
        key_in = 32'h0;
        #10
        key_in = 32'h0;
        #10
        key_in = 32'h0;
        #10
        key_in = 0;
        key_valid = 0;
        nonce_valid = 1;
        nonce_in = 'h0;
        #10
        // wait for nonce ready
        #10
        nonce_in = 'h0;
        #10
        nonce_in = 'h0;
        #10
        nonce_in = 'h0;
        #10
        nonce_valid = 0;
        nonce_in = 0;
        #130
        assoc_in = 'h0;
        assoc_valid = 1;
        #20
        assoc_valid = 0;
        #50
        data_in_valid = 1;
        data_in = 'h6e000000;
        #70
        data_in = 'h6173636f;
        data_in_last = 1;
    end
endmodule