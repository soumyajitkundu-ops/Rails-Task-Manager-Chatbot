import React, { useState, useEffect, useRef } from 'react';
import { apiCall } from '../api';

export default function Chatbot() {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const chatEndRef = useRef(null);

  const fetchChats = async () => {
    try {
      const res = await apiCall('/ai/chats');
      setMessages(res.messages || []);
    } catch (err) {
      console.error(err);
    }
  };

  useEffect(() => {
    fetchChats();
  }, []);

  useEffect(() => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages, isTyping]);

  const handleSend = async (e) => {
    e.preventDefault();
    if (!input.trim()) return;

    const userText = input;
    setInput('');
    // Optimistic UI update for the user's message
    setMessages(prev => [...prev, { user_message: userText, assistant_message: null, id: Date.now() }]);
    setIsTyping(true);

    try {
      // Sends message to the AI Chat Service[cite: 1]
      const res = await apiCall('/ai/chat', {
        method: 'POST',
        body: JSON.stringify({ message: userText })
      });
      
      // Update with the final durable transcript
      fetchChats(); 
    } catch (err) {
      alert("Failed to send message.");
    } finally {
      setIsTyping(false);
    }
  };

  const handleClearMemory = async () => {
    try {
      // Clears the active session and database snapshot[cite: 1, 5]
      await apiCall('/ai/clear_memory', { method: 'DELETE' });
      alert("AI working memory cleared!");
    } catch (err) {
      alert("Failed to clear memory.");
    }
  };

  return (
    <div className="flex flex-col h-[600px] bg-white rounded-lg shadow-md overflow-hidden">
      <div className="flex items-center justify-between p-4 text-white bg-indigo-600">
        <h2 className="text-lg font-bold">AI Assistant</h2>
        <button onClick={handleClearMemory} className="px-3 py-1 text-xs bg-indigo-800 rounded hover:bg-indigo-900">
          Clear AI Memory
        </button>
      </div>

      <div className="flex-1 p-4 overflow-y-auto bg-gray-50">
        {messages.map((msg) => (
          <div key={msg.id} className="mb-4">
             {/* User Message[cite: 7] */}
            <div className="flex justify-end mb-2">
              <div className="px-4 py-2 text-white bg-blue-500 rounded-lg max-w-[80%]">
                {msg.user_message}
              </div>
            </div>
            {/* Assistant Message[cite: 7] */}
            {msg.assistant_message && (
              <div className="flex justify-start">
                <div className="px-4 py-2 text-gray-800 bg-gray-200 rounded-lg max-w-[80%]">
                  {msg.assistant_message}
                </div>
              </div>
            )}
          </div>
        ))}
        {isTyping && <div className="text-sm text-gray-500 italic">AI is thinking...</div>}
        <div ref={chatEndRef} />
      </div>

      <form onSubmit={handleSend} className="flex p-4 border-t bg-white">
        <input
          type="text"
          placeholder="Ask the AI..."
          className="flex-1 px-4 py-2 border rounded-l-md focus:outline-none focus:ring-2 focus:ring-indigo-500"
          value={input}
          onChange={e => setInput(e.target.value)}
        />
        <button type="submit" className="px-6 py-2 text-white bg-indigo-600 rounded-r-md hover:bg-indigo-700">
          Send
        </button>
      </form>
    </div>
  );
}