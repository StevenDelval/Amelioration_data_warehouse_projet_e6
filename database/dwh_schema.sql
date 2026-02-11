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

-- Créer les schémas
CREATE SCHEMA staging;
CREATE SCHEMA marts;

-- ============================================
-- RÔLES ET PERMISSIONS - DWH SHOPNOW
-- ============================================

-- 1. DATA ENGINEERS
-- Gestion complète des pipelines ETL, schémas et données
CREATE ROLE role_data_engineer;

-- Permissions sur les schémas
GRANT CREATE TABLE TO role_data_engineer;
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


-- Permissions complètes sur toutes les tables (DML + DDL)
GRANT SELECT, INSERT, UPDATE, DELETE ON dim_customer TO role_data_engineer;
GRANT SELECT, INSERT, UPDATE, DELETE ON dim_seller TO role_data_engineer;
GRANT SELECT, INSERT, UPDATE, DELETE ON dim_product TO role_data_engineer;
GRANT SELECT, INSERT, UPDATE, DELETE ON dim_seller_product_pricing TO role_data_engineer;
GRANT SELECT, INSERT, UPDATE, DELETE ON fact_order TO role_data_engineer;
GRANT SELECT, INSERT, UPDATE, DELETE ON fact_order_items TO role_data_engineer;
GRANT SELECT, INSERT, UPDATE, DELETE ON fact_seller_product_stock TO role_data_engineer;
GRANT SELECT, INSERT, UPDATE, DELETE ON fact_clickstream TO role_data_engineer;

-- Permissions pour modifier les structures (ALTER TABLE, DROP, etc.)
GRANT ALTER ON dim_customer TO role_data_engineer;
GRANT ALTER ON dim_seller TO role_data_engineer;
GRANT ALTER ON dim_product TO role_data_engineer;
GRANT ALTER ON dim_seller_product_pricing TO role_data_engineer;
GRANT ALTER ON fact_order TO role_data_engineer;
GRANT ALTER ON fact_order_items TO role_data_engineer;
GRANT ALTER ON fact_seller_product_stock TO role_data_engineer;
GRANT ALTER ON fact_clickstream TO role_data_engineer;

-- 2. ADMINISTRATEURS SYSTÈME
-- Gestion infrastructure, backups, monitoring, sécurité
CREATE ROLE role_system_admin;

-- Permissions de lecture sur toutes les tables (monitoring)
GRANT SELECT ON dim_customer TO role_system_admin;
GRANT SELECT ON dim_seller TO role_system_admin;
GRANT SELECT ON dim_product TO role_system_admin;
GRANT SELECT ON dim_seller_product_pricing TO role_system_admin;
GRANT SELECT ON fact_order TO role_system_admin;
GRANT SELECT ON fact_order_items TO role_system_admin;
GRANT SELECT ON fact_seller_product_stock TO role_system_admin;
GRANT SELECT ON fact_clickstream TO role_system_admin;

-- Permissions pour les vues système et monitoring
GRANT VIEW DATABASE STATE TO role_system_admin;

-- Permissions pour la gestion des backups
GRANT BACKUP DATABASE TO role_system_admin;
GRANT BACKUP LOG TO role_system_admin;

-- Permissions pour la gestion des index et optimisation
GRANT ALTER ON dim_customer TO role_system_admin;
GRANT ALTER ON dim_seller TO role_system_admin;
GRANT ALTER ON dim_product TO role_system_admin;
GRANT ALTER ON dim_seller_product_pricing TO role_system_admin;
GRANT ALTER ON fact_order TO role_system_admin;
GRANT ALTER ON fact_order_items TO role_system_admin;
GRANT ALTER ON fact_seller_product_stock TO role_system_admin;
GRANT ALTER ON fact_clickstream TO role_system_admin;


-- 3. OPÉRATEURS QUALITÉ
-- Validation données, analyse rejets, contrôles cohérence
CREATE ROLE role_quality_operator;

-- Lecture complète sur toutes les tables
GRANT SELECT ON dim_customer TO role_quality_operator;
GRANT SELECT ON dim_seller TO role_quality_operator;
GRANT SELECT ON dim_product TO role_quality_operator;
GRANT SELECT ON dim_seller_product_pricing TO role_quality_operator;
GRANT SELECT ON fact_order TO role_quality_operator;
GRANT SELECT ON fact_order_items TO role_quality_operator;
GRANT SELECT ON fact_seller_product_stock TO role_quality_operator;
GRANT SELECT ON fact_clickstream TO role_quality_operator;

-- Création de tables de contrôle qualité et reporting
GRANT CREATE TABLE TO role_quality_operator;

-- Permissions pour créer des vues de contrôle
GRANT CREATE VIEW TO role_quality_operator;

-- Permissions pour exécuter des procédures de validation
GRANT EXECUTE TO role_quality_operator;


-- 4. RESPONSABLE DATA GOVERNANCE
-- Définition règles métiers, documentation, conformité RGPD, gestion accès
CREATE ROLE role_data_governance;

-- Lecture complète sur toutes les tables
GRANT SELECT ON dim_customer TO role_data_governance;
GRANT SELECT ON dim_seller TO role_data_governance;
GRANT SELECT ON dim_product TO role_data_governance;
GRANT SELECT ON dim_seller_product_pricing TO role_data_governance;
GRANT SELECT ON fact_order TO role_data_governance;
GRANT SELECT ON fact_order_items TO role_data_governance;
GRANT SELECT ON fact_seller_product_stock TO role_data_governance;
GRANT SELECT ON fact_clickstream TO role_data_governance;

-- Permissions pour voir les métadonnées et structures
GRANT VIEW DEFINITION ON dim_customer TO role_data_governance;
GRANT VIEW DEFINITION ON dim_seller TO role_data_governance;
GRANT VIEW DEFINITION ON dim_product TO role_data_governance;
GRANT VIEW DEFINITION ON dim_seller_product_pricing TO role_data_governance;
GRANT VIEW DEFINITION ON fact_order TO role_data_governance;
GRANT VIEW DEFINITION ON fact_order_items TO role_data_governance;
GRANT VIEW DEFINITION ON fact_seller_product_stock TO role_data_governance;
GRANT VIEW DEFINITION ON fact_clickstream TO role_data_governance;

-- Permissions pour gérer les accès (conformité RGPD)
GRANT ALTER ANY USER TO role_data_governance;
GRANT VIEW DEFINITION TO role_data_governance;

-- Gestion des rôles
GRANT ALTER ANY ROLE TO role_data_governance;


-- Permissions pour créer des vues de documentation
GRANT CREATE VIEW TO role_data_governance;

-- Permissions pour UPDATE sur données sensibles (anonymisation RGPD)
GRANT UPDATE ON dim_customer TO role_data_governance;
GRANT DELETE ON dim_customer TO role_data_governance;
GRANT DELETE ON fact_clickstream TO role_data_governance;


-- 5. LECTURE SEULE (Analystes, Reporting, BI)
-- Accès en lecture uniquement pour consultation et analyse
CREATE ROLE role_read_only;

-- Lecture sur toutes les tables
GRANT SELECT ON dim_customer TO role_read_only;
GRANT SELECT ON dim_seller TO role_read_only;
GRANT SELECT ON dim_product TO role_read_only;
GRANT SELECT ON dim_seller_product_pricing TO role_read_only;
GRANT SELECT ON fact_order TO role_read_only;
GRANT SELECT ON fact_order_items TO role_read_only;
GRANT SELECT ON fact_seller_product_stock TO role_read_only;
GRANT SELECT ON fact_clickstream TO role_read_only;

-- Permissions pour voir les définitions des objets
GRANT VIEW DEFINITION ON dim_customer TO role_read_only;
GRANT VIEW DEFINITION ON dim_seller TO role_read_only;
GRANT VIEW DEFINITION ON dim_product TO role_read_only;
GRANT VIEW DEFINITION ON dim_seller_product_pricing TO role_read_only;
GRANT VIEW DEFINITION ON fact_order TO role_read_only;
GRANT VIEW DEFINITION ON fact_order_items TO role_read_only;
GRANT VIEW DEFINITION ON fact_seller_product_stock TO role_read_only;
GRANT VIEW DEFINITION ON fact_clickstream TO role_read_only;