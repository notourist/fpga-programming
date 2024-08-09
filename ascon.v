`include "perm.v" 

`define BLOCK_LENGTH 64
`define KEY_LENGTH 128
`define STATE_LENGTH (`BLOCK_LENGTH * 5)
`define ROUNDS_A 11
`define ROUNDS_B 5
`define IV 64'h80400c0600000000

`define MODE_DEC 0
`define MODE_ENC 1

`define x4 ascon_state[(`BLOCK_LENGTH - 1) : 0]
`define x3 ascon_state[((`BLOCK_LENGTH * 2) - 1) : `BLOCK_LENGTH]
`define x2 ascon_state[((`BLOCK_LENGTH * 3) - 1) : ((`BLOCK_LENGTH * 2))]
`define x1 ascon_state[((`BLOCK_LENGTH * 4) - 1) : ((`BLOCK_LENGTH * 3))]
`define x0 ascon_state[((`BLOCK_LENGTH * 5) - 1) : ((`BLOCK_LENGTH * 4))]

`define state_r ascon_state[(`STATE_LENGTH - 1):(`STATE_LENGTH - `BLOCK_LENGTH)]
`define state_c ascon_state[(`STATE_LENGTH - 1 - `BLOCK_LENGTH):0]

module ascon(
        input wire                         clk,
        input wire                         mode,
        input wire [(`BLOCK_LENGTH - 1):0] block_in,
        input wire                         block_in_valid,
        input wire                         block_in_last,
        output reg                         block_in_ready,
        output reg [(`BLOCK_LENGTH - 1):0] block_out,        
        output reg                         block_out_valid,
        output reg                         block_out_last,
        input wire                         block_out_ready
    );

    localparam STATE_WAIT           = 0;
    localparam STATE_READ_KEY_NONCE = 1;
    localparam STATE_INIT_PERM      = 2;
    localparam STATE_ADD_KEY        = 3;
    localparam STATE_ASSOC_READ     = 4;
    localparam STATE_ASSOC_PERM     = 5;
    localparam STATE_ASSOC_SEP      = 6;
    localparam STATE_TEXT_READ      = 7;
    localparam STATE_TEXT_PERM      = 8;
    localparam STATE_FINAL_KEY      = 9;
    localparam STATE_FINAL_PERM     = 10;
    localparam STATE_TAG_KEY        = 11;
    localparam STATE_TAG            = 12;

    reg [3:0] state_machine;

    reg  [(`STATE_LENGTH - 1):0] ascon_state;
    reg      [`KEY_LENGTH - 1:0] ascon_key;
    reg                    [2:0] ascon_block_count;
    reg                    [7:0] ascon_rounds;
    reg  [(`BLOCK_LENGTH - 1):0] ascon_partial_state;
    reg                          ascon_last;

    wire                   [7:0]  c_r = 
        (8'hf0 - ((8'd11 - ascon_rounds) * 8'h10) + (8'd11 - ascon_rounds));
    wire [(`BLOCK_LENGTH - 1):0] x0_p;
    wire [(`BLOCK_LENGTH - 1):0] x1_p;
    wire [(`BLOCK_LENGTH - 1):0] x2_p;
    wire [(`BLOCK_LENGTH - 1):0] x3_p;
    wire [(`BLOCK_LENGTH - 1):0] x4_p;

    ascon_p ascon_perm(
        .c_r(c_r),
        .x0_in(`x0),
        .x1_in(`x1),
        .x2_in(`x2),
        .x3_in(`x3),
        .x4_in(`x4),
        .x0_out(x0_p),
        .x1_out(x1_p),
        .x2_out(x2_p),
        .x3_out(x3_p),
        .x4_out(x4_p)
    );

    wire do_work             = state_machine == STATE_WAIT & block_in_valid;
    
    wire read_key_nonce      = state_machine == STATE_READ_KEY_NONCE & block_in_valid & block_in_ready;
    wire read_key_nonce_last = read_key_nonce & ascon_block_count == 0;

    wire init_perm_last      = state_machine == STATE_INIT_PERM & ascon_rounds == 0;

    wire read_text           = state_machine == STATE_TEXT_READ & block_in_valid & block_in_ready;
    wire text_perm_last      = state_machine == STATE_TEXT_PERM & ascon_rounds == 0;

    initial begin
        state_machine <= STATE_WAIT;
        ascon_state <= 0;
        ascon_partial_state <= 0;
        ascon_key <= 0;
        ascon_block_count <= 0;
        ascon_rounds <= 0;
    end

    always @(posedge clk) begin
        state_machine <= state_machine;
        if (text_perm_last)
        begin
            state_machine <= STATE_TEXT_READ;
        end
        if (read_text)
        begin
            if (ascon_last)
            begin
                state_machine <= STATE_FINAL_KEY;
            end else begin
                state_machine <= STATE_TEXT_PERM;
            end
        end
        if (state_machine == STATE_ASSOC_SEP)
        begin
            state_machine <= STATE_TEXT_READ;
        end
        if (state_machine == STATE_ADD_KEY)
        begin
            if (block_in_valid)
            begin
                state_machine <= STATE_ASSOC_READ;
            end else begin
                state_machine <= STATE_ASSOC_SEP;
            end
        end
        if (init_perm_last)
        begin
            state_machine <= STATE_ADD_KEY;
        end
        if (read_key_nonce_last)
        begin
            state_machine <= STATE_INIT_PERM;
        end
        if (do_work)
        begin
            state_machine <= STATE_READ_KEY_NONCE;
        end
    end

    // State updates
    // DO NOT TOUCH ANYTHING BUT THE STATE VARIABLE --->!!!!FUTURE ME!!!<----
    always @(posedge clk) begin
        if (read_text)
        begin
            `state_r <= ascon_partial_state;
        end
        if (state_machine == STATE_ASSOC_SEP)
        begin
            ascon_state <= ascon_state ^ 1;
        end
        if (state_machine == STATE_ADD_KEY)
        begin
            ascon_state <= ascon_state ^ ascon_key;
        end
        if (state_machine == STATE_INIT_PERM | state_machine == STATE_TEXT_PERM)
        begin
            `x0 <= x0_p;
            `x1 <= x1_p;
            `x2 <= x2_p;
            `x3 <= x3_p;
            `x4 <= x4_p;
        end
        if (read_key_nonce)
        begin
            if (ascon_block_count >= 2)
            begin
                ascon_key[`BLOCK_LENGTH * (ascon_block_count - 2) +: `BLOCK_LENGTH] <= ascon_partial_state;
            end
            ascon_state[`BLOCK_LENGTH * ascon_block_count +: `BLOCK_LENGTH] <= ascon_partial_state;
            ascon_block_count <= ascon_block_count - 1;
        end
        if (do_work)
        begin
            ascon_state <= `IV << 256;
            ascon_block_count <= 3;
        end

        // Rounds
        if (state_machine == STATE_INIT_PERM | state_machine == STATE_TEXT_PERM)
        begin
            ascon_rounds <= ascon_rounds - 1;
        end
        if (read_key_nonce_last)
        begin
            ascon_rounds <= `ROUNDS_A;
        end
        if (read_text)
        begin
            ascon_rounds <= `ROUNDS_B;
        end
    end

    always @(posedge clk) begin
        block_in_ready = 0;
        block_out = 0;
        block_out_valid = 0;
        block_out_last = 0;
        if (state_machine == STATE_TEXT_READ)
        begin
            block_in_ready = 1;
            ascon_partial_state = `state_r ^ block_in;
            block_out_valid = 1;
            block_out = ascon_partial_state;
            block_out_last = block_in_last;
            ascon_last = block_in_last;
        end
        if (state_machine == STATE_READ_KEY_NONCE)
        begin
            block_in_ready = 1;
            ascon_partial_state = block_in;
        end
    end
endmodule
