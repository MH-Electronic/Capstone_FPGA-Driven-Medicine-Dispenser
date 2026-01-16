module system_top (
    // System
    input  wire         clk, 
    input  wire         rst,
    
    // UART
    input  wire         rx,
    output wire         tx,

    // RFID
    input  wire         miso,
    output wire         sclk,
    output wire         mosi,
    output wire         cs_n,
    output wire         nrst_pd,

    // Servo PWM Outputs
    output wire [4:0]   pwm_servos, // [0] = A -> B, C, D, E

    // IR Inputs
    input  wire [4:0]   input_ir,
	
	// Status LEDs
	output wire [4:0] led_busy,
	output wire         led1, led2
	
);

    // Internal Connections 
    // 1. RFID Interfaces
    wire [31:0] UID;
    wire        card_OK;

    // 2. Servo Interfaces
    wire [4:0] disp_start;
    wire [3:0] s_count [0:4];  // Array to hold count_A through count_E
    wire [4:0] busy_servo;


    // HIGH if any servo is currently moving
    wire dispensing_active = |busy_servo;

    assign led2     = dispensing_active;
	assign led_busy = busy_servo;

    // RFID Module (SPI Master + RC522 FSM)
    rc522 rfid_inst (
        .clk            (clk),
        .rst            (rst),
        .miso           (miso),
        .sclk           (sclk),
        .mosi           (mosi),
        .cs_n           (cs_n),
        .nrst_pd        (nrst_pd),
        .UID            (UID),
        .card_OK        (card_OK)
    );

    // UART Controller
    wire [3:0] count_A, count_B, count_C, count_D, count_E;
    assign s_count[0] = count_A;
    assign s_count[1] = count_B;
    assign s_count[2] = count_C;
    assign s_count[3] = count_D;
    assign s_count[4] = count_E;

    uart_controller comm_inst(
        .clk            (clk),
        .rst            (rst),
        .rx             (rx),
        .tx             (tx),
        .led1           (led1),
        
        // RFID
        .UID            (UID),
        .card_OK        (card_OK),

        // IR Sensors
        .ir_status      (input_ir),

        // Servo Interfaces
        .dispensing_active  (dispensing_active),
        .dispenser_start    (disp_start),

        .count_A        (count_A),
        .count_B        (count_B),
        .count_C        (count_C),
        .count_D        (count_D),
        .count_E        (count_E)
    );

    // Servo Controllers 
    genvar i;
    generate
        for (i = 1; i < 5; i = i + 1) begin: servo_dispensers
            servo_fsm_unit servo_inst1(
                .clk            (clk),
                .rst            (rst),
                .start_trigger  (disp_start[i]),
                .num_turns      (s_count[i]),
                .pwm_out        (pwm_servos[i]),
                .busy           (busy_servo[i])
            );
        end
    endgenerate

	servo_fsm_unit_anticlockwise servo_inst2(
		.clk            (clk),
		.rst            (rst),
		.start_trigger  (disp_start[0]),
		.num_turns      (s_count[0]),
		.pwm_out        (pwm_servos[0]),
		.busy           (busy_servo[0])
	);
	
endmodule