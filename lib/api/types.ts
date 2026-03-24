export interface ApiResponse<T> {
  get: string;
  parameters: any;
  errors: { [key: string]: string | string[] };
  results: number;
  paging: { current: number; total: number };
  response: T[];
}

export interface League {
  league: { id: number; name: string; type: string; logo: string };
  country: { name: string; code: string; flag: string };
  seasons: { year: number; current: boolean; coverage: any }[];
}

export interface Fixture {
  fixture: { id: number; referee: string | null; timezone: string; date: string; timestamp: number; status: { long: string; short: string; elapsed: number | null } };
  league: { id: number; name: string; logo: string; season: number; round: string };
  teams: { home: { id: number; name: string; logo: string; winner: boolean | null }; away: { id: number; name: string; logo: string; winner: boolean | null } };
  goals: { home: number | null; away: number | null };
}

export class QuotaExceededError extends Error {
  constructor(message: string = "API 할당량이 초과되었습니다.") {
    super(message);
    this.name = "QuotaExceededError";
  }
}
