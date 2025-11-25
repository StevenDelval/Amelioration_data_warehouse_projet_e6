-- ============================================
-- DIMENSIONS
-- ============================================

-- dim_customer
CREATE TABLE dim_customer (
    customer_sk INT IDENTITY(1,1) PRIMARY KEY,
    customer_id VARCHAR(50) NOT NULL,
    name NVARCHAR(255),
    email NVARCHAR(255),
    city NVARCHAR(100),
    country NVARCHAR(100),
    address NVARCHAR(500),
    start_date DATE DEFAULT GETDATE(),
    end_date DATE NULL,
    is_current BIT DEFAULT 1
);
CREATE UNIQUE INDEX idx_dim_customer_id ON dim_customer(customer_id);

-- dim_seller
CREATE TABLE dim_seller (
    seller_sk INT IDENTITY(1,1) PRIMARY KEY,
    seller_id VARCHAR(50) NOT NULL,
    name NVARCHAR(255),
    status NVARCHAR(50),
    country NVARCHAR(100),
    city NVARCHAR(100),
    address NVARCHAR(500),
    start_date DATE DEFAULT GETDATE(),
    end_date DATE NULL,
    is_current BIT DEFAULT 1
);
CREATE UNIQUE INDEX idx_dim_seller_id ON dim_seller(seller_id);

-- dim_product
CREATE TABLE dim_product (
    product_sk INT IDENTITY(1,1) PRIMARY KEY,
    product_id VARCHAR(50) NOT NULL,
    name NVARCHAR(255),
    category NVARCHAR(100),
    description NVARCHAR(MAX),
    start_date DATE DEFAULT GETDATE(),
    end_date DATE NULL,
    is_current BIT DEFAULT 1
);
CREATE UNIQUE INDEX idx_dim_product_id ON dim_product(product_id);

-- dim_seller_product_pricing
CREATE TABLE dim_seller_product_pricing (
    seller_product_sk INT IDENTITY(1,1) PRIMARY KEY,
    seller_sk INT NOT NULL,
    product_sk INT NOT NULL,
    price DECIMAL(18,2),
    start_date DATE DEFAULT GETDATE(),
    end_date DATE NULL,
    is_current BIT DEFAULT 1,
    CONSTRAINT FK_seller FOREIGN KEY (seller_sk) REFERENCES dim_seller(seller_sk),
    CONSTRAINT FK_product FOREIGN KEY (product_sk) REFERENCES dim_product(product_sk)
);
CREATE INDEX idx_seller_product_fk ON dim_seller_product_pricing(seller_sk, product_sk);


-- ============================================
-- FACTS
-- ============================================

-- fact_order
CREATE TABLE fact_order (
    order_id VARCHAR(50) NOT NULL,
    customer_sk INT NOT NULL,
    order_date DATE DEFAULT GETDATE(),
    total_amount DECIMAL(18,2),
    CONSTRAINT FK_order_customer FOREIGN KEY (customer_sk) REFERENCES dim_customer(customer_sk)
);
CREATE INDEX idx_fact_order_date ON fact_order(order_date);
CREATE UNIQUE INDEX idx_fact_order_id ON fact_order(order_id);

-- fact_order_items
CREATE TABLE fact_order_items (
    order_id VARCHAR(50) NOT NULL,
    seller_product_sk INT NOT NULL,
    quantity INT,
    CONSTRAINT FK_order_items_order FOREIGN KEY (order_id) REFERENCES fact_order(order_id),
    CONSTRAINT FK_order_items_seller_product FOREIGN KEY (seller_product_sk) REFERENCES dim_seller_product_pricing(seller_product_sk)
);
CREATE INDEX idx_order_items_order ON fact_order_items(order_id);
CREATE INDEX idx_order_items_seller_product ON fact_order_items(seller_product_sk);

-- fact_seller_product_stock 
CREATE TABLE fact_seller_product_stock (
    seller_product_sk INT NOT NULL,
    stock INT,
    event_timestamp DATETIME NOT NULL DEFAULT GETDATE(),
    source NVARCHAR(100),
    CONSTRAINT PK_stock PRIMARY KEY (seller_product_sk, event_timestamp),
    CONSTRAINT FK_stock_seller_product FOREIGN KEY (seller_product_sk) REFERENCES dim_seller_product_pricing(seller_product_sk)
);
CREATE INDEX idx_stock_event_timestamp ON fact_seller_product_stock(event_timestamp);
CREATE INDEX idx_stock_seller_product ON fact_seller_product_stock(seller_product_sk);

-- fact_clickstream
CREATE TABLE fact_clickstream (
    event_id VARCHAR(50) PRIMARY KEY,
    session_id VARCHAR(50),
    user_id VARCHAR(50),
    url NVARCHAR(MAX),
    event_type NVARCHAR(50),
    event_timestamp DATETIME DEFAULT GETDATE()
);
CREATE INDEX idx_clickstream_event_timestamp ON fact_clickstream(event_timestamp);
CREATE INDEX idx_clickstream_user_id ON fact_clickstream(user_id);
