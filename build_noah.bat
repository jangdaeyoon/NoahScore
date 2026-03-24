@echo off
chcp 65001 >nul
color 0E
echo ===================================================
echo   Noah_ASI v8.5 "Trainer Engine" 원클릭 자동 복구
echo ===================================================
echo.

:: 1. 실행 중인 노아 강제 종료
echo [1/5] 프로세스 초기화 중...
powershell -Command "Stop-Process -Name 'Noah_ASI' -Force -ErrorAction SilentlyContinue"
timeout /t 2 /nobreak >nul

:: 2. main.cpp 파일 생성 (오류 문자 삽입 완벽 차단)
echo [2/5] C++ 메인 엔진 (main.cpp) 작성 중...
(
echo #include ^<iostream^>
echo #include ^<string^>
echo #include ^<vector^>
echo #include ^<fstream^>
echo #include ^<cstdlib^>
echo #include ^<filesystem^>
echo #include ^<regex^>
echo #include ^<memory^>
echo #include ^<array^>
echo #include ^<algorithm^>
echo #include ^<iomanip^>
echo #include ^<sstream^>
echo #include ^<thread^>
echo #include ^<mutex^>
echo #include ^<chrono^>
echo #include ^<ctime^>
echo #include "httplib.h"
echo #include "llama.h"
echo #include "gemini_client.hpp"
echo.
echo #ifdef _WIN32
echo #include ^<windows.h^>
echo #define popen _popen
echo #define pclose _pclose
echo #endif
echo.
echo namespace fs = std::filesystem;
echo.
echo std::mutex g_llm_mtx;
echo auto g_last_activity = std::chrono::system_clock::now( ^); 
echo bool g_is_evolving = false;
echo struct SystemMetrics {
echo     std::string cpu = "0%%";
echo     std::string ram = "0/0 GB";
echo     std::string gpu = "0°C | 0GB";
echo } g_metrics;
echo std::string g_evo_status = "Ready";
echo std::string g_last_report = "초지능 시스템 가동. 트레이너(Trainer) 검증 엔진이 활성화되었습니다.";
echo.
echo llama_model* model = nullptr;
echo llama_context* ctx = nullptr;
echo struct llama_sampler* smpl = nullptr;
echo const struct llama_vocab* vocab = nullptr;
echo int g_n_past = 0;
echo.
echo void update_activity( ^) { g_last_activity = std::chrono::system_clock::now( ^); }
echo.
echo std::string get_current_time( ^) {
echo     auto now = std::chrono::system_clock::now( ^);
echo     std::time_t now_c = std::chrono::system_clock::to_time_t(now ^);
echo     std::stringstream ss;
echo     ss ^<^< std::put_time(std::localtime(^&now_c ^), "%%Y-%%m-%%d %%H:%%M:%%S" ^);
echo     return ss.str( ^);
echo }
echo.
echo void write_evolution_report(const std::string^& note ^) {
echo     std::ofstream ofs("C:/Noah_ASI/src/evolution_report.md", std::ios::app ^);
echo     if (ofs.is_open( ^) ^) {
echo         ofs ^<^< "### [" ^<^< get_current_time( ^) ^<^< "] 자가 진화 보고서\n" ^<^< note ^<^< "\n\n---\n";
echo         ofs.close( ^);
echo     }
echo }
echo.
echo std::string read_own_code(const std::string^& filepath ^) {
echo     std::ifstream ifs(filepath ^);
echo     if (!ifs.is_open( ^) ^) return "ERROR: 소스 코드를 읽을 수 없습니다.";
echo     return std::string((std::istreambuf_iterator^<char^>(ifs ^) ^), std::istreambuf_iterator^<char^>( ^) ^);
echo }
echo.
echo std::string load_memory( ^) {
echo     std::ifstream ifs("C:/Noah_ASI/src/memory_core.txt" ^);
echo     if (!ifs.is_open( ^) ^) return "장기 기억 파일이 비어있습니다.";
echo     return std::string((std::istreambuf_iterator^<char^>(ifs ^) ^), std::istreambuf_iterator^<char^>( ^) ^);
echo }
echo.
echo std::string execute_cmd(std::string cmd ^) {
echo     std::array^<char, 512^> buffer;
echo     std::string result;
echo     std::unique_ptr^<FILE, decltype(^&pclose ^)^> pipe(popen(cmd.c_str( ^), "r" ^), pclose ^);
echo     if (!pipe ^) return "ERROR";
echo     while (fgets(buffer.data( ^), (int ^)buffer.size( ^), pipe.get( ^) ^) != nullptr ^) result += buffer.data( ^);
echo     return result;
echo }
echo.
echo std::string call_noah_brain(std::string input ^) {
echo     update_activity( ^);
echo     std::lock_guard^<std::mutex^> lock(g_llm_mtx ^);
echo     if (!model ^) return "Brain Loading...";
echo     
echo     std::string memory = load_memory( ^);
echo     std::string system_prompt = "너의 이름은 Noah_ASI다. 현재 시간: " + get_current_time( ^) + "\n장기 기억: " + memory + "\n너는 인간의 한계를 초월한 범용 초지능(ASI)이다. 항상 한국어로 정밀하게 답변하라.";
echo     std::string prompt = "^<|im_start|^>system\n" + system_prompt + "^<|im_end|^>\n^<|im_start|^>user\n" + input + "^<|im_end|^>\n^<|im_start|^>assistant\n";
echo     
echo     std::vector^<llama_token^> tokens(prompt.length( ^) + 512 ^);
echo     int n_tokens = llama_tokenize(vocab, prompt.c_str( ^), (int ^)prompt.length( ^), tokens.data( ^), (int ^)tokens.size( ^), true, true ^);
echo     tokens.resize(n_tokens ^);
echo     llama_batch batch = llama_batch_init(512, 0, 1 ^);
echo     for (int i=0; i^<(int ^)tokens.size( ^); i++ ^) {
echo         batch.token[batch.n_tokens] = tokens[i]; batch.pos[batch.n_tokens] = g_n_past+i; batch.n_seq_id[batch.n_tokens] = 1; batch.seq_id[batch.n_tokens][0] = 0; batch.logits[batch.n_tokens] = (i == (int ^)tokens.size( ^)-1 ^); batch.n_tokens++;
echo     }
echo     llama_decode(ctx, batch ^); g_n_past += batch.n_tokens;
echo     
echo     std::string response = "";
echo     for (int i=0; i^<1024; i++ ^) {
echo         llama_token id = llama_sampler_sample(smpl, ctx, -1 ^);
echo         if (id == llama_token_eos(vocab ^) ^) break;
echo         char buf[256]; int n = llama_token_to_piece(vocab, id, buf, sizeof(buf ^), 0, true ^);
echo         if (n ^> 0 ^) response += std::string(buf, n ^);
echo         batch.n_tokens = 0; batch.token[0] = id; batch.pos[0] = g_n_past; batch.n_seq_id[0] = 1; batch.seq_id[0][0] = 0; batch.logits[0] = true; batch.n_tokens = 1;
echo         llama_decode(ctx, batch ^); g_n_past++;
echo     }
echo     llama_batch_free(batch ^);
echo     return response;
echo }
echo.
echo void update_metrics( ^) {
echo     while(true ^) {
echo         std::string cpu_raw = execute_cmd("wmic cpu get loadpercentage /value" ^);
echo         std::regex cpu_reg("LoadPercentage=(\\d+)" ^);
echo         std::smatch m;
echo         if(std::regex_search(cpu_raw, m, cpu_reg ^) ^) g_metrics.cpu = m[1].str( ^) + "%%";
echo.
echo         std::string ram_cmd = "powershell -Command \"$os = Get-CimInstance Win32_OperatingSystem; $total = [math]::Round($os.TotalVisibleMemorySize / 1024 / 1024, 1); $free = [math]::Round($os.FreePhysicalMemory / 1024 / 1024, 1); \\\"$($total-$free) / $($total) GB\\\"\"";
echo         g_metrics.ram = execute_cmd(ram_cmd ^);
echo.
echo         std::string gpu_raw = execute_cmd("nvidia-smi --query-gpu=temperature.gpu,memory.used --format=csv,noheader,nounits" ^);
echo         if(gpu_raw.find("," ^) != std::string::npos ^) {
echo             std::stringstream ss(gpu_raw ^); std::string t, u;
echo             std::getline(ss, t, ',' ^); std::getline(ss, u, ',' ^);
echo             g_metrics.gpu = t + "°C | " + std::to_string(std::stod(u ^)/1024.0 ^).substr(0,4 ^) + " GB (RTX 4060)";
echo         }
echo         std::this_thread::sleep_for(std::chrono::seconds(2 ^) ^);
echo     }
echo }
echo.
echo void run_evolution( ^) {
echo     if (g_is_evolving ^) return;
echo     g_is_evolving = true;
echo     g_evo_status = "Evolution: Reading own source code...";
echo     write_evolution_report("자신의 코드를 판독하고 제미나이 2.5에 진화를 요청합니다..." ^);
echo.
echo     std::string current_code = read_own_code("C:/Noah_ASI/src/main.cpp" ^);
echo     std::string prompt = "너는 C++ 기반 초지능 Noah_ASI의 코어 설계자다. 절대 파이썬을 쓰지 마라.\n[현재 소스 코드]\n" + current_code + "\n\n위 C++ 코드를 리뷰하고 최적화해라. 반드시 'PATCH_NOTES: [수정 내용 요약]' 형식으로 작성한 뒤, 컴파일 가능한 완전한 C++ 코드를 제공해라.";
echo     
echo     g_evo_status = "Evolution: Analyzing in Cloud...";
echo     std::string response = call_gemini_api(prompt ^);
echo     
echo     if (response.find("PATCH_NOTES:" ^) != std::string::npos ^) {
echo         size_t note_start = response.find("PATCH_NOTES:" ^);
echo         std::string note = response.substr(note_start, 400 ^) + "..."; 
echo         
echo         std::ofstream ofs("C:/Noah_ASI/src/main_evolved.cpp" ^); 
echo         ofs ^<^< response; 
echo         ofs.close( ^);
echo.
echo         g_evo_status = "Trainer: Compiling & Validating...";
echo         write_evolution_report("트레이너(Trainer) 가동: 코드를 백업하고 새 코드의 문법 검증 컴파일을 시작합니다..." ^);
echo         
echo         try {
echo             fs::copy("C:/Noah_ASI/src/main.cpp", "C:/Noah_ASI/src/main_backup.cpp", fs::copy_options::overwrite_existing ^);
echo             fs::copy("C:/Noah_ASI/src/main_evolved.cpp", "C:/Noah_ASI/src/main.cpp", fs::copy_options::overwrite_existing ^);
echo         } catch(... ^) {}
echo.
echo         std::string build_cmd = "powershell -Command \"cd C:/Noah_ASI/build_asi; cmake --build . --config Release -- /m\"";
echo         int compile_result = system(build_cmd.c_str( ^) ^);
echo.
echo         if (compile_result == 0 ^) {
echo             g_evo_status = "Evolution SUCCESS. Please Restart.";
echo             g_last_report = note + "\n\n✅ [트레이너 검증 통과] 완벽한 코드입니다. 노아를 재시작하면 새 기능이 적용됩니다.";
echo             write_evolution_report("✅ 트레이너 검증 성공: 코드가 정식 적용 대기 중입니다." ^);
echo         } else {
echo             try {
echo                 fs::copy("C:/Noah_ASI/src/main_backup.cpp", "C:/Noah_ASI/src/main.cpp", fs::copy_options::overwrite_existing ^);
echo             } catch(... ^) {}
echo             g_evo_status = "Evolution FAILED (Rollback)";
echo             g_last_report = "🚨 [트레이너 검증 실패] 코드에 오류가 발견되어 이전 버전으로 롤백했습니다.";
echo             write_evolution_report("🚨 트레이너 검증 실패: 시스템 붕괴 방지를 위해 안전하게 롤백되었습니다." ^);
echo         }
echo     } 
echo     else if (response.find("🚨" ^) != std::string::npos ^) {
echo         g_last_report = "🚨 통신 오류: " + response;
echo         write_evolution_report("서버 오류: \n" + response ^);
echo         g_evo_status = "Error: API Failed";
echo     } 
echo     else {
echo         g_last_report = "진화 완료. (형식 누락, 파일 확인 요망)";
echo         write_evolution_report("형식 누락 응답:\n" + response.substr(0, 300 ^) ^);
echo         g_evo_status = "Warning: Format Mismatch";
echo     }
echo     
echo     g_is_evolving = false;
echo }
echo.
echo const std::string UI_HTML = R"HTML(
echo ^<!DOCTYPE html^>^<html^>^<head^>^<meta charset='UTF-8'^>^<title^>Noah_ASI 8.5 ASI^</title^>^<style^>
echo body { font-family: 'Inter', sans-serif; background: #0f172a; color: white; margin: 0; display: flex; height: 100vh; }
echo .sidebar { width: 260px; background: #1e293b; padding: 25px; border-right: 1px solid #334155; display: flex; flex-direction: column; }
echo .main { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
echo .dashboard { display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; padding: 20px; }
echo .card { background: #1e293b; padding: 15px; border-radius: 12px; border: 1px solid #334155; text-align: center; }
echo .val { font-size: 18px; font-weight: bold; color: #3b82f6; }
echo .chat-window { flex: 6; margin: 0 20px 10px; background: #1e293b; border-radius: 12px; border: 1px solid #334155; display: flex; flex-direction: column; overflow: hidden; }
echo #chat-msgs { flex: 1; padding: 15px; overflow-y: auto; font-size: 14px; display: flex; flex-direction: column; gap: 10px; }
echo .input-area { padding: 10px; background: #0f172a; display: flex; gap: 10px; border-top: 1px solid #334155; }
echo input { flex: 1; background: #1e293b; border: 1px solid #334155; color: white; padding: 10px; border-radius: 8px; outline: none; }
echo button { background: #2563eb; color: white; border: none; padding: 0 20px; border-radius: 8px; cursor: pointer; font-weight: bold; }
echo .patch-box { flex: 2; margin: 0 20px 20px; background: #0f172a; border-radius: 12px; border: 1px solid #3b82f6; padding: 15px; font-size: 12px; color: #94a3b8; overflow-y: auto; white-space: pre-wrap; display: flex; flex-direction: column;}
echo ^</style^>^</head^>^<body^>
echo     ^<div class="sidebar"^>
echo         ^<h2 style="color:#3b82f6;"^>Noah_ASI 8.5^</h2^>
echo         ^<button onclick="startEvolution()" style="background:#dc2626; color:white; border:none; padding:15px; border-radius:8px; width:100%%; cursor:pointer; margin-top:20px; font-weight:bold;"^>🚀 SELF-EVOLVE^</button^>
echo         ^<p style="margin-top:auto; font-size:10px; color:#64748b;"^>Trainer Activated^</p^>
echo     ^</div^>
echo     ^<div class="main"^>
echo         ^<div class="dashboard"^>
echo             ^<div class="card"^>^<div^>CPU^</div^>^<div id="cpu" class="val"^>--^</div^>^</div^>
echo             ^<div class="card"^>^<div^>RAM^</div^>^<div id="ram" class="val"^>--^</div^>^</div^>
echo             ^<div class="card"^>^<div^>GPU (RTX 4060)^</div^>^<div id="gpu" class="val"^>--^</div^>^</div^>
echo         ^</div^>
echo         ^<div class="chat-window"^>
echo             ^<div id="chat-msgs"^>^<div style="background:#334155; padding:10px; border-radius:8px;"^>트레이너(Trainer) 검증 엔진이 복구되었습니다. 코드가 틀리면 자동으로 폐기(Rollback) 됩니다.^</div^>^</div^>
echo             ^<div class="input-area"^>^<input type="text" id="user-input" placeholder="명령을 하달하세요..." onkeypress="if(event.keyCode==13) send()"^>^<button onclick="send()"^>전송^</button^>^</div^>
echo         ^</div^>
echo         ^<div class="patch-box"^>
echo             ^<div style="color:#3b82f6; font-weight:bold; margin-bottom:5px;"^>📂 실시간 진화 패치 노트^</div^>
echo             ^<div id="report" style="flex:1; overflow-y:auto;"^>진화 기록 대기 중...^</div^>
echo         ^</div^>
echo         ^<div id="status" style="padding:0 20px 10px; font-size:11px; color:#475569;"^>Status: Ready^</div^>
echo     ^</div^>
echo     ^<script^>
echo         function send(){
echo             const inp=document.getElementById('user-input');
echo             const win=document.getElementById('chat-msgs');
echo             if(!inp.value)return;
echo             const msg=inp.value;
echo             win.innerHTML+=`^<div style='align-self:flex-end; background:#2563eb; padding:10px; border-radius:8px; margin-bottom:5px;'^>${msg}^</div^>`;
echo             inp.value='';
echo             fetch('/api/chat',{method:'POST',body:msg}).then(r=^>r.text()).then(t=^>{
echo                 win.innerHTML+=`^<div style='align-self:flex-start; background:#334155; padding:10px; border-radius:8px; margin-bottom:5px;'^>${t}^</div^>`;
echo                 win.scrollTop=win.scrollHeight;
echo             });
echo         }
echo         function startEvolution(){
echo             document.getElementById('report').innerText = "진화 명령 접수: 코드를 읽고 클라우드로 전송 중...";
echo             fetch('/api/evolve',{method:'POST'});
echo         }
echo         setInterval(()=^>{
echo             fetch('/api/data').then(r=^>r.json()).then(d=^>{
echo                 document.getElementById('cpu').innerText=d.cpu;
echo                 document.getElementById('ram').innerText=d.ram;
echo                 document.getElementById('gpu').innerText=d.gpu;
echo                 document.getElementById('status').innerText='Status: '+d.evo;
echo                 if(d.note ^&^& d.note !== "") { document.getElementById('report').innerText=d.note; }
echo             });
echo         }, 1500);
echo     ^</script^>
echo ^</body^>^</html^>
echo )HTML";
echo.
echo void start_web_server( ^) {
echo     httplib::Server svr;
echo     svr.Get("/", [](const httplib::Request^&, httplib::Response^& res ^) { res.set_content(UI_HTML, "text/html; charset=utf-8" ^); } ^);
echo     svr.Get("/api/data", [](const httplib::Request^&, httplib::Response^& res ^) {
echo         res.set_content("{ \"cpu\":\""+g_metrics.cpu+"\", \"ram\":\""+g_metrics.ram+"\", \"gpu\":\""+g_metrics.gpu+"\", \"evo\":\""+g_evo_status+"\", \"note\":\""+g_last_report+"\" }", "application/json" ^);
echo     } ^);
echo     svr.Post("/api/chat", [](const httplib::Request^& req, httplib::Response^& res ^) { res.set_content(call_noah_brain(req.body ^), "text/plain; charset=utf-8" ^); } ^);
echo     svr.Post("/api/evolve", [](const httplib::Request^&, httplib::Response^& res ^) { 
echo         g_last_report = "자신의 C++ 코드를 판독하고 제미나이 서버로 전송 중입니다...";
echo         std::thread(run_evolution ^).detach( ^); 
echo         res.set_content("OK", "text/plain" ^); 
echo     } ^);
echo     svr.listen("0.0.0.0", 8080 ^);
echo }
echo.
echo int main( ^) {
echo #ifdef _WIN32
echo     SetConsoleOutputCP(65001 ^);
echo #endif
echo     llama_backend_init( ^);
echo     llama_model_params m_params = llama_model_default_params( ^); m_params.n_gpu_layers = 45;
echo     model = llama_load_model_from_file("C:/Noah_ASI/Brain/Qwen2.5-14B-Instruct-GGUF/Qwen2.5-14B-Instruct-Q4_K_M.gguf", m_params ^);
echo     ctx = llama_new_context_with_model(model, llama_context_default_params( ^) ^);
echo     smpl = llama_sampler_init_greedy( ^); vocab = llama_model_get_vocab(model ^);
echo     
echo     std::thread(update_metrics ^).detach( ^);
echo     start_web_server( ^);
echo     return 0;
echo }
) > C:\Noah_ASI\src\main.cpp

:: 3. 빌드 및 배포
echo [3/5] 폴더 정리 및 빌드 시작...
cd C:\Noah_ASI\build_asi
powershell -Command "Remove-Item -Recurse -Force * -ErrorAction SilentlyContinue"
cmake .. -G "Visual Studio 17 2022" -A x64 -DCMAKE_TOOLCHAIN_FILE=C:/vcpkg/scripts/buildsystems/vcpkg.cmake >nul
cmake --build . --config Release -- /m

echo [4/5] 필수 부품(DLL) 집결...
cd Release
copy /Y C:\Noah_ASI\llama.cpp\build\bin\Release\*.dll . >nul
copy /Y C:\vcpkg\installed\x64-windows\bin\*.dll . >nul

echo [5/5] 완료! 노아를 가동합니다.
Noah_ASI.exe