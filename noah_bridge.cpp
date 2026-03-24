#include <iostream>
#include <string>
#include <curl/curl.h> // libcurl 필요 [cite: 2026-03-02]
#include <nlohmann/json.hpp> // nlohmann/json 필요

using json = nlohmann::json;

size_t WriteCallback(void* contents, size_t size, size_t nmemb, void* userp) {
    ((std::string*)userp)->append((char*)contents, size * nmemb);
    return size * nmemb;
}

void get_ai_analysis(const json& match_data) {
    CURL* curl;
    CURLcode res;
    std::string readBuffer;

    curl = curl_easy_init();
    if(curl) {
        struct curl_slist *headers = NULL;
        headers = curl_slist_append(headers, "Content-Type: application/json");

        std::string json_str = match_data.dump();
        
        curl_easy_setopt(curl, CURLOPT_URL, "http://127.0.0.1:5000/analyze");
        curl_easy_setopt(curl, CURLOPT_POSTFIELDS, json_str.c_str());
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, WriteCallback);
        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &readBuffer);

        res = curl_easy_perform(curl);
        if(res != CURLE_OK) {
            std::cerr << "❌ AI 서버 연결 실패: " << curl_easy_strerror(res) << std::endl;
        } else {
            std::cout << "✅ Noah AI 분석 결과 수신 완료: " << std::endl;
            std::cout << readBuffer << std::endl;
        }
        curl_easy_cleanup(curl);
    }
}

int main() {
    // 실전 경기 데이터 시뮬레이션 [cite: 2026-03-07]
    json test_match = {
        {"home_att", 2.8}, {"away_def", 1.2}, 
        {"home_pts", 21}, {"away_pts", 15}, {"market_odds", 1.95}
    };
    get_ai_analysis(test_match);
    return 0;
}
