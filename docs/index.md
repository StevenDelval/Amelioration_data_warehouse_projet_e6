# Documentation DWH ShopNow – Terraform & DBT

Bienvenue dans la documentation du **Data Warehouse ShopNow**.  
Cette documentation couvre la configuration, le modèle de données, les pipelines DBT et l'infrastructure Terraform utilisée pour supporter le DWH Marketplace.

---

## Objectifs de la documentation
- Décrire la **structure et le fonctionnement du DWH**
- Documenter le **projet DBT** pour la transformation et la qualité des données
- Décrire l’**infrastructure Terraform** pour déploiement et gestion des ressources
- Fournir des **références sur les rôles, permissions et bonnes pratiques**
- Centraliser toutes les informations pour les équipes data et devops

---

## Navigation rapide

### Base de données
- Présentation du **modèle de données**
- Schéma des **dimensions** et **tables de faits**
- Rôles et permissions SQL

### DBT (Data Build Tool)
- Structure du projet DBT (`staging` & `marts`)
- Sources, modèles et transformations
- Tests de qualité (not_null, unique, relationships)

### Terraform
- Déploiement de l’infrastructure Azure
- Modules : containers, Event Hubs, Stream Analytics, SQL Database
- Variables et providers
