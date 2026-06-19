//============================================================================
// 주차장 관리 시스템 - Top Module (v2)
// Basys3 FPGA (XC7A35T)
// 변경: empty_count 신호 추가 (controller → VGA display)
//============================================================================
module parking_system_top(
    input        clk,           // 100MHz
    // 버튼 (active high on Basys3)
    input        btnC,          // 입차/출차 확인
    input        btnU,          // 숫자 증가
    input        btnD,          // 숫자 감소
    input        btnL,          // 자릿수 왼쪽 이동
    input        btnR,          // 자릿수 오른쪽 이동
    // 스위치
    input  [1:0] sw,            // sw[0]: 0=입차모드, 1=출차모드
                                // sw[1]: 리셋
    // VGA 출력
    output [3:0] vga_r,
    output [3:0] vga_g,
    output [3:0] vga_b,
    output       vga_hs,
    output       vga_vs,
    // 7-Segment
    output [6:0] seg,           // active low
    output       dp,
    output [3:0] an,            // active low
    // 초음파 센서 (PMOD JA - 하드웨어 연결 유지)
    output       ultra_trig,
    input        ultra_echo
);

    // =========================================================
    // 내부 신호
    // =========================================================
    wire sys_rst = sw[1];

    // 디바운스된 버튼
    wire btnC_db, btnU_db, btnD_db, btnL_db, btnR_db;
    wire btnC_pulse, btnU_pulse, btnD_pulse, btnL_pulse, btnR_pulse;

    // VGA 관련
    wire [9:0] pixel_x, pixel_y;
    wire       video_on;
    wire       pclk_en;

    // 주차장 상태
    wire [31:0] spot_status_flat;
    wire [4:0]  empty_count;      // 빈자리 개수 (controller → VGA)

    // 7-Segment
    wire [3:0]  seg_digit0, seg_digit1, seg_digit2, seg_digit3;
    wire [3:0]  seg_blink_mask;
    wire        seg_show_special;
    wire [1:0]  seg_special_code;

    // 초음파 센서
    wire obj_detected;
    wire ultra_valid;

    // 깜빡임 클럭 (~3Hz)
    reg [24:0] blink_cnt;
    wire       blink_clk;
    always @(posedge clk or posedge sys_rst) begin
        if (sys_rst)
            blink_cnt <= 0;
        else
            blink_cnt <= blink_cnt + 1;
    end
    assign blink_clk = blink_cnt[24];

    // 25MHz 픽셀 클럭 이네이블
    reg [1:0] pclk_cnt;
    always @(posedge clk or posedge sys_rst) begin
        if (sys_rst)
            pclk_cnt <= 0;
        else
            pclk_cnt <= pclk_cnt + 1;
    end
    assign pclk_en = (pclk_cnt == 2'b00);

    // =========================================================
    // 버튼 디바운스
    // =========================================================
    debounce #(.N(20)) db_C (.clk(clk), .rst(sys_rst), .btn_in(btnC), .btn_out(btnC_db), .btn_pulse(btnC_pulse));
    debounce #(.N(20)) db_U (.clk(clk), .rst(sys_rst), .btn_in(btnU), .btn_out(btnU_db), .btn_pulse(btnU_pulse));
    debounce #(.N(20)) db_D (.clk(clk), .rst(sys_rst), .btn_in(btnD), .btn_out(btnD_db), .btn_pulse(btnD_pulse));
    debounce #(.N(20)) db_L (.clk(clk), .rst(sys_rst), .btn_in(btnL), .btn_out(btnL_db), .btn_pulse(btnL_pulse));
    debounce #(.N(20)) db_R (.clk(clk), .rst(sys_rst), .btn_in(btnR), .btn_out(btnR_db), .btn_pulse(btnR_pulse));

    // =========================================================
    // 초음파 센서 (하드웨어 연결 유지)
    // =========================================================
    ultrasonic_sensor u_ultra (
        .clk        (clk),
        .rst        (sys_rst),
        .echo       (ultra_echo),
        .trig       (ultra_trig),
        .obj_in_range(obj_detected),
        .valid      (ultra_valid)
    );

    // =========================================================
    // 주차장 컨트롤러
    // =========================================================
    parking_controller u_ctrl (
        .clk            (clk),
        .rst            (sys_rst),
        .mode_sw        (sw[0]),
        .btnC_pulse     (btnC_pulse),
        .btnU_pulse     (btnU_pulse),
        .btnD_pulse     (btnD_pulse),
        .btnL_pulse     (btnL_pulse),
        .btnR_pulse     (btnR_pulse),
        .obj_detected   (obj_detected),
        .ultra_valid    (ultra_valid),
        // 주차장 상태 출력
        .spot_status_flat(spot_status_flat),
        .empty_count    (empty_count),
        // 7-seg
        .seg_digit0     (seg_digit0),
        .seg_digit1     (seg_digit1),
        .seg_digit2     (seg_digit2),
        .seg_digit3     (seg_digit3),
        .seg_blink_mask (seg_blink_mask),
        .seg_show_special(seg_show_special),
        .seg_special_code(seg_special_code)
        );

    // =========================================================
    // VGA 동기 신호
    // =========================================================
    vga_sync u_vga_sync (
        .clk      (clk),
        .rst      (sys_rst),
        .pclk_en  (pclk_en),
        .hsync    (vga_hs),
        .vsync    (vga_vs),
        .video_on (video_on),
        .pixel_x  (pixel_x),
        .pixel_y  (pixel_y)
    );

    // =========================================================
    // VGA 주차장 화면
    // =========================================================
    vga_parking_display u_vga_disp (
        .clk              (clk),
        .pclk_en          (pclk_en),
        .video_on         (video_on),
        .pixel_x          (pixel_x),
        .pixel_y          (pixel_y),
        .spot_status_flat (spot_status_flat),
        .empty_count      (empty_count),
        .blink_clk        (blink_clk),
        .vga_r            (vga_r),
        .vga_g            (vga_g),
        .vga_b            (vga_b)
    );

    // =========================================================
    // 7-Segment 컨트롤러
    // =========================================================
    seg7_controller u_seg7 (
        .clk            (clk),
        .rst            (sys_rst),
        .digit0         (seg_digit0),
        .digit1         (seg_digit1),
        .digit2         (seg_digit2),
        .digit3         (seg_digit3),
        .blink_mask     (seg_blink_mask),
        .blink_clk      (blink_clk),
        .show_special   (seg_show_special),
        .special_code   (seg_special_code),
        .seg            (seg),
        .dp             (dp),
        .an             (an)
    );

endmodule