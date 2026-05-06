# Plex Partial Scan

Un conteneur Docker léger qui surveille vos dossiers médias et déclenche automatiquement des scans partiels Plex uniquement sur les nouveaux fichiers détectés.

## ✨ Fonctionnalités

- 🔍 **Scan partiel** : Ne scanne que les dossiers contenant de nouveaux fichiers (pas toute la bibliothèque)
- 📁 **Multi-dossiers** : Surveille plusieurs dossiers avec des bibliothèques Plex différentes
- 🪶 **Léger** : Basé sur Alpine Linux
- ⚡ **Rapide** : Détection par polling avec intervalle configurable

## 📋 Prérequis

- Docker et Docker Compose
- Un serveur Plex accessible
- Un token Plex (voir section [Obtenir son token Plex](#-obtenir-son-token-plex))

## 🚀 Installation

1. **Cloner le repository**
   ```bash
   git clone https://github.com/votre-user/plex-partial-scan.git
   cd plex-partial-scan
   ```

2. **Configurer `plex-scan.conf`**
   ```conf
   # Intervalle de polling (secondes)
   INTERVAL=10

   # Plex
   PLEX_IP=YOUR_PLEX_IP
   PLEX_PORT=32400
   PLEX_TOKEN=YOUR_PLEX_TOKEN

   # WATCHDIRS
   # format : chemin_dans_conteneur | plex_lib_id | label | chemin_plex
   WATCHDIRS="
   /mnt/media/series|2|series|/data/series
   /mnt/media/films|1|films|/data/films
   "
   ```

3. **Adapter `docker-compose.yml`**
   
   Modifiez les volumes pour correspondre à vos chemins :
   ```yaml
   volumes:
     - type: bind
       source: /chemin/parent/du/montage
       target: /mnt/media
       read_only: true
       bind:
         propagation: rslave
   ```

   Pour un montage rclone/FUSE démonté puis remonté côté hôte, montez le dossier parent du point de montage avec `propagation: rslave`. Par exemple, si rclone monte `/mnt/decypharr`, utilisez `source: /mnt` et `target: /mnt`.

4. **Lancer le conteneur**
   ```bash
   docker-compose up -d
   ```

## ⚙️ Configuration

### plex-scan.conf

| Variable | Description |
|----------|-------------|
| `INTERVAL` | Intervalle de vérification en secondes |
| `PLEX_IP` | Adresse IP de votre serveur Plex |
| `PLEX_PORT` | Port Plex (par défaut : 32400) |
| `PLEX_TOKEN` | Token d'authentification Plex |
| `WATCHDIRS` | Liste des dossiers à surveiller |

### Format WATCHDIRS

Chaque ligne suit le format :
```
chemin_dans_conteneur|id_bibliotheque_plex|label|chemin_plex
```

- **chemin_dans_conteneur** : Chemin du dossier tel que monté dans le conteneur
- **id_bibliotheque_plex** : ID de la section Plex (voir ci-dessous)
- **label** : Nom pour les logs (informatif)
- **chemin_plex** : Chemin de base tel que Plex le voit

### 🔑 Obtenir son token Plex

1. Connectez-vous à Plex Web
2. Ouvrez n'importe quel média
3. Cliquez sur `...` → `Obtenir des infos` → `Voir le XML`
4. Dans l'URL, récupérez la valeur de `X-Plex-Token`

### 📚 Trouver l'ID d'une bibliothèque Plex

Accédez à cette URL dans votre navigateur :
```
http://PLEX_IP:32400/library/sections?X-Plex-Token=VOTRE_TOKEN
```

Chaque `<Directory>` contient un attribut `key` qui correspond à l'ID de la bibliothèque.

## 📝 Logs

Pour voir les logs en temps réel :
```bash
docker logs -f plex-partial-scan
```

Exemple de sortie :
```
▶️ Démarrage surveillance multi-watchdir
👀 Surveillance de /mnt/media/series
👀 Surveillance de /mnt/media/films
2026-01-20 14:30:15 - Nouveaux fichiers dans /mnt/media/series
→ Scan Plex (lib 2) sur : /mnt/media/series/Breaking Bad/Season 1
```

## 🛠️ Commandes utiles

```bash
# Démarrer
docker-compose up -d

# Arrêter
docker-compose down

# Redémarrer
docker-compose restart

# Voir les logs
docker logs -f plex-partial-scan
```

## 📄 Licence

MIT
