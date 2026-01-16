module servo_fsm_unit_anticlockwise (
    input  wire clk,            // 125 MHz
    input  wire rst,            // Active-high reset
    input  wire start_trigger,  // Triggered by protocol_handler
    input  wire [3:0] num_turns,// Number of sweeps
    output reg  pwm_out,
    output reg  busy            
);

    // Timing Constants for 125MHz
    localparam FRAME_COUNT = 2_500_000;   // 20ms frame
    localparam MIN_PULSE   = 62_500;      // 0.5ms (0 degrees)
    
    // Fixed START_PULSE for 170 degrees:
    // Calculation: 62,500 + ((170 * 250,000) / 180) = 298,611
    localparam START_PULSE = 298_611;

    localparam STEP        = 3000;        // Speed of sweep
    localparam ONE_SEC     = 62_500_000;  // Adjusted to 0.5s for faster response

    // FSM States
    localparam ST_IDLE        = 3'b000;
    localparam ST_PAUSE_START = 3'b001; // Initial pause at 170 degrees
    localparam ST_SWEEP_DOWN  = 3'b010; // Sweep toward 0 degrees
    localparam ST_PAUSE_MIN   = 3'b011; // Pause at 0 degrees
    localparam ST_SWEEP_UP    = 3'b100; // Return to 170 degrees
    localparam ST_CHECK       = 3'b101;

    reg [2:0]  state;
    reg [21:0] counter;
    reg [21:0] pulse_width;
    reg [3:0]  current_turn;
    reg [26:0] wait_counter; 

    reg start_reg;
    wire start_edge = (start_trigger && !start_reg);

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_IDLE;
            counter <= 0;
            pulse_width <= START_PULSE; 
            current_turn <= 0;
            pwm_out <= 0;
            busy <= 0;
            start_reg <= 0;
            wait_counter <= 0;
        end else begin
            start_reg <= start_trigger;

            if (counter >= FRAME_COUNT - 1) counter <= 0;
            else counter <= counter + 1;

            pwm_out <= (counter < pulse_width);

            case (state)
                ST_IDLE: begin
                    busy <= 0;
                    current_turn <= 0;
                    pulse_width <= START_PULSE; 
                    if (start_edge && num_turns > 0) begin
                        state <= ST_PAUSE_START;
                        busy <= 1;
                        wait_counter <= 0;
                    end
                end

                ST_PAUSE_START: begin
                    pulse_width <= START_PULSE;
                    if (wait_counter >= ONE_SEC - 1) begin
                        state <= ST_SWEEP_DOWN;
                        wait_counter <= 0;
                    end else begin
                        wait_counter <= wait_counter + 1;
                    end
                end

                ST_SWEEP_DOWN: begin
                    if (counter == 0) begin 
                        if (pulse_width <= MIN_PULSE) begin
                            state <= ST_PAUSE_MIN;
                            wait_counter <= 0;
                        end else begin
                            pulse_width <= pulse_width - STEP;
                        end
                    end
                end

                ST_PAUSE_MIN: begin
                    pulse_width <= MIN_PULSE;
                    if (wait_counter >= ONE_SEC - 1) begin
                        state <= ST_SWEEP_UP;
                        wait_counter <= 0;
                    end else begin
                        wait_counter <= wait_counter + 1;
                    end
                end

                ST_SWEEP_UP: begin
                    if (counter == 0) begin
                        if (pulse_width >= START_PULSE) begin
                            state <= ST_CHECK;
                        end else begin
                            pulse_width <= pulse_width + STEP;
                        end
                    end
                end

                ST_CHECK: begin
                    if (current_turn + 1 >= num_turns) begin
                        state <= ST_IDLE;
                    end else begin
                        current_turn <= current_turn + 1;
                        state <= ST_PAUSE_START; 
                        wait_counter <= 0;
                    end
                end
                
                default: state <= ST_IDLE;
            endcase
        end
    end
endmodule