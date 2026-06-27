class CoPilotSupabaseClient {
  constructor(config = {}) {
    this.baseUrl = (config.supabaseUrl || '').replace(/\/$/, '');
    this.key = config.supabaseAnonKey || '';
    this.restUrl = `${this.baseUrl}/rest/v1`;
    this.authUrl = `${this.baseUrl}/auth/v1`;
    this.storageUrl = `${this.baseUrl}/storage/v1`;
    this.accessToken = localStorage.getItem('cp_access_token') || '';
    this.refreshToken = localStorage.getItem('cp_refresh_token') || '';
  }

  get enabled() {
    return Boolean(this.baseUrl && this.key);
  }

  setSession(session = null) {
    this.accessToken = session?.access_token || '';
    this.refreshToken = session?.refresh_token || '';
    if (this.accessToken) localStorage.setItem('cp_access_token', this.accessToken);
    else localStorage.removeItem('cp_access_token');
    if (this.refreshToken) localStorage.setItem('cp_refresh_token', this.refreshToken);
    else localStorage.removeItem('cp_refresh_token');
  }

  headers(extra = {}) {
    return {
      apikey: this.key,
      Authorization: `Bearer ${this.accessToken || this.key}`,
      'Content-Type': 'application/json',
      ...extra
    };
  }

  async request(path, options = {}) {
    if (!this.enabled) throw new Error('Supabase config missing.');
    const url = path.startsWith('http') ? path : `${this.restUrl}${path}`;
    const res = await fetch(url, { ...options, headers: this.headers(options.headers || {}) });
    const text = await res.text();
    let data = null;
    if (text) {
      try { data = JSON.parse(text); } catch { data = text; }
    }
    if (!res.ok) {
      const err = new Error(data?.message || data?.error_description || data?.error || text || `Supabase ${res.status}`);
      err.status = res.status;
      err.details = data;
      throw err;
    }
    return data;
  }

  async authRequest(path, payload = {}, method = 'POST') {
    if (!this.enabled) throw new Error('Supabase config missing.');
    const res = await fetch(`${this.authUrl}${path}`, {
      method,
      headers: {
        apikey: this.key,
        Authorization: `Bearer ${method === 'POST' ? this.key : (this.accessToken || this.key)}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });
    const text = await res.text();
    let data = null;
    if (text) {
      try { data = JSON.parse(text); } catch { data = text; }
    }
    if (!res.ok) throw new Error(data?.error_description || data?.message || data?.error || text || `Auth ${res.status}`);
    return data;
  }

  async signIn(email, password) {
    const data = await this.authRequest('/token?grant_type=password', { email, password });
    this.setSession(data);
    return data;
  }

  async signUp(email, password, metadata = {}) {
    const data = await this.authRequest('/signup', { email, password, data: metadata });
    if (data?.access_token) this.setSession(data);
    return data;
  }


  async signUpNoSession(email, password, metadata = {}) {
    const previousSession = { access_token: this.accessToken, refresh_token: this.refreshToken };
    const data = await this.authRequest('/signup', { email, password, data: metadata });
    this.accessToken = previousSession.access_token || '';
    this.refreshToken = previousSession.refresh_token || '';
    if (this.accessToken) localStorage.setItem('cp_access_token', this.accessToken);
    if (this.refreshToken) localStorage.setItem('cp_refresh_token', this.refreshToken);
    return data;
  }

  async signOut() {
    this.setSession(null);
  }

  async rpc(name, args = {}) {
    return this.request(`/rpc/${encodeURIComponent(name)}`, {
      method: 'POST',
      body: JSON.stringify(args || {})
    });
  }

  async uploadStorageObject(bucket, path, file, options = {}) {
    if (!this.enabled) throw new Error('Supabase config missing.');
    if (!this.accessToken) throw new Error('Login session missing.');
    const safeBucket = encodeURIComponent(bucket);
    const safePath = String(path || '').split('/').map(encodeURIComponent).join('/');
    const res = await fetch(`${this.storageUrl}/object/${safeBucket}/${safePath}`, {
      method: 'POST',
      headers: {
        apikey: this.key,
        Authorization: `Bearer ${this.accessToken}`,
        'Content-Type': file?.type || 'application/octet-stream',
        'x-upsert': options.upsert ? 'true' : 'false'
      },
      body: file
    });
    const text = await res.text();
    let data = null;
    if (text) {
      try { data = JSON.parse(text); } catch { data = text; }
    }
    if (!res.ok) throw new Error(data?.message || data?.error || text || `Storage upload failed (${res.status})`);
    return data;
  }

  getPublicUrl(bucket, path) {
    const safeBucket = encodeURIComponent(bucket);
    const safePath = String(path || '').split('/').map(encodeURIComponent).join('/');
    return `${this.storageUrl}/object/public/${safeBucket}/${safePath}`;
  }
}

window.CoPilotSupabaseClient = CoPilotSupabaseClient;
