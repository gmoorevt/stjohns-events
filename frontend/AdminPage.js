import React, { useState, useEffect } from 'react';
import { API_BASE_URL } from './config';

function AdminPage() {
    const [goal, setGoal] = useState('');
    const [error, setError] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const [isDownloading, setIsDownloading] = useState(false);

    useEffect(() => {
        fetchGoal();
    }, []);

    const fetchGoal = async () => {
        try {
            const response = await fetch(`${API_BASE_URL}/api/goal`);
            const data = await response.json();
            setGoal(data.goal.toString());
        } catch (err) {
            setError('Error loading goal amount');
            console.error(err);
        }
    };

    const handleGoalChange = (e) => {
        const value = e.target.value;
        // Only allow positive integers
        if (/^\d*$/.test(value)) {
            setGoal(value);
            setError('');
        }
    };

    const handleSubmit = async (e) => {
        e.preventDefault();
        if (!goal || parseInt(goal) <= 0) {
            setError('Please enter a valid positive goal amount');
            return;
        }

        setIsLoading(true);
        setError('');
        try {
            const response = await fetch(`${API_BASE_URL}/api/goal`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({ goal: parseFloat(goal) }),
            });
            if (!response.ok) {
                throw new Error('Failed to update goal');
            }
        } catch (err) {
            setError('Error updating goal amount');
            console.error(err);
        } finally {
            setIsLoading(false);
        }
    };

    const handleDownloadEventbriteData = async () => {
        setIsDownloading(true);
        setError('');
        try {
            const response = await fetch(`${API_BASE_URL}/api/eventbrite-raw`);
            if (!response.ok) {
                throw new Error('Failed to fetch Eventbrite data');
            }
            const data = await response.json();
            
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
            setError('Error downloading Eventbrite data');
            console.error(err);
        } finally {
            setIsDownloading(false);
        }
    };

    return (
        <div className="container mx-auto p-4">
            <h1 className="text-2xl font-bold mb-4">Admin Dashboard</h1>
            
            <div className="bg-white shadow-md rounded px-8 pt-6 pb-8 mb-4">
                <h2 className="text-xl font-semibold mb-4">Set Goal Amount</h2>
                <form onSubmit={handleSubmit} className="mb-4">
                    <div className="mb-4">
                        <label className="block text-gray-700 text-sm font-bold mb-2" htmlFor="goal">
                            Goal Amount ($)
                        </label>
                        <input
                            className="shadow appearance-none border rounded w-full py-2 px-3 text-gray-700 leading-tight focus:outline-none focus:shadow-outline"
                            id="goal"
                            type="text"
                            value={goal}
                            onChange={handleGoalChange}
                            placeholder="Enter goal amount"
                        />
                    </div>
                    {error && <p className="text-red-500 text-xs italic mb-4">{error}</p>}
                    <button
                        className="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded focus:outline-none focus:shadow-outline"
                        type="submit"
                        disabled={isLoading}
                    >
                        {isLoading ? 'Updating...' : 'Update Goal'}
                    </button>
                </form>

                <hr className="my-8 border-t-2 border-gray-200" />

                <div className="bg-gray-50 p-6 rounded-lg border border-gray-200">
                    <h2 className="text-xl font-semibold mb-4 text-gray-800">Eventbrite Data Export</h2>
                    <p className="text-gray-600 mb-4">Download the raw Eventbrite API response for this event.</p>
                    <button
                        className="bg-green-500 hover:bg-green-700 text-white font-bold py-2 px-6 rounded-lg focus:outline-none focus:shadow-outline transition-colors duration-200"
                        onClick={handleDownloadEventbriteData}
                        disabled={isDownloading}
                    >
                        {isDownloading ? 'Downloading...' : 'Download Eventbrite Data'}
                    </button>
                </div>
            </div>
        </div>
    );
}

export default AdminPage; 