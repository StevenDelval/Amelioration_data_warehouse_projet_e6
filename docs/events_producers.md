# Producteur d’événements – `_events_producers`

Le script `producers.py` permet de **simuler et envoyer des flux de données** vers Azure Event Hubs pour le DWH ShopNow.  
Il produit des événements pour les commandes, stocks et clickstreams, en utilisant des données réalistes générées avec `Faker` et les tables du DWH.


## 1. Structure du dossier
```
_events_producers/
├── Dockerfile # Conteneurisation du producer
├── producers.py # Script principal
├── README.md # Cette documentation
└── requirements.txt # Librairies Python (faker, sqlalchemy, azure-eventhub...)
```

## 2. Variables d’environnement

Le script utilise **dotenv** pour charger les paramètres de connexion et les intervalles d’événements.  

```env
# Connexion à la base SQL
SQL_USER=""
SQL_PASSWORD=""
SQL_SERVER=""
SQL_DB="dwh-shopnow"

# Connexion à Azure Event Hubs
EVENTHUB_CONN_STR=""

# Intervalles en secondes pour la génération d'événements
ORDERS_INTERVAL=30        # Commandes
STOCK_INTERVAL=30         # Stocks
CLICKSTREAM_INTERVAL=3    # Clickstreams
```

Conseil : ne pas commiter ce fichier sur un repo public, car il contient des credentials sensibles.

## 3. Connexion et chargement des données

Le script utilise SQLAlchemy pour récupérer les données existantes et remplir les pools :

| Pool	|Table SQL|	|Description|
|---------------|-------------|---------------------------------|
|CUSTOMERS_POOL	|dim_customer	|Clients existants|
|SELLERS_POOL	|dim_seller	|Vendeurs existants|
|PRODUCTS_POOL	|dim_product	|Produits existants|
|SELLER_PRODUCT_POOL	|dim_seller_product_pricing	|Produits avec vendeurs et prix|

Ces pools sont utilisés pour générer des événements réalistes.

## 4. Types d’événements
### a. Commandes (build_order_event)

Sélection aléatoire d’un client

Sélection de 1 à 5 produits vendus par différents vendeurs

Calcul du total_amount et construction des items
```json
{
  "event_type": "order",
  "event_id": "uuid",
  "order_id": "uuid",
  "customer_sk": 1,
  "items": [
    {"seller_product_sk": 5, "quantity": 2, "unit_price": 50.0}
  ],
  "total_amount": 100.0,
  "currency": "USD",
  "status": "PLACED",
  "timestamp": "2026-02-11T12:00:00Z"
}
```

### b. Stock (build_stock_event)

Sélection aléatoire d’un produit-vendeur

Génère la quantité disponible
```json
{
  "event_id": "uuid",
  "seller_product_sk": 5,
  "stock": 120,
  "event_timestamp": "2026-02-11T12:00:00Z",
  "source": "generator"
}
```

### c. Clickstream (build_clickstream_event)

Simule des actions utilisateur : view_page, add_to_cart, checkout_start

Génère un user_agent et ip avec Faker

```json
{
  "event_type": "clickstream",
  "event_id": "uuid",
  "session_id": "uuid",
  "user_id": "uuid",
  "url": "/product/abc123",
  "action": "view_page",
  "user_agent": "Mozilla/5.0 ...",
  "ip": "192.168.1.1",
  "timestamp": "2026-02-11T12:00:00Z"
}
```

## 5. Envoi vers Event Hubs

```pytho
def send_event(hub_name, event):
    batch = producers[hub_name].create_batch()
    batch.add(EventData(json.dumps(event)))
    producers[hub_name].send_batch(batch)
```

- Sérialise l’événement en JSON

- Envoie dans le hub correspondant (orders, stock, clickstream)

- Affiche dans la console les événements envoyés

## 6. Boucle principale

Vérifie chaque intervalle configuré (ORDERS_INTERVAL, STOCK_INTERVAL, CLICKSTREAM_INTERVAL)

Envoie les événements correspondants

Pause de 0,5 seconde pour limiter la charge CPU

Affiche les logs pour suivre l’envoi
```python
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
```
## 7. Installation et exécution
### a. Installer les dépendances
```bash
pip install -r requirements.txt
```

### b. Lancer le producteur
```bash
python producers.py
```