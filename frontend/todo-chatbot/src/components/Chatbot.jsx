import React, { useState, useEffect, useRef } from 'react';
import { createConsumer } from '@rails/actioncable';
import ReactMarkdown from 'react-markdown';
import remarkGfm from 'remark-gfm';
import { apiCall } from '../api';

const mergeGroupMessages = (current, incoming) => {
  const messagesById = new Map(current.map(message => [message.id, message]));
  incoming.forEach(message => messagesById.set(message.id, message));
  return [...messagesById.values()].sort((first, second) => first.id - second.id);
};

export default function Chatbot({ currentUserId }) {
  const [messages, setMessages] = useState([]);
  const [groupMessages, setGroupMessages] = useState([]);
  const [activeView, setActiveView] = useState('ai');
  const [input, setInput] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const [isGroupAiThinking, setIsGroupAiThinking] = useState(false);
  const [hasMoreGroupMessages, setHasMoreGroupMessages] = useState(false);
  const [isLoadingOlder, setIsLoadingOlder] = useState(false);
  
  const chatEndRef = useRef(null);
  const groupScrollRef = useRef(null);
  const previousGroupScrollHeight = useRef(null);
  
  // Ref to hold WebSocket connection across renders and handle the disconnect delay
  const wsRef = useRef({ consumer: null, subscription: null, timeoutId: null });

  const fetchChats = async () => {
    console.log('[Chatbot] Fetching AI chat history...');
    try {
      const res = await apiCall('/ai/chats');
      setMessages(res.messages || []);
      console.log('[Chatbot] AI chat history loaded.');
    } catch (err) {
      console.error('[Chatbot] Error fetching AI chats:', err);
    }
  };

  useEffect(() => {
    console.log('[Chatbot] Component mounted.');
    fetchChats();
  }, []);

  // Cleanup completely if the Chatbot component itself unmounts
  useEffect(() => {
    return () => {
      console.log('[Chatbot] Component unmounting. Cleaning up connections...');
      if (wsRef.current.timeoutId) clearTimeout(wsRef.current.timeoutId);
      wsRef.current.subscription?.unsubscribe();
      wsRef.current.consumer?.disconnect();
    };
  }, []);

  // Handle the view switching with a 2-second grace period for the WebSocket
  useEffect(() => {
    console.log(`[Chatbot] Active view switched to: ${activeView}`);

    if (activeView === 'group') {
      // 1. Cancel any pending disconnect if the user quickly switched back
      if (wsRef.current.timeoutId) {
        console.log('[Chatbot] Welcome back to group! Canceling the pending WS disconnect timer.');
        clearTimeout(wsRef.current.timeoutId);
        wsRef.current.timeoutId = null;
      }

      // 2. Fetch missing messages
      let isActive = true;
      console.log('[Chatbot] Fetching latest group messages via HTTP...');
      apiCall('/group_chat/messages')
        .then(result => {
          if (!isActive) return;
          setGroupMessages(current => mergeGroupMessages(current, result.messages || []));
          setHasMoreGroupMessages(result.has_more);
          console.log('[Chatbot] Group messages HTTP fetch complete.');
        })
        .catch(error => console.error('[Chatbot] Error fetching group messages:', error));

      // 3. Connect WebSocket ONLY if we aren't already connected
      if (!wsRef.current.subscription) {
        console.log('[Chatbot] No active WS connection found. Establishing new connection...');
        const consumer = createConsumer('ws://localhost:3000/cable');
        const subscription = consumer.subscriptions.create('GroupChatChannel', {
          connected() {
            console.log('[Chatbot] WS Connected successfully.');
          },
          disconnected() {
            console.log('[Chatbot] WS Disconnected.');
          },
          received(message) {
            console.log('[Chatbot] WS Received new message:', message.id);
            setGroupMessages(current => mergeGroupMessages(current, [message]));
          },
        });
        
        wsRef.current.consumer = consumer;
        wsRef.current.subscription = subscription;
      } else {
        console.log('[Chatbot] Existing WS connection found. Reusing it.');
      }

      return () => {
        isActive = false; // Prevents the HTTP fetch from setting state if unmounted before resolving
      };
      
    } else {
      // 4. User switched away from group view. Schedule a 2-second delayed disconnect.
      if (wsRef.current.subscription && !wsRef.current.timeoutId) {
        console.log('[Chatbot] Switched away from group view. Scheduling WS disconnect in 2 seconds...');
        wsRef.current.timeoutId = setTimeout(() => {
          console.log('[Chatbot] 2 seconds passed. Executing WS disconnect.');
          wsRef.current.subscription?.unsubscribe();
          wsRef.current.consumer?.disconnect();
          
          // Clear out the refs so it reconnects cleanly next time
          wsRef.current.subscription = null;
          wsRef.current.consumer = null;
          wsRef.current.timeoutId = null;
        }, 2000);
      }
    }
  }, [activeView]);

  useEffect(() => {
    if (activeView === 'ai') {
      chatEndRef.current?.scrollIntoView({ behavior: 'smooth' });
    }
  }, [messages, isTyping, activeView]);

  useEffect(() => {
    if (activeView !== 'group') return;

    const container = groupScrollRef.current;
    if (!container) return;

    if (previousGroupScrollHeight.current !== null) {
      container.scrollTop += container.scrollHeight - previousGroupScrollHeight.current;
      previousGroupScrollHeight.current = null;
      return;
    }

    container.scrollTop = container.scrollHeight;
  }, [activeView, groupMessages]);

  const handleLoadOlder = async () => {
    if (!hasMoreGroupMessages || isLoadingOlder || groupMessages.length === 0) return;

    console.log('[Chatbot] Loading older group messages...');
    setIsLoadingOlder(true);
    const previousScrollHeight = groupScrollRef.current?.scrollHeight ?? null;
    try {
      const beforeId = groupMessages[0].id;
      const result = await apiCall(`/group_chat/messages?before_id=${beforeId}`);
      previousGroupScrollHeight.current = previousScrollHeight;
      setGroupMessages(current => mergeGroupMessages(current, result.messages || []));
      setHasMoreGroupMessages(result.has_more);
      console.log(`[Chatbot] Loaded ${result.messages?.length || 0} older messages.`);
    } catch (error) {
      console.error('[Chatbot] Error loading older messages:', error);
    } finally {
      setIsLoadingOlder(false);
    }
  };

  const handleSend = async (e) => {
    e.preventDefault();
    if (!input.trim()) return;

    const userText = input;
    setInput('');

    if (activeView === 'group') {
      const mentionsAi = /(?<!\w)@AI\b/i.test(userText);
      if (mentionsAi) setIsGroupAiThinking(true);

      console.log('[Chatbot] Sending group message...');
      try {
        const result = await apiCall('/group_chat/messages', {
          method: 'POST',
          body: JSON.stringify({ text: userText.trim() }),
        });
        setGroupMessages(current => mergeGroupMessages(current, result.messages || [result.message]));
        console.log('[Chatbot] Group message sent successfully.');
      } catch {
        setInput(userText);
        console.error('[Chatbot] Failed to send group message.');
        alert('Failed to send message.');
      } finally {
        if (mentionsAi) setIsGroupAiThinking(false);
      }
      return;
    }

    console.log('[Chatbot] Sending AI message...');
    setMessages(prev => [...prev, { user_message: userText, assistant_message: null, id: Date.now() }]);
    setIsTyping(true);

    try {
      await apiCall('/ai/chat', {
        method: 'POST',
        body: JSON.stringify({ message: userText })
      });
      console.log('[Chatbot] AI responded successfully. Fetching durable transcript...');
      fetchChats(); 
    } catch (err) {
      console.error('[Chatbot] Failed to send AI message:', err);
      alert("Failed to send message.");
    } finally {
      setIsTyping(false);
    }
  };

  const handleClearMemory = async () => {
    console.log('[Chatbot] Attempting to clear AI memory...');
    try {
      await apiCall('/ai/clear_memory', { method: 'DELETE' });
      console.log('[Chatbot] AI memory cleared successfully.');
      alert("AI working memory cleared!");
    } catch (err) {
      console.error('[Chatbot] Failed to clear AI memory:', err);
      alert("Failed to clear memory.");
    }
  };

  return (
    <div className="flex flex-col h-150 bg-white rounded-lg shadow-md overflow-hidden">
      <div className="flex items-center justify-between p-4 text-white bg-indigo-600">
        <h2 className="text-lg font-bold">{activeView === 'ai' ? 'AI Assistant' : 'Group Chat'}</h2>
        <div className="flex items-center gap-2">
          <div className="flex rounded bg-indigo-800 p-1" role="group" aria-label="Chat type">
            <button
              type="button"
              aria-pressed={activeView === 'ai'}
              onClick={() => setActiveView('ai')}
              className={`rounded px-3 py-1 text-xs ${activeView === 'ai' ? 'bg-white text-indigo-800' : 'text-white'}`}
            >
              AI Assistant
            </button>
            <button
              type="button"
              aria-pressed={activeView === 'group'}
              onClick={() => setActiveView('group')}
              className={`rounded px-3 py-1 text-xs ${activeView === 'group' ? 'bg-white text-indigo-800' : 'text-white'}`}
            >
              Group Chat
            </button>
          </div>
          {activeView === 'ai' && (
            <button onClick={handleClearMemory} className="px-3 py-1 text-xs bg-indigo-800 rounded hover:bg-indigo-900">
              Clear AI Memory
            </button>
          )}
        </div>
      </div>

      <div ref={groupScrollRef} className="flex-1 p-4 overflow-y-auto bg-gray-50">
        {activeView === 'ai' ? (
          <>
            {messages.map((msg) => (
              <div key={msg.id} className="mb-4">
                <div className="flex justify-end mb-2">
                  <div className="px-4 py-2 text-white bg-blue-500 rounded-lg max-w-[80%]">
                    {msg.user_message}
                  </div>
                </div>
                {msg.assistant_message && (
                  <div className="flex justify-start">
                    <div className="px-4 py-2 text-gray-800 bg-gray-200 rounded-lg max-w-[90%] wrap-break-word overflow-x-auto text-sm">
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
                        {msg.assistant_message}
                      </ReactMarkdown>
                    </div>
                  </div>
                )}
              </div>
            ))}
            {isTyping && <div className="text-sm text-gray-500 italic">AI is thinking...</div>}
            <div ref={chatEndRef} />
          </>
        ) : (
          <>
            {hasMoreGroupMessages && (
              <div className="mb-4 text-center">
                <button
                  type="button"
                  onClick={handleLoadOlder}
                  disabled={isLoadingOlder}
                  className="px-3 py-1 text-sm text-indigo-700 hover:text-indigo-900 disabled:text-gray-400"
                >
                  {isLoadingOlder ? 'Loading...' : 'Load older messages'}
                </button>
              </div>
            )}
            {groupMessages.map(message => {
              const isAiMessage = message.ownerid === -1;
              const isOwnMessage = message.ownerid === currentUserId;
              const bubbleStyle = isAiMessage
                ? 'border border-cyan-400 bg-cyan-950 text-cyan-50 shadow-sm shadow-cyan-900/30'
                : isOwnMessage
                  ? 'bg-blue-500 text-white'
                  : 'border border-gray-200 bg-white text-gray-800';

              return (
                <div key={message.id} className={`mb-3 flex ${isOwnMessage ? 'justify-end' : 'justify-start'}`}>
                  <div className={`max-w-[80%] rounded-lg px-4 py-2 ${bubbleStyle}`}>
                    {!isOwnMessage && (
                      <div className={`mb-1 text-xs font-semibold ${isAiMessage ? 'text-cyan-300' : 'text-gray-500'}`}>
                        {message.ownername}
                      </div>
                    )}
                    <div className="whitespace-pre-wrap wrap-break-word">{message.text}</div>
                  </div>
                </div>
              );
            })}
            {isGroupAiThinking && <div className="text-sm italic text-cyan-800">AI is replying...</div>}
          </>
        )}
      </div>

      <form onSubmit={handleSend} className="flex p-4 border-t bg-white">
        <input
          type="text"
          placeholder={activeView === 'ai' ? 'Ask the AI...' : 'Write to the group...'}
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