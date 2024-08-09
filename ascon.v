`include "perm.v" 

`define X_SIZE 64 
// We cannot use the full 64 bits, because we want to use
// the GPIO pins and only have 64. We need to fit
// the data and control signals into those,
// => 32 bits + control bits < 64 bits
`define INPUT_LENGTH 32
`define MODE_DEC 0
`define MODE_ENC 1
// data types
`define TYPE_EMPTY  0
`define TYPE_PLAIN  1
`define TYPE_CIPHER 2

`define x4 ascon_state[(`X_SIZE - 1) : 0]
`define x3 ascon_state[((`X_SIZE * 2) - 1) : `X_SIZE]
`define x2 ascon_state[((`X_SIZE * 3) - 1) : ((`X_SIZE * 2))]
`define x1 ascon_state[((`X_SIZE * 4) - 1) : ((`X_SIZE * 3))]
`define x0 ascon_state[((`X_SIZE * 5) - 1) : ((`X_SIZE * 4))]

`define state_r ascon_state[319:(319 - 64)]
`define state_c ascon_state[(319 - 64):0]

module ascon(
        input          clk,
        input          rst,
        input          mode,
        // TODO: convert 31 to `INPUT_LENGTH - 1
        input wire [31:0] key_in,
        input wire        key_valid,
        output reg        key_ready      = 0,
        input wire [31:0] nonce_in,
        input wire        nonce_valid,
        output reg        nonce_ready    = 0,
        input wire [31:0] assoc_in,
        input wire        assoc_valid,
        output reg        assoc_ready    = 0,
        input wire [31:0] data_in,
        input wire  [1:0] data_in_type,
        input wire        data_in_valid,
        input wire        data_in_last,
        output reg        data_in_ready  = 0,
        output reg [31:0] data_out       = 0,        
        output reg  [1:0] data_out_type  = 0,
        output reg        data_out_valid = 0,
        output reg        data_out_last  = 0,
        output reg [127:0] tag           = 0,
        output reg        tag_valid      = 0

    );

    // ascon parameters
    // a = 12
    // b = 6
    // k = 128
    // r = 64
    localparam ROUNDS_A = 11;
    localparam ROUNDS_B = 5;
    localparam KEY_LENGTH = 128;
    localparam DATA_LENGTH = 64;
    // IV = k || r || a || b
    localparam IV = 'h80400c06;

    // state machine
    localparam STATE_WAIT          = 0;
    localparam STATE_READ_KEY      = 1;
    localparam STATE_READ_NONCE    = 2;
    localparam STATE_INIT          = 3;
    localparam STATE_PROCESS_ASSOC = 4;
    localparam STATE_PROCESS_TEXT  = 5;
    localparam STATE_FINAL         = 6;

    reg [3:0] state_machine;
    reg [3:0] next_state;


    reg [319:0] ascon_state;
    reg [127:0] ascon_key;
    reg   [2:0] input_count;
    reg   [7:0] rounds;
    reg         is_last;

    wire [7:0] c_r = (8'hf0 - ((8'd11 - rounds) * 8'h10) + (8'd11 - rounds));

    wire [63:0] x0_p;
    wire [63:0] x1_p;
    wire [63:0] x2_p;
    wire [63:0] x3_p;
    wire [63:0] x4_p;

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

    initial begin
        state_machine <= STATE_WAIT;
        next_state <= STATE_WAIT;
        ascon_state <= 0;
        rounds <= 0;
        ascon_key <= 0;
        input_count <= 0;
        is_last <= 0;
    end

    // We also need to differentiate between different states in states.
    // But we will not the state machine for this, because this is too complicated
    wire dist_wait           = state_machine == STATE_WAIT;
    wire dist_wait_finish    = dist_wait & key_valid;
    wire dist_read_key       = (state_machine == STATE_READ_KEY) & key_valid & key_ready & input_count < 4;
    // Do not use state_machine == ..., this can fail as key_valid might not be set!
    // We need to reuse the previous dist_read_key
    wire dist_read_key_last   = dist_read_key & (input_count == 3);
    wire dist_read_nonce      = (state_machine == STATE_READ_NONCE) & nonce_valid & nonce_ready & input_count < 4;
    wire dist_read_nonce_last = dist_read_nonce & (input_count == 3);
    wire dist_init            = (state_machine == STATE_INIT) & rounds != 0;
    wire dist_init_add_key    = (state_machine == STATE_INIT) & rounds == 0;
    wire dist_assoc           = state_machine == STATE_PROCESS_ASSOC;
    wire dist_assoc_read      = dist_assoc & assoc_ready & assoc_valid & rounds == 0;
    wire dist_assoc_perm      = dist_assoc & rounds != 0;
    wire dist_assoc_finished  = dist_assoc & !assoc_ready & !assoc_valid & rounds == 0;
    wire dist_text            = state_machine == STATE_PROCESS_TEXT;
    wire dist_text_read       = dist_text & (data_in_type == `TYPE_PLAIN || data_in_type == `TYPE_CIPHER) & data_in_valid & data_in_ready & rounds == 0;
    wire dist_text_perm       = dist_text & rounds != 0;
    wire dist_final           = state_machine == STATE_FINAL;
    wire dist_final_perm      = dist_final & rounds != 0;
    wire dist_final_tag       = dist_final & rounds == 0; 

    // state machine transitions
    always @(posedge clk)
    begin
        // We need to assign the current state
        // because we want to stay in the current state
        // if nothing happens/we aren't finished with the current state.
        next_state = state_machine;
        if (dist_final_tag)
        begin
            next_state = STATE_WAIT;
        end
        if (dist_text_perm & is_last)
        begin
            next_state = STATE_FINAL;
        end
        if (dist_assoc_finished)
        begin
            next_state = STATE_PROCESS_TEXT;
        end
        if (dist_init_add_key)
        begin
            next_state = STATE_PROCESS_ASSOC;
        end
        if (dist_read_nonce_last)
        begin
            next_state = STATE_INIT;
        end
        if (dist_read_key_last)
        begin
            next_state = STATE_READ_NONCE;
        end
        if (dist_wait_finish)
        begin
            next_state = STATE_READ_KEY;
        end
    end

    // apply next state in case we are not resetting
    always @(posedge clk)
    begin
        if (rst)
        begin   
            state_machine <= STATE_WAIT;
        end else begin
            state_machine <= next_state;
        end
    end

    // update rounds and counter
    always @(posedge clk)
    begin
        if (dist_read_key | dist_read_nonce)
        begin
            input_count <= input_count + 1;
        end
        if (dist_read_key_last | dist_read_nonce_last)
        begin
            input_count <= 0;
        end
        if (dist_assoc_read | dist_text_read)
        begin
            rounds <= ROUNDS_B;
        end
        if (dist_read_nonce_last | dist_final)
        begin
            rounds <= ROUNDS_A;
        end
        if (dist_init | dist_assoc_perm | (dist_text_perm & !is_last) | dist_final_perm)
        begin
            rounds <= rounds - 1;
        end
    end

    // update ascon stuff (state, nonce or key)
    always @(posedge clk)
    begin
        if (rst != 1)
        begin
            if (dist_text_read)
            begin
                if (mode == `MODE_DEC)
                begin
                    `state_r <= data_in;
                end else begin
                    `state_r <= `state_r ^ data_in;
                end
                is_last <= data_in_last;
            end
            if (dist_assoc_finished)
            begin
                ascon_state <= ascon_state + 1;
            end
            if (dist_assoc_read)
            begin
                `state_r <= `state_r ^ assoc_in;
            end
            if (dist_init_add_key | dist_final)
            begin
                `state_c <= `state_c ^ {256'h0, ascon_key};
            end
            if (dist_init | dist_assoc_perm | dist_text_perm | dist_final_perm)
            begin
                $display("c_r: %x\n", c_r);
                $display("%x\n%x\n%x\n%x\n%x\n", `x0, `x1, `x2, `x3, `x4);
                `x0 <= x0_p;
                `x1 <= x1_p;
                `x2 <= x2_p;
                `x3 <= x3_p;
                `x4 <= x4_p;
            end
            if (dist_read_nonce_last)
            begin
                ascon_state <= (IV << 288) | (ascon_key << 128) | ascon_state; 
            end
            if (dist_read_nonce)
            begin
                ascon_state[(input_count * `INPUT_LENGTH) +: `INPUT_LENGTH] <= nonce_in;
            end
            if (dist_read_key)
            begin
                ascon_key[(input_count * `INPUT_LENGTH) +: `INPUT_LENGTH] <= key_in;
            end
        end
    end

    // output updates
    always @(posedge clk)
    begin
        key_ready = 0;
        nonce_ready = 0;
        assoc_ready = 0;
        data_in_ready = 0;
        data_out = 32'b0;
        data_out_type = `TYPE_EMPTY;
        data_out_valid = 0;
        data_out_last = 0;
        tag = 0;
        tag_valid = 0;
        case (state_machine)
            STATE_FINAL:
            begin
                if (dist_final_tag)
                begin
                    tag = ascon_state[127:0] ^ ascon_key;
                    tag_valid = 1;
                end
            end
            STATE_PROCESS_TEXT:
            begin
                data_in_ready = 1;
                if (dist_text_read)
                begin
                    data_in_ready = 0;
                    // I don't want to create another state so we will just 
                    // hack this in here
                    data_out_valid = 1;
                    data_out_last = data_in_last;
                    if (mode == `MODE_DEC)
                    begin
                        data_out_type = `TYPE_PLAIN;
                        data_out = `state_r ^ data_in;
                    end else begin
                        data_out_type = `TYPE_CIPHER;
                        data_out = `state_r ^ data_in;
                    end
                end
                if (dist_text_perm)
                begin
                    data_in_ready = 0;
                end
            end
            STATE_PROCESS_ASSOC:
            begin
                assoc_ready = 1;
                if (dist_assoc_read | dist_assoc_perm)
                begin
                    assoc_ready = 0;
                end
            end
            STATE_READ_KEY:
            begin
                key_ready = 1;
            end
            STATE_READ_NONCE:
            begin
                nonce_ready = 1;
            end
        endcase
    end
endmodule
