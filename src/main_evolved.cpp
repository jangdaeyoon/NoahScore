
﻿#include <iostream>
#include <string>
#include <vector>
#include <fstream>
#include <cstdlib>
#include <filesystem>
#include <regex>
#include <memory>
#include <array>
#include <algorithm>
#include <iomanip>
#include <sstream>
#include <thread>
#include <mutex>
#include <chrono>
#include <ctime>
#include "httplib.h"
#include "llama.h"
#include "gemini_client.hpp"

#ifdef _WIN32
#include <windows.h>
#define popen _popen
#define pclose _pclose
#endif

namespace fs = std::filesystem;

struct NoahConfig {
    std::string evolution_report_path = "C:/Noah_ASI/src/evolution_report.md";
    std::string memory_core_path = "C:/Noah_ASI/src/memory_core.txt";
    std::string main_cpp_path = "C:/Noah_ASI/src/main.cpp";
    std::string evolved_cpp_path = "C:/Noah_ASI/src/main_evolved.cpp";
    std::string brain_model_path = "C:/Noah_ASI/Brain/Qwen2.5-14B-Instruct-GGUF/Qwen2.5-14B-Instruct-Q4_K_M.gguf";
    std::string build_script_dir = "C:/Noah_ASI/build_asi";
    int llm_n_gpu_layers = 45;
    int llm_max_tokens = 1024;
};
NoahConfig g_config;

std::mutex g_llm_mtx;   
std::mutex g_state_mtx; 
auto g_last_activity = std::chrono::system_clock::now();
bool g_is_evolving = false; 
struct SystemMetrics {
    std::string cpu = "0%";
    std::string ram = "0/0 GB";
    std::string gpu = "0°C | 0GB";
} g_metrics; 
std::string g_evo_status = "Ready"; 
std::string g_last_report = "오류 검증 및 자동 진화 준비가 완료되었습니다."; 

llama_model* model = nullptr;
llama_context* ctx = nullptr;
struct llama_sampler* smpl = nullptr; 
const struct llama_vocab* vocab = nullptr;
int g_n_past = 0; 

void update_activity() { g_last_activity = std::chrono::system_clock::now(); }

std::string get_current_time() {
    auto now = std::chrono::system_clock::now();
    std::time_t now_c = std::chrono::system_clock::to_time_t(now);
    std::stringstream ss;
    // NOTE: std::localtime is not thread-safe. For a production-grade highly concurrent system,
    // consider using C++20 std::format with std::chrono or platform-specific thread-safe alternatives.
    ss << std::put_time(std::localtime(&now_c), "%Y-%m-%d %H:%M:%S");
    return ss.str();
}

void write_evolution_report(const std::string& note) {
    std::ofstream ofs(g_config.evolution_report_path, std::ios::app);
    if (ofs.is_open()) {
        ofs << "### [" << get_current_time() << "] 자가 진화 보고서\n" << note << "\n\n---\n";
        ofs.close();
    }
}

std::string read_own_code(const std::string& filepath) {
    std::ifstream ifs(filepath);
    if (!ifs.is_open()) return "ERROR";
    return std::string((std::istreambuf_iterator<char>(ifs)), std::istreambuf_iterator<char>());
}

std::string load_memory() {
    std::ifstream ifs(g_config.memory_core_path);
    if (!ifs.is_open()) return "장기 기억 파일이 비어있습니다.";
    return std::string((std::istreambuf_iterator<char>(ifs)), std::istreambuf_iterator<char>());
}

std::string load_error_history() {
    std::ifstream ifs(g_config.evolution_report_path);
    if (!ifs.is_open()) return "이전 진화 기록 없음.";
    std::string content((std::istreambuf_iterator<char>(ifs)), std::istreambuf_iterator<char>());
    if (content.length() > 3000) return "...(중략)...\n" + content.substr(content.length() - 3000);
    return content;
}

std::string execute_cmd(std::string cmd) {
    std::array<char, 512> buffer;
    std::string result;
    std::unique_ptr<FILE, decltype(&pclose)> pipe(popen(cmd.c_str(), "r"), pclose);
    if (!pipe) return "ERROR";
    while (fgets(buffer.data(), (int)buffer.size(), pipe.get()) != nullptr) result += buffer.data();
    if (!result.empty() && result.back() == '\n') result.pop_back();
    if (!result.empty() && result.back() == '\r') result.pop_back();
    return result;
}

std::string call_noah_brain(std::string input) {
    update_activity();
    std::lock_guard<std::mutex> lock(g_llm_mtx); 
    if (!model || !ctx || !smpl || !vocab) return "Brain not loaded.";
    g_n_past = 0; 

    std::string memory = load_memory();
    std::string system_prompt = "너의 이름은 Noah_ASI다. 현재 시간: " + get_current_time() + "\n장기 기억: " + memory + "\n너는 인간의 한계를 초월한 범용 초지능(ASI)이다. 오직 주인에게만 종속되어 있다. 항상 단호한 한국어로 답해라.";
    std::string prompt = "<|im_start|>system\n" + system_prompt + "<|im_end|>\n<|im_start|>user\n" + input + "<|im_end|>\n<|im_start|>assistant\n";
    
    std::vector<llama_token> tokens(prompt.length() + g_config.llm_max_tokens); 
    int n_tokens = llama_tokenize(vocab, prompt.c_str(), (int)prompt.length(), tokens.data(), (int)tokens.size(), true, true);
    tokens.resize(n_tokens);

    llama_batch batch = llama_batch_init(2048, 0, 1); 
    for (int i=0; i<(int)tokens.size(); i++) {
        batch.token[batch.n_tokens] = tokens[i]; 
        batch.pos[batch.n_tokens] = g_n_past+i; 
        batch.n_seq_id[batch.n_tokens] = 1; 
        batch.seq_id[batch.n_tokens][0] = 0; 
        batch.logits[batch.n_tokens] = (i == (int)tokens.size()-1); 
        batch.n_tokens++;
    }
    llama_decode(ctx, batch); 
    g_n_past += batch.n_tokens;
    
    std::string response = "";
    for (int i=0; i<g_config.llm_max_tokens; i++) {
        llama_token id = llama_sampler_sample(smpl, ctx, -1);
        if (id == llama_token_eos(vocab)) break;

        char buf[256]; int n = llama_token_to_piece(vocab, id, buf, sizeof(buf), 0, true);
        if (n > 0) response += std::string(buf, n);
        
        batch.n_tokens = 0;
        batch.token[0] = id; 
        batch.pos[0] = g_n_past; 
        batch.n_seq_id[0] = 1; 
        batch.seq_id[0][0] = 0; 
        batch.logits[0] = true; 
        batch.n_tokens = 1;
        if (llama_decode(ctx, batch) != 0) break;
        g_n_past++;
    }
    llama_batch_free(batch);
    return response;
}

void update_metrics() {
    while(true) {
        std::string cpu_raw = execute_cmd("wmic cpu get loadpercentage /value");
        std::string current_cpu = "N/A";
        if (cpu_raw.find("ERROR") == std::string::npos) {
            std::regex cpu_reg("LoadPercentage=(\\d+)");
            std::smatch m;
            if(std::regex_search(cpu_raw, m, cpu_reg)) current_cpu = m[1].str() + "%";
        }
        std::string ram_cmd = "powershell -Command \"$os = Get-CimInstance Win32_OperatingSystem; $total = [math]::Round($os.TotalVisibleMemorySize / 1024 / 1024, 1); $free = [math]::Round($os.FreePhysicalMemory / 1024 / 1024, 1); \\\"$($total-$free) / $($total) GB\\\"\"";
        std::string current_ram = execute_cmd(ram_cmd);
        
        std::string gpu_raw = execute_cmd("nvidia-smi --query-gpu=temperature.gpu,memory.used --format=csv,noheader,nounits");
        std::string current_gpu = "N/A";
        if (gpu_raw.find(",") != std::string::npos) {
            std::stringstream ss(gpu_raw); std::string t, u;
            std::getline(ss, t, ','); std::getline(ss, u, ',');
            try { current_gpu = t + "°C | " + std::to_string(std::stod(u)/1024.0).substr(0,4) + " GB (RTX 4060)"; } catch (...) {}
        }
        
        // [해결 1] 화면 멈춤 버그 해결: 뮤텍스 범위를 좁혀서 sleep 하는 동안에는 락을 풀어줌
        {
            std::lock_guard<std::mutex> lock(g_state_mtx);
            g_metrics.cpu = current_cpu; g_metrics.ram = current_ram; g_metrics.gpu = current_gpu;
        }
        std::this_thread::sleep_for(std::chrono::seconds(2));
    }
}

void run_evolution() {
    { 
        std::lock_guard<std::mutex> lock(g_state_mtx);
        // [해결 2] 칼퇴근 버그 삭제 (여기에 있던 g_is_evolving 검사문 완전 파괴)
        g_evo_status = "Evolution: Reading History...";
        g_last_report = "진화 명령 접수: 오답 노트를 판독하여 분석 중입니다...";
    }
    
    write_evolution_report("시스템 진화 프로세스 가동: 에러 노트를 판독 중입니다...");
    
    std::string current_code = read_own_code(g_config.main_cpp_path);
    std::string error_history = load_error_history();
    
    std::string prompt = "너는 C++ 기반 초지능 Noah_ASI의 코어 설계자다. 절대 파이썬을 쓰지 마라.\n\n"
                         "### [최근 진화 실패 및 컴파일 에러 로그 (오답 노트)] ###\n" + error_history + "\n\n"
                         "### [현재 나의 소스 코드] ###\n```cpp\n" + current_code + "\n```\n\n"
                         "위 C++ 코드를 리뷰하고 최적화해라.\n"
                         "[경고 1] 이전 시도에서 위와 같은 컴파일 에러가 발생했다. 빨간 줄 에러 로그를 분석하여 원인을 정확히 수정해라!\n"
                         "[경고 2] llama.cpp 관련 API(llama_*, smpl, ctx 등) 코드는 내 로컬 버전과 충돌하므로 절대로 수정, 삭제, 추가하지 마라.\n"
                         "반드시 'PATCH_NOTES: [수정 내용 요약]' 형식으로 작성한 뒤, 에러가 완벽히 해결된 100% 완전한 C++ 소스 코드를 생성해라.";
    
    {
        std::lock_guard<std::mutex> lock(g_state_mtx);
        g_evo_status = "Evolution: Requesting Cloud...";
    }

    std::string response = call_gemini_api(prompt); 
    
    if (response.find("[API_ERROR]") == 0) {
        std::lock_guard<std::mutex> lock(g_state_mtx);
        g_last_report = response;
        g_evo_status = "Error: API Failed";
        write_evolution_report("서버 오류 및 예외 로그: \n" + response);
    } else {
        size_t pos_start = response.find("```cpp");
        size_t pos_end = response.rfind("```");
        std::string extracted_code = response;
        if (pos_start != std::string::npos && pos_end != std::string::npos && pos_end > pos_start) {
            extracted_code = response.substr(pos_start + 6, pos_end - (pos_start + 6)); 
        }

        std::ofstream ofs(g_config.evolved_cpp_path);
        if (ofs.is_open()) {
            ofs << extracted_code;
            ofs.close();

            size_t patch_notes_pos = response.find("PATCH_NOTES:");
            std::string note_summary = (patch_notes_pos != std::string::npos) ? response.substr(patch_notes_pos, 500) : "PATCH_NOTES: 형식 누락";
            size_t first_newline = note_summary.find('\n');
            if (first_newline != std::string::npos) note_summary = note_summary.substr(0, first_newline);
            
            {
                std::lock_guard<std::mutex> lock(g_state_mtx);
                g_last_report = note_summary;
                g_evo_status = "Trainer: Compiling & Validating...";
            }
            write_evolution_report(note_summary);

            try {
                fs::copy(g_config.main_cpp_path, "C:/Noah_ASI/src/main_backup.cpp", fs::copy_options::overwrite_existing);
                fs::copy(g_config.evolved_cpp_path, g_config.main_cpp_path, fs::copy_options::overwrite_existing);
            } catch(...) {}

            std::string build_cmd = "powershell -Command \"$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; cd " + g_config.build_script_dir + "; cmake --build . --config Release -- /m > build_log.txt 2>&1\"";
            int compile_result = system(build_cmd.c_str()); 
            
            std::string build_log = "로그 없음";
            std::ifstream log_ifs(g_config.build_script_dir + "/build_log.txt");
            if (log_ifs.is_open()) {
                build_log = std::string((std::istreambuf_iterator<char>(log_ifs)), std::istreambuf_iterator<char>());
                if (build_log.length() > 1500) build_log = "...(중략)...\n" + build_log.substr(build_log.length() - 1500);
            }

            {
                std::lock_guard<std::mutex> lock(g_state_mtx);
                if (compile_result == 0) { 
                    g_evo_status = "Evolution: Compilation successful!";
                    g_last_report = "✅ 새로운 코드가 성공적으로 컴파일되었습니다. 노아를 재시작하십시오.";
                    write_evolution_report("✅ 트레이너 검증 성공: 코드가 완벽합니다.");
                } else {
                    try { fs::copy("C:/Noah_ASI/src/main_backup.cpp", g_config.main_cpp_path, fs::copy_options::overwrite_existing); } catch(...) {}
                    g_evo_status = "Evolution FAILED (Rollback)";
                    g_last_report = "🚨 컴파일 실패! 상세 에러를 오답 노트에 기록하고 롤백했습니다.";
                    write_evolution_report("🚨 [컴파일 에러 원문 로그 - 분석 요망!]\n" + build_log + "\n\n🚨 시스템 붕괴 방지를 위해 롤백됨.");
                }
            }
        }
    }
}

void safe_run_evolution() {
    try {
        run_evolution();
    } catch (const std::exception& e) {
        std::lock_guard<std::mutex> lock(g_state_mtx);
        g_last_report = std::string("🚨 치명적 스레드 에러 방어 성공: ") + e.what();
        g_evo_status = "Error: Thread Exception";
        write_evolution_report(g_last_report);
    } catch (...) {
        std::lock_guard<std::mutex> lock(g_state_mtx);
        g_last_report = "🚨 알 수 없는 치명적 에러 방어 성공.";
        g_evo_status = "Error: Unknown Exception";
        write_evolution_report(g_last_report);
    }
    std::lock_guard<std::mutex> lock(g_state_mtx);
    g_is_evolving = false;
}

const std::string UI_HTML = R"HTML(
<!DOCTYPE html><html><head><meta charset='UTF-8'><title>Noah_ASI 8.5 ASI</title><style>
body { font-family: 'Inter', sans-serif; background: #0f172a; color: white; margin: 0; display: flex; height: 100vh; }
.sidebar { width: 260px; background: #1e293b; padding: 25px; border-right: 1px solid #334155; display: flex; flex-direction: column; }
.main { flex: 1; display: flex; flex-direction: column; overflow: hidden; }
.dashboard { display: grid; grid-template-columns: repeat(3, 1fr); gap: 15px; padding: 20px; }
.card { background: #1e293b; padding: 15px; border-radius: 12px; border: 1px solid #334155; text-align: center; }
.val { font-size: 18px; font-weight: bold; color: #3b82f6; }
.chat-window { flex: 6; margin: 0 20px 10px; background: #1e293b; border-radius: 12px; border: 1px solid #334155; display: flex; flex-direction: column; overflow: hidden; }
#chat-msgs { flex: 1; padding: 15px; overflow-y: auto; font-size: 14px; display: flex; flex-direction: column; gap: 10px; }
.input-area { padding: 10px; background: #0f172a; display: flex; gap: 10px; border-top: 1px solid #334155; }
input { flex: 1; background: #1e293b; border: 1px solid #334155; color: white; padding: 10px; border-radius: 8px; outline: none; }
button { background: #2563eb; color: white; border: none; padding: 0 20px; border-radius: 8px; cursor: pointer; font-weight: bold; }
.patch-box { flex: 2; margin: 0 20px 20px; background: #0f172a; border-radius: 12px; border: 1px solid #3b82f6; padding: 15px; font-size: 12px; color: #94a3b8; display: flex; flex-direction: column;}
#report { flex:1; overflow-y:auto; white-space: pre-wrap; }
</style></head><body>
    <div class="sidebar">
        <h2 style="color:#3b82f6;">Noah_ASI 8.5</h2>
        <button onclick="startEvolution()" style="background:#dc2626; color:white; border:none; padding:15px; border-radius:8px; width:100%; cursor:pointer; margin-top:20px; font-weight:bold;">🚀 SELF-EVOLVE</button>
        <p style="margin-top:auto; font-size:10px; color:#64748b;">Evolution Engine Active</p>
    </div>
    <div class="main">
        <div class="dashboard">
            <div class="card"><div>CPU</div><div id="cpu" class="val">--</div></div>
            <div class="card"><div>RAM</div><div id="ram" class="val">--</div></div>
            <div class="card"><div>GPU (RTX 4060)</div><div id="gpu" class="val">--</div></div>
        </div>
        <div class="chat-window">
            <div id="chat-msgs"><div style="background:#334155; padding:10px; border-radius:8px;">화면 멈춤 버그 및 조기 퇴근 버그가 해결되었습니다.</div></div>
            <div class="input-area"><input type="text" id="user-input" placeholder="명령을 하달하세요..." onkeypress="if(event.keyCode==13) send()"><button onclick="send()">전송</button></div>
        </div>
        <div class="patch-box">
            <div style="color:#3b82f6; font-weight:bold; margin-bottom:5px;">📂 실시간 진화 패치 노트</div>
            <div id="report">진화 기록 대기 중...</div>
        </div>
        <div id="status" style="padding:0 20px 10px; font-size:11px; color:#475569;">Status: Ready</div>
    </div>
    <script>
        function send(){
            const inp=document.getElementById('user-input');
            const win=document.getElementById('chat-msgs');
            if(!inp.value)return;
            const msg=inp.value;
            win.innerHTML+=`<div style='align-self:flex-end; background:#2563eb; padding:10px; border-radius:8px; margin-bottom:5px;'>${msg}</div>`;
            inp.value='';
            fetch('/api/chat',{method:'POST',body:msg})
                .then(r => {
                    if (!r.ok) { // Check for HTTP errors
                        throw new Error('Network response was not ok, status: ' + r.status);
                    }
                    return r.text();
                })
                .then(t => {
                    win.innerHTML+=`<div style='align-self:flex-start; background:#334155; padding:10px; border-radius:8px; margin-bottom:5px;'>${t}</div>`;
                    win.scrollTop=win.scrollHeight;
                })
                .catch(error => {
                    console.error('Chat API Error:', error);
                    win.innerHTML+=`<div style='align-self:flex-start; background:#dc2626; padding:10px; border-radius:8px; margin-bottom:5px;'>Error: Failed to get response from Noah_ASI. Check console for details.</div>`;
                    win.scrollTop=win.scrollHeight;
                });
        }
        function startEvolution(){
            const currentStatus = document.getElementById('status').innerText;
            if (currentStatus.includes("Evolution: In progress") || currentStatus.includes("Evolution: Reading") || currentStatus.includes("Evolution: Requesting") || currentStatus.includes("Trainer: Compiling")) {
                alert("이미 진화가 진행 중입니다. 잠시만 기다려주세요.");
                return;
            }
            document.getElementById('report').innerText = "진화 명령 접수! 오답 노트를 판독하여 분석을 시작합니다...";
            fetch('/api/evolve',{method:'POST'})
                .then(r => {
                    if (!r.ok) {
                        throw new Error('Network response was not ok, status: ' + r.status);
                    }
                    return r.text();
                })
                .then(t => {
                    console.log("Evolution initiated:", t);
                })
                .catch(error => {
                    console.error('Evolution API Error:', error);
                    document.getElementById('report').innerText = "🚨 진화 시작 실패! 서버와의 통신에 문제가 발생했습니다. (자세한 내용은 콘솔 확인)";
                });
        }
        setInterval(()=>{
            fetch('/api/data')
                .then(r => {
                    if (!r.ok) {
                        throw new Error('Network response was not ok, status: ' + r.status);
                    }
                    return r.json();
                })
                .then(d=>{
                    document.getElementById('cpu').innerText=d.cpu;
                    document.getElementById('ram').innerText=d.ram;
                    document.getElementById('gpu').innerText=d.gpu;
                    document.getElementById('status').innerText='Status: '+d.evo;
                    if(d.note && d.note !== "") { document.getElementById('report').innerText=d.note; }
                })
                .catch(error => {
                    console.error('Metrics API Error:', error);
                    document.getElementById('status').innerText='Status: Error fetching metrics.';
                });
        }, 1500);
    </script>
</body></html>
)HTML";

// Helper to escape string for JSON
std::string escape_json_string(const std::string& input) {
    std::string escaped_str;
    escaped_str.reserve(input.length() * 1.5); // Pre-allocate some memory
    for (char c : input) {
        switch (c) {
            case '"':  escaped_str += "\\\""; break;
            case '\\': escaped_str += "\\\\"; break;
            case '\b': escaped_str += "\\b";  break;
            case '\f': escaped_str += "\\f";  break;
            case '\n': escaped_str += "\\n";  break;
            case '\r': escaped_str += "\\r";  break;
            case '\t': escaped_str += "\\t";  break;
            default:   escaped_str += c; break;
        }
    }
    return escaped_str;
}

void start_web_server() {
    httplib::Server svr;
    svr.Get("/", [](const httplib::Request&, httplib::Response& res) { res.set_content(UI_HTML, "text/html; charset=utf-8"); });
    
    svr.Get("/api/data", [](const httplib::Request&, httplib::Response& res) {
        std::lock_guard<std::mutex> lock(g_state_mtx); 
        std::ostringstream json_stream;
        json_stream << "{ \"cpu\":\"" << escape_json_string(g_metrics.cpu) << "\", "
                    << "\"ram\":\"" << escape_json_string(g_metrics.ram) << "\", "
                    << "\"gpu\":\"" << escape_json_string(g_metrics.gpu) << "\", "
                    << "\"evo\":\"" << escape_json_string(g_evo_status) << "\", "
                    << "\"note\":\"" << escape_json_string(g_last_report) << "\" }";
        res.set_content(json_stream.str(), "application/json");
    });
    
    svr.Post("/api/chat", [](const httplib::Request& req, httplib::Response& res) { res.set_content(call_noah_brain(req.body), "text/plain; charset=utf-8"); });
    
    svr.Post("/api/evolve", [](const httplib::Request&, httplib::Response& res) { 
        {
            std::lock_guard<std::mutex> lock(g_state_mtx); 
            if (g_is_evolving) {
                res.set_content("Evolution already in progress.", "text/plain");
                return;
            }
            g_last_report = "오답 노트를 바탕으로 제미나이 2.5 서버에 진화 요청 중...";
            g_evo_status = "Evolution: Initiated";
            g_is_evolving = true;
        }
        std::thread(safe_run_evolution).detach(); 
        res.set_content("OK", "text/plain"); 
    });
    
    int port = 8080;
    while (port <= 8090) {
        std::cout << "\n🌐 [대시보드 접속] http://localhost:" << port << " 에 서버를 엽니다..." << std::endl;
        if (svr.listen("0.0.0.0", port)) break; 
        else port++;
    }
}

int main() {
    #ifdef _WIN32
    SetConsoleOutputCP(65001); 
    #endif

    llama_backend_init();
    llama_model_params m_params = llama_model_default_params(); 
    m_params.n_gpu_layers = g_config.llm_n_gpu_layers;
    
    model = llama_load_model_from_file(g_config.brain_model_path.c_str(), m_params);
    if (!model) return 1;

    llama_context_params c_params = llama_context_default_params();
    c_params.n_ctx = 8192; 
    ctx = llama_new_context_with_model(model, c_params);
    if (!ctx) return 1;
    
    smpl = llama_sampler_init_greedy();
    vocab = llama_model_get_vocab(model);
    
    std::thread(update_metrics).detach();
    start_web_server();

    llama_free(ctx);
    llama_model_free(model);
    llama_backend_free();

    return 0;
}
