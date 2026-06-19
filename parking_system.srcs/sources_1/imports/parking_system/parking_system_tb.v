//============================================================================
// 주차장 시스템 테스트벤치
// 시뮬레이션용 - 시간 단축을 위해 타이머 값 조정 필요
//============================================================================
`timescale 1ns / 1ps

module parking_system_tb;

    // =========================================================
    // 신호 선언
    // =========================================================
    reg         clk;
    reg         btnC, btnU, btnD, btnL, btnR;
    reg  [1:0]  sw;
    reg         ultra_echo;

    wire [3:0]  vga_r, vga_g, vga_b;
    wire        vga_hs, vga_vs;
    wire [6:0]  seg;
    wire        dp;
    wire [3:0]  an;
    wire        ultra_trig;
    wire [15:0] led;

    // =========================================================
    // DUT 인스턴스
    // =========================================================
    parking_system_top DUT (
        .clk        (clk),
        .btnC       (btnC),
        .btnU       (btnU),
        .btnD       (btnD),
        .btnL       (btnL),
        .btnR       (btnR),
        .sw         (sw),
        .vga_r      (vga_r),
        .vga_g      (vga_g),
        .vga_b      (vga_b),
        .vga_hs     (vga_hs),
        .vga_vs     (vga_vs),
        .seg        (seg),
        .dp         (dp),
        .an         (an),
        .ultra_trig (ultra_trig),
        .ultra_echo (ultra_echo),
        .led        (led)
    );

    // =========================================================
    // 클럭 생성 (100MHz → 10ns 주기)
    // =========================================================
    initial clk = 0;
    always #5 clk = ~clk;

    // =========================================================
    // 버튼 눌림 태스크 (30ms 유지로 디바운스 통과)
    // 시뮬레이션 속도를 위해 짧게 조정
    // =========================================================
    task press_btn;
        input integer btn_id; // 0=C, 1=U, 2=D, 3=L, 4=R
        begin
            case (btn_id)
                0: btnC = 1;
                1: btnU = 1;
                2: btnD = 1;
                3: btnL = 1;
                4: btnR = 1;
            endcase
            #20_000_000; // 20ms
            case (btn_id)
                0: btnC = 0;
                1: btnU = 0;
                2: btnD = 0;
                3: btnL = 0;
                4: btnR = 0;
            endcase
            #5_000_000; // 5ms 대기
        end
    endtask

    // =========================================================
    // 메인 시뮬레이션 시나리오
    // =========================================================
    initial begin
        // 초기화
        btnC = 0; btnU = 0; btnD = 0; btnL = 0; btnR = 0;
        sw = 2'b00;
        ultra_echo = 0;

        // 리셋
        sw[1] = 1;
        #100_000_000; // 100ms
        sw[1] = 0;
        #50_000_000;  // 50ms 안정화

        $display("=== 시뮬레이션 시작 ===");
        $display("시간: %0t", $time);

        // ---------------------------------------------------------
        // 테스트 1: 입차 - 차량번호 1234 입력
        // ---------------------------------------------------------
        $display("\n--- 테스트 1: 입차 (번호: 1234) ---");
        sw[0] = 0; // 입차 모드

        // btnC: 입차 시작
        press_btn(0);
        $display("입차 시작, state=%d", DUT.u_ctrl.state);

        // 첫째 자리: 1 (btnU 1번)
        press_btn(1); // 0→1
        $display("digit0 = %d", DUT.u_ctrl.input_digits[0]);

        // 오른쪽 이동
        press_btn(4); // pos 0→1

        // 둘째 자리: 2 (btnU 2번)
        press_btn(1); // 0→1
        press_btn(1); // 1→2
        $display("digit1 = %d", DUT.u_ctrl.input_digits[1]);

        // 오른쪽 이동
        press_btn(4); // pos 1→2

        // 셋째 자리: 3 (btnU 3번)
        press_btn(1);
        press_btn(1);
        press_btn(1);
        $display("digit2 = %d", DUT.u_ctrl.input_digits[2]);

        // 오른쪽 이동
        press_btn(4); // pos 2→3

        // 넷째 자리: 4 (btnU 4번)
        press_btn(1);
        press_btn(1);
        press_btn(1);
        press_btn(1);
        $display("digit3 = %d", DUT.u_ctrl.input_digits[3]);

        // btnC: 입력 확인
        press_btn(0);
        $display("배정 완료! assigned_spot=%d", DUT.u_ctrl.assigned_spot);
        $display("spot_status[0]=%d", DUT.u_ctrl.spot_status[0]);

        // 자리 배정 표시 확인 대기
        #300_000_000; // 300ms

        // ---------------------------------------------------------
        // 테스트 2: 두번째 입차 - 차량번호 5678
        // ---------------------------------------------------------
        $display("\n--- 테스트 2: 입차 (번호: 5678) ---");

        // btnC: 입차 시작
        press_btn(0);

        // 첫째 자리: 5
        press_btn(1); press_btn(1); press_btn(1); press_btn(1); press_btn(1);
        press_btn(4); // 오른쪽

        // 둘째 자리: 6
        press_btn(1); press_btn(1); press_btn(1);
        press_btn(1); press_btn(1); press_btn(1);
        press_btn(4);

        // 셋째 자리: 7
        repeat(7) press_btn(1);
        press_btn(4);

        // 넷째 자리: 8
        repeat(8) press_btn(1);

        // 확인
        press_btn(0);
        $display("배정 완료! assigned_spot=%d", DUT.u_ctrl.assigned_spot);
        $display("spot0=%d, spot1=%d", DUT.u_ctrl.spot_status[0], DUT.u_ctrl.spot_status[1]);

        #200_000_000;

        // ---------------------------------------------------------
        // 테스트 3: 출차 - 차량번호 1234
        // ---------------------------------------------------------
        $display("\n--- 테스트 3: 출차 (번호: 1234) ---");
        sw[0] = 1; // 출차 모드
        #10_000_000;

        // btnC: 출차 시작
        press_btn(0);

        // 번호 1234 입력
        press_btn(1); // 1
        press_btn(4);
        press_btn(1); press_btn(1); // 2
        press_btn(4);
        press_btn(1); press_btn(1); press_btn(1); // 3
        press_btn(4);
        repeat(4) press_btn(1); // 4

        // 확인
        press_btn(0);
        $display("출차 처리! spot0=%d", DUT.u_ctrl.spot_status[0]);

        #300_000_000;

        // ---------------------------------------------------------
        // 테스트 4: 존재하지 않는 번호로 출차 시도
        // ---------------------------------------------------------
        $display("\n--- 테스트 4: 잘못된 번호 출차 (9999) ---");

        press_btn(0); // 출차 시작

        // 9999 입력
        repeat(9) press_btn(1);
        press_btn(4);
        repeat(9) press_btn(1);
        press_btn(4);
        repeat(9) press_btn(1);
        press_btn(4);
        repeat(9) press_btn(1);

        press_btn(0); // 확인
        $display("에러 표시: show_special=%d, code=%d",
                 DUT.u_ctrl.seg_show_special, DUT.u_ctrl.seg_special_code);

        #500_000_000;

        // ---------------------------------------------------------
        // 시뮬레이션 종료
        // ---------------------------------------------------------
        $display("\n=== 시뮬레이션 완료 ===");
        $display("LED 상태: %b", led);
        $finish;
    end

    // =========================================================
    // VCD 덤프 (파형 확인용)
    // =========================================================
    initial begin
        $dumpfile("parking_system.vcd");
        $dumpvars(0, parking_system_tb);
    end

    // =========================================================
    // 상태 모니터링
    // =========================================================
    always @(DUT.u_ctrl.state) begin
        $display("[%0t] Controller State = %d", $time, DUT.u_ctrl.state);
    end

endmodule
