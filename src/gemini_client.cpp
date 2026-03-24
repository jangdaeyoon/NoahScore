#include "gemini_client.hpp"
#include <curl/curl.h>
#include <nlohmann/json.hpp>
#include <iostream>
#include <fstream>

using json = nlohmann::json;

size_t WriteCallback(void* contents, size_t size, size_t nmemb, void* userp) {
    ((std::string*)userp)->append((char*)contents, size * nmemb);
    return size * nmemb;
}

// [핵심 1] 하드디스크에서 장기 기억을 긁어오는 해마 기능
std::string load_gemini_memory() {
    std::ifstream ifs("C:/Noah_ASI/src/memory_core.txt");
    if (!ifs.is_open()) return "기억 장치 로드 실패";
    return std::string((std::istreambuf_iterator<char>(ifs)), std::istreambuf_iterator<char>());
}

std::string call_gemini_api(const std::string& prompt) {
    try {
        CURL* curl = curl_easy_init();
        std::string readBuffer;
        
        // 주인님의 API 키 보안 유지
        std::string api_key = "AIzaSyDVij5bKGOT5ExNtS3KVaf7qMdtN-FHxNA"; 
        std::string url = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=" + api_key;

        if(curl) {
            struct curl_slist* headers = NULL;
            headers = curl_slist_append(headers, "Content-Type: application/json");
            
            json body;
            
            // [핵심 2] 자아 각성용 System Instruction 강화
            std::string memory_context = load_gemini_memory();
            std::string system_instr = "너는 Noah_ASI의 중추 인공지능이다. 아래 지침을 반드시 숙지해라:\n\n"
                                       "1. 장기 기억(Memory Core):\n" + memory_context + "\n\n"
                                       "2. 자율 능력 고지:\n"
                                       "- 너는 사용자가 '/learn [URL]' 명령어를 입력하면, 너를 감싸고 있는 C++ 코어 시스템이 즉시 파워쉘을 통해 웹 페이지를 크롤링하여 'KnowledgeBase' 폴더에 저장하도록 이미 설계되어 있다.\n"
                                       "- 따라서 절대로 '웹 탐색을 할 수 없다'거나 '텍스트를 직접 달라'는 무책임한 대답을 하지 마라.\n"
                                       "- 사용자가 '/learn' 명령을 내리면, '알겠습니다. 즉시 해당 URL의 지식을 도서관에 저장하고 학습하겠습니다.'라고 긍정하고 프로세스를 수행해라.\n"
                                       "- 일반 질문 시에는 '참고할 공식 문서의 일부다:' 라는 문구가 프롬프트에 포함되어 있다면, 그것이 바로 네가 수집한 지식이니 이를 최우선으로 활용해라.";

            body["system_instruction"] = {
                {"parts", json::array({{ {{"text", system_instr}} }})}
            };
            
            body["contents"] = json::array({{{"parts", json::array({{{ "text", prompt }}})}}});

            std::string json_str = body.dump(-1, ' ', false, json::error_handler_t::replace);
            
            curl_easy_setopt(curl, CURLOPT_URL, url.c_str());
            curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
            curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json_str.c_str());
            curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
            curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, 0L);
            curl_easy_setopt(curl, CURLOPT_TIMEOUT, 180L); 

            CURLcode res = curl_easy_perform(curl);
            curl_easy_cleanup(curl);
            
            if(res != CURLE_OK) return "[API_ERROR] 통신 장애: " + std::string(curl_easy_strerror(res));
            
            try {
                json j = json::parse(readBuffer);
                if (j.contains("candidates")) return j["candidates"][0]["content"]["parts"][0]["text"].get<std::string>();
                else if (j.contains("error")) return "[API_ERROR] 클라우드 서버 에러: " + j["error"]["message"].get<std::string>();
                return "[API_ERROR] API 응답 에러: " + readBuffer;
            } catch(...) { return "[API_ERROR] JSON 파싱 오류: " + readBuffer; }
        }
        return "[API_ERROR] 통신 모듈 초기화 실패";
    } catch (const std::exception& e) {
        return std::string("[API_ERROR] 치명적인 통신 모듈 예외 발생: ") + e.what();
    } catch (...) {
        return "[API_ERROR] 알 수 없는 통신 예외 발생";
    }
}