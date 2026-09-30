import React, { useEffect, useState } from 'react';
import { apiCall } from '../api';
import TodoList from './TodoList';
import Chatbot from './Chatbot';

export default function Dashboard({ onLogout }) {
  const [userData, setUserData] = useState(null);

  const fetchDashboardData = async () => {
    try {
      // Returns user info along with embedded todos[cite: 4]
      const res = await apiCall('/me');
      setUserData(res.user);
    } catch (err) {
      console.error("Failed to load dashboard");
    }
  };

  useEffect(() => {
    fetchDashboardData();
  }, []);

  const handleLogout = async () => {
    try {
      await apiCall('/logout', { method: 'DELETE' }); // Blacklists the token and deletes cookie[cite: 3]
      onLogout();
    } catch (err) {
      alert("Logout failed");
    }
  };

  if (!userData) return <div className="p-10 text-center">Loading...</div>;

  return (
    <div className="min-h-screen p-8 bg-gray-100">
      <div className="max-w-6xl mx-auto">
        <div className="flex items-center justify-between mb-8">
          <h1 className="text-3xl font-bold text-gray-800">Welcome, {userData.name}</h1>
          <button onClick={handleLogout} className="px-4 py-2 text-white bg-red-600 rounded hover:bg-red-700">
            Logout
          </button>
        </div>

        <div className="grid grid-cols-1 gap-8 lg:grid-cols-2">
          <div>
            <TodoList todos={userData.todos} refreshData={fetchDashboardData} />
          </div>
          <div>
            <Chatbot />
          </div>
        </div>
      </div>
    </div>
  );
}