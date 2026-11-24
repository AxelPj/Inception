# Inception

Bienvenue dans mon repository Inception ! Ce projet consiste à monter une petite infrastructure web avec Docker : un site WordPress servi en HTTPS par NGINX et appuyé sur une base de données MariaDB, chaque service tournant dans son propre conteneur. L'objectif est d'apprendre à écrire des Dockerfiles, à orchestrer plusieurs conteneurs avec Docker Compose, et à gérer proprement le réseau, les volumes et les secrets.

> **Le projet n'est pas terminé.** Certaines parties sont encore en cours d'écriture ou de correction.

## Sommaire

- [À propos](#à-propos)
- [Fonctionnalités](#fonctionnalités)
- [Installation](#installation)
- [Utilisation](#utilisation)
- [Structure du projet](#structure-du-projet)
- [Contributions](#contributions)

## À propos

L'architecture est composée de trois conteneurs construits à partir d'images Debian Bookworm, reliés par un réseau Docker dédié (`inception`, de type `bridge`) :

- **NGINX** : seul point d'entrée, il écoute sur le port 443 en TLSv1.2 / TLSv1.3 et transmet les requêtes PHP à WordPress.
- **WordPress** : le site, exécuté par PHP-FPM sur le port 9000 (accessible uniquement depuis le réseau interne).
- **MariaDB** : la base de données du site, sur le port 3306 (interne également).

Les mots de passe ne sont pas passés en variables d'environnement : ils sont fournis sous forme de **Docker secrets**, montés dans `/run/secrets/` et lus par les scripts d'initialisation. Les autres paramètres (nom de domaine, utilisateurs, e-mails) sont dans `srcs/.env`.

## Fonctionnalités

### 1. NGINX (reverse proxy HTTPS)

- Certificat auto-signé généré au build, dans une première étape de construction (`openssl req -x509`, valable 365 jours), puis copié dans l'image finale.
- Configuration par défaut supprimée et remplacée par `conf/nginx.conf`.
- Écoute en HTTPS sur le port 443 (IPv4 et IPv6), protocoles TLSv1.2 et TLSv1.3 uniquement.
- Les fichiers `.php` sont transmis à `wordpress:9000` via FastCGI.
- Lancé à travers `tini` pour gérer correctement les signaux et les processus.

### 2. WordPress (PHP-FPM)

- Installation de PHP, PHP-FPM, `php-mysql` et du client MariaDB.
- Téléchargement de WordPress 6.9.1 en français et de `wp-cli`.
- PHP-FPM configuré pour écouter sur le port 9000 au lieu d'un socket.
- Au démarrage, le script `wd_script.sh` :
  - attend que MariaDB réponde ;
  - si WordPress n'est pas encore installé, crée `wp-config.php`, installe le site avec un compte administrateur et crée un second utilisateur avec le rôle `author` ;
  - lance ensuite PHP-FPM au premier plan.

### 3. MariaDB (base de données)

- Configuration personnalisée (`50-server.cnf`) pour écouter sur toutes les interfaces du réseau Docker.
- Au premier démarrage, le script `mdb_script.sh` :
  - initialise le dossier de données si nécessaire ;
  - crée la base, l'utilisateur et ses droits, et définit le mot de passe root ;
  - arrête le serveur temporaire puis relance `mysqld` comme processus principal.
- Si la base existe déjà, l'initialisation est ignorée.

### 4. Persistance des données

- Deux volumes nommés, `wordpress` et `mariadb`, stockés sur la machine hôte dans `/home/axelpeti/data/`.
- Les données sont conservées même si les conteneurs sont supprimés.

### 5. Redémarrage automatique

- Chaque conteneur est configuré avec `restart: on-failure`.

## Installation

```sh
git clone git@github.com:AxelPj/Inception.git
cd Inception
make
```

Avant de lancer `make`, il faut :

- avoir Docker et Docker Compose installés, ainsi que les droits `sudo` ;
- remplir les fichiers de `secrets/` (`db_password.txt`, `db_root_password.txt`, `wd_password.txt`) ;
- vérifier les variables de `srcs/.env` ;
- faire pointer le domaine défini par `DOMAIN_NAME` dans `srcs/.env` vers `127.0.0.1` dans `/etc/hosts`.

`make` crée les dossiers de données, règle leurs droits, puis construit et lance les conteneurs.

Autres règles disponibles :

```sh
make down     # arrête les conteneurs
make logs     # affiche les 100 dernières lignes de logs et suit la sortie
make status   # affiche l'état des conteneurs
make clean    # supprime les données de /home/axelpeti/data et arrête les conteneurs avec leurs volumes
make fclean   # clean + suppression des images et nettoyage complet de Docker (docker system prune)
make re       # clean puis reconstruit et relance les conteneurs
```

## Utilisation

Une fois les conteneurs lancés, ouvrez dans le navigateur :

```sh
https://<DOMAIN_NAME>            # le site
https://<DOMAIN_NAME>/wp-admin   # l'interface d'administration WordPress
```

Le certificat étant auto-signé, le navigateur affiche un avertissement qu'il faut accepter.

Pour vérifier que tout fonctionne :

```sh
make status                 # les trois conteneurs doivent être « Up »
make logs                   # suivre les logs de tous les services
docker exec -it mariadb sh  # entrer dans un conteneur
```

## Structure du projet

- `Makefile` : commandes du projet (règles `all`, `up`, `down`, `re`, `logs`, `status`, `clean`, `fclean`).
- `secrets/db_password.txt` : mot de passe de l'utilisateur de la base de données.
- `secrets/db_root_password.txt` : mot de passe root de MariaDB.
- `secrets/wd_password.txt` : mot de passe des comptes WordPress.
- `srcs/.env` : variables de configuration (domaine, base, utilisateurs WordPress).
- `srcs/docker-compose.yml` : définition des services, du réseau, des volumes et des secrets.
- `srcs/requirements/nginx/dockerfile` : image NGINX et génération du certificat TLS.
- `srcs/requirements/nginx/conf/nginx.conf` : configuration du serveur HTTPS et du passage vers PHP-FPM.
- `srcs/requirements/wordpress/dockerfile` : image WordPress avec PHP-FPM et `wp-cli`.
- `srcs/requirements/wordpress/tools/wd_script.sh` : script d'installation et de lancement de WordPress.
- `srcs/requirements/mariadb/dockerfile` : image MariaDB.
- `srcs/requirements/mariadb/conf/50-server.cnf` : configuration du serveur MariaDB.
- `srcs/requirements/mariadb/tools/mdb_script.sh` : script d'initialisation de la base de données.
- `USER_DOC.me` : documentation utilisateur.
- `DEV_DOC.me` : documentation développeur.

## Contributions

Les contributions sont les bienvenues !

1. Forkez le repository.
2. Créez une branche : `git checkout -b ma-fonctionnalite`
3. Commitez vos modifications : `git commit -m "Ajout de ma fonctionnalité"`
4. Poussez la branche : `git push origin ma-fonctionnalite`
5. Ouvrez une Pull Request.
