import random
import uuid
import time
import os
import requests
from datetime import datetime, timezone
from faker import Faker
from azure.eventhub import EventHubProducerClient, EventData
import json
from sqlalchemy import create_engine, text
from urllib.parse import quote_plus
from dotenv import load_dotenv
load_dotenv()

fake = Faker()

# ================== CONFIG ==================
ORDERS_INTERVAL      = int(os.getenv("ORDERS_INTERVAL", 30))
STOCK_INTERVAL       = int(os.getenv("STOCK_INTERVAL", 30))
CLICKSTREAM_INTERVAL = int(os.getenv("CLICKSTREAM_INTERVAL", 3))

EVENTHUB_CONN_STR = os.getenv("EVENTHUB_CONN_STR")
if not EVENTHUB_CONN_STR:
    raise RuntimeError("EVENTHUB_CONNECTION_STR n'est pas défini !")


SQL_USER = os.getenv("SQL_USER", "")
SQL_PASSWORD = quote_plus(os.getenv("SQL_PASSWORD", ""))
SQL_SERVER   = os.getenv("SQL_SERVER", "")
SQL_DB       = os.getenv("SQL_DB", "")


params = quote_plus(
    f"DRIVER={{ODBC Driver 18 for SQL Server}};"
    f"SERVER={SQL_SERVER};DATABASE={SQL_DB};UID={SQL_USER};PWD={SQL_PASSWORD};Encrypt=yes;TrustServerCertificate=no;"
)

engine = create_engine(f"mssql+pyodbc:///?odbc_connect={params}")
# ================== LOAD DATA POOLS FROM DB ==================
CUSTOMERS_POOL = []
PRODUCTS_POOL = []
SELLERS_POOL = []
SELLER_PRODUCT_POOL = []

with engine.begin() as conn:  # begin = auto commit transaction

    # ----- Customers -----
    for _ in range(50):
        customer_id = str(uuid.uuid4())
        result = conn.execute(text("""
            INSERT INTO dim_customer (customer_id, name, email, city, country, address)
            OUTPUT INSERTED.customer_sk
            VALUES (:customer_id, :name, :email, :city, :country, :address)
        """), {
            "customer_id": customer_id,
            "name": fake.name(),
            "email": fake.email(),
            "city": fake.city(),
            "country": fake.country(),
            "address": fake.address()
        })
        sk = result.fetchone()[0]
        CUSTOMERS_POOL.append({"customer_sk": sk, "id": customer_id})

    # ----- Sellers -----
    for _ in range(20):
        seller_id = str(uuid.uuid4())
        result = conn.execute(text("""
            INSERT INTO dim_seller (seller_id, name, status, country, city, address)
            OUTPUT INSERTED.seller_sk
            VALUES (:seller_id, :name, :status, :country, :city, :address)
        """), {
            "seller_id": seller_id,
            "name": fake.company(),
            "status": random.choice(["Active","Inactive"]),
            "country": fake.country(),
            "city": fake.city(),
            "address": fake.address()
        })
        sk = result.fetchone()[0]
        SELLERS_POOL.append({"seller_sk": sk, "id": seller_id})

    # ----- Products -----
    for _ in range(50):
        product_id = str(uuid.uuid4())
        result = conn.execute(text("""
            INSERT INTO dim_product (product_id, name, category, description)
            OUTPUT INSERTED.product_sk
            VALUES (:product_id, :name, :category, :description)
        """), {
            "product_id": product_id,
            "name": fake.word().title(),
            "category": random.choice(["Electronics","Home","Clothes","Toys","Computers"]),
            "description": fake.text(80)
        })
        sk = result.fetchone()[0]
        PRODUCTS_POOL.append({"product_sk": sk, "id": product_id, "price": round(random.uniform(10, 2000),2)})

    # ----- Seller Product Pricing -----
    for _ in range(80):
        seller = random.choice(SELLERS_POOL)
        product = random.choice(PRODUCTS_POOL)
        price = round(random.uniform(10, 2000),2)
        result = conn.execute(text("""
            INSERT INTO dim_seller_product_pricing (seller_sk, product_sk, price)
            OUTPUT INSERTED.seller_product_sk
            VALUES (:seller_sk, :product_sk, :price)
        """), {
            "seller_sk": seller["seller_sk"],
            "product_sk": product["product_sk"],
            "price": price
        })
        sk = result.fetchone()[0]
        SELLER_PRODUCT_POOL.append({
            "seller_product_sk": sk,
            "seller_sk": seller["seller_sk"],
            "product_sk": product["product_sk"],
            "price": price
        })

CUSTOMERS_POOL = []
PRODUCTS_POOL = []
SELLERS_POOL = []
SELLER_PRODUCT_POOL = []

with engine.connect() as conn:
    # Customers
    for row in conn.execute(text("SELECT customer_sk, customer_id, name, email, address, city, country FROM dim_customer")).fetchall():
        CUSTOMERS_POOL.append({
            "customer_sk": row.customer_sk,
            "id": row.customer_id,
            "name": row.name,
            "email": row.email,
            "address": row.address,
            "city": row.city,
            "country": row.country
        })

    # Products
    for row in conn.execute(text("SELECT product_sk, product_id, name, category FROM dim_product")).fetchall():
        PRODUCTS_POOL.append({
            "product_sk": row.product_sk,
            "id": row.product_id,
            "name": row.name,
            "category": row.category,
            "price": round(random.uniform(10, 2000), 2)  # Optionnel, tu peux avoir price réel si tu as dim_seller_product_pricing
        })

    # Sellers
    for row in conn.execute(text("SELECT seller_sk, seller_id, name FROM dim_seller")).fetchall():
        SELLERS_POOL.append({
            "seller_sk": row.seller_sk,
            "id": row.seller_id,
            "name": row.name
        })

    # Seller_Product Pricing
    for row in conn.execute(text("SELECT seller_product_sk, seller_sk, product_sk, price FROM dim_seller_product_pricing")).fetchall():
        seller = next(s for s in SELLERS_POOL if s["seller_sk"]==row.seller_sk)
        product = next(p for p in PRODUCTS_POOL if p["product_sk"]==row.product_sk)
        SELLER_PRODUCT_POOL.append({
            "seller_product_sk": row.seller_product_sk,
            "seller": seller,
            "product": product,
            "price": row.price
        })

print(f"Loaded {len(CUSTOMERS_POOL)} customers, {len(PRODUCTS_POOL)} products, {len(SELLERS_POOL)} sellers, {len(SELLER_PRODUCT_POOL)} seller_products")

# ================== EVENT HUB PRODUCER ==================
EVENT_HUBS = {
    "orders": ORDERS_INTERVAL,
    "stock": STOCK_INTERVAL,
    "clickstream": CLICKSTREAM_INTERVAL
}

producers = {
    name: EventHubProducerClient.from_connection_string(EVENTHUB_CONN_STR, eventhub_name=name)
    for name in EVENT_HUBS
}

def build_order_event():
    # Choisir un client
    customer = random.choice(CUSTOMERS_POOL)
    customer_sk = customer["customer_sk"]
    customer_id = customer["id"]

    # Générer un order
    order_id = str(uuid.uuid4())
    num_items = random.randint(1,5)
    items_raw = random.sample(SELLER_PRODUCT_POOL, num_items)

    # Créer items avec seller_product_sk et quantité
    items = []
    total_amount = 0
    for item in items_raw:
        quantity = random.randint(1,3)
        total_amount += item["price"] * quantity
        items.append({
            "seller_product_sk": item["seller_product_sk"],  # FK vers dim_seller_product_pricing
            "seller_id": item["seller"]["id"],
            "product_id": item["product"]["id"],
            "unit_price": float(item["price"]),
            "quantity": quantity
        })

    return {
        "event_type": "order",
        "event_id": str(uuid.uuid4()),
        "order_id": order_id,
        "customer_sk": customer_sk,      # FK vers dim_customer
        "customer_id": customer_id,      # facultatif pour info
        "items": items,
        "total_amount": float(round(total_amount,2)),
        "currency": "USD",
        "status": "PLACED",
        "timestamp": datetime.now(timezone.utc).isoformat()
    }
def build_stock_event():
    item = random.choice(SELLER_PRODUCT_POOL)
    return {
        "event_id": str(uuid.uuid4()),
        "seller_product_sk": item["seller_product_sk"],
        "stock": random.randint(0,200),
        "event_timestamp": datetime.now(timezone.utc).isoformat(),
        "source":"generator"
    }

def build_clickstream_event():
    event_type = random.choice(["view_page", "add_to_cart", "checkout_start"])
    product = random.choice(PRODUCTS_POOL)
    url = f"/product/{product['id']}" if event_type=="view_page" else ("/cart" if event_type=="add_to_cart" else "/checkout")
    return {
        "event_type": "clickstream",
        "event_id": str(uuid.uuid4()),
        "session_id": str(uuid.uuid4()),
        "user_id": str(uuid.uuid4()),
        "url": url,
        "action": event_type,
        "user_agent": fake.user_agent(),
        "ip": fake.ipv4(),
        "timestamp": datetime.now(timezone.utc).isoformat()
    }

def send_event(hub_name, event):
    try:
        batch = producers[hub_name].create_batch()
        batch.add(EventData(json.dumps(event)))
        producers[hub_name].send_batch(batch)
        print(f"[{hub_name}] Sent event {event['event_id']}")
    except Exception as e:
        print(f"Error sending to {hub_name}: {e}")

# ================== STREAMING LOOP ==================
timers = {k:0 for k in EVENT_HUBS}
print("Event Hub Stream Producer démarré…")

while True:
    now = time.time()
    for name, interval in EVENT_HUBS.items():
        if now - timers[name] >= interval:
            if name=="orders":
                send_event(name, build_order_event())
            elif name=="stock":
                send_event(name, build_stock_event())
            elif name=="clickstream":
                send_event(name, build_clickstream_event())
            timers[name] = now
    time.sleep(0.5)
