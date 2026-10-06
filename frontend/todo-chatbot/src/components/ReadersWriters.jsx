import { useEffect, useState } from 'react';
import { createConsumer } from '@rails/actioncable';
import { apiCall } from '../api';

const emptyState = { reader_count: 0, readers: [], writer: null, active_users: [] };

export default function ReadersWriters({ currentUserId }) {
  const [room, setRoom] = useState(emptyState);
  const [sessionMode, setSessionMode] = useState(null);
  const [isConnected, setIsConnected] = useState(false);
  const [isBusy, setIsBusy] = useState(false);
  const [error, setError] = useState('');

  useEffect(() => {
    let isActive = true;
    const consumer = createConsumer('ws://localhost:3000/cable');
    const subscription = consumer.subscriptions.create('ReadersWritersChannel', {
        connected() {
          if (!isActive) return;
          setIsConnected(true);
          apiCall('/readers_writers/state')
            .then(state => {
              if (!isActive) return;
              setRoom(state);
              setSessionMode(state.session_mode);
            })
            .catch(() => {
              if (isActive) setError('Could not load the room state.');
            });
        },
        disconnected() {
          if (!isActive) return;
          setIsConnected(false);
          setSessionMode(null);
        },
        received(state) {
          if (!isActive) return;
          setRoom(state);
          setSessionMode(state.session_mode);
        },
      });

    return () => {
      isActive = false;
      subscription.unsubscribe();
      consumer.disconnect();
    };
  }, []);

  const acquire = async mode => {
    setIsBusy(true);
    setError('');
    try {
      const state = await apiCall('/readers_writers/lock', {
        method: 'POST',
        body: JSON.stringify({ mode }),
      });
      setRoom(state);
      setSessionMode(state.session_mode);
    } catch (requestError) {
      setError(requestError.message);
      try {
        const state = await apiCall('/readers_writers/state');
        setRoom(state);
        setSessionMode(state.session_mode);
      } catch {
        setError(requestError.message);
      }
    } finally {
      setIsBusy(false);
    }
  };

  const release = async () => {
    setIsBusy(true);
    setError('');
    try {
      const state = await apiCall('/readers_writers/lock', {
        method: 'DELETE',
      });
      setRoom(state);
      setSessionMode(null);
    } catch (requestError) {
      setError(requestError.message);
    } finally {
      setIsBusy(false);
    }
  };

  return (
    <section className="overflow-hidden rounded-lg border border-gray-200 bg-white shadow-sm">
      <div className="flex flex-wrap items-center justify-between gap-4 border-b border-gray-200 bg-gray-900 px-6 py-5 text-white">
        <div>
          <p className="text-xs font-semibold uppercase tracking-wide text-emerald-300">Shared resource</p>
          <h2 className="mt-1 text-2xl font-bold">Readers &amp; Writers</h2>
        </div>
        <div className="flex items-center gap-2 text-sm" aria-live="polite">
          <span className={`h-2.5 w-2.5 rounded-full ${isConnected ? 'bg-emerald-400' : 'bg-amber-400'}`} />
          {isConnected ? 'Live' : 'Connecting'}
        </div>
      </div>

      <div className="grid gap-8 p-6 lg:grid-cols-[minmax(0,1fr)_18rem]">
        <div>
          <div className="mb-6 flex flex-wrap items-end gap-8">
            <div>
              <p className="text-sm font-medium text-gray-500">Active readers</p>
              <p className="mt-1 text-4xl font-bold tabular-nums text-gray-900">{room.reader_count}</p>
            </div>
            <div>
              <p className="text-sm font-medium text-gray-500">Write lock</p>
              <p className={`mt-2 text-sm font-semibold ${room.writer ? 'text-rose-700' : 'text-emerald-700'}`}>
                {room.writer ? `Held by ${room.writer}` : 'Available'}
              </p>
            </div>
            <div>
              <p className="text-sm font-medium text-gray-500">Your lock</p>
              <p className="mt-2 text-sm font-semibold capitalize text-gray-900">{sessionMode || 'Idle'}</p>
            </div>
          </div>

          <p className="mb-5 max-w-2xl text-sm leading-6 text-gray-600">
            Readers can share access. A writer receives exclusive access only after every reader has released the resource.
          </p>

          <div className="flex flex-wrap gap-3">
            <button
              type="button"
              onClick={() => acquire('reader')}
              disabled={!isConnected || isBusy || sessionMode === 'reader' || Boolean(room.writer)}
              className="rounded-md bg-emerald-700 px-4 py-2.5 text-sm font-semibold text-white hover:bg-emerald-800 disabled:cursor-not-allowed disabled:bg-gray-300"
            >
              Acquire read lock
            </button>
            <button
              type="button"
              onClick={() => acquire('writer')}
              disabled={!isConnected || isBusy || sessionMode === 'writer' || room.reader_count > 0 || Boolean(room.writer)}
              className="rounded-md bg-rose-700 px-4 py-2.5 text-sm font-semibold text-white hover:bg-rose-800 disabled:cursor-not-allowed disabled:bg-gray-300"
            >
              Acquire write lock
            </button>
            <button
              type="button"
              onClick={release}
              disabled={!isConnected || isBusy || !sessionMode}
              className="rounded-md border border-gray-300 px-4 py-2.5 text-sm font-semibold text-gray-700 hover:bg-gray-50 disabled:cursor-not-allowed disabled:text-gray-400"
            >
              Release lock
            </button>
          </div>
          {error && <p className="mt-4 text-sm font-medium text-rose-700" role="alert">{error}</p>}
        </div>

        <aside className="border-t border-gray-200 pt-5 lg:border-l lg:border-t-0 lg:pl-6 lg:pt-0">
          <h3 className="text-sm font-bold text-gray-900">Active users</h3>
          <ul className="mt-3 space-y-3">
            {room.active_users.map((user, index) => (
              <li key={`${user.name}-${index}`} className="flex items-center justify-between gap-3 text-sm">
                <span className="truncate font-medium text-gray-800">
                  {user.name}{user.id === currentUserId ? ' (you)' : ''}
                </span>
                <span className="shrink-0 capitalize text-gray-500">{user.mode || 'online'}</span>
              </li>
            ))}
            {room.active_users.length === 0 && <li className="text-sm text-gray-500">No active users.</li>}
          </ul>
        </aside>
      </div>
    </section>
  );
}