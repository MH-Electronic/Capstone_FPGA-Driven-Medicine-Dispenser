module rc522 (
    input               clk,            // 125 MHz (system clock) T=8ns
    input               rst,          // active low reset
    input               miso,           // SPI MISO
    output              sclk,           // SPI clock (3.9 MHz) T=256ns
    output              mosi,           // SPI MOSI
    output              cs_n,           // SPI chip select (active low)
    output reg          nrst_pd,            // RC522 reset 
    output reg [31:0]   UID,            // UID value 32bits
    output reg          card_OK         // flag set when the card UID and checksum match expected value (intended)
    // output              RGB5,
    // output              RGB4,
    // output              RGB3,
    // output              RGB2,
    // output              RGB1,
    // output              RGB0         
);


//******************************************REGISTER ADDRESS***************************************************************************//
   
		// Command / Control Reg  (<<1 shift left ->[Read/Write Bit] [Address (6 bits)] [0] So, address 0x01 (000001) becomes 0000010 )
 localparam  	CommandReg              = 8'h01 << 1,   // starts and stops command execution
                ComIEnReg               = 8'h02 << 1,   // enable and disable interrupt request control bits
                DivIEnReg               = 8'h03 << 1,   // enable and disable interrupt request control bits
                ComIrqReg               = 8'h04 << 1,   // interrupt request bits
                DivIrqReg               = 8'h05 << 1,   // interrupt request bits
                ErrorReg                = 8'h06 << 1,   // error bits showing the error status of the last command executed 
                Status1Reg              = 8'h07 << 1,   // communication status bits
                Status2Reg              = 8'h08 << 1,   // receiver and transmitter status bits
                FIFODataReg             = 8'h09 << 1,   // input and output of 64 byte FIFO buffer
                FIFOLevelReg            = 8'h0A << 1,   // number of bytes stored in the FIFO buffer
                WaterLevelReg           = 8'h0B << 1,   // level for FIFO underflow and overflow warning
                ControlReg              = 8'h0C << 1,   // miscellaneous control registers
                BitFramingReg           = 8'h0D << 1,   // adjustments for bit-oriented frames
                CollReg                 = 8'h0E << 1,   // bit position of the first bit-collision detected on the RF interface
                //                        8'h0F         // reserved for future use
                
                // Page 1: Communication Reg
                //                        8'h10         // reserved for future use
                ModeReg                 = 8'h11 << 1,   // defines general modes for transmitting and receiving 
                TxModeReg               = 8'h12 << 1,   // defines transmission data rate and framing
                RxModeReg               = 8'h13 << 1,   // defines reception data rate and framing
                TxControlReg            = 8'h14 << 1,   // controls the logical behavior of the antenna driver pins TX1 and TX2
                TxASKReg                = 8'h15 << 1,   // controls the setting of the transmission modulation
                TxSelReg                = 8'h16 << 1,   // selects the internal sources for the antenna driver
                RxSelReg                = 8'h17 << 1,   // selects internal receiver settings
                RxThresholdReg          = 8'h18 << 1,   // selects thresholds for the bit decoder
                DemodReg                = 8'h19 << 1,   // defines demodulator settings
                //                        8'h1A         // reserved for future use
                //                        8'h1B         // reserved for future use
                MfTxReg                 = 8'h1C << 1,   // controls some MIFARE communication transmit parameters
                MfRxReg                 = 8'h1D << 1,   // controls some MIFARE communication receive parameters
                //                        8'h1E         // reserved for future use
                SerialSpeedReg          = 8'h1F << 1,   // selects the speed of the serial UART interface
                
                // Page 2: Configuration
                //                        8'h20         // reserved for future use
                CRCResultRegH           = 8'h21 << 1,   // shows the MSB and LSB values of the CRC calculation
                CRCResultRegL           = 8'h22 << 1,
                //                        8'h23         // reserved for future use
                ModWidthReg             = 8'h24 << 1,   // controls the ModWidth setting?
                //                        8'h25         // reserved for future use
                RFCfgReg                = 8'h26 << 1,   // configures the receiver gain
                GsNReg                  = 8'h27 << 1,   // selects the conductance of the antenna driver pins TX1 and TX2 for modulation 
                CWGsPReg                = 8'h28 << 1,   // defines the conductance of the p-driver output during periods of no modulation
                ModGsPReg               = 8'h29 << 1,   // defines the conductance of the p-driver output during periods of modulation
                TModeReg                = 8'h2A << 1,   // defines settings for the internal timer
                TPrescalerReg           = 8'h2B << 1,   // the lower 8 bits of the TPrescaler value. The 4 high bits are in TModeReg.
                TReloadRegH             = 8'h2C << 1,   // defines the 16-bit timer reload value
                TReloadRegL             = 8'h2D << 1,
                TCounterValueRegH       = 8'h2E << 1,   // shows the 16-bit timer value
                TCounterValueRegL       = 8'h2F << 1,
                
                // Page 3: Test Registers
                //                        8'h30         // reserved for future use
                TestSel1Reg             = 8'h31 << 1,   // general test signal configuration
                TestSel2Reg             = 8'h32 << 1,   // general test signal configuration
                TestPinEnReg            = 8'h33 << 1,   // enables pin output driver on pins D1 to D7
                TestPinValueReg         = 8'h34 << 1,   // defines the values for D1 to D7 when it is used as an I/O bus
                TestBusReg              = 8'h35 << 1,   // shows the status of the internal test bus
                AutoTestReg             = 8'h36 << 1,   // controls the digital self-test
                VersionReg              = 8'h37 << 1,   // shows the software version
                AnalogTestReg           = 8'h38 << 1,   // controls the pins AUX1 and AUX2
                TestDAC1Reg             = 8'h39 << 1,   // defines the test value for TestDAC1
                TestDAC2Reg             = 8'h3A << 1,   // defines the test value for TestDAC2
                TestADCReg              = 8'h3B << 1;   // shows the value of ADC I and Q channels
                //                        8'h3C         // reserved for production tests
                //                        8'h3D         // reserved for production tests
                //                        8'h3E         // reserved for production tests
                //                        8'h3F         // reserved for production tests


//********************************************************Proximity Coupling Device (PCD->RC522) COMMAND ************************************************************//

    localparam  PCD_Idle                = 8'h00,        // no action, cancels current command execution
                PCD_Mem                 = 8'h01,        // stores 25 bytes into the internal buffer
                PCD_GenerateRandomID    = 8'h02,        // generates a 10-byte random ID number
                PCD_CalcCRC             = 8'h03,        // activates the CRC coprocessor or performs a self-test
                PCD_Transmit            = 8'h04,        // transmits data from the FIFO buffer
                PCD_NoCmdChange         = 8'h07,        // no command change, can be used to modify the CommandReg register bits without affecting the command, for example, the PowerDown bit
                PCD_Receive             = 8'h08,        // activates the receiver circuits
                PCD_Transceive          = 8'h0C,        // transmits data from FIFO buffer to antenna and automatically activates the receiver after transmission
                PCD_MFAuthent           = 8'h0E,        // performs the MIFARE standard authentication as a reader
                PCD_SoftReset           = 8'h0F;        // resets the MFRC522


//***********************************************************Proximity Integrated Circuit Card (PICC) COMMAND************************************************************//
    localparam  PICC_CMD_REQA           = 8'h26,        // REQuest command, Type A. Invites PICCs in state IDLE to go to READY and prepare for anticollision or selection. 7 bit frame.
                PICC_CMD_WUPA          = 8'h52,         // Wake-UP command, Type A. Invites PICCs in state IDLE and HALT to go to READY(*) and prepare for anticollision or selection. 7 bit frame.
                
		PICC_CMD_CT            = 8'h88,         // Cascade Tag. Not really a command, but used during anti collision.
                PICC_CMD_SEL_CL1       = 8'h93,         // Anti collision/Select, Cascade Level 1
                PICC_CMD_SEL_CL2       = 8'h95,         // Anti collision/Select, Cascade Level 2
                UltraPICC_CMD_SEL_CL3       = 8'h97,         // Anti collision/Select, Cascade Level 3
                
		PICC_CMD_HLTA          = 8'h50,         // HaLT command, Type A. Instructs an ACTIVE PICC to go to state HALT.
                PICC_CMD_RATS          = 8'hE0,         // Request command for Answer To Reset.
                // The commands used for MIFARE Classic (from http://www.mouser.com/ds/2/302/MF1S503x-89574.pdf, Section 9)
                // Use PCD_MFAuthent to authenticate access to a sector, then use these commands to read/write/modify the blocks on the sector.
                // The read/write commands can also be used for MIFARE Ultralight.
                PICC_CMD_MF_AUTH_KEY_A = 8'h60,         // Perform authentication with Key A
                PICC_CMD_MF_AUTH_KEY_B = 8'h61,         // Perform authentication with Key B
                PICC_CMD_MF_READ       = 8'h30,         // Reads one 16 byte block from the authenticated sector of the PICC. Also used for MIFARE Ultralight.
                PICC_CMD_MF_WRITE      = 8'hA0,         // Writes one 16 byte block to the authenticated sector of the PICC. Called "COMPATIBILITY WRITE" for MIFARE Ultralight.
                PICC_CMD_MF_DECREMENT  = 8'hC0,         // Decrements the contents of a block and stores the result in the internal data register.
                PICC_CMD_MF_INCREMENT  = 8'hC1,         // Increments the contents of a block and stores the result in the internal data register.
                PICC_CMD_MF_RESTORE    = 8'hC2,         // Reads the contents of a block into the internal data register.
                PICC_CMD_MF_TRANSFER   = 8'hB0,         // Writes the contents of the internal data register to a block.
                // The commands used for MIFARE Ultralight (from http://www.nxp.com/documents/data_sheet/MF0ICU1.pdf, Section 7)
                // The PICC_CMD_MF_READ and PICC_CMD_MF_WRITE can also be used for MIFARE Ultralight.
                PICC_CMD_UL_WRITE      = 8'hA2;         // Writes one 4 byte page to the PICC.


//********************************************************************MAIN CODE ********************************************************************//

    // SPI module instance
    reg         spi_start; // Trigger signal: 1 = Start sending SPI data
    reg [15:0]  data_tx;   // 16-bit register: Holds "Address + Data" to send 
    wire [15:0] data_rx;   // 16-bit wire: Carries data received from SPI module
    wire        spi_busy;	// Wire: 1 = SPI module is working, 0 = Done
    reg         new_card;	// Flag: 1 = RC522 says "I found a card!"

    spi_master #(
        .DATA_WIDTH     (16),
        .CLK_DIV        (32),
        .CPOL           (0),
        .CPHA           (0),
        .LEAD_TICKS     (15),
        .LAG_TICKS      (15)
    ) spi_module (
        .clk            (clk),
        .rst            (rst),
        .start          (spi_start),
        .tx_data        (data_tx),
        .rx_data        (data_rx),
        .sclk           (sclk),
        .mosi           (mosi),
        .miso           (miso),
        .cs_n           (cs_n),
        .busy           (spi_busy)
    );
    
    reg [31:0]  cnt;					// Main Timer (32-bit counter)
    reg [2:0]   cnt_2; 					// Small loop counter (for retrying)
    reg [7:0]   FIFOLevelReg_Value;	// Stores how many bytes are in RC522 FIFO
    reg [7:0]   BCC;					// Stores the Checksum byte from the card

    // Main FSM state machine state
    reg [9:0] instr_step; //0-1024
    
    // Task for SPI write operation (used in the main FSM).
    task spi_write;
        input [7:0] reg_addr;
        input [7:0] value;
        begin
            spi_start   <= 1;
            data_tx     <= {reg_addr, value};	//It glues two 8-bit values into one 16-bit value.
        end										//Addr 0x14 + Data 0x03 becomes 0x1403 (binary 00010100 00000011).
    endtask

    // Task for SPI read operation (used in the main FSM).
    task spi_read;
        input [7:0] reg_addr;
        begin
            spi_start   <= 1;							//It takes your address (e.g., 00000100) and forces the top bit to 1 (Result: 10000100). MSB=1 ->read
            data_tx     <= {reg_addr | 8'h80, 8'h00};	//The second byte is just empty zeros (dummy data) to keep the clock running while the RC522 sends its answer back.
        end
    endtask


    always @(posedge clk or posedge rst) begin
        if (rst) begin
            instr_step      <= 0;
            spi_start       <= 0;
            nrst_pd             <= 1;   				//nrst_pd for rc522
            UID             <= 32'h00000000;
            // LED_state       <= 6'b000000;
            cnt             <= 0;
            cnt_2           <= 0;
            new_card        <= 0;
            card_OK         <= 0;
        end else begin													//Start SPI after 32 cycles (short delay) ->AND of the bottom 5 bits of cnt. This becomes 1 when cnt[4:0] == 5'b11111
            if  (&cnt[4:0] && spi_start)                                    // pull spi_start down after 2^5(32bits) * 8ns = 256ns
                spi_start   <= 0;											

            if  (&cnt[16:0] && ~spi_busy) begin                             //Process data after 131k cycles AND SPI finished (long delay)
                case (instr_step)											//// 1 step = 2^17(131kbits) * 8ns # 1.05ms
                    1:  nrst_pd <= 0;                                           // Hard Reset, ?1.3ms
                    2:  nrst_pd <= 1;                                           // wait hard reset to complete, ?50ms

                    // initialize RC522 after reset
                    50: spi_write (TxModeReg,       8'h00);                 // reset transmit baud rates 106kBd
                    51: spi_write (RxModeReg,       8'h00);                 // reset receive  baud rates 106kBd
                    52: spi_write (ModWidthReg,     8'h26);                 // reset ModWidthReg
                    53: spi_write (TModeReg,        8'h80);                 // setup timeout
                    54: spi_write (TPrescalerReg,   8'hA9);            
                    55: spi_write (TReloadRegH,     8'h03);
                    56: spi_write (TReloadRegL,     8'hE8);
                    57: spi_write (TxASKReg,        8'h40);                 // default 0x00. Force a 100% ASK modulation
                    58: spi_write (ModeReg,         8'h3D);                 // default 0x3F. Set the preset value for the CRC coprocessor for the CalcCRC command to 0x6363
                    59: spi_read  (TxControlReg);							//the return byte will appear in data_rx after SPI completes
                    60: spi_write (TxControlReg,    8'h03 | data_rx[7:0]);       // enable the antenna driver pins TX1 and TX2 (they were disabled by the reset)
                   
                    // check if new card is present
                    62: spi_write (CommandReg,      PCD_Idle);              // stop any active command
                    63: spi_write (ComIrqReg,       8'h7F);                 // clear all 7 interrupt request bits
                    64: spi_write (FIFOLevelReg,    8'h80);                 // flush the FIFO buffer
                    65: spi_write (FIFODataReg,     PICC_CMD_REQA);         // send REQA command
                    66: spi_write (BitFramingReg,   8'h07);                 // bit adjustments: 7 bit frame
                    67: spi_write (CommandReg,      PCD_Transceive);        // start the transceive command
                    68: spi_write (BitFramingReg,   8'h87);                 // StartSend = 1, start the transmission of data

                    // read ComIrqReg to check if card has responded
                    70: spi_read  (ComIrqReg);                              // read the ComIrqReg
                    71: if (data_rx[5])                                     // ComIrqReg[5]: RxIRq -> set if received data is detected
                            new_card <= 1;

                    // send SELECT command to the card
                    73: spi_write (FIFOLevelReg,    8'h80);                 // flush the FIFO buffer
                    74: spi_write (FIFODataReg,     PICC_CMD_SEL_CL1);      // send SELECT command: 0x93, 0x20
                    75: spi_write (FIFODataReg,     8'h20);
                    76: spi_write (BitFramingReg,   8'h00);                 // reset bit adjustments
                    77: spi_write (CommandReg,      PCD_Transceive);        // start the transceive command
                    78: spi_write (BitFramingReg,   8'h80);                 // StartSend = 1, start the transmission of data

                    // read UID and BCC. 
                    // RFID card will response with 5 bytes: UID_0, UID_1, UID_2, UID_3, BCC (saved in FIFO buffer)
                    // BCC = UID_0 ^ UID_1 ^ UID_2 ^ UID_3 (for error checking)
                    83: spi_read  (FIFOLevelReg);
                    84: FIFOLevelReg_Value <= data_rx[7:0];
                    85: spi_read  (FIFODataReg);
                    86: UID[31:24] <= data_rx[7:0];
                    87: spi_read  (FIFODataReg);
                    88: UID[23:16] <= data_rx[7:0];
                    89: spi_read  (FIFODataReg);
                    90: UID[15:8] <= data_rx[7:0];
                    91: spi_read  (FIFODataReg);
                    92: UID[7:0] <= data_rx[7:0];
                    93: spi_read  (FIFODataReg);
                    94: BCC <= data_rx[7:0];                                     
                    95: new_card <= 0;

                    // check if UID is correct
                    96: if ((FIFOLevelReg_Value == 5) && (BCC == (UID[31:24] ^ UID[23:16] ^ UID[15:8] ^ UID[7:0])))
                            card_OK <= 1;
                    97: card_OK <= 0;

                endcase

                // FSM state transitions
                if (instr_step == 72 && ~new_card) begin //state=72, no card
                    cnt_2 <= cnt_2 + 1;
                    if (cnt_2 == 5) begin
                        cnt_2 <= 0;
                        instr_step <= 62;
                    end else
                        instr_step <= 70;
                end else if (instr_step == 501)
                    instr_step <= 62;
                else
                    instr_step <= instr_step + 1;

            end
            cnt <= cnt + 1;
        end
    end

endmodule