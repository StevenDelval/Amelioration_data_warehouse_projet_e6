# Projet DBT – ShopNow

## 1. Introduction
Ce dossier contient le projet **DBT (Data Build Tool)** pour transformer les données brutes du DWH ShopNow en modèles analytiques prêts pour le reporting.  
L’objectif est de structurer, nettoyer et historiser les données pour supporter le modèle Marketplace multi-vendeurs.

---

## 2. Configuration générale (`dbt_project.yml`)
- Nom du projet : `shopnow_dbt`
- Version : `1.0.0`
- Profil DBT : `shopnow_dbt`
- Répertoires utilisés :
  - `models/` : modèles de transformation
  - `analyses/` : analyses ad hoc
  - `tests/` : tests de qualité des données
  - `seeds/` : tables statiques
  - `macros/` : fonctions SQL réutilisables
  - `snapshots/` : historique des données
- Modèles `staging` et `marts` sont matérialisés sous forme de tables et organisés par schéma (`staging` / `marts`).

---

## 3. Sources (`models/staging/src.yml`)
Les tables brutes proviennent du DWH ShopNow (`database=dwh-shopnow`, `schema=dbo`) :

| Table source                       | Description                              |
|-----------------------------------|------------------------------------------|
| dim_customer                        | Dimension client brute                    |
| dim_seller                          | Dimension vendeur brute                   |
| dim_product                         | Dimension produit brute                   |
| dim_seller_product_pricing          | Tarification produits-vendeurs brute     |
| fact_order                          | Faits commandes brute                     |
| fact_order_items                    | Détails des commandes brute               |
| fact_seller_product_stock           | Événements stock brute                    |
| fact_clickstream                    | Événements de navigation utilisateur     |

---

## 4. Modèles de staging
Les modèles `stg_` permettent de **nettoyer et normaliser** les données brutes avant de les intégrer dans les marts analytiques.

### Exemple de transformation :

**stg_customer.sql**
```sql
SELECT
    customer_sk,
    customer_id,
    TRIM(name) AS customer_name,
    LOWER(email) AS email,
    city,
    country,
    address,
    start_date,
    end_date,
    is_current
FROM {{ source('shopnow_raw', 'dim_customer') }}
WHERE customer_id IS NOT NULL
```
## 5. Modèles de Marts
Les modèles **Marts** représentent les tables finales destinées aux analyses et au reporting.  
Elles sont construites à partir des **staging models** et incluent des agrégations et KPIs.  
Chaque table est testée pour garantir l’intégrité des données.

### Exemple de table :
```sql
SELECT *
FROM {{ ref('stg_customer') }}
WHERE is_current = 1
```

## 6. Tests de qualité 

### a. Tests sur les modèles de staging

| Modèle         | Colonne           | Test DBT                          | Objectif                                      |
|----------------|-----------------|----------------------------------|-----------------------------------------------|
| stg_customer    | customer_sk      | not_null, unique                  | Assurer qu’il n’y a pas de doublons ni de valeurs nulles |
| stg_customer    | customer_id      | not_null, unique                  | Clé externe fiable pour les relations        |
| stg_customer    | email            | not_null                          | Vérifier que les emails existent             |
| stg_seller      | seller_sk        | not_null, unique                  | Clé primaire unique                           |
| stg_seller      | seller_id        | not_null, unique                  | Identifiant vendeur unique                    |
| stg_product     | product_sk       | not_null, unique                  | Clé primaire unique                           |
| stg_order       | order_id         | not_null, unique                  | Identifier chaque commande de manière unique |
| stg_order       | customer_sk      | not_null, relationships → stg_customer.customer_sk | Assurer l'intégrité des relations client     |
| stg_order_items | order_id         | not_null, relationships → stg_order.order_id | Lier les items à une commande existante      |
| stg_order_items | seller_product_sk| relationships → stg_seller_product_pricing.seller_product_sk | Lier les items aux produits vendus           |

---

### b. Tests sur les modèles Marts

| Modèle      | Colonne       | Test DBT                               | Objectif                                    |
|------------|---------------|----------------------------------------|---------------------------------------------|
| dim_customer | customer_sk   | not_null, unique                        | Clé primaire, pas de doublons              |
| dim_seller   | seller_sk     | not_null, unique                        | Clé primaire                                |
| dim_product  | product_sk    | not_null, unique                        | Clé primaire                                |
| fact_sales   | order_id      | not_null                                | Chaque ligne correspond à une commande     |
| fact_sales   | customer_sk   | relationships → dim_customer.customer_sk | Intégrité relationnelle avec client        |
| fact_sales   | product_sk    | relationships → dim_product.product_sk   | Intégrité relationnelle avec produit       |
| fact_sales   | seller_sk     | relationships → dim_seller.seller_sk     | Intégrité relationnelle avec vendeur       |



## 7. Structure des modèles DBT
```
shopnow_dbt/
├── models/
│   ├── staging/                # Tables de staging (nettoyage, standardisation)
│   │   ├── src.yml
│   │   ├── schema.yml
│   │   ├── stg_customer.sql
│   │   ├── stg_seller.sql
│   │   ├── stg_product.sql
│   │   ├── stg_seller_product_pricing.sql
│   │   ├── stg_order.sql
│   │   ├── stg_order_items.sql
│   │   ├── stg_stock.sql
│   │   └── stg_clickstream.sql
│   └── marts/                  # Modèles analytiques (agrégations, KPIs)
│       ├── dim_customer.sql
│       ├── dim_product.sql
│       ├── dim_seller.sql
│       ├── fact_clickstream.sql
│       ├── fact_sales.sql
│       ├── fact_stock_latest.sql
│       └── schema.yml
├── analyses/                   # Analyses SQL ad hoc
├── snapshots/                  # Historisation des données
├── tests/                      # Tests unitaires et intégrité
├── macros/                     # Fonctions SQL réutilisables
└── seeds/                      # Tables statiques
```