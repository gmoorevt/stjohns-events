# Summerfest Event Dashboard

A clean, modern dashboard for tracking Eventbrite event metrics. Built with FastAPI, React, and TypeScript.

## Features

- Real-time event metrics tracking
- Clean, minimalist design
- Magic link authentication
- Responsive layout
- Interactive data visualizations

## Tech Stack

- Backend: Python 3.9+, FastAPI
- Frontend: React, TypeScript, Tailwind CSS
- Database: SQLite
- Authentication: Magic.link
- API: Eventbrite API

## Project Structure

```
summerfest/
├── backend/           # FastAPI application
│   └── summerfest.db  # SQLite database file
├── frontend/         # React application
├── .env.example      # Environment variables template
└── README.md         # This file
```

## Setup Instructions

### Backend Setup

1. Create a virtual environment:
   ```bash
   python -m venv venv
   source venv/bin/activate  # On Windows: .\venv\Scripts\activate
   ```

2. Install dependencies:
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

3. Set up environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your credentials
   ```

4. Run the backend:
   ```bash
   uvicorn main:app --reload
   ```

### Frontend Setup

1. Install dependencies:
   ```bash
   cd frontend
   npm install
   ```

2. Set up environment variables:
   ```bash
   cp .env.example .env
   # Edit .env with your configuration
   ```

3. Run the development server:
   ```bash
   npm run dev
   ```

## Environment Variables

Create a `.env` file in both backend and frontend directories with the following variables:

### Backend (.env)
```
EVENTBRITE_API_KEY=your_api_key
EVENTBRITE_CLIENT_SECRET=your_client_secret
EVENTBRITE_PRIVATE_TOKEN=your_private_token
EVENTBRITE_PUBLIC_TOKEN=your_public_token
MAGIC_SECRET_KEY=your_magic_secret_key
DATABASE_URL=sqlite:///./summerfest.db
```

### Frontend (.env)
```
VITE_API_URL=http://localhost:8000
VITE_MAGIC_PUBLISHABLE_KEY=your_magic_publishable_key
```

## Development

- Backend API runs on http://localhost:8000
- Frontend development server runs on http://localhost:5173
- API documentation available at http://localhost:8000/docs

## Security Notes

- Never commit `.env` files
- Keep API keys and secrets secure
- Use environment variables for all sensitive data
- The SQLite database file should be backed up regularly 