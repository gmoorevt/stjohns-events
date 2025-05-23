import React, { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from 'react-query';
import axios from 'axios';

export default function Admin() {
  const queryClient = useQueryClient();
  const { data, isLoading, error } = useQuery('goal', async () => {
    const res = await axios.get(`${import.meta.env.VITE_API_URL}/api/goal`);
    return res.data.goal;
  });

  const [goal, setGoal] = useState<number | ''>('');
  const [isDownloading, setIsDownloading] = useState(false);
  const [downloadError, setDownloadError] = useState<string | null>(null);

  React.useEffect(() => {
    if (typeof data === 'number') setGoal(data);
  }, [data]);

  const mutation = useMutation(
    (newGoal: number) => axios.post(`${import.meta.env.VITE_API_URL}/api/goal`, { goal: newGoal }),
    {
      onSuccess: () => {
        queryClient.invalidateQueries('goal');
      },
    }
  );

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (goal !== '' && !isNaN(Number(goal))) {
      mutation.mutate(Number(goal));
    }
  };

  const handleDownloadEventbriteData = async () => {
    setIsDownloading(true);
    setDownloadError(null);
    try {
      const response = await axios.get(`${import.meta.env.VITE_API_URL}/api/eventbrite-raw`);
      const data = response.data;
      
      // Create a blob and download link
      const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
      const url = window.URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `eventbrite-data-${new Date().toISOString().split('T')[0]}.json`;
      document.body.appendChild(a);
      a.click();
      window.URL.revokeObjectURL(url);
      document.body.removeChild(a);
    } catch (err) {
      setDownloadError('Error downloading Eventbrite data');
      console.error('Download error:', err);
    } finally {
      setIsDownloading(false);
    }
  };

  return (
    <div className="min-h-screen flex flex-col items-center justify-center bg-gray-50 p-4">
      <div className="bg-white p-8 rounded shadow-md w-full max-w-md mb-8">
        <h2 className="text-2xl font-bold mb-4">Admin: Set Goal Amount</h2>
        {isLoading ? (
          <div>Loading current goal...</div>
        ) : error ? (
          <div className="text-red-600">Error loading goal</div>
        ) : (
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label className="block text-sm font-medium text-gray-700 mb-1">Current Goal</label>
              <input
                type="number"
                className="border rounded px-3 py-2 w-full"
                value={goal}
                onChange={e => setGoal(e.target.value === '' ? '' : Number(e.target.value))}
                min={0}
                step={1}
              />
            </div>
            <button
              type="submit"
              className="bg-indigo-600 text-white px-4 py-2 rounded hover:bg-indigo-700 w-full"
              disabled={mutation.isLoading}
            >
              {mutation.isLoading ? 'Saving...' : 'Save Goal'}
            </button>
            {mutation.isError && <div className="text-red-600">Error saving goal</div>}
            {mutation.isSuccess && <div className="text-green-600">Goal updated!</div>}
          </form>
        )}
      </div>

      <div className="bg-white p-8 rounded shadow-md w-full max-w-md">
        <h2 className="text-2xl font-bold mb-4">Eventbrite Data Export</h2>
        <p className="text-gray-600 mb-4">Download the raw Eventbrite API response for this event.</p>
        <button
          onClick={handleDownloadEventbriteData}
          disabled={isDownloading}
          className="bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700 w-full transition-colors duration-200"
        >
          {isDownloading ? 'Downloading...' : 'Download Eventbrite Data'}
        </button>
        {downloadError && <div className="text-red-600 mt-2">{downloadError}</div>}
      </div>
    </div>
  );
} 