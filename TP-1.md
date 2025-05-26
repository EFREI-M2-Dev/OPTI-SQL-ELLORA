# TP #01 : Création et importation de requêtes

## Création des tables

Le script `create-and-import-queries.sql` définit plusieurs tables pour stocker des données liées aux titres, aux personnes et à leurs relations. Voici un résumé des tables créées :

### 1. **`title_basics`**
- Contient des informations de base sur les titres (films, séries, etc.).
- **Colonnes principales** :
    - `tconst` : Identifiant unique du titre.
    - `title_type` : Type de titre (ex. : movie, tvSeries).
    - `primary_title` : Titre principal.
    - `start_year` : Année de début.
    - `genres` : Genres associés.

### 2. **`title_akas`**
- Stocke les titres alternatifs (aussi connus sous d'autres noms).
- **Colonnes principales** :
    - `title_id` : Identifiant du titre (référence à `tconst`).
    - `region` : Région où le titre est utilisé.
    - `language` : Langue du titre.

### 3. **`title_episode`**
- Contient des informations sur les épisodes de séries.
- **Colonnes principales** :
    - `tconst` : Identifiant unique de l'épisode.
    - `parent_tconst` : Identifiant de la série parente.
    - `season_number` : Numéro de la saison.
    - `episode_number` : Numéro de l'épisode.

### 4. **`title_principals`**
- Liste les personnes associées à un titre (acteurs, réalisateurs, etc.).
- **Colonnes principales** :
    - `tconst` : Identifiant du titre.
    - `nconst` : Identifiant de la personne.
    - `category` : Rôle ou catégorie (ex. : acteur, réalisateur).

### 5. **`title_ratings`**
- Contient les notes et le nombre de votes pour chaque titre.
- **Colonnes principales** :
    - `tconst` : Identifiant du titre.
    - `average_rating` : Note moyenne.
    - `num_votes` : Nombre de votes.

### 6. **`name_basics`**
- Stocke des informations sur les personnes (acteurs, réalisateurs, etc.).
- **Colonnes principales** :
    - `nconst` : Identifiant unique de la personne.
    - `primary_name` : Nom principal.
    - `primary_profession` : Professions principales.
    - `known_for_titles` : Titres associés.

### 7. **`title_crew`**
- Contient les informations sur les réalisateurs et scénaristes.
- **Colonnes principales** :
    - `tconst` : Identifiant du titre.
    - `directors` : Liste des réalisateurs (CSV).
    - `writers` : Liste des scénaristes (CSV).

---

## Modifications des colonnes

Certaines colonnes ont été modifiées pour changer leur type :
- Les colonnes `types`, `attributes`, `primary_profession`, `known_for_titles`, `directors` et `writers` ont été converties en type `TEXT` pour simplifier leur gestion.

---

## Importation des données

Les données sont importées dans les tables à partir de fichiers compressés au format TSV. Voici les commandes utilisées :

- **Fichiers importés** :
    - `name.basics.tsv.gz` → `name_basics`
    - `title.basics.tsv.gz` → `title_basics`
    - `title.akas.tsv.gz` → `title_akas`
    - `title.crew.tsv.gz` → `title_crew`
    - `title.episode.tsv.gz` → `title_episode`
    - `title.principals.tsv.gz` → `title_principals`
    - `title.ratings.tsv.gz` → `title_ratings`

- **Commande d'importation** :
  ```sql
  COPY <table_name> FROM PROGRAM 'zcat <file_path>'
      WITH (FORMAT csv, DELIMITER E'\t', HEADER, NULL '\N', QUOTE E'\001');
  ```
    - **Options** :
        - `FORMAT csv` : Format des données.
        - `DELIMITER E'\t'` : Délimiteur tabulation.
        - `HEADER` : Ignore la première ligne (en-têtes).
        - `NULL '\N'` : Traite `\N` comme valeur NULL.
        - `QUOTE E'\001'` : Désactive les guillemets.

---

## Résumé

Le script configure une base de données relationnelle pour gérer des informations sur les titres, les personnes et leurs relations. Les données sont importées depuis des fichiers compressés, avec des colonnes adaptées pour une meilleure compatibilité.