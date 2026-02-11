# Infrastructure Terraform – ShopNow Marketplace

Ce dossier contient les fichiers Terraform permettant de déployer l’infrastructure cloud pour le DWH ShopNow, incluant :

- Resource Group Azure
- Event Hubs pour ingestion des flux
- Base de données SQL Server / Azure SQL
- Stream Analytics pour transformation en temps réel
- Conteneurs pour initialisation et producteurs d’événements (optionnel)


## 1. Structure du projet Terraform
```
terraform/
├── 1_main.tf # Déploiement principal
├── 2_variables.tf # Déclaration des variables
├── 3_providers.tf # Providers Terraform (Azure)
└── modules/
├── container_producers/ # Module ACI pour producteurs
├── event_hubs/ # Module Event Hubs
├── make_docker_image/ # Module création image Docker
├── sql_database/ # Module SQL Server / DB
└── stream_analytics/ # Module ASA
```


## 2. Variables Terraform (`2_variables.tf`)

| Variable | Type | Description |
|----------|------|-------------|
| `username` | string | Nom utilisateur pour suffixes ressources |
| `subscription_id` | string | ID de la subscription Azure |
| `location` | string | Région Azure (ex : francecentral) |
| `eventhubs` | list(string) | Liste des noms de Event Hubs (`orders`, `stock`, `clickstream`) |
| `container_producers_image` | string | Image Docker pour les producteurs d’événements |
| `sql_admin_login` | string | Login admin SQL |
| `sql_admin_password` | string, sensitive | Mot de passe admin SQL |
| `dockerhub_username` | string | Login DockerHub pour push/pull |
| `dockerhub_token` | string | Token DockerHub |

💡 **Conseil** : Sensibles, ne pas commiter les credentials sur un repo public.

## 3. Déploiement principal (`1_main.tf`)

### a. Resource Group
```hcl
resource "azurerm_resource_group" "rg" {
  name     = "rg-e6-${var.username}"
  location = var.location
}
```
### b. Event Hubs
- Namespace Azure Event Hub (Basic SKU)
- Event Hubs : orders, stock, clickstream
- Autorisations send et listen

### c. Base de données SQL

- Azure SQL Server + base dwh-shopnow
- Firewall : accès Azure et IP publique
- Backups court terme et long terme pour PITR / conformité RGPD
- Container optionnel pour exécution du script dwh_schema.sql lors de la création

### d. Stream Analytics

- Transformation des flux Event Hubs vers les tables fact :
    - fact_order / fact_order_items
    - fact_clickstream
    - fact_seller_product_stock
- Entrées : Event Hubs (orders, clickstream, stock)
- Sorties : Azure SQL Database

### e. Conteneurs Producteurs (optionnel)

- Azure Container Instance pour producteurs d’événements

- Variables d’environnement : connexions Event Hub, SQL et intervalles de génération

## 4. Modules Terraform

| Module	| Fonction |
|---------------|-------------|
|event_hubs	|Crée namespace Event Hub + Hubs + policies|
|sql_database|	Crée SQL Server, base et firewall|
|stream_analytics|	Crée job ASA + inputs/outputs vers SQL|
|make_docker_image	|Construit l’image Docker pour producteurs|
|container_producers|	Déploie un ACI pour exécuter producers.py|
## 5. Exécution Terraform

Copier les variables dans terraform.tfvars :
    

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

Initialiser Terraform :
```
cd terraform
terraform init
```
Vérifier le plan :
```
terraform plan
```
Appliquer le plan :
```
terraform apply
```
Terraform crée automatiquement :
- Resource Group
- Event Hubs + namespace
- SQL Server / Database
- Stream Analytics Job avec inputs et outputs
- Container pour l’initialisation du schéma (si activé)
- Conteneur producteurs (si module décommenté)