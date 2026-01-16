module protocol_handler(
    input wire          clk,
    input wire          rst,

    // RX FIFO Interface
    output reg          rx_rd,
    input  wire         rx_empty,
    input  wire [7:0]   rx_data,

    // TX FIFO Interface
    output reg          tx_wr,
    input  wire         tx_full,
    output reg [7:0]    tx_data,

    // --- RFID Interface Pins ---
    input wire          card_OK,    // Priority trigger
    input wire [31:0]   UID,        // 32-bit UID from rc522.v

    // Servo Controls
    input wire          dispensing_active, 
    output reg [4:0]    dispenser_start,
    output reg [3:0]    count_A, count_B, count_C, count_D, count_E,

    // IR Inputs for Stock Level
    input  wire [4:0]   input_ir,

    // Status LEDs
    output reg          led1
);

    localparam CMD_MAX = 32;

    // REDEFINING STATES with 3 bits
    localparam IDLE       = 3'd0;
    localparam FETCH      = 3'd1;
    localparam WAIT_RX    = 3'd2;
    localparam PROCESS    = 3'd3;
    localparam RESPOND    = 3'd4;
    localparam TRANSMIT   = 3'd5;
    localparam WAIT_TX    = 3'd6;
    localparam RFID_SEND  = 3'd7;

    // State Registers
    reg [2:0] current_state, next_state;

    // Internal Registers
    reg       system_authorized;         // Only HIGH when received "START"

    // Session Registers
    reg       session_captured;          // Flag = 1 (UID had been stored)
    reg [31:0] session_uid;

    // Edge detection for "Dispense Done"
    reg       disp_active_prev;

    // Buffers and Pointers
    reg [7:0] rx_buf [0:CMD_MAX-1];
    reg [7:0] tx_buf [0:CMD_MAX-1];
    reg [5:0] rx_len;
    reg [5:0] tx_len;
    reg [5:0] tx_idx;

    // Logic for normalization
    wire [7:0] rx_upper = (rx_data >= 8'h61 && rx_data <= 8'h7A) ? (rx_data - 8'h20) : rx_data;

    // Lockout Counter to prevent trigger flooding
    reg [27:0] lockout_cnt;
    
    // Timer for LED Blinking
    reg [24:0] blink_timer;

    // State Machine Transition
    always @(posedge clk) begin
        if (rst) begin
            current_state    <= IDLE;
            disp_active_prev <= 1'b0;
        end else begin
            current_state    <= next_state;
            disp_active_prev <= dispensing_active;
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = current_state;

        // Priority 1 : RFID Scan
        if (card_OK && system_authorized && !session_captured && lockout_cnt == 0 && current_state == IDLE) begin
            next_state = RFID_SEND;
        end 
        // Priority 2 : Dispensing Action Done
        else if (disp_active_prev && !dispensing_active && current_state == IDLE) begin
            next_state = RESPOND;
        end
        else begin
            case (current_state)
                IDLE:
                    if (!rx_empty) next_state = FETCH;
                
                FETCH:
                    next_state = WAIT_RX;

                WAIT_RX:
                    next_state = PROCESS;

                PROCESS: begin
                    if (rx_len == 0 && (rx_upper <= 8'h20)) next_state = IDLE;
                    else if (rx_upper == 8'h0A || rx_upper == 8'h0D) begin
                        if (rx_len == 1 && rx_buf[0] == "T") next_state = RFID_SEND;
                        else next_state = RESPOND;
                    end
                    else if (rx_len >= CMD_MAX) next_state = IDLE;
                    else next_state = IDLE;
                end

                RESPOND:
                    if (tx_len > 0) next_state = TRANSMIT;
                    else            next_state = IDLE;

                RFID_SEND:
                    next_state = TRANSMIT;
                
                TRANSMIT: begin
                    if (tx_idx < tx_len) begin
                        if (!tx_full) next_state = WAIT_TX;
                        else          next_state = TRANSMIT;
                    end else begin
                        next_state = IDLE;
                    end
                end

                WAIT_TX:
                    next_state = TRANSMIT;
                
                default: next_state = IDLE;
            endcase
        end
    end

    // Output Logic
    always @(posedge clk) begin
        if (rst) begin
            rx_rd             <= 1'b0;
            tx_wr             <= 1'b0;
            rx_len            <= 6'd0;
            tx_len            <= 6'd0;
            tx_idx            <= 6'd0;
            system_authorized <= 1'b0;
            session_captured  <= 1'b0;
            led1              <= 1'b0;
            lockout_cnt       <= 0;
            blink_timer       <= 0;
            session_uid       <= 32'h0;
        end else begin
            rx_rd <= 1'b0;
            tx_wr <= 1'b0;
            
            // --- LED Logic Tree ---
            // Centralized control avoids blocking session_captured logic
            if (!system_authorized) begin
                led1        <= 1'b0;
                blink_timer <= 0;
            end else begin
                blink_timer <= blink_timer + 1'b1;
                if (session_captured) begin
                    led1 <= 1'b1;           // Solid ON after capture
                end else begin
                    led1 <= blink_timer[24]; // Blinking after START
                end
            end

            if (lockout_cnt > 0) lockout_cnt <= lockout_cnt - 1;

            case (next_state)
                FETCH: begin
                    rx_rd <= 1'b1;
                end

                PROCESS: begin
                    if (current_state == WAIT_RX) begin
                        if (rx_len < CMD_MAX && rx_upper > 8'h20 && rx_upper != 8'h0A && rx_upper != 8'h0D) begin
                            rx_buf[rx_len] <= rx_upper;
                            rx_len         <= rx_len + 1'b1;
                        end
                    end
                end

                RESPOND: begin
                    tx_len          <= 0;
                    tx_idx          <= 0;
                    dispenser_start <= 5'b00000;

                    if (disp_active_prev && !dispensing_active) begin
						tx_buf[0] <= "D"; 
						tx_buf[1] <= "O"; 
						tx_buf[2] <= "N"; 
						tx_buf[3] <= "E"; 
						tx_buf[4] <= 8'h0A;
						tx_len    <= 5;
                    end
                    else if (rx_len == 5 && rx_buf[0] == "S" && rx_buf[1] == "T" && rx_buf[2] == "A" && rx_buf[3] == "R" && rx_buf[4] == "T") begin
                        system_authorized <= 1'b1;
                        session_captured  <= 1'b0;
                        session_uid       <= 32'h0;
                    end
                    else if (rx_len == 3 && rx_buf[0] == "E" && rx_buf[1] == "N" && rx_buf[2] == "D") begin
						system_authorized <= 1'b0;
						session_captured  <= 1'b0;
						session_uid       <= 32'h0;
						tx_buf[0] <= "S"; 
						tx_buf[1] <= "T"; 
						tx_buf[2] <= "K"; 
						tx_buf[3] <= ":";
						tx_buf[4] <= input_ir[4] ? 8'h31 : 8'h30;
						tx_buf[5] <= input_ir[3] ? 8'h31 : 8'h30;
						tx_buf[6] <= input_ir[2] ? 8'h31 : 8'h30;
						tx_buf[7] <= input_ir[1] ? 8'h31 : 8'h30;
						tx_buf[8] <= input_ir[0] ? 8'h31 : 8'h30;
						tx_buf[9] <= 8'h0A;
						tx_len    <= 10;
                    end
                    else if (system_authorized) begin
                        if (rx_len == 4 && rx_buf[0] == "P" && rx_buf[1] == "I" && rx_buf[2] == "N" && rx_buf[3] == "G") begin
							tx_buf[0] <= "P"; 
							tx_buf[1] <= "O"; 
							tx_buf[2] <= "N"; 
							tx_buf[3] <= "G"; 
							tx_buf[4] <= 8'h0A;
							tx_len    <= 5;
                        end
                        else if (rx_len == 14 && rx_buf[0] == "M" && rx_buf[1] == "E" && rx_buf[2] == "D" && !dispensing_active) begin
						// else if (rx_len == 14 && rx_buf[0] == "M" && rx_buf[1] == "E" && rx_buf[2] == "D" && !dispensing_active) begin
							count_A <= rx_buf[5] - 8'h30; 
							count_B <= rx_buf[7] - 8'h30; 
							count_C <= rx_buf[9] - 8'h30;
							count_D <= rx_buf[11] - 8'h30; 
							count_E <= rx_buf[13] - 8'h30;
							
							if (rx_buf[5]  > 8'h30) dispenser_start[0] <= 1'b1;
							if (rx_buf[7]  > 8'h30) dispenser_start[1] <= 1'b1;
							if (rx_buf[9]  > 8'h30) dispenser_start[2] <= 1'b1;
							if (rx_buf[11] > 8'h30) dispenser_start[3] <= 1'b1;
							if (rx_buf[13] > 8'h30) dispenser_start[4] <= 1'b1;
							tx_buf[0] <= "D"; 
							tx_buf[1] <= "I"; 
							tx_buf[2] <= "S"; 
							tx_buf[3] <= "P"; 
							tx_buf[4] <= "E"; 
							tx_buf[5] <= "N";
							tx_buf[6] <= "S"; 
							tx_buf[7] <= "I"; 
							tx_buf[8] <= "N"; 
							tx_buf[9] <= "G"; 
							tx_buf[10]<= "."; 
							tx_buf[11]<= ".";
							tx_buf[12]<= "."; 
							tx_buf[13]<= 8'h0A;
							tx_len    <= 14;
                        end else begin
                            tx_buf[0] <= "E"; tx_buf[1] <= "R"; tx_buf[2] <= "R"; tx_buf[3] <= 8'h0A;
                            tx_len    <= 4;
                        end
                    end
                    rx_len <= 6'd0;
                end

                RFID_SEND: begin
					session_captured 	<= 1'b1; // Card is read
					session_uid      	<= UID;
					tx_buf[0] 			<= "P"; 
					tx_buf[1] 			<= "I"; 
					tx_buf[2] 			<= "D"; 
					tx_buf[3] 			<= ":";
					tx_buf[4] 			<= UID[31:24]; 
					tx_buf[5] 			<= UID[23:16]; 
					tx_buf[6] 			<= UID[15:8]; 
					tx_buf[7] 			<= UID[7:0];
					tx_buf[8] 			<= 8'h0A;
					tx_len    			<= 9;
					tx_idx    			<= 0;
					rx_len    			<= 0;
					lockout_cnt 		<= 28'd30_000_000;
                end

                WAIT_TX: begin
                    tx_data <= tx_buf[tx_idx];
                    tx_wr   <= 1'b1;
                    tx_idx  <= tx_idx + 1'b1;
                end 
            endcase
        end
    end
endmodule