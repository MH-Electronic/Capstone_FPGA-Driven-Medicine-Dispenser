module uart_rx #(
    parameter integer CLOCK_FREQ = 125_000_000,
    parameter integer BAUD_RATE  = 115_200
)(
    input  wire        clk,
    input  wire        rst,
    input  wire        rx,
    output reg  [7:0]  data_out,
    output reg         data_valid
);
    // Calculate ticks for 16x oversampling
    localparam integer TICKS_16X = CLOCK_FREQ / (BAUD_RATE * 16);

    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;

    reg [1:0]  current_state, next_state;
    reg [31:0] tick_cnt;
    reg [3:0]  sample_cnt; // Counts 0-15 for oversampling
    reg [2:0]  bit_cnt;
    reg [7:0]  shift_reg;
    reg [1:0]  rx_sync;

    // Double-flop to prevent metastability
    always @(posedge clk) begin
        if (rst) rx_sync <= 2'b11;
        else     rx_sync <= {rx_sync[0], rx};
    end
    wire rx_s = rx_sync[1];

    // State Machine
    always @(posedge clk) begin
        if (rst) current_state <= IDLE;
        else     current_state <= next_state;
    end

    // Next State Logic
    wire tick_done = (tick_cnt == TICKS_16X - 1);

    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: begin
                if (rx_s == 1'b0)  next_state = START;                  // Start bit detected
            end

            START: begin
                if (tick_done && sample_cnt == 7 && rx_s == 1'b1)
                    next_state = IDLE;
                else if (tick_done && sample_cnt == 15)
                    next_state = DATA; // Start bit processed
            end

            DATA: begin
                if (tick_done && sample_cnt == 15 && bit_cnt == 7)
                    next_state = STOP; // All data bits received
            end

            STOP: begin
                if (tick_done && sample_cnt == 15)
                    next_state = IDLE; // Stop bit processed
            end
        endcase
    end

    // Output Logic
    always @(posedge clk) begin
        if (rst) begin
            tick_cnt   <= 0;
            sample_cnt <= 0;
            bit_cnt    <= 0;
            shift_reg  <= 8'b00;
            data_valid <= 1'b0;
            data_out   <= 8'b0;
        end else begin
            data_valid <= 1'b0;

            if (tick_cnt < TICKS_16X - 1) begin
                tick_cnt <= tick_cnt + 1;
            end else begin
                tick_cnt <= 0;

                case (current_state)
                    IDLE: begin
                        sample_cnt <= 0;
                        bit_cnt    <= 0;
                    end

                    START: begin
                        if (sample_cnt == 15) sample_cnt <= 0;
                        else                  sample_cnt <= sample_cnt + 1;
                    end
                
                    DATA: begin
                        if (sample_cnt == 7) begin
                            // Sample in the middle of the bit period
                            shift_reg[bit_cnt] <= rx_s;
                        end

                        if (sample_cnt == 15) begin
                            sample_cnt <= 0;
                            if (bit_cnt == 7) bit_cnt <= 0;
                            else              bit_cnt <= bit_cnt + 1;
                        end else begin
                            sample_cnt <= sample_cnt + 1;
                        end
                    end
                
                    STOP: begin
                        if (sample_cnt == 15) begin
                            sample_cnt <= 0;
                            data_out   <= shift_reg;
                            data_valid <= 1'b1;
                        end else begin
                            sample_cnt <= sample_cnt + 1;
                        end
                    end
                endcase
            end
        end
    end

endmodule