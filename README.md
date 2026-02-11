# Amelioration_data_warehouse_projet_e6

## Sommaire
- [Pré-requis](#pré-requis)
- [Contexte](#contexte)
- [Nouveaux enjeux Marketplace](#nouveaux-enjeux-marketplace)
- [Objectifs](#objectifs)
- [Structure du projet](#structure-du-projet)
- [Installation et déploiement](#installation-et-déploiement)
  - [1. Infrastructure](#1-infrastructure)
  - [2. Producteurs d’événements](#2-producteurs-dévenements)
  - [3. DBT](#3-dbt)
  - [4. Documentation](#4-documentation)

## Pré-requis

Avant de déployer l’infrastructure et exécuter le projet, assurez-vous d’avoir :

### 1. Outils locaux
- [Terraform](https://developer.hashicorp.com/terraform/downloads) ≥ 1.5
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli) pour initier et gérer les ressources Azure
- [Python](https://www.python.org/downloads/) ≥ 3.9
- `pip` pour installer les dépendances Python

### 2. Compte Azure
- Subscription valide
- Permissions pour créer : Resource Group, Event Hub, SQL Server, Stream Analytics, Container Instances

### 3. Variables d’environnement
Créer un fichier `.env` pour les producteurs d’événements :
```env
SQL_USER=""
SQL_PASSWORD=""
SQL_SERVER=""
SQL_DB="dwh-shopnow"
EVENTHUB_CONN_STR="Endpoint=sb:///;SharedAccessKeyName=RootManageSharedAccessKey;SharedAccessKey=XXXXXX"
```
### 4. DBT
- Installer DBT : pip install dbt-core dbt-sqlserver
- Connexion à la base SQL Azure configurée dans profiles.yml

## Contexte
ShopNow est une plateforme e-commerce en forte croissance. Historiquement, tous les produits étaient internes. Afin d'augmenter son offre et ses revenus, ShopNow devient une **Marketplace**, permettant à des vendeurs tiers de proposer leurs produits sur la plateforme.

Le Data Warehouse existant repose sur un modèle en étoile simple :
- `dim_customer`
- `dim_product`
- `fact_order`
- `fact_clickstream`

Il est alimenté par des données internes et un flux temps réel depuis **Azure Event Hubs**.

## Nouveaux enjeux Marketplace
Avec l’arrivée des vendeurs tiers, plusieurs besoins apparaissent :
1. **Suivi des vendeurs dans le temps**  
   - Historisation des informations des vendeurs (profil, statut, catégorie).
2. **Qualité des données envoyées par les vendeurs**  
   - Détection d’anomalies, isolation des données problématiques.
3. **Intégration de nouvelles sources externes**  
   - Stocks, mises à jour de produits, disponibilités via API et systèmes hétérogènes.
4. **Sécurité et cloisonnement des données**  
   - Accès limité pour chaque vendeur à ses propres données.

## Objectifs
- Analyser l’impact de la transition Marketplace sur le DWH existant.
- Identifier les limites et risques de l’architecture actuelle.
- Proposer des évolutions structurelles et techniques.
- Garantir qualité, sécurité et cohérence des données dans un environnement multi-vendeurs.

## Workflow global
1. **Sources** : données internes et Event Hubs
2. **Staging (DBT)** : nettoyage et historisation des tables
3. **Marts (DBT)** : tables analytiques et KPIs
4. **Tests** : qualité des données via DBT
5. **Consommation** : reporting et analyses BI

## Structure du projet
```
.
├── _certification
│   ├── description_c16_c17.md
│   ├── description_e6.md
│   ├── etude_de_cas.md
│   └── notes.md
├── database
│   ├── dwh_schema.sql
│   ├── dwh_schema.sql.old
│   └── schema.md
├── _events_producers
│   ├── Dockerfile
│   ├── producers.py
│   ├── README.md
│   └── requirements.txt
├── mkdocs.yml
├── README.md
├── shopnow_dbt
│   ├── analyses
│   ├── dbt_project.yml
│   ├── logs
│   │   └── dbt.log
│   ├── macros
│   │   └── generate_schema_name.sql
│   ├── models
│   │   ├── marts
│   │   │   ├── dim_customer.sql
│   │   │   ├── dim_product.sql
│   │   │   ├── dim_seller.sql
│   │   │   ├── fact_clickstream.sql
│   │   │   ├── fact_sales.sql
│   │   │   ├── fact_stock_latest.sql
│   │   │   └── schema.yml
│   │   └── staging
│   │       ├── schema.yml
│   │       ├── src.yml
│   │       ├── stg_clickstream.sql
│   │       ├── stg_customer.sql
│   │       ├── stg_order_items.sql
│   │       ├── stg_order.sql
│   │       ├── stg_product.sql
│   │       ├── stg_seller_product_pricing.sql
│   │       ├── stg_seller.sql
│   │       └── stg_stock.sql
│   ├── README.md
│   ├── seeds
│   ├── snapshots
│   ├── target
│   │   ├── compiled
│   │   │   └── shopnow_dbt
│   │   ├── graph.gpickle
│   │   ├── graph_summary.json
│   │   ├── manifest.json
│   │   ├── partial_parse.msgpack
│   │   ├── run
│   │   │   └── shopnow_dbt
│   │   ├── run_results.json
│   │   └── semantic_manifest.json
│   └── tests
└── terraform
    ├── 1_main.tf
    ├── 2_variables.tf
    ├── 3_providers.tf
    ├── modules
    │   ├── container_producers
    │   │   ├── main.tf
    │   │   └── variables.tf
    │   ├── event_hubs
    │   │   ├── main.tf
    │   │   ├── outputs.tf
    │   │   └── variables.tf
    │   ├── make_docker_image
    │   │   ├── main.tf
    │   │   ├── outputs.tf
    │   │   └── variables.tf
    │   ├── sql_database
    │   │   ├── main.tf
    │   │   ├── outputs.tf
    │   │   └── variables.tf
    │   └── stream_analytics
    │       ├── main.tf
    │       ├── outputs.tf
    │       └── variables.tf
```

## Installation et déploiement

### 1. Infrastructure
Déployez les ressources cloud via Terraform :
Ajoute le fichier terraform.tfvars dans le dossier terraform
```
username                  = "votre username"
subscription_id           = "votre azure subscription id"
location                  = "francecentral"
eventhubs                 = ["orders", "products", "clickstream", "stock"]
container_producers_image = "sengsathit/event_hub_producers:latest"
sql_admin_login           = "votre sql_admin_login"
sql_admin_password        = "votre sql_admin_password"
dockerhub_username        = "votre dockerhub_username"
dockerhub_token           = "votre dockerhub_token"
```

```bash
cd terraform
terraform init
terraform plan
terraform apply
```
### 2. Producteurs d’événements

Pour générer les flux Event Hubs :
```bash
cd _events_producers
pip install -r requirements.txt
python producers.py
```

### 3. DBT

Pour construire et tester les modèles analytiques :
```bash
cd shopnow_dbt
dbt deps
dbt run
dbt test
```

### 4. Documentation

Pour visualiser la documentation avec MkDocs :
```bash
mkdocs serve
# Accéder à http://127.0.0.1:8000
```