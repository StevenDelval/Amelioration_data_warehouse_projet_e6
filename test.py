import random
import uuid
import time
import os
from datetime import datetime, timezone, timedelta
from faker import Faker
from sqlalchemy import create_engine, text
from urllib.parse import quote_plus


fake = Faker()

# ================== CONFIG ==================
ORDERS_INTERVAL      = int(os.getenv("ORDERS_INTERVAL", 60))
STOCK_INTERVAL       = int(os.getenv("STOCK_INTERVAL", 30))
CLICKSTREAM_INTERVAL = int(os.getenv("CLICKSTREAM_INTERVAL", 3))

password = quote_plus(os.getenv("SQL_PASSWORD", "P@ssw0rd!2024"))
server = os.getenv("SQL_SERVER", "sql-server-rg-e6-sdelval.database.windows.net")
database = os.getenv("SQL_DB", "dwh-shopnow")

connection_string = (
    f"mssql+pyodbc://sqladmin:{password}"
    f"@{server}:1433/{database}"
    "?driver=ODBC+Driver+18+for+SQL+Server"
    "&Encrypt=yes&TrustServerCertificate=yes"
)

engine = create_engine(connection_string, fast_executemany=True)

# ================== INSERT INITIAL DIMENSIONS ==================
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

print("✅ Dimensions initialized!")

# ================== STREAMING LOOP ==================
def insert_order(conn):
    order_id = str(uuid.uuid4())
    customer = random.choice(CUSTOMERS_POOL)
    num_items = random.randint(1,5)
    selected_items = random.sample(SELLER_PRODUCT_POOL, num_items)

    total_amount = 0
    conn.execute(text("""
        INSERT INTO fact_order (order_id, customer_sk, order_date, total_amount)
        VALUES (:order_id, :customer_sk, :dt, 0)
    """), {"order_id": order_id, "customer_sk": customer["customer_sk"], "dt": datetime.now(timezone.utc)})

    for item in selected_items:
        qty = random.randint(1,3)
        conn.execute(text("""
            INSERT INTO fact_order_items (order_id, seller_product_sk, quantity)
            VALUES (:order_id, :sp_sk, :qty)
        """), {"order_id": order_id, "sp_sk": item["seller_product_sk"], "qty": qty})
        total_amount += item["price"] * qty

    conn.execute(text("""
        UPDATE fact_order SET total_amount = :total WHERE order_id = :order_id
    """), {"total": total_amount, "order_id": order_id})

    print(f"[orders] Inserted order {order_id}, total={total_amount}")

def insert_stock_event(conn):
    event = random.choice(SELLER_PRODUCT_POOL)
    conn.execute(text("""
        INSERT INTO fact_seller_product_stock (seller_product_sk, stock, event_timestamp, source)
        VALUES (:sk, :stock, :ts, 'stream-generator')
    """), {"sk": event["seller_product_sk"], "stock": random.randint(0,200), "ts": datetime.now(timezone.utc)})
    print(f"[stock] Updated seller_product_sk {event['seller_product_sk']}")

def insert_clickstream(conn):
    event_id = str(uuid.uuid4())
    event_type = random.choice(["view_page", "add_to_cart", "checkout_start"])
    if event_type == "add_to_cart":
        url = "/cart"
    elif event_type == "checkout_start":
        url = "/checkout"
    else:
        product = random.choice(PRODUCTS_POOL)
        url = f"/product/{product['id']}"

    conn.execute(text("""
        INSERT INTO fact_clickstream (event_id, session_id, user_id, url, event_type, event_timestamp)
        VALUES (:eid, :sid, :uid, :url, :etype, :ts)
    """), {"eid": event_id, "sid": str(uuid.uuid4()), "uid": str(uuid.uuid4()), "url": url,
           "etype": event_type, "ts": datetime.now(timezone.utc)})
    print(f"[clickstream] Event {event_id}")

# ================== MAIN LOOP ==================
timers = {"orders":0, "stock":0, "clickstream":0}
print("🎯 SQL Stream Producer démarré…")

with engine.connect() as conn:
    while True:
        now = time.time()
        if now - timers["orders"] >= ORDERS_INTERVAL:
            insert_order(conn)
            timers["orders"] = now
            conn.commit()
        if now - timers["stock"] >= STOCK_INTERVAL:
            insert_stock_event(conn)
            timers["stock"] = now
            conn.commit()
        if now - timers["clickstream"] >= CLICKSTREAM_INTERVAL:
            insert_clickstream(conn)
            timers["clickstream"] = now
            conn.commit()
        time.sleep(0.5)
