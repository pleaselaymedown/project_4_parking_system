//============================================================================
// HC-SR04 초음파 센서 인터페이스
// 100MHz 클럭 기준
// - 60ms마다 10us 트리거 펄스 전송
// - 에코 펄스 폭 측정으로 거리 계산
// - 1m 이내 물체 감지 시 obj_in_range = 1
//============================================================================
module ultrasonic_sensor(
    input      clk,        // 100MHz
    input      rst,
    input      echo,       // Echo 핀 입력
    output reg trig,       // Trigger 핀 출력
    output reg obj_in_range, // 1m 이내 물체 감지
    output reg valid       // 측정 유효
);

    // 타이밍 상수 (100MHz 기준)
    localparam TRIG_CYCLES    = 1_000;       // 10us 트리거 펄스
    localparam CYCLE_PERIOD   = 6_000_000;   // 60ms 측정 주기
    localparam MAX_ECHO       = 2_500_000;   // 25ms 최대 에코 (약 4m)
    // 1m 거리 기준: 왕복시간 = 2*1/343 ≈ 5.83ms = 583,000 사이클
    localparam THRESHOLD_1M   = 583_000;

    // FSM 상태
    localparam S_IDLE    = 2'd0;
    localparam S_TRIG    = 2'd1;
    localparam S_WAIT    = 2'd2;  // 에코 시작 대기
    localparam S_MEASURE = 2'd3;  // 에코 폭 측정

    reg [1:0]  state;
    reg [22:0] cycle_cnt;     // 측정 주기 카운터
    reg [21:0] echo_cnt;      // 에코 폭 카운터
    reg [9:0]  trig_cnt;      // 트리거 펄스 카운터
    reg [19:0] wait_timeout;  // 에코 대기 타임아웃

    // Echo 핀 동기화 (메타스테이빌리티 방지)
    reg echo_sync1, echo_sync2;
    always @(posedge clk) begin
        echo_sync1 <= echo;
        echo_sync2 <= echo_sync1;
    end
    wire echo_s = echo_sync2;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state        <= S_IDLE;
            trig         <= 0;
            obj_in_range <= 0;
            valid        <= 0;
            cycle_cnt    <= 0;
            echo_cnt     <= 0;
            trig_cnt     <= 0;
            wait_timeout <= 0;
        end else begin
            case (state)
                S_IDLE: begin
                    trig <= 0;
                    if (cycle_cnt >= CYCLE_PERIOD) begin
                        cycle_cnt <= 0;
                        state     <= S_TRIG;
                        trig_cnt  <= 0;
                    end else begin
                        cycle_cnt <= cycle_cnt + 1;
                    end
                end

                S_TRIG: begin
                    trig <= 1;
                    if (trig_cnt >= TRIG_CYCLES) begin
                        trig         <= 0;
                        state        <= S_WAIT;
                        wait_timeout <= 0;
                    end else begin
                        trig_cnt <= trig_cnt + 1;
                    end
                end

                S_WAIT: begin
                    // 에코 시작(rising edge) 대기
                    if (echo_s) begin
                        state    <= S_MEASURE;
                        echo_cnt <= 0;
                    end else if (wait_timeout >= 500_000) begin
                        // 10ms 타임아웃 - 센서 없음
                        state <= S_IDLE;
                        valid <= 0;
                    end else begin
                        wait_timeout <= wait_timeout + 1;
                    end
                end

                S_MEASURE: begin
                    if (!echo_s || echo_cnt >= MAX_ECHO) begin
                        // 에코 종료 또는 최대치 초과
                        valid <= 1;
                        if (echo_cnt < THRESHOLD_1M && echo_cnt > 100)
                            obj_in_range <= 1;
                        else
                            obj_in_range <= 0;
                        state <= S_IDLE;
                    end else begin
                        echo_cnt <= echo_cnt + 1;
                    end
                end
            endcase
        end
    end

endmodule
