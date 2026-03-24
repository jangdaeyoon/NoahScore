import axios, { AxiosInstance } from 'axios';
import { ApiResponse, Fixture, League, QuotaExceededError } from '../api/types';

const API_KEY = 'YOUR_RAPIDAPI_KEY'; // <-- 주인님 키 입력 필요

class ApiService {
  private api: AxiosInstance;
  private cache = new Map<string, { data: any; expires: number | null }>();

  constructor() {
    this.api = axios.create({
      baseURL: 'https://v3.football.api-sports.io',
      headers: { 'x-rapidapi-key': API_KEY, 'x-rapidapi-host': 'v3.football.api-sports.io' },
      params: { timezone: 'Asia/Seoul' }
    });

    this.api.interceptors.response.use((response) => {
      const errors = response.data.errors;
      if (errors && JSON.stringify(errors).match(/rate_limit|token_exceeded/)) {
        throw new QuotaExceededError();
      }
      return response;
    });
  }

  async getFixtures(params: any) {
    const cacheKey = 'fixtures' + JSON.stringify(params);
    if (this.cache.has(cacheKey)) return this.cache.get(cacheKey)!.data;

    const res = await this.api.get<ApiResponse<Fixture>>('/fixtures', { params });
    const data = res.data.response;
    
    // FT(종료) 경기는 무제한 캐시
    const hasFT = data.every(f => f.fixture.status.short === 'FT');
    this.cache.set(cacheKey, { data, expires: hasFT ? null : Date.now() + 60000 });
    
    return data;
  }
}

export default new ApiService();
