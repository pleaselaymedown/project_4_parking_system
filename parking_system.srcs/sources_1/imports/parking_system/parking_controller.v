//============================================================================
// 주차장 컨트롤러 - 메인 FSM (v3)
// - 입차 → ASSIGNED (내부 배정, VGA에서는 초록)
// - 초음파 1m 이내 5초 연속 감지 → PARKED (빨간색)
// - 중복 차량번호 입력 시 Err
// - LFSR 랜덤 자리 선택
// - LED 항상 꺼짐
//============================================================================
module parking_controller(
    input        clk,
    input        rst,
    input        mode_sw,       // 0=입차, 1=출차
    input        btnC_pulse,
    input        btnU_pulse,
    input        btnD_pulse,
    input        btnL_pulse,
    input        btnR_pulse,
    input        obj_detected,  // 초음파: 1m 이내 물체
    input        ultra_valid,   // 초음파 측정 유효
    // 주차장 상태 출력
    output [31:0] spot_status_flat,  // 16 spots x 2 bits
    output [4:0]  empty_count,       // 빈자리 개수 (0~16)
    // 7-Segment 출력
    output reg [3:0] seg_digit0,
    output reg [3:0] seg_digit1,
    output reg [3:0] seg_digit2,
    output reg [3:0] seg_digit3,
    output reg [3:0] seg_blink_mask,
    output reg       seg_show_special,
    output reg [1:0] seg_special_code  // 1=FULL, 2=Err
);

    // =========================================================
    // FSM 상태
    // =========================================================
    localparam ST_IDLE     = 3'd0;
    localparam ST_INPUT    = 3'd1;  // 차량번호 입력
    localparam ST_DONE     = 3'd2;  // 입차/출차 결과 표시
    localparam ST_SHOW_MSG = 3'd3;  // FULL / Err 메시지

    // 주차 자리 상태 (3가지)
    localparam SPOT_EMPTY    = 2'd0;  // 빈자리
    localparam SPOT_ASSIGNED = 2'd1;  // 배정됨 (초음파 대기)
    localparam SPOT_PARKED   = 2'd2;  // 주차 완료

    // =========================================================
    // 내부 레지스터
    // =========================================================
    reg [2:0]  state;
    reg        is_entry;

    reg [1:0]  spot_status [0:15];
    reg [15:0] spot_car    [0:15];

    reg [3:0]  input_digits [0:3];
    reg [1:0]  input_pos;

    reg [27:0] msg_timer;
    localparam MSG_DURATION = 28'd200_000_000; // 2초

    // 최근 배정 자리 (초음파 감시 대상)
    reg [3:0]  assigned_spot;

    // 초음파 타이머 (5초 = 500,000,000 사이클 @ 100MHz)
    reg [28:0] park_timer;
    localparam PARK_TIMEOUT = 29'd500_000_000; // 5초

    // =========================================================
    // LFSR (16비트) - 랜덤 자리 선택
    // =========================================================
    reg [15:0] lfsr;
    always @(posedge clk or posedge rst) begin
        if (rst)
            lfsr <= 16'hACE1;
        else
            lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[14] ^ lfsr[12] ^ lfsr[3]};
    end

    // =========================================================
    // 주차 상태 평탄화 출력
    // =========================================================
    genvar gi;
    generate
        for (gi = 0; gi < 16; gi = gi + 1) begin : gen_flat
            assign spot_status_flat[gi*2+1:gi*2] = spot_status[gi];
        end
    endgenerate

    // =========================================================
    // 초록 점 개수 (VGA 깜빡임 판단용: EMPTY + ASSIGNED)
    // =========================================================
    reg [4:0] empty_cnt_comb;
    integer ci;
    always @(*) begin
        empty_cnt_comb = 5'd0;
        for (ci = 0; ci < 16; ci = ci + 1) begin
            // 모니터에서 초록색으로 보이는 자리 수 (EMPTY + ASSIGNED)
            if (spot_status[ci] != SPOT_PARKED)
                empty_cnt_comb = empty_cnt_comb + 1;
        end
    end
    assign empty_count = empty_cnt_comb;

    // 만차 판정은 EMPTY가 0개일 때 (ASSIGNED는 이미 배정됨)
    reg all_full_comb;
    integer fi;
    always @(*) begin
        all_full_comb = 1'b1;
        for (fi = 0; fi < 16; fi = fi + 1) begin
            if (spot_status[fi] == SPOT_EMPTY)
                all_full_comb = 1'b0;
        end
    end
    wire all_full = all_full_comb;

    // =========================================================
    // 랜덤 빈자리 검색 (LFSR 시작점 순환 탐색)
    // =========================================================
    wire [3:0] rand_start = lfsr[3:0];
    reg [3:0]  rand_empty_spot;
    reg        rand_found;
    integer    ri2;
    reg [3:0]  chk;

    always @(*) begin
        rand_empty_spot = 4'd0;
        rand_found      = 1'b0;
        for (ri2 = 0; ri2 < 16; ri2 = ri2 + 1) begin
            chk = (rand_start + ri2[3:0]) & 4'hF;
            if (!rand_found) begin
                case (chk)
                    4'd0:  if (spot_status[0]  == SPOT_EMPTY) begin rand_empty_spot = 4'd0;  rand_found = 1; end
                    4'd1:  if (spot_status[1]  == SPOT_EMPTY) begin rand_empty_spot = 4'd1;  rand_found = 1; end
                    4'd2:  if (spot_status[2]  == SPOT_EMPTY) begin rand_empty_spot = 4'd2;  rand_found = 1; end
                    4'd3:  if (spot_status[3]  == SPOT_EMPTY) begin rand_empty_spot = 4'd3;  rand_found = 1; end
                    4'd4:  if (spot_status[4]  == SPOT_EMPTY) begin rand_empty_spot = 4'd4;  rand_found = 1; end
                    4'd5:  if (spot_status[5]  == SPOT_EMPTY) begin rand_empty_spot = 4'd5;  rand_found = 1; end
                    4'd6:  if (spot_status[6]  == SPOT_EMPTY) begin rand_empty_spot = 4'd6;  rand_found = 1; end
                    4'd7:  if (spot_status[7]  == SPOT_EMPTY) begin rand_empty_spot = 4'd7;  rand_found = 1; end
                    4'd8:  if (spot_status[8]  == SPOT_EMPTY) begin rand_empty_spot = 4'd8;  rand_found = 1; end
                    4'd9:  if (spot_status[9]  == SPOT_EMPTY) begin rand_empty_spot = 4'd9;  rand_found = 1; end
                    4'd10: if (spot_status[10] == SPOT_EMPTY) begin rand_empty_spot = 4'd10; rand_found = 1; end
                    4'd11: if (spot_status[11] == SPOT_EMPTY) begin rand_empty_spot = 4'd11; rand_found = 1; end
                    4'd12: if (spot_status[12] == SPOT_EMPTY) begin rand_empty_spot = 4'd12; rand_found = 1; end
                    4'd13: if (spot_status[13] == SPOT_EMPTY) begin rand_empty_spot = 4'd13; rand_found = 1; end
                    4'd14: if (spot_status[14] == SPOT_EMPTY) begin rand_empty_spot = 4'd14; rand_found = 1; end
                    4'd15: if (spot_status[15] == SPOT_EMPTY) begin rand_empty_spot = 4'd15; rand_found = 1; end
                endcase
            end
        end
    end

    // =========================================================
    // 차량번호 검색 (입차 중복 체크 + 출차 검색 겸용)
    // ASSIGNED 또는 PARKED 상태 모두 매칭
    // =========================================================
    wire [15:0] input_car_num = {input_digits[0], input_digits[1],
                                  input_digits[2], input_digits[3]};
    reg [3:0]  found_spot;
    reg        car_found;
    integer    si;
    always @(*) begin
        found_spot = 4'd0;
        car_found  = 1'b0;
        for (si = 0; si < 16; si = si + 1) begin
            if ((spot_status[si] == SPOT_PARKED || spot_status[si] == SPOT_ASSIGNED) &&
                 spot_car[si] == input_car_num) begin
                found_spot = si[3:0];
                car_found  = 1'b1;
            end
        end
    end

    // =========================================================
    // 초음파 기반 주차 확인 (모든 FSM 상태에서 병렬 동작)
    // assigned_spot의 상태가 ASSIGNED일 때만 감시
    // 1m 이내 5초 연속 감지 → PARKED 전환
    // =========================================================
    // (메인 FSM always 블록 안에서 처리)

    // =========================================================
    // 메인 FSM
    // =========================================================
    integer ri;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state            <= ST_IDLE;
            is_entry         <= 1;
            input_pos        <= 0;
            msg_timer        <= 0;
            assigned_spot    <= 0;
            park_timer       <= 0;
            seg_digit0       <= 4'hF;
            seg_digit1       <= 4'hF;
            seg_digit2       <= 4'hF;
            seg_digit3       <= 4'hF;
            seg_blink_mask   <= 4'b0000;
            seg_show_special <= 0;
            seg_special_code <= 0;
            for (ri = 0; ri < 16; ri = ri + 1) begin
                spot_status[ri] <= SPOT_EMPTY;
                spot_car[ri]    <= 16'd0;
            end
            for (ri = 0; ri < 4; ri = ri + 1)
                input_digits[ri] <= 4'd0;
        end else begin

            // ==============================================
            // 초음파 주차 확인 (모든 상태에서 항상 동작)
            // ==============================================
            if (spot_status[assigned_spot] == SPOT_ASSIGNED) begin
                if (obj_detected && ultra_valid) begin
                    if (park_timer >= PARK_TIMEOUT) begin
                        // 5초 연속 감지 → 주차 확정
                        spot_status[assigned_spot] <= SPOT_PARKED;
                        park_timer <= 0;
                    end else begin
                        park_timer <= park_timer + 1;
                    end
                end else begin
                    // 물체 사라짐 → 타이머 리셋
                    park_timer <= 0;
                end
            end

            // ==============================================
            // FSM
            // ==============================================
            case (state)
                // =============================================
                // IDLE
                // =============================================
                ST_IDLE: begin
                    seg_show_special <= 0;
                    seg_blink_mask   <= 4'b0000;
                    seg_digit0       <= 4'hF;
                    seg_digit1       <= 4'hF;
                    seg_digit2       <= 4'hF;
                    seg_digit3       <= 4'hF;

                    if (btnC_pulse) begin
                        if (mode_sw == 0) begin
                            // 입차
                            is_entry <= 1;
                            if (all_full) begin
                                state            <= ST_SHOW_MSG;
                                seg_show_special <= 1;
                                seg_special_code <= 2'd1; // FULL
                                msg_timer        <= 0;
                            end else begin
                                state     <= ST_INPUT;
                                input_pos <= 0;
                                input_digits[0] <= 4'd0;
                                input_digits[1] <= 4'd0;
                                input_digits[2] <= 4'd0;
                                input_digits[3] <= 4'd0;
                            end
                        end else begin
                            // 출차
                            is_entry  <= 0;
                            state     <= ST_INPUT;
                            input_pos <= 0;
                            input_digits[0] <= 4'd0;
                            input_digits[1] <= 4'd0;
                            input_digits[2] <= 4'd0;
                            input_digits[3] <= 4'd0;
                        end
                    end
                end

                // =============================================
                // INPUT: 차량번호 입력
                // =============================================
                ST_INPUT: begin
                    seg_show_special <= 0;
                    seg_digit0 <= input_digits[0];
                    seg_digit1 <= input_digits[1];
                    seg_digit2 <= input_digits[2];
                    seg_digit3 <= input_digits[3];

                    case (input_pos)
                        2'd0: seg_blink_mask <= 4'b1000;
                        2'd1: seg_blink_mask <= 4'b0100;
                        2'd2: seg_blink_mask <= 4'b0010;
                        2'd3: seg_blink_mask <= 4'b0001;
                    endcase

                    if (btnU_pulse) begin
                        if (input_digits[input_pos] == 4'd9)
                            input_digits[input_pos] <= 4'd0;
                        else
                            input_digits[input_pos] <= input_digits[input_pos] + 1;
                    end

                    if (btnD_pulse) begin
                        if (input_digits[input_pos] == 4'd0)
                            input_digits[input_pos] <= 4'd9;
                        else
                            input_digits[input_pos] <= input_digits[input_pos] - 1;
                    end

                    if (btnL_pulse && input_pos > 0)
                        input_pos <= input_pos - 1;

                    if (btnR_pulse && input_pos < 3)
                        input_pos <= input_pos + 1;

                    // 확인 (btnC)
                    if (btnC_pulse) begin
                        seg_blink_mask <= 4'b0000;

                        if (is_entry) begin
                            // ---- 입차 ----
                            if (car_found) begin
                                // 중복 차량번호 → 에러
                                state            <= ST_SHOW_MSG;
                                seg_show_special <= 1;
                                seg_special_code <= 2'd2; // Err
                                msg_timer        <= 0;
                            end else if (rand_found) begin
                                // 빈자리에 ASSIGNED (초음파 대기)
                                spot_status[rand_empty_spot] <= SPOT_ASSIGNED;
                                spot_car[rand_empty_spot]    <= input_car_num;
                                assigned_spot <= rand_empty_spot;
                                park_timer    <= 0;
                                state         <= ST_DONE;
                                msg_timer     <= 0;
                                // 7-seg에 배정 자리 표시 (층-번)
                                seg_digit0 <= rand_empty_spot[3:2] + 4'd1;
                                seg_digit1 <= 4'hE;
                                seg_digit2 <= 4'd0;
                                seg_digit3 <= rand_empty_spot[1:0] + 4'd1;
                            end else begin
                                // 만차
                                state            <= ST_SHOW_MSG;
                                seg_show_special <= 1;
                                seg_special_code <= 2'd1; // FULL
                                msg_timer        <= 0;
                            end
                        end else begin
                            // ---- 출차 ----
                            if (car_found) begin
                                spot_status[found_spot] <= SPOT_EMPTY;
                                spot_car[found_spot]    <= 16'd0;
                                state     <= ST_DONE;
                                msg_timer <= 0;
                            end else begin
                                // 차량번호 없음 → Err
                                state            <= ST_SHOW_MSG;
                                seg_show_special <= 1;
                                seg_special_code <= 2'd2;
                                msg_timer        <= 0;
                            end
                        end
                    end
                end

                // =============================================
                // DONE: 결과 표시 (2초)
                // =============================================
                ST_DONE: begin
                    seg_show_special <= 0;
                    if (!is_entry) begin
                        // 출차 완료: 차량번호 4자리 깜빡임
                        seg_blink_mask <= 4'b1111;
                        seg_digit0 <= input_digits[0];
                        seg_digit1 <= input_digits[1];
                        seg_digit2 <= input_digits[2];
                        seg_digit3 <= input_digits[3];
                    end else begin
                        seg_blink_mask <= 4'b0000;
                    end

                    msg_timer <= msg_timer + 1;
                    if (msg_timer >= MSG_DURATION)
                        state <= ST_IDLE;
                end

                // =============================================
                // SHOW_MSG: FULL / Err (2초)
                // =============================================
                ST_SHOW_MSG: begin
                    msg_timer <= msg_timer + 1;
                    if (msg_timer >= MSG_DURATION)
                        state <= ST_IDLE;
                    if (btnC_pulse)
                        state <= ST_IDLE;
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule

