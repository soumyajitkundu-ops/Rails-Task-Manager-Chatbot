import { useEffect, useState } from 'react';
import { apiCall } from '../api';
import TodoList from './TodoList';
import Chatbot from './Chatbot';
import ReadersWriters from './ReadersWriters';
import McpChatbot from './McpChatbot';

export default function Dashboard({ onLogout }) {
  const [userData, setUserData] = useState(null);
  const [activeSection, setActiveSection] = useState('workspace');

  const fetchDashboardData = async () => {
    try {
      // Returns user info along with embedded todos[cite: 4]
      const res = await apiCall('/me');
      setUserData(res.user);
    } catch {
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

        <nav className="mb-6 flex gap-2 border-b border-gray-300" aria-label="Dashboard sections">
          <button
            type="button"
            aria-pressed={activeSection === 'workspace'}
            onClick={() => setActiveSection('workspace')}
            className={`border-b-2 px-4 py-3 text-sm font-semibold ${activeSection === 'workspace' ? 'border-indigo-600 text-indigo-700' : 'border-transparent text-gray-600 hover:text-gray-900'}`}
          >
            Workspace
          </button>
          <button
            type="button"
            aria-pressed={activeSection === 'readers-writers'}
            onClick={() => setActiveSection('readers-writers')}
            className={`border-b-2 px-4 py-3 text-sm font-semibold ${activeSection === 'readers-writers' ? 'border-indigo-600 text-indigo-700' : 'border-transparent text-gray-600 hover:text-gray-900'}`}
          >
            Readers &amp; Writers
          </button>
          <button
            type="button"
            aria-pressed={activeSection === 'mcp'}
            onClick={() => setActiveSection('mcp')}
            className={`border-b-2 px-4 py-3 text-sm font-semibold ${activeSection === 'mcp' ? 'border-indigo-600 text-indigo-700' : 'border-transparent text-gray-600 hover:text-gray-900'}`}
          >
            MCP Chatbot
          </button>
        </nav>

        {activeSection === 'workspace' && (
          <div className="grid grid-cols-1 gap-8 lg:grid-cols-2">
            <div>
              <TodoList todos={userData.todos} refreshData={fetchDashboardData} />
            </div>
            <div>
              <Chatbot currentUserId={userData.id} />
            </div>
          </div>
        )}
        
        {activeSection === 'readers-writers' && <ReadersWriters currentUserId={userData.id} />}
        
        {activeSection === 'mcp' && <McpChatbot currentUserId={userData.id} />}
      </div>
    </div>
  );
}