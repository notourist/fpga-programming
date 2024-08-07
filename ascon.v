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
        output reg [31:0] tag            = 0,
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
    localparam STATE_PROCESS_ASSOC = 6;
    localparam STATE_PROCESS_PLAIN = 7;
    localparam STATE_FINAL         = 8;

    reg [3:0] state_machine;
    reg [3:0] next_state;


    reg [319:0] ascon_state;
    reg [127:0] ascon_key;
    reg [127:0] ascon_nonce;
    reg   [2:0] count;
    reg   [7:0] rounds;
    
    // TODO: is this correct?
    wire [320:(320-64)] ascon_state_r;
    wire [(320 - 64):0] ascon_state_c;

    wire [63:0] x0 = ascon_state[(`X_SIZE - 1) : 0];
    wire [63:0] x1 = ascon_state[((`X_SIZE * 2) - 1) : `X_SIZE];
    wire [63:0] x2 = ascon_state[((`X_SIZE * 3) - 1) : ((`X_SIZE * 2) - 1)];
    wire [63:0] x3 = ascon_state[((`X_SIZE * 4) - 1) : ((`X_SIZE * 3) - 1)];
    wire [63:0] x4 = ascon_state[((`X_SIZE * 5) - 1) : ((`X_SIZE * 4) - 1)];
    wire [63:0] x0_p;
    wire [63:0] x1_p;
    wire [63:0] x2_p;
    wire [63:0] x3_p;
    wire [63:0] x4_p;

    ascon_p ascon_perm(
        .c_r((8'hf0 - (rounds * 8'h10) + rounds)),
        .x0_in(x0),
        .x1_in(x1),
        .x2_in(x2),
        .x3_in(x3),
        .x4_in(x4),
        .x0_out(x0_p),
        .x1_out(x1_p),
        .x2_out(x2_p),
        .x3_out(x3_p),
        .x4_out(x4_p)
    );


    initial begin
        state_machine <= STATE_WAIT;
        ascon_state = 0;
        ascon_key = 0;
        ascon_nonce = 0;
        count = 0;
    end

    // We also need to differentiate between different states in states.
    // But we will not the state machine for this, because this is too complicated
    wire dist_wait           = (state_machine == STATE_WAIT);
    wire dist_wait_finish    = dist_wait & key_valid;
    wire dist_read_key       = (state_machine == STATE_READ_KEY) & key_valid & key_ready;
    // Do not use state_machine == ..., this can fail as key_valid might not be set!
    // We need to reuse the previous dist_read_key
    wire dist_read_key_last   = dist_read_key & (count == 3);
    wire dist_read_nonce      = (state_machine == STATE_READ_NONCE) & nonce_valid & nonce_ready;
    wire dist_read_nonce_last = dist_read_nonce & (count == 3);
    wire dist_init            = (state_machine == STATE_INIT);
    wire dist_init_key        = (state_machine == STATE_INIT) & rounds == 0;

    // state machine transitions
    always @(posedge clk)
    begin
        // We need to assign the current state
        // because we want to stay in the current state
        // if nothing happens/we aren't finished with the current state.
        next_state = state_machine;
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

    // update counters
    always @(posedge clk)
    begin
        if (dist_read_key | dist_read_nonce)
        begin
            count <= count + 1;
        end
        if (dist_read_key_last | dist_read_nonce_last)
        begin
            count <= 0;
        end
        if (dist_read_nonce_last)
        begin
            rounds <= ROUNDS_A;
        end
        if (dist_init)
        begin
            rounds <= rounds - 1;
        end
    end

    // update ascon stuff (state, nonce or key)
    always @(posedge clk)
    begin
        // We also need to check for the reset here <.<
        if (rst != 1)
        begin
            if (dist_init_key)
            begin
                ascon_state <= 'hffff;
            end
            if (dist_read_nonce_last)
            begin
                ascon_state <= (IV << 288) | (ascon_key << 128) | (ascon_nonce); 
            end
            if (dist_read_nonce)
            begin
                ascon_nonce[(count * `INPUT_LENGTH) +: `INPUT_LENGTH] <= nonce_in;
            end
            if (dist_read_key)
            begin
                ascon_key[(count * `INPUT_LENGTH) +: `INPUT_LENGTH] <= key_in;
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
            STATE_READ_KEY:
            begin
                key_ready = 1;
            end
            STATE_READ_NONCE:
            begin
                nonce_ready = 1;
            end
            default: ;
        endcase
    end
endmodule
