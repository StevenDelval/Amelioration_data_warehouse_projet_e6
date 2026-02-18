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
CREATE INDEX idx_dim_customer_id ON dim_customer(customer_id);

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

-- Créer les schémas
CREATE SCHEMA staging;
CREATE SCHEMA marts;
CREATE SCHEMA audit;

CREATE TABLE audit.dbt_run_logs (
    id INT IDENTITY(1,1) PRIMARY KEY,
    run_id UNIQUEIDENTIFIER,
    run_started_at DATETIME2,
    run_ended_at DATETIME2,
    resource_type NVARCHAR(50),
    resource_name NVARCHAR(200),
    status NVARCHAR(20),
    executed_by NVARCHAR(200),
    message NVARCHAR(MAX)
);
-- ============================================
-- RÔLES ET PERMISSIONS - DWH SHOPNOW
-- ============================================

-- 1. DATA ENGINEERS
-- Gestion complète des pipelines ETL, schémas et données
CREATE ROLE role_data_engineer;

-- Permissions sur les schémas
GRANT SELECT, INSERT, UPDATE, DELETE ON SCHEMA::dbo TO role_data_engineer;
GRANT ALTER ON SCHEMA::dbo TO role_data_engineer;

-- Permissions système (nécessaires pour dbt)
GRANT VIEW DATABASE STATE TO role_data_engineer;
GRANT VIEW DEFINITION TO role_data_engineer;
GRANT EXECUTE TO role_data_engineer;
GRANT SELECT ON sys.sql_expression_dependencies TO role_data_engineer;

-- Permissions de création d'objets
GRANT CREATE TABLE TO role_data_engineer;
GRANT CREATE VIEW TO role_data_engineer;
GRANT CREATE PROCEDURE TO role_data_engineer;
GRANT CREATE FUNCTION TO role_data_engineer;
GRANT CREATE SCHEMA TO role_data_engineer;

-- Contrôle complet sur les schémas de travail
GRANT CONTROL ON SCHEMA::staging TO role_data_engineer;
GRANT CONTROL ON SCHEMA::marts TO role_data_engineer;
GRANT CONTROL ON SCHEMA::audit TO role_data_engineer;

-- 2. ADMINISTRATEURS SYSTÈME
-- Gestion infrastructure, backups, monitoring, sécurité
CREATE ROLE role_system_admin;

-- Lecture globale
GRANT SELECT ON SCHEMA::dbo TO role_system_admin;
GRANT SELECT ON SCHEMA::staging TO role_system_admin;
GRANT SELECT ON SCHEMA::marts TO role_system_admin;

-- Monitoring
GRANT VIEW DATABASE STATE TO role_system_admin;

-- Backup
GRANT BACKUP DATABASE TO role_system_admin;
GRANT BACKUP LOG TO role_system_admin;

-- Gestion performance (index, alter tables)
GRANT ALTER ON SCHEMA::dbo TO role_system_admin;
GRANT ALTER ON SCHEMA::staging TO role_system_admin;
GRANT ALTER ON SCHEMA::marts TO role_system_admin;


-- 3. OPÉRATEURS QUALITÉ
-- Validation données, analyse rejets, contrôles cohérence
CREATE ROLE role_quality_operator;

-- Lecture complète DWH
GRANT SELECT ON SCHEMA::dbo TO role_quality_operator;
GRANT SELECT ON SCHEMA::staging TO role_quality_operator;
GRANT SELECT ON SCHEMA::marts TO role_quality_operator;
GRANT CONTROL ON SCHEMA::audit TO role_data_engineer;

-- Création objets de contrôle qualité
GRANT CREATE TABLE TO role_quality_operator;
GRANT CREATE VIEW TO role_quality_operator;

-- Permissions pour exécuter des procédures de validation
GRANT EXECUTE TO role_quality_operator;


-- 4. RESPONSABLE DATA GOVERNANCE
-- Définition règles métiers, documentation, conformité RGPD, gestion accès
CREATE ROLE role_data_governance;

-- Lecture complète
GRANT SELECT ON SCHEMA::dbo TO role_data_governance;
GRANT SELECT ON SCHEMA::staging TO role_data_governance;
GRANT SELECT ON SCHEMA::marts TO role_data_governance;

-- Permissions pour voir les métadonnées et structures
GRANT VIEW DEFINITION TO role_data_governance;

-- Gestion des rôles / accès
GRANT ALTER ANY ROLE TO role_data_governance;
GRANT ALTER ANY USER TO role_data_governance;

-- Permissions pour créer des vues de documentation
GRANT CREATE VIEW TO role_data_governance;

-- Permissions pour UPDATE sur données sensibles (anonymisation RGPD)
GRANT UPDATE ON SCHEMA::marts TO role_data_governance;


-- 5. LECTURE SEULE (Analystes, Reporting, BI)
-- Accès en lecture uniquement pour consultation et analyse
CREATE ROLE role_read_only;

-- Lecture uniquement sur marts
GRANT SELECT ON SCHEMA::marts TO role_read_only;

-- Voir les structures
GRANT VIEW DEFINITION ON SCHEMA::marts TO role_read_only;

--CREATE USER da_user WITH PASSWORD = 'StrongP@ssw0rd!efzs';
--ALTER ROLE role_data_governance ADD MEMBER da_user;

-- CREATE USER etl_user WITH PASSWORD = 'StrongP@ssw0rd!efzs';
-- ALTER ROLE role_data_engineer ADD MEMBER etl_user;