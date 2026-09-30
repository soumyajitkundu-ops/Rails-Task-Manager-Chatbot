import React, { useState } from 'react';
import { apiCall } from '../api';

export default function TodoList({ todos, refreshData }) {
  const [newTask, setNewTask] = useState({ task: '', description: '', priority: '1' });
  const [stagedTodos, setStagedTodos] = useState([]);

  // Adds a task to the local bulk upload queue
  const handleStageTask = (e) => {
    e.preventDefault();
    if (!newTask.task.trim() || !newTask.description.trim()) return;
    
    setStagedTodos([...stagedTodos, newTask]);
    setNewTask({ task: '', description: '', priority: '1' });
  };

  const handleRemoveStaged = (index) => {
    setStagedTodos(stagedTodos.filter((_, i) => i !== index));
  };

  // Submits the entire array to the Rails POST /todos endpoint[cite: 4]
  const handleBulkUpload = async () => {
    if (stagedTodos.length === 0) return;
    try {
      await apiCall('/todos', {
        method: 'POST',
        body: JSON.stringify({ todos: stagedTodos }) 
      });
      setStagedTodos([]);
      refreshData();
    } catch (err) {
      alert(err.message);
    }
  };

  // Handles both increasing (delta = 1) and decreasing (delta = -1) priority
  const handleUpdatePriority = async (id, currentPriority, delta) => {
    const newPriority = parseInt(currentPriority) + delta;
    if (newPriority < 1) return; // Prevent priority from going below 1

    try {
      await apiCall(`/todos/${id}`, {
        method: 'PATCH',
        body: JSON.stringify({ priority: newPriority })
      });
      refreshData();
    } catch (err) {
      alert(err.message);
    }
  };

  return (
    <div className="flex flex-col h-[600px] bg-white rounded-lg shadow-md overflow-hidden">
      
      {/* Creation Form */}
      <div className="p-4 bg-gray-50 border-b">
        <h2 className="mb-3 text-lg font-bold text-gray-800">Task Manager</h2>
        
        <form onSubmit={handleStageTask} className="space-y-3">
          <div className="flex flex-col gap-2 sm:flex-row">
            <input
              type="text" placeholder="Task title..." required
              className="flex-1 px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:outline-none"
              value={newTask.task} onChange={e => setNewTask({...newTask, task: e.target.value})}
            />
            <input
              type="text" placeholder="Description..." required
              className="flex-1 px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:outline-none"
              value={newTask.description} onChange={e => setNewTask({...newTask, description: e.target.value})}
            />
          </div>
          <div className="flex items-center gap-3">
            <label className="text-sm font-medium text-gray-600">Priority:</label>
            <input
              type="number" min="1" required
              className="w-20 px-3 py-2 border rounded-md focus:ring-2 focus:ring-blue-500 focus:outline-none"
              value={newTask.priority} onChange={e => setNewTask({...newTask, priority: e.target.value})}
            />
            <button type="submit" className="px-4 py-2 text-sm text-blue-700 bg-blue-100 rounded-md hover:bg-blue-200 whitespace-nowrap">
              + Stage Task
            </button>
          </div>
        </form>
      </div>

      {/* Bulk Upload Staging Area */}
      {stagedTodos.length > 0 && (
        <div className="p-4 bg-yellow-50 border-b border-yellow-100 shrink-0">
          <div className="flex items-center justify-between mb-2">
            <h3 className="text-sm font-bold text-yellow-800">Ready to Upload ({stagedTodos.length})</h3>
            <button onClick={handleBulkUpload} className="px-3 py-1 text-sm text-white bg-green-600 rounded hover:bg-green-700 shadow-sm">
              Upload All
            </button>
          </div>
          <ul className="space-y-2 max-h-32 overflow-y-auto pr-2">
            {stagedTodos.map((todo, index) => (
              <li key={index} className="flex items-center justify-between p-2 text-sm bg-white border border-yellow-200 rounded">
                <span className="truncate">
                  <strong>{todo.task}</strong> <span className="text-gray-500">| P: {todo.priority}</span>
                </span>
                <button onClick={() => handleRemoveStaged(index)} className="ml-2 text-red-500 hover:text-red-700 font-bold shrink-0">
                  ✕
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}

      {/* Saved Todo List */}
      <div className="flex-1 p-4 overflow-y-auto">
        <h3 className="mb-3 text-xs font-bold tracking-wider text-gray-500 uppercase">Saved Tasks</h3>
        <ul className="space-y-3">
          {todos.map(todo => (
            <li key={todo.id} className="flex flex-col gap-2 p-3 border rounded-md bg-gray-50 sm:flex-row sm:items-center sm:justify-between">
              <div className="overflow-hidden">
                <p className="font-semibold text-gray-800 truncate">{todo.task}</p>
                <p className="text-sm text-gray-600 truncate">{todo.description}</p>
              </div>
              
              <div className="flex items-center gap-2 shrink-0">
                <span className="px-2 py-1 text-xs font-medium text-gray-700 bg-gray-200 rounded">
                  Priority: {todo.priority}
                </span>
                <button
                  onClick={() => handleUpdatePriority(todo.id, todo.priority, 1)}
                  className="w-8 h-8 flex items-center justify-center text-white bg-blue-500 rounded hover:bg-blue-600 focus:outline-none"
                  title="Increase Priority"
                >
                  ▲
                </button>
                <button
                  onClick={() => handleUpdatePriority(todo.id, todo.priority, -1)}
                  disabled={todo.priority <= 1}
                  className="w-8 h-8 flex items-center justify-center text-white bg-gray-500 rounded hover:bg-gray-600 disabled:opacity-50 disabled:cursor-not-allowed focus:outline-none"
                  title="Decrease Priority"
                >
                  ▼
                </button>
              </div>
            </li>
          ))}
          {todos.length === 0 && <p className="text-sm italic text-gray-500">No saved tasks yet.</p>}
        </ul>
      </div>

    </div>
  );
}