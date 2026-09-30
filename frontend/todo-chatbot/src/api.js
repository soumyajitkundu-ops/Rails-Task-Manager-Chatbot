const BASE_URL = 'http://localhost:3000';
export const apiCall = async (endpoint, options = {}) => {
  const defaultOptions = {
    // Crucial for sending/receiving the HTTP-only JWT cookie[cite: 3]
    credentials: 'include', 
    headers: {
      'Content-Type': 'application/json',
      ...options.headers,
    },
  };

  const response = await fetch(`${BASE_URL}${endpoint}`, {
    ...defaultOptions,
    ...options,
  });

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}));
    throw new Error(errorData.error || errorData.errors?.join(', ') || 'API Error');
  }

  return response.json();
};