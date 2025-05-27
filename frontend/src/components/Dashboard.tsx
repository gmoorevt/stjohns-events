import React from 'react';
import { useQuery } from 'react-query';
import axios, { AxiosError } from 'axios';

interface TicketType {
  name: string;
  quantity_sold: number;
  quantity_total: number;
  quantity_available: number;
  cost: number;
  status: string;
  on_sale_status: string;
}

interface Metrics {
  total_gross: number;
  total_net: number;
  ticket_types: TicketType[];
  goal_percentage: number;
}

interface Order {
  name: string;
  quantity: number;
  ticket_type: string;
  price: number;
  order_id?: string;
  date?: string;
}

interface OrdersResponse {
  orders: Order[];
}

export default function Dashboard() {
  const { data: metrics, isLoading: metricsLoading, error: metricsError } = useQuery<Metrics, AxiosError>(
    'metrics',
    async () => {
      console.log('Fetching metrics from:', `${import.meta.env.VITE_API_URL}/api/metrics`);
      try {
        const response = await axios.get(`${import.meta.env.VITE_API_URL}/api/metrics`);
        console.log('API Response:', response.data);
        return response.data;
      } catch (err) {
        const error = err as AxiosError;
        console.error('API Error details:', {
          message: error.message,
          response: error.response?.data,
          status: error.response?.status,
          headers: error.response?.headers,
          config: {
            url: error.config?.url,
            method: error.config?.method,
            headers: error.config?.headers
          }
        });
        throw error;
      }
    },
    {
      refetchInterval: 30000, // Refetch every 30 seconds
      onError: (error: AxiosError) => {
        console.error('Query error:', error.message);
      },
      onSuccess: (data) => {
        console.log('Query success:', data);
      }
    }
  );

  const { data: ordersData, isLoading: ordersLoading, error: ordersError } = useQuery<OrdersResponse, AxiosError>(
    'orders',
    async () => {
      try {
        const response = await axios.get(`${import.meta.env.VITE_API_URL}/api/orders`);
        return response.data;
      } catch (err) {
        const error = err as AxiosError;
        console.error('Orders API Error:', error.message);
        throw error;
      }
    },
    {
      refetchInterval: 30000, // Refetch every 30 seconds
    }
  );

  // Calculate total unique orders
  const totalOrders = React.useMemo(() => {
    if (!ordersData?.orders) return 0;
    const uniqueOrderIds = new Set(ordersData.orders.map(order => order.order_id || order.name));
    return uniqueOrderIds.size;
  }, [ordersData]);

  console.log('Current metrics state:', { metrics, isLoading: metricsLoading, error: metricsError });

  // Calculate days until event
  const eventDate = new Date('2025-06-08');
  const today = new Date();
  const daysUntilEvent = Math.ceil((eventDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24));

  // Calculate total attendees (tickets for tracking attendance)
  const totalAttendees = metrics?.ticket_types.reduce((sum, ticket) => {
    if (ticket.name.toLowerCase().includes('tracking attendance')) {
      return sum + ticket.quantity_sold;
    }
    return sum;
  }, 0) || 0;

  if (metricsLoading || ordersLoading) {
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600"></div>
      </div>
    );
  }

  if (metricsError || ordersError) {
    const error = (metricsError || ordersError) as AxiosError;
    console.error('Dashboard error:', error.message);
    return (
      <div className="min-h-screen flex items-center justify-center">
        <div className="text-red-600">
          <p className="text-xl font-semibold mb-2">Error loading dashboard data</p>
          <p className="text-sm">{error.message || 'Unknown error occurred'}</p>
        </div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-indigo-50 via-white to-pink-50 font-sans">
      <nav className="bg-white shadow-md sticky top-0 z-20">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-20 items-center">
            <div className="flex items-center">
              <h1 className="text-3xl font-extrabold text-indigo-700 tracking-tight">Summerfest Dashboard</h1>
            </div>
          </div>
        </div>
      </nav>

      <main className="max-w-7xl mx-auto py-10 sm:px-6 lg:px-8">
        {/* Event Info Card */}
        <div className="mb-10 flex flex-col sm:flex-row gap-8">
          <div className="bg-gradient-to-tr from-pink-100 via-white to-indigo-100 shadow-xl rounded-2xl p-8 w-full sm:w-1/2 relative overflow-hidden border border-indigo-100">
            <div className="relative z-10">
              <h2 className="text-3xl font-extrabold text-indigo-800 mb-3 flex items-center gap-2">
                <svg className="w-8 h-8 text-pink-400" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M8 7V3M16 7V3M4 11H20M5 19H19M4 7H20M12 15V19" /></svg>
                St. John's 2025 Summerfest
              </h2>
              <div className="flex items-center text-gray-600 mb-4 text-lg">
                <svg className="w-5 h-5 mr-2 text-indigo-400" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M8 7V3M16 7V3M4 11H20M5 19H19M4 7H20M12 15V19" /></svg>
                Sun, Jun 8, 2025, 4:00 PM
              </div>
              <div className="flex items-center mb-2">
                <a href="https://stjohnsumerfest.eventbrite.com" target="_blank" rel="noopener noreferrer" className="ml-6 text-blue-600 hover:underline flex items-center text-base font-semibold">
                  View
                  <svg className="w-5 h-5 ml-1" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M14 3h7m0 0v7m0-7L10 14m-7 7h7a2 2 0 002-2v-7" /></svg>
                </a>
              </div>
            </div>
          </div>
        </div>

        {/* Metrics Overview */}
        <div className="grid grid-cols-1 gap-8 sm:grid-cols-2 lg:grid-cols-5 mb-12">
          {/* Total Gross */}
          <div className="bg-white hover:shadow-2xl transition-shadow duration-200 shadow-lg rounded-2xl p-6 flex flex-col items-center border-t-4 border-indigo-400">
            <div className="flex items-center mb-2">
              <svg className="w-6 h-6 text-indigo-400 mr-2" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M12 8c-1.657 0-3 1.343-3 3s1.343 3 3 3 3-1.343 3-3-1.343-3-3-3zm0 0V4m0 7v7" /></svg>
              <dt className="text-base font-medium text-gray-500">Total Gross</dt>
            </div>
            <dd className="text-4xl font-extrabold text-indigo-700 text-center">${metrics?.total_gross.toLocaleString()}</dd>
          </div>

          {/* Total Net */}
          <div className="bg-white hover:shadow-2xl transition-shadow duration-200 shadow-lg rounded-2xl p-6 flex flex-col items-center border-t-4 border-green-400">
            <div className="flex items-center mb-2">
              <svg className="w-6 h-6 text-green-400 mr-2" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M12 8c-1.657 0-3 1.343-3 3s1.343 3 3 3 3-1.343 3-3-1.343-3-3-3zm0 0V4m0 7v7" /></svg>
              <dt className="text-base font-medium text-gray-500">Total Net</dt>
            </div>
            <dd className="text-4xl font-extrabold text-green-700 text-center">${metrics?.total_net.toLocaleString()}</dd>
          </div>

          {/* Goal Progress */}
          <div className="bg-white hover:shadow-2xl transition-shadow duration-200 shadow-lg rounded-2xl p-6 flex flex-col items-center border-t-4 border-pink-400">
            <div className="flex items-center mb-2">
              <svg className="w-6 h-6 text-pink-400 mr-2" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M12 8c-1.657 0-3 1.343-3 3s1.343 3 3 3 3-1.343 3-3-1.343-3-3-3zm0 0V4m0 7v7" /></svg>
              <dt className="text-base font-medium text-gray-500">Goal Progress</dt>
            </div>
            <dd className="text-4xl font-extrabold text-pink-700 text-center">{metrics?.goal_percentage.toFixed(1)}%</dd>
            <div className="mt-2 w-full bg-gray-200 rounded-full h-3">
              <div
                className="bg-pink-400 h-3 rounded-full transition-all duration-300"
                style={{ width: `${Math.min(metrics?.goal_percentage || 0, 100)}%` }}
              ></div>
            </div>
            <div className="mt-2 text-xs text-gray-500 text-center w-full">
              Goal: ${((metrics?.total_gross || 0) / (metrics?.goal_percentage || 1) * 100).toLocaleString(undefined, {minimumFractionDigits: 0, maximumFractionDigits: 0})}
            </div>
          </div>

          {/* Days to Event */}
          <div className="bg-white hover:shadow-2xl transition-shadow duration-200 shadow-lg rounded-2xl p-6 flex flex-col items-center border-t-4 border-yellow-400">
            <div className="flex items-center mb-2">
              <svg className="w-6 h-6 text-yellow-400 mr-2" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M8 7V3M16 7V3M4 11H20M5 19H19M4 7H20M12 15V19" /></svg>
              <dt className="text-base font-medium text-gray-500">Days to Event</dt>
            </div>
            <dd className="text-4xl font-extrabold text-yellow-700 text-center">{daysUntilEvent}</dd>
            <div className="mt-2 text-xs text-gray-500 text-center w-full">
              Sun, Jun 8, 2025
            </div>
          </div>

          {/* Number of Attendees */}
          <div className="bg-white hover:shadow-2xl transition-shadow duration-200 shadow-lg rounded-2xl p-6 flex flex-col items-center border-t-4 border-blue-400">
            <div className="flex items-center mb-2">
              <svg className="w-6 h-6 text-blue-400 mr-2" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M17 20h5v-2a4 4 0 00-3-3.87M9 20H4v-2a4 4 0 013-3.87M17 8a4 4 0 11-8 0 4 4 0 018 0zm6 12v-2a4 4 0 00-3-3.87M3 20v-2a4 4 0 013-3.87" /></svg>
              <dt className="text-base font-medium text-gray-500">Attendees</dt>
            </div>
            <dd className="text-4xl font-extrabold text-blue-700 text-center">{totalAttendees.toLocaleString()}</dd>
          </div>

          {/* Total Orders */}
          <div className="bg-white hover:shadow-2xl transition-shadow duration-200 shadow-lg rounded-2xl p-6 flex flex-col items-center border-t-4 border-gray-400">
            <div className="flex items-center mb-2">
              <svg className="w-6 h-6 text-gray-400 mr-2" fill="none" stroke="currentColor" strokeWidth="2" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" d="M3 7h18M3 12h18M3 17h18" /></svg>
              <dt className="text-base font-medium text-gray-500">Total Orders</dt>
            </div>
            <dd className="text-4xl font-extrabold text-gray-700 text-center">{ordersLoading ? <span className="text-gray-400">...</span> : totalOrders.toLocaleString()}</dd>
            <div className="mt-2 text-xs text-gray-500 text-center w-full">
              Number of families
            </div>
          </div>
        </div>

        {/* Ticket Details Table */}
        <div className="mt-12">
          <div className="bg-white shadow-xl rounded-2xl overflow-hidden">
            <div className="px-6 py-6 border-b border-gray-200 bg-gradient-to-r from-indigo-50 to-pink-50">
              <h3 className="text-2xl font-bold text-indigo-800">Ticket Details</h3>
            </div>
            <div className="border-t border-gray-200">
              <table className="min-w-full divide-y divide-gray-200">
                <thead className="bg-gray-50">
                  <tr>
                    <th scope="col" className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Ticket Type</th>
                    <th scope="col" className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Sold</th>
                    <th scope="col" className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Price</th>
                    <th scope="col" className="px-6 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Revenue</th>
                  </tr>
                </thead>
                <tbody className="bg-white divide-y divide-gray-100">
                  {metrics?.ticket_types.map((ticket) => (
                    <tr key={ticket.name} className="hover:bg-indigo-50 transition-colors">
                      <td className="px-6 py-4 whitespace-nowrap text-base font-medium text-gray-900">{ticket.name}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-base text-gray-500">{ticket.quantity_sold}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-base text-gray-500">${ticket.cost.toLocaleString()}</td>
                      <td className="px-6 py-4 whitespace-nowrap text-base text-gray-500">
                        ${(ticket.quantity_sold * ticket.cost).toLocaleString()}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
} 