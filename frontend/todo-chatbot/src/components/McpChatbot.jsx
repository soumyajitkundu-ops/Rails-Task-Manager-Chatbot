import React, { useState, useRef, useEffect } from 'react';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { apiCall } from '../api';

export default function McpChatbot({ currentUserId }) {
  const [messages, setMessages] = useState([]);
  const [input, setInput] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const chatEndRef = useRef(null);

  const scrollToBottom = () => {
    chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages, isTyping]);

  const handleSend = async (e) => {
    e.preventDefault();
    if (!input.trim()) return;

    const userText = input;
    setInput('');
    
    const newMessages = [...messages, { role: 'user', content: userText }];
    setMessages(newMessages);
    setIsTyping(true);

    try {
      const response = await apiCall('/mcp/chat', {
        method: 'POST',
        body: JSON.stringify({ messages: newMessages })
      });
      
      setMessages([...newMessages, response]);
    } catch (err) {
      console.error('[McpChatbot] Failed to send message:', err);
      alert('Failed to send message.');
    } finally {
      setIsTyping(false);
    }
  };

  const handleClear = () => {
    setMessages([]);
  };

  return (
    <div className="flex flex-col h-150 bg-white rounded-lg shadow-md overflow-hidden border border-gray-200">
      <div className="flex items-center justify-between p-4 text-white bg-teal-700">
        <h2 className="text-lg font-bold">MCP Chatbot</h2>
        <button onClick={handleClear} className="px-3 py-1 text-xs bg-teal-800 rounded hover:bg-teal-900">
          Clear Conversation
        </button>
      </div>

      <div className="flex-1 p-4 overflow-y-auto bg-gray-50 space-y-4">
        {messages.map((msg, index) => {
          const isUser = msg.role === 'user';
          return (
            <div key={index} className={`flex ${isUser ? 'justify-end' : 'justify-start'}`}>
              <div className="flex flex-col max-w-[90%]">
                <div className={`px-4 py-2 rounded-lg text-sm ${isUser ? 'bg-blue-500 text-white' : 'bg-white border border-gray-300 text-gray-800'}`}>
                  {isUser ? (
                    <div className="whitespace-pre-wrap wrap-break-word">{msg.content}</div>
                  ) : (
                    <div className="wrap-break-word overflow-x-auto">
                      <ReactMarkdown
                        remarkPlugins={[remarkGfm]}
                        components={{
                          ul: ({node, ...props}) => <ul className="list-disc pl-5 my-2" {...props} />,
                          ol: ({node, ...props}) => <ol className="list-decimal pl-5 my-2" {...props} />,
                          li: ({node, ...props}) => <li className="mb-1" {...props} />,
                          p: ({node, ...props}) => <p className="mb-2 last:mb-0" {...props} />,
                          strong: ({node, ...props}) => <strong className="font-semibold" {...props} />,
                          code: ({node, ...props}) => <code className="bg-gray-100 text-pink-600 px-1 py-0.5 rounded text-xs" {...props} />,
                          pre: ({node, ...props}) => <pre className="bg-gray-100 p-2 rounded my-2 overflow-x-auto text-xs" {...props} />,
                          table: ({node, ...props}) => <table className="min-w-full divide-y divide-gray-200 my-2 border border-gray-200" {...props} />,
                          thead: ({node, ...props}) => <thead className="bg-gray-50" {...props} />,
                          tbody: ({node, ...props}) => <tbody className="divide-y divide-gray-200 bg-white" {...props} />,
                          tr: ({node, ...props}) => <tr className="hover:bg-gray-50" {...props} />,
                          th: ({node, ...props}) => <th className="px-3 py-2 text-left text-xs font-medium text-gray-500 uppercase tracking-wider border-b" {...props} />,
                          td: ({node, ...props}) => <td className="px-3 py-2 text-sm text-gray-700 whitespace-nowrap" {...props} />
                        }}
                      >
                        {msg.content}
                      </ReactMarkdown>
                    </div>
                  )}
                </div>
                {msg.tool_used && (
                  <div className="mt-1 text-xs text-teal-600 font-medium px-2 italic">
                    Using MCP tool: {msg.tool_used}
                  </div>
                )}
              </div>
            </div>
          );
        })}
        {isTyping && <div className="text-sm text-gray-500 italic">AI is thinking...</div>}
        <div ref={chatEndRef} />
      </div>

      <form onSubmit={handleSend} className="flex p-4 border-t bg-white">
        <input
          type="text"
          placeholder="Ask the MCP assistant..."
          className="flex-1 px-4 py-2 border rounded-l-md focus:outline-none focus:ring-2 focus:ring-teal-500"
          value={input}
          onChange={e => setInput(e.target.value)}
        />
        <button type="submit" className="px-6 py-2 text-white bg-teal-700 rounded-r-md hover:bg-teal-800">
          Send
        </button>
      </form>
    </div>
  );
}
