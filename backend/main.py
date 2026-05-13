from contextlib import asynccontextmanager
from fastapi import Depends, FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List, Dict, Any
import os
from dotenv import load_dotenv
import aiohttp
import json
from decimal import Decimal

# Load environment variables
load_dotenv()

from db import get_db
from deps import get_current_user, require_admin
from models import Setting, User
from auth_routes import router as auth_router
from admin_routes import router as admin_router
from startup import ensure_admin_user

EVENTBRITE_API_KEY = os.getenv("EVENTBRITE_API_KEY")
EVENTBRITE_OAUTH_TOKEN = os.getenv("EVENTBRITE_OAUTH_TOKEN")
EVENTBRITE_ORG_ID = os.getenv("EVENTBRITE_ORG_ID")
EVENT_ID = os.getenv("EVENTBRITE_EVENT_ID", "1989097915410")

# Debug CORS configuration
cors_origins_str = os.getenv("BACKEND_CORS_ORIGINS", "http://localhost:5173")
# Clean up the string by removing any brackets and quotes
cors_origins = [origin.strip().strip('"\'[]') for origin in cors_origins_str.split(",")]
print(f"Configuring CORS with origins: {cors_origins}")

@asynccontextmanager
async def lifespan(app: FastAPI):
    ensure_admin_user()
    yield


# Initialize FastAPI app
app = FastAPI(
    title="Summerfest Event Dashboard API",
    description="API for tracking Eventbrite event metrics",
    version="1.0.0",
    lifespan=lifespan,
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth_router)
app.include_router(admin_router)

# Health check endpoint
@app.get("/api/health")
async def health_check():
    return {
        "status": "healthy",
        "version": "1.0.0",
        "api_status": "operational"
    }

# Models
class EventMetrics(BaseModel):
    total_gross: float
    total_net: float
    ticket_types: List[Dict[str, Any]]
    goal_percentage: float
    attendee_count: int = 0
    event_name: str | None = None
    event_start_local: str | None = None  # ISO local time, e.g. "2026-06-07T16:00:00"
    event_url: str | None = None

class GoalRequest(BaseModel):
    goal: float

class Order(BaseModel):
    name: str
    quantity: int
    ticket_type: str
    price: float
    order_id: str | None = None
    date: str | None = None

class OrdersResponse(BaseModel):
    orders: List[Order]

# Mock data
MOCK_DATA = {
    "event": {
        "costs": {
            "gross": {"major_value": 75000},
            "net": {"major_value": 65000}
        }
    },
    "tickets": {
        "ticket_classes": [
            {
                "name": "Early Bird",
                "quantity_sold": 150,
                "cost": {"major_value": 50.00}
            },
            {
                "name": "Regular Admission",
                "quantity_sold": 300,
                "cost": {"major_value": 75.00}
            },
            {
                "name": "VIP",
                "quantity_sold": 50,
                "cost": {"major_value": 150.00}
            },
            {
                "name": "Student",
                "quantity_sold": 100,
                "cost": {"major_value": 25.00}
            }
        ]
    }
}

# Routes
@app.get("/")
async def root():
    return {"message": "Welcome to Summerfest Event Dashboard API"}

@app.get("/api/goal")
async def get_goal(_: User = Depends(get_current_user), db: Session = Depends(get_db)):
    return {"goal": read_goal(db)}

@app.get("/api/eventbrite-raw")
async def get_eventbrite_raw(_: User = Depends(require_admin)):
    try:
        eventbrite_data = await fetch_eventbrite_event(EVENT_ID)
        return eventbrite_data
    except Exception as e:
        print(f"Error fetching raw Eventbrite data: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/goal")
async def set_goal(goal_req: GoalRequest, _: User = Depends(require_admin), db: Session = Depends(get_db)):
    write_goal(db, goal_req.goal)
    return {"goal": goal_req.goal}

@app.get("/api/metrics", response_model=EventMetrics)
async def get_metrics(_: User = Depends(get_current_user), db: Session = Depends(get_db)):
    try:
        event_name: str | None = None
        event_start_local: str | None = None
        event_url: str | None = None
        try:
            print("\n=== Starting metrics fetch ===")
            print(f"Using Event ID: {EVENT_ID}")
            sales_data = await calculate_sales_metrics(EVENT_ID)
            total_gross = sales_data['total_gross']
            total_net = sales_data['total_net']
            ticket_types = sales_data['ticket_types']
            attendee_count = sales_data['attendee_count']

            event_data = await fetch_eventbrite_event(EVENT_ID)
            event_name = (event_data.get("name") or {}).get("text")
            event_start_local = (event_data.get("start") or {}).get("local")
            event_url = event_data.get("url")
            cache_event_meta(db, event_name, event_start_local, event_url)
        except Exception as e:
            print(f"\nError fetching Eventbrite data: {str(e)}")
            print("Falling back to mock data + cached event meta")
            event = MOCK_DATA["event"]
            total_gross = float(event["costs"]["gross"]["major_value"])
            total_net = float(event["costs"]["net"]["major_value"])
            ticket_types = [
                {
                    "name": tc["name"],
                    "quantity_sold": tc["quantity_sold"],
                    "quantity_total": tc.get("quantity_total", tc["quantity_sold"]),
                    "quantity_available": tc.get("quantity_available", 0),
                    "cost": float(tc["cost"]["major_value"]),
                    "fee": 0.0,
                    "gross_revenue": float(tc["cost"]["major_value"]) * tc["quantity_sold"],
                    "net_revenue": float(tc["cost"]["major_value"]) * tc["quantity_sold"],
                    "status": "active",
                    "on_sale_status": "on_sale"
                }
                for tc in MOCK_DATA["tickets"]["ticket_classes"]
            ]
            event_name, event_start_local, event_url = read_event_meta(db)
            attendee_count = 0

        goal = read_goal(db)
        goal_percentage = (total_gross / goal) * 100 if goal > 0 else 0
        return EventMetrics(
            total_gross=total_gross,
            total_net=total_net,
            ticket_types=ticket_types,
            goal_percentage=goal_percentage,
            attendee_count=attendee_count,
            event_name=event_name,
            event_start_local=event_start_local,
            event_url=event_url,
        )
    except Exception as e:
        print(f"\nFatal error in get_metrics: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/orders", response_model=OrdersResponse)
async def get_orders(_: User = Depends(get_current_user)):
    try:
        orders = await fetch_orders(EVENT_ID)
        valid_orders = [order for order in orders if order.get("status") not in ["cancelled", "refunded"]]

        formatted_orders: List[Order] = []
        for order in valid_orders:
            order_id = order.get("id")
            order_date = order.get("created")
            for attendee in order.get("attendees", []):
                if attendee.get("cancelled") or attendee.get("refunded"):
                    continue
                attendee_gross = (attendee.get("costs") or {}).get("gross") or {}
                price = float(attendee_gross.get("value") or 0) / 100
                formatted_orders.append(Order(
                    name=(attendee.get("profile") or {}).get("name", "Unknown"),
                    quantity=1,
                    ticket_type=attendee.get("ticket_class_name") or "Unknown",
                    price=price,
                    order_id=str(order_id) if order_id else None,
                    date=order_date,
                ))

        return OrdersResponse(orders=formatted_orders)
    except Exception as e:
        print(f"Error fetching orders: {e}")
        raise HTTPException(status_code=500, detail=str(e))

GOAL_KEY = "goal"
GOAL_FILE = "goal.txt"
DEFAULT_GOAL = 100000.0


def read_goal(db: Session) -> float:
    row = db.get(Setting, GOAL_KEY)
    if row is not None:
        try:
            return float(row.value)
        except ValueError:
            pass
    # Legacy fallback: migrate from goal.txt if present, then return DEFAULT_GOAL.
    if os.path.exists(GOAL_FILE):
        try:
            with open(GOAL_FILE, "r") as f:
                value = float(f.read().strip())
            db.merge(Setting(key=GOAL_KEY, value=str(value)))
            db.commit()
            return value
        except Exception as e:
            print(f"Error migrating goal.txt: {e}")
    return DEFAULT_GOAL


def write_goal(db: Session, goal: float) -> None:
    db.merge(Setting(key=GOAL_KEY, value=str(goal)))
    db.commit()


EVENT_META_KEYS = ("event_name", "event_start_local", "event_url")


def cache_event_meta(db: Session, name: str | None, start_local: str | None, url: str | None) -> None:
    for key, value in zip(EVENT_META_KEYS, (name, start_local, url)):
        if value:
            db.merge(Setting(key=key, value=value))
    db.commit()


def read_event_meta(db: Session) -> tuple[str | None, str | None, str | None]:
    return tuple(  # type: ignore[return-value]
        (db.get(Setting, key).value if db.get(Setting, key) else None)
        for key in EVENT_META_KEYS
    )

# (Optional) Eventbrite API helper (fetch event details and ticket classes) – (using aiohttp for async calls)
async def fetch_eventbrite_event(event_id: str) -> Dict[Any, Any]:
    if not EVENTBRITE_API_KEY or not EVENTBRITE_OAUTH_TOKEN:
        raise HTTPException(status_code=500, detail="Eventbrite credentials not configured.")
    
    url = f"https://www.eventbriteapi.com/v3/events/{event_id}?expand=ticket_classes"
    headers = { 
        "Authorization": f"Bearer {EVENTBRITE_OAUTH_TOKEN}",
        "Accept": "application/json"
    }
    async with aiohttp.ClientSession() as session:
        async with session.get(url, headers=headers) as resp:
            if resp.status != 200:
                raise HTTPException(status_code=resp.status, detail=f"Eventbrite API error: {resp.status} – {await resp.text()}")
            data = await resp.json()
            if not isinstance(data, dict):
                raise HTTPException(status_code=500, detail="Eventbrite API returned invalid (non-dict) data.")
            return data

async def fetch_ticket_classes(event_id: str) -> List[Dict[Any, Any]]:
    """Fetch detailed ticket class information including quantities and costs."""
    if not EVENTBRITE_API_KEY or not EVENTBRITE_OAUTH_TOKEN:
        print("Missing Eventbrite credentials")
        raise HTTPException(status_code=500, detail="Eventbrite credentials not configured.")
    
    url = f"https://www.eventbriteapi.com/v3/events/{event_id}/ticket_classes/"
    headers = { 
        "Authorization": f"Bearer {EVENTBRITE_OAUTH_TOKEN}",
        "Accept": "application/json"
    }
    print(f"Fetching ticket classes from: {url}")
    
    async with aiohttp.ClientSession() as session:
        async with session.get(url, headers=headers) as resp:
            print(f"Ticket classes response status: {resp.status}")
            if resp.status != 200:
                error_text = await resp.text()
                print(f"Ticket classes error response: {error_text}")
                raise HTTPException(status_code=resp.status, detail=f"Eventbrite API error: {resp.status} – {error_text}")
            data = await resp.json()
            print(f"Raw ticket classes data: {data}")
            if not isinstance(data, dict) or 'ticket_classes' not in data:
                print("Invalid ticket classes response")
                raise HTTPException(status_code=500, detail="Invalid ticket classes response")
            return data['ticket_classes']

async def fetch_orders(event_id: str) -> List[Dict[Any, Any]]:
    """Fetch all orders for the event, including attendees."""
    if not EVENTBRITE_API_KEY or not EVENTBRITE_OAUTH_TOKEN:
        print("Missing Eventbrite credentials, using mock data")
        # Return mock orders data
        return [
            {
                "status": "completed",
                "attendees": [
                    {
                        "profile": {"name": "John Doe"},
                        "ticket_class": {"name": "Regular Admission"}
                    }
                ],
                "costs": {
                    "gross": {"value": 7500},
                    "eventbrite_fee": {"value": 1000}
                }
            },
            {
                "status": "completed",
                "attendees": [
                    {
                        "profile": {"name": "Jane Smith"},
                        "ticket_class": {"name": "VIP"}
                    }
                ],
                "costs": {
                    "gross": {"value": 15000},
                    "eventbrite_fee": {"value": 2000}
                }
            }
        ]
    
    url = f"https://www.eventbriteapi.com/v3/events/{event_id}/orders/"
    headers = { 
        "Authorization": f"Bearer {EVENTBRITE_OAUTH_TOKEN}",
        "Accept": "application/json"
    }
    print(f"Fetching orders from: {url}")
    
    all_orders = []
    page = 1
    
    async with aiohttp.ClientSession() as session:
        while True:
            try:
                params = {"page": page, "expand": "attendees"}
                async with session.get(url, headers=headers, params=params) as resp:
                    if resp.status != 200:
                        error_text = await resp.text()
                        print(f"Orders error response: {error_text}")
                        raise HTTPException(status_code=resp.status, detail=f"Eventbrite API error: {resp.status} – {error_text}")
                    
                    data = await resp.json()
                    orders = data.get("orders", [])
                    all_orders.extend(orders)
                    
                    # Check if there are more pages
                    if not data.get("pagination", {}).get("has_more_items", False):
                        break
                    page += 1
            except Exception as e:
                print(f"Error fetching orders (page {page}): {e}")
                break
    
    return all_orders

async def calculate_sales_metrics(event_id: str) -> Dict[str, float]:
    """Calculate sales metrics from ticket classes and orders."""
    try:
        # Get ticket classes and orders
        ticket_classes = await fetch_ticket_classes(event_id)
        orders = await fetch_orders(event_id)
        valid_orders = [order for order in orders if order.get("status") not in ["cancelled", "refunded"]]
        
        # Calculate from orders first as it's the most accurate.
        # Net = gross - eventbrite_fee - payment_fee (matches Eventbrite's "Net sales" total).
        # Attendees = total GA tickets across all orders + 1 per support-only order
        # (an order that contains tickets but no General Admission still represents one attendee).
        order_gross = Decimal('0')
        order_fees = Decimal('0')
        attendee_count = 0

        for order in valid_orders:
            costs = order.get("costs", {})
            if costs.get("gross", {}):
                order_gross += Decimal(str(costs["gross"].get("value", 0))) / 100
            if costs.get("eventbrite_fee", {}):
                order_fees += Decimal(str(costs["eventbrite_fee"].get("value", 0))) / 100
            if costs.get("payment_fee", {}):
                order_fees += Decimal(str(costs["payment_fee"].get("value", 0))) / 100

            attendees = [
                a for a in order.get("attendees", [])
                if not a.get("cancelled") and not a.get("refunded")
            ]
            ga_count = sum(
                1 for a in attendees
                if "general admission" in (a.get("ticket_class_name") or "").lower()
            )
            if ga_count:
                attendee_count += ga_count
            elif attendees:
                attendee_count += 1
        
        # Calculate from ticket classes as a backup
        total_gross = Decimal('0')
        total_net = Decimal('0')
        ticket_types = []
        
        for tc in ticket_classes:
            quantity_sold = tc.get("quantity_sold", 0)
            is_donation = tc.get("donation", False)
            
            # For donations, use actual_cost if available, otherwise use cost
            if is_donation:
                cost = tc.get("actual_cost", tc.get("cost", {}))
                fee = tc.get("actual_fee", tc.get("fee", {}))
            else:
                cost = tc.get("cost", {})
                fee = tc.get("fee", {})
            
            # Calculate revenue for this ticket type
            ticket_price = Decimal(str(cost.get("value", 0))) / 100 if cost and cost.get("value") is not None else Decimal('0')
            ticket_fee = Decimal(str(fee.get("value", 0))) / 100 if fee and fee.get("value") is not None else Decimal('0')
            
            gross_revenue = ticket_price * quantity_sold
            net_revenue = (ticket_price - ticket_fee) * quantity_sold
            
            total_gross += gross_revenue
            total_net += net_revenue
            
            ticket_info = {
                "name": tc.get("name", ""),
                "quantity_sold": quantity_sold,
                "quantity_total": tc.get("quantity_total", 0),
                "quantity_available": tc.get("quantity_available", 0),
                "cost": float(ticket_price),
                "fee": float(ticket_fee),
                "gross_revenue": float(gross_revenue),
                "net_revenue": float(net_revenue),
                "status": tc.get("status", ""),
                "on_sale_status": tc.get("on_sale_status", "")
            }
            ticket_types.append(ticket_info)
        
        # Use the order-based calculations as they're more accurate
        # The order data includes the actual amounts paid, including variable donations
        return {
            "total_gross": float(order_gross),
            "total_net": float(order_gross - order_fees),
            "ticket_types": ticket_types,
            "attendee_count": attendee_count,
        }
    except Exception as e:
        print(f"Error calculating sales metrics: {e}")
        raise

# (New function) Save Eventbrite API response (eventbrite_data) to a file (e.g. "eventbrite_response.json")
def save_eventbrite_response(eventbrite_data: Dict[Any, Any], filename: str = "eventbrite_response.json") -> None:
    try:
        with open(filename, "w") as f:
            json.dump(eventbrite_data, f, indent=2)
        print(f"Eventbrite response saved to {filename}.")
    except Exception as e:
        print(f"Error saving Eventbrite response: {e}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000) 