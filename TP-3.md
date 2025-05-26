# TP #O3 : Indexation fondamentale et avancée

## Exercice 1 : Index B-Tree

### 1.1 : Analyse sans index

```sql
EXPLAIN ANALYZE SELECT * FROM title_basics WHERE primary_title LIKE 'The%';
```

Résultat : 
```
"Gather  (cost=1000.00..297383.90 rows=629293 width=84) (actual time=2.872..1743.819 rows=600030 loops=1)"
"  Workers Planned: 2"
"  Workers Launched: 2"
"  ->  Parallel Seq Scan on title_basics  (cost=0.00..233454.60 rows=262205 width=84) (actual time=3.390..1584.080 rows=200010 loops=3)"
"        Filter: ((primary_title)::text ~~ 'The%'::text)"
"        Rows Removed by Filter: 3683932"
"Planning Time: 0.098 ms"
"JIT:"
"  Functions: 6"
"  Options: Inlining false, Optimization false, Expressions true, Deforming true"
"  Timing: Generation 0.582 ms (Deform 0.220 ms), Inlining 0.000 ms, Optimization 0.683 ms, Emission 8.058 ms, Total 9.324 ms"
"Execution Time: 1765.961 ms"
```

### 1.2 : Création d'un index B-Tree

```sql
CREATE INDEX idx_title_basics_primary_title ON title_basics(primary_title);
```

### 1.3 : Analyse après indexation

Résultat de la requête après création de l'index :

```
"Gather  (cost=1000.00..297383.90 rows=629293 width=84) (actual time=59.463..1825.203 rows=600030 loops=1)"
"  Workers Planned: 2"
"  Workers Launched: 2"
"  ->  Parallel Seq Scan on title_basics  (cost=0.00..233454.60 rows=262205 width=84) (actual time=23.223..1752.810 rows=200010 loops=3)"
"        Filter: ((primary_title)::text ~~ 'The%'::text)"
"        Rows Removed by Filter: 3683932"
"Planning Time: 2.336 ms"
"JIT:"
"  Functions: 6"
"  Options: Inlining false, Optimization false, Expressions true, Deforming true"
"  Timing: Generation 4.418 ms (Deform 0.870 ms), Inlining 0.000 ms, Optimization 8.953 ms, Emission 60.506 ms, Total 73.876 ms"
"Execution Time: 1851.145 ms"
```

Conclusion : 
- Après la création de l’index B-tree sur primary_title, le plan d’exécution reste identique : PostgreSQL utilise toujours un Parallel Seq Scan
- L’index n’est pas utilisé, car la requête retourne un grand nombre de lignes (600 000). Dans ce cas, un scan séquentiel reste plus rapide qu’un accès par index
- Le temps d’exécution est même légèrement plus élevé après indexation (~1851 ms contre ~1765 ms), car PostgreSQL a évalué le coût de l’index mais a finalement préféré le scan parallèle

### 1.4 : Test des différentes opérations

1. Égalité exacte (`primary_title = 'The Matrix'`)
    - Index utilisé (Bitmap Index Scan)
    - Très rapide (~1.7 ms)
    - Index parfaitement exploité pour l’égalité

2. Préfixe (`LIKE 'The%'`)
    - Index non utilisé
    - PostgreSQL utilise un Parallel Seq Scan
    - Trop de résultats, index jugé moins efficace

3. Suffixe (`LIKE '%The'`)
    - Index non utilisé
    - Le motif commence par %, l’index B-tree n’est pas applicable

4. Sous-chaîne (`LIKE '%The%'`)
    - Index non utilisé
    - Même raison : % en début rend l’index inutilisable

5. Tri (`ORDER BY primary_title`)
    - Index utilisé (Index Scan)
    - Lecture des données dans l’ordre de l’index
    - Très utile pour éviter un tri explicite, mais long si beaucoup de lignes

### 1.5 : Analyse et réflexion

1. Pour quels types d'opérations l'index B-tree est-il efficace?
    - Pour les recherches par égalité (`=`).
    - Pour les préfixes (`LIKE 'abc%'`) si la requête est suffisamment sélective.
    - Pour le tri (`ORDER BY`) sur la colonne indexée.

2. Pourquoi l'index n'est-il pas utilisé pour certaines opérations?
    - Parce que certaines conditions comme `LIKE '%abc'` ou `LIKE '%abc%'` commencent par un caractère joker (`%`), ce qui empêche l’utilisation de l’ordre de tri de l’index.
    - Parce que si le filtre retourne trop de lignes, PostgreSQL estime qu’un scan séquentiel est plus efficace qu’un accès via index.

3. Dans quels cas un index B-tree est-il le meilleur choix?
    - Lorsqu’on fait des recherches exactes ou des préfixes très sélectifs.
    - Lorsqu’on trie souvent les résultats sur la colonne indexée.
    - Lorsqu’on effectue des jointures sur une colonne fortement discriminante.

## Exercice 2: Index Hash

### 2.1 Requête d'égalité exacte

```sql 
EXPLAIN ANALYZE SELECT * FROM title_basics WHERE tconst = 'tt0133093';
```

Résultat:  
```
"Index Scan using title_basics_pkey on title_basics  (cost=0.43..8.45 rows=1 width=84) (actual time=0.031..0.033 rows=1 loops=1)"
"  Index Cond: ((tconst)::text = 'tt0133093'::text)"
"Planning Time: 0.090 ms"
"Execution Time: 0.047 ms"
```

### 2.2 Création d'un index Hash

```sql
CREATE INDEX idx_title_basics_tconst_hash ON title_basics USING HASH (tconst);
```

### 2.3 Comparaison avec B-tree

```sql
CREATE INDEX idx_title_basics_tconst_btree ON title_basics(tconst);
```

1. Le temps d'exécution de la requête avec l'index B-tree est similaire à celui de l'index Hash.

```sql
SELECT indexrelid::regclass AS index_name, pg_size_pretty(pg_relation_size(indexrelid)) AS size FROM pg_index
WHERE indrelid = 'title_basics'::regclass;
```

2. Résultat de la taille des index :
```
 index_name                     | size
--------------------------------+--------
 title_basics_pkey              | 351 MB
 idx_title_basics_tconst        | 321 MB
 idx_title_basics_primary_title | 286 MB
 idx_title_basics_tconst_hash   | 321 MB
 idx_title_basics_tconst_btree  | 351 MB
```

3. L’index Hash est uniquement utile pour les recherches par égalité. Le B-tree est plus complet : il gère les égalités, les plages (BETWEEN, <, >), et le tri (ORDER BY).


### 2.4 Analyse et réflexion

1. **Quelles sont les différences de performance entre Hash et B-tree pour l'égalité exacte ?**
   - Les deux index offrent des performances similaires sur l’égalité exacte
   - L’index Hash peut être légèrement plus rapide dans certains cas très ciblés, mais le gain est souvent négligeable
   - PostgreSQL utilise par défaut le B-tree car il est plus polyvalent

2. **Pourquoi l’index Hash ne fonctionne-t-il pas pour les recherches par plage ?**
   - Car un index Hash ne conserve pas l’ordre des valeurs, il ne permet donc pas de comparer des plages (`<`, `>`, `BETWEEN`)
   - Il est uniquement conçu pour les correspondances exactes (`=`)

3. **Dans quel contexte précis privilégier un index Hash à un B-tree ?**
   - Lorsqu’on effectue exclusivement des recherches par égalité sur une colonne, avec un tès grand volume de données
   - Et si les B-tree sont trop volumineux ou si l’espace mémoire est contraint
   - Dans la majorité des cas, un B-tree reste préférable

## Exercice 3: Index composites

### 3.1 Requête avec plusieurs conditions
```sql
SELECT * FROM title_basics WHERE genres = 'Drama' AND start_year = 1994;
```

### 3.2 Test sans index

Résultat sans index : 
```
"Gather  (cost=1000.00..247424.82 rows=8329 width=84) (actual time=18.092..1998.063 rows=5796 loops=1)"
"  Workers Planned: 2"
"  Workers Launched: 2"
"  ->  Parallel Seq Scan on title_basics  (cost=0.00..245591.92 rows=3470 width=84) (actual time=13.902..1829.987 rows=1932 loops=3)"
"        Filter: (((genres)::text = 'Drama'::text) AND (start_year = 1994))"
"        Rows Removed by Filter: 3882010"
"Planning Time: 0.154 ms"
"JIT:"
"  Functions: 6"
"  Options: Inlining false, Optimization false, Expressions true, Deforming true"
"  Timing: Generation 1.675 ms (Deform 0.601 ms), Inlining 0.000 ms, Optimization 2.415 ms, Emission 18.891 ms, Total 22.981 ms"
"Execution Time: 1999.142 ms"
```

### 3.3 Index sur colonnes individuelles

```sql
CREATE INDEX idx_title_basics_genres ON title_basics(genres);
CREATE INDEX idx_title_basics_start_year ON title_basics(start_year);
```

Résultat de la requête après création des index :
```
"Bitmap Heap Scan on title_basics  (cost=15202.02..42565.18 rows=8329 width=84) (actual time=102.588..1454.246 rows=5796 loops=1)"
"  Recheck Cond: ((start_year = 1994) AND ((genres)::text = 'Drama'::text))"
"  Rows Removed by Index Recheck: 34344"
"  Heap Blocks: exact=13699"
"  ->  BitmapAnd  (cost=15202.02..15202.02 rows=8329 width=0) (actual time=97.227..97.228 rows=0 loops=1)"
"        ->  Bitmap Index Scan on idx_title_basics_start_year  (cost=0.00..805.90 rows=73795 width=0) (actual time=6.727..6.727 rows=68536 loops=1)"
"              Index Cond: (start_year = 1994)"
"        ->  Bitmap Index Scan on idx_title_basics_genres  (cost=0.00..14391.71 rows=1315103 width=0) (actual time=89.210..89.210 rows=1311711 loops=1)"
"              Index Cond: ((genres)::text = 'Drama'::text)"
"Planning Time: 0.967 ms"
"Execution Time: 1455.089 ms"
```

Analyse : 
- Avant indexation : PostgreSQL utilisait un `Parallel Seq Scan` sur toute la table, ce qui impliquait le traitement de plusieurs millions de lignes non pertinentes. Le temps d’exécution était d’environ **1999 ms**.
- Après création des deux index séparés (`genres` et `start_year`), PostgreSQL utilise un **`Bitmap Heap Scan` combiné avec `BitmapAnd`**, ce qui permet de cibler les lignes plus efficacement.
- Le temps d’exécution est réduit à environ **1455 ms**, soit un gain de performance d’environ **27 %**.
**Conclusion :** Les index sur colonnes individuelles améliorent les performances, mais restent limités car PostgreSQL doit combiner les résultats des deux index et effectuer une vérification sur le tas (relecture des blocs). Un index composite pourrait offrir de meilleures performances.

### 3.4 Index composite
```sql
CREATE INDEX idx_title_basics_genres_year ON title_basics(genres, start_year);
```

Résultat de la requête après création de l'index composite :
```
"Bitmap Heap Scan on title_basics  (cost=117.81..27480.96 rows=8329 width=84) (actual time=1.398..172.945 rows=5796 loops=1)"
"  Recheck Cond: (((genres)::text = 'Drama'::text) AND (start_year = 1994))"
"  Heap Blocks: exact=1629"
"  ->  Bitmap Index Scan on idx_title_basics_genres_year  (cost=0.00..115.73 rows=8329 width=0) (actual time=0.783..0.783 rows=5796 loops=1)"
"        Index Cond: (((genres)::text = 'Drama'::text) AND (start_year = 1994))"
"Planning Time: 2.262 ms"
"Execution Time: 173.478 ms"
```

Analyse :
- L’index composite permet à PostgreSQL de cibler directement les lignes correspondant aux deux conditions.
- Plus efficace que la combinaison de deux index simples : aucun BitmapAnd, moins de blocs à rechecker.
- Le temps d’exécution est considérablement réduit (près de 90 % de gain par rapport au scan initial).

### 3.5 Test de l'ordre des colonnes
```sql
CREATE INDEX idx_title_basics_year_genres ON title_basics(start_year, genres);
```

1. Filrer uniquement sur le genre :
```sql
EXPLAIN ANALYZE SELECT * FROM title_basics WHERE genres = 'Drama';
```

Résultat :
```
"Bitmap Heap Scan on title_basics  (cost=14720.48..308629.92 rows=1315103 width=84) (actual time=77.100..5692.031 rows=1311711 loops=1)"
"  Recheck Cond: ((genres)::text = 'Drama'::text)"
"  Rows Removed by Index Recheck: 5732081"
"  Heap Blocks: exact=36252 lossy=98962"
"  ->  Bitmap Index Scan on idx_title_basics_genres  (cost=0.00..14391.71 rows=1315103 width=0) (actual time=67.770..67.771 rows=1311711 loops=1)"
"        Index Cond: ((genres)::text = 'Drama'::text)"
"Planning Time: 0.217 ms"
"JIT:"
"  Functions: 2"
"  Options: Inlining false, Optimization false, Expressions true, Deforming true"
"  Timing: Generation 0.301 ms (Deform 0.138 ms), Inlining 0.000 ms, Optimization 0.295 ms, Emission 2.397 ms, Total 2.993 ms"
"Execution Time: 5740.826 ms"
```

2. Filtrer uniquement sur l'année :
```sql
EXPLAIN ANALYZE SELECT * FROM title_basics WHERE start_year = 1994;
```

Résultat :
```
"Bitmap Heap Scan on title_basics  (cost=824.35..136754.34 rows=73795 width=84) (actual time=16.950..307.184 rows=68536 loops=1)"
"  Recheck Cond: (start_year = 1994)"
"  Heap Blocks: exact=20648"
"  ->  Bitmap Index Scan on idx_title_basics_start_year  (cost=0.00..805.90 rows=73795 width=0) (actual time=13.690..13.691 rows=68536 loops=1)"
"        Index Cond: (start_year = 1994)"
"Planning Time: 0.087 ms"
"JIT:"
"  Functions: 2"
"  Options: Inlining false, Optimization false, Expressions true, Deforming true"
"  Timing: Generation 0.179 ms (Deform 0.090 ms), Inlining 0.000 ms, Optimization 0.000 ms, Emission 0.000 ms, Total 0.179 ms"
"Execution Time: 310.212 ms"
```

3. Filtrer sur les deux colonnes :
```sql
EXPLAIN ANALYZE SELECT * FROM title_basics WHERE genres = 'Drama' AND start_year = 1994;
```

Résultat :
```
"Bitmap Heap Scan on title_basics  (cost=117.81..27480.96 rows=8329 width=84) (actual time=0.508..6.667 rows=5796 loops=1)"
"  Recheck Cond: ((start_year = 1994) AND ((genres)::text = 'Drama'::text))"
"  Heap Blocks: exact=1629"
"  ->  Bitmap Index Scan on idx_title_basics_year_genres  (cost=0.00..115.73 rows=8329 width=0) (actual time=0.316..0.317 rows=5796 loops=1)"
"        Index Cond: ((start_year = 1994) AND ((genres)::text = 'Drama'::text))"
"Planning Time: 0.153 ms"
"Execution Time: 6.889 ms"
```

4. Trie par genre puis par année :
```sql
EXPLAIN ANALYZE SELECT * FROM title_basics ORDER BY genres, start_year;
```

Résultat :
```
"Index Scan using idx_title_basics_genres_year on title_basics  (cost=0.43..906418.00 rows=11651827 width=84) (actual time=0.732..15415.820 rows=11651827 loops=1)"
"Planning Time: 0.518 ms"
"Execution Time: 15833.791 ms"
```

5. Trie par année puis par genre :
```sql
EXPLAIN ANALYZE SELECT * FROM title_basics ORDER BY start_year, genres;
```

Résultat :
```
"Index Scan using idx_title_basics_year_genres on title_basics  (cost=0.43..896312.15 rows=11651827 width=84) (actual time=0.127..12481.903 rows=11651827 loops=1)"
"Planning Time: 0.135 ms"
"Execution Time: 12891.589 ms"
```

Tableau de comparaison des performances :
### 3.5 Comparaison des performances selon le filtre et l’ordre d’index

| N° | Requête                                       | Index utilisé                        | Type de scan             | Lignes retournées | Temps d'exécution |
|----|-----------------------------------------------|--------------------------------------|--------------------------|-------------------|-------------------|
| 1  | `WHERE genres = 'Drama'`                      | idx_title_basics_genres              | Bitmap Heap Scan         | 1 311 711         | 5740 ms           |
| 2  | `WHERE start_year = 1994`                     | idx_title_basics_start_year          | Bitmap Heap Scan         | 68 536            | 310 ms            |
| 3  | `WHERE genres = 'Drama' AND start_year = 1994`| idx_title_basics_year_genres         | Bitmap Heap Scan         | 5 796             | 6.8 ms            |
| 4  | `ORDER BY genres, start_year`                 | idx_title_basics_genres_year         | Index Scan               | 11 651 827        | 15 834 ms         |
| 5  | `ORDER BY start_year, genres`                 | idx_title_basics_year_genres         | Index Scan               | 11 651 827        | 12 892 ms         |

### 3.6 Analyse et réflexion

1. **Comment l'ordre des colonnes dans l'index composite affecte-t-il son utilisation ?**
   - L’ordre des colonnes détermine dans quelles conditions l’index peut être utilisé efficacement.
   - PostgreSQL utilise l’index composite si les filtres ou tris correspondent **au début de l’index**, dans le même ordre.
   - Par exemple, un index `(genres, start_year)` est utile pour `WHERE genres = ...` ou `ORDER BY genres, start_year`, mais pas pour `WHERE start_year = ...`.

2. **Quand un index composite est-il préférable à plusieurs index séparés ?**
   - Lorsqu’une requête filtre ou trie **simultanément sur plusieurs colonnes**.
   - Il évite la combinaison coûteuse des index via `BitmapAnd`, et permet un accès plus direct aux lignes concernées.
   - Il est aussi plus performant pour les requêtes très ciblées avec peu de résultats.

3. **Comment choisir l'ordre optimal des colonnes dans un index composite ?**
   - Placer en premier la colonne la **plus filtrante (la plus sélective)** dans les requêtes.
   - Suivre l’ordre des colonnes utilisé le plus souvent dans les `WHERE` ou `ORDER BY`.
   - Analyser les requêtes réelles exécutées pour adapter l’index à l’usage principal de la base.

## Exercice 4: Index partiels

### 4.1 Identifier un sous-ensemble fréquent
```sql
SELECT start_year, COUNT(*) AS film_count
FROM title_basics
WHERE start_year IS NOT NULL
GROUP BY start_year
ORDER BY film_count DESC
LIMIT 20;
```

Conclusion : La décennie 2015 à 2024 contient le plus de films, avec plus de 4 millions d’enregistrements. Elle est donc idéale pour la création d’un index partiel, car elle représente un sous-ensemble massif et ciblé.

### 4.2 Requête sur ce sous-ensemble

```sql
EXPLAIN ANALYZE SELECT * FROM title_basics
WHERE start_year BETWEEN 2015 AND 2024;
```

### 4.3 Création d'un index partiel
```sql
CREATE INDEX idx_title_basics_start_year_2015_2024
ON title_basics(start_year)
WHERE start_year BETWEEN 2015 AND 2024;
```

### 4.4 Comparaison avec index complet
```sql
CREATE INDEX idx_title_basics_start_year_full ON title_basics(start_year);
```

1. Performances pour les requêtes dans la période ciblée (2015–2024)

| Index utilisé                            | Type de scan    | Lignes retournées | Temps d'exécution |
|-----------------------------------------|------------------|-------------------|-------------------|
| Aucun (ni partiel ni complet utilisé)   | Seq Scan         | 4 521 187         | 1626.705 ms       |

**Observation** : L’index partiel n’est pas utilisé car la requête retourne trop de lignes. PostgreSQL choisit un `Seq Scan` direct.

2. Performances pour les requêtes hors de la période (1990–1999)

| Index utilisé                        | Type de scan           | Lignes retournées | Temps d'exécution |
|-------------------------------------|-------------------------|-------------------|-------------------|
| `idx_title_basics_start_year_full`  | Parallel Bitmap Heap Scan | 752 036         | 636.283 ms        |

**Observation** : L’index complet est bien utilisé pour des requêtes plus sélectives.

3. Taille des deux index

| Index                                  | Taille     |
|----------------------------------------|------------|
| `idx_title_basics_start_year_2015_2024`| 30 MB      |
| `idx_title_basics_start_year_full`     | 77 MB      |

**Observation** :
   - L’index partiel est **près de 2,5 fois plus petit** que l’index complet.
  - Il est donc plus économique en espace, mais limité aux requêtes très spécifiques à sa condition.

### 4.5 Analyse et réflexion

1. **Quels sont les avantages et inconvénients d'un index partiel?**
   - **Avantages** : plus léger, plus rapide sur un sous-ensemble ciblé, moins coûteux à maintenir.
   - **Inconvénients** : utilisé uniquement si la requête correspond exactement à la condition `WHERE`.

2. **Dans quels scénarios un index partiel est-il particulièrement utile?**
   - Si les requêtes portent souvent sur un même filtre (ex : années récentes, status actif).
   - Si ce sous-ensemble est bien plus petit que la table entière.

3. **Comment déterminer si un index partiel est adapté à votre cas d'usage?**
   - Analyser les requêtes fréquentes.
   - Vérifier si le filtre est récurrent et sélectif.
   - Tester avec `EXPLAIN ANALYZE` et comparer aux performances d’un index complet.


## Exercice 5: Index d'expressions
    5.1 Recherche insensible à la casse
    une requête qui recherche des titres indépendamment de la casse:
```sql
        SELECT *
        FROM title_basics
        WHERE lower(primary_title) LIKE lower('%star wars%');
```

    5.2 Mesure des performances sans index adapté
    Analysez les performances avec l'index B-tree standard sur primary_Title
```sql
    EXPLAIN ANALYZE 
    SELECT * 
    FROM title_basics 
    WHERE primary_title LIKE 'The%';
```
    "Gather  (cost=1000.00..246708.42 rows=1165 width=84) (actual time=10.372..1685.231 rows=7479 loops=1)"
    "  Workers Planned: 2"
    "  Workers Launched: 2"
    "  ->  Parallel Seq Scan on title_basics  (cost=0.00..245591.92 rows=485 width=84) (actual time=15.314..1653.126 rows=2493 loops=3)"
    "        Filter: (lower((primary_title)::text) ~~ '%star wars%'::text)"
    "        Rows Removed by Filter: 3881449"
    "Planning Time: 0.244 ms"
    "JIT:"
    "  Functions: 6"
    "  Options: Inlining false, Optimization false, Expressions true, Deforming true"
    "  Timing: Generation 1.696 ms (Deform 0.340 ms), Inlining 0.000 ms, Optimization 2.000 ms, Emission 37.546 ms, Total 41.242 ms"
    "Execution Time: 1686.629 ms"

    5.3 Création d'un index d'expression
    Création d'un index sur l'expression LOWER(primary_Title).
 ```sql
    CREATE INDEX idx_lower_primary_title ON title_basics (LOWER(primary_title));
```
    5.4 Mise à jour de la requête et test
    Modification de la requête pour utiliser LOWER() et mesure l'amélioration des performances
 ``` sql
    EXPLAIN ANALYZE
    SELECT *
    FROM title_basics
    WHERE LOWER(primary_title) LIKE 'the%';
 ``` 
    "Gather  (cost=1000.00..252417.82 rows=58259 width=84) (actual time=11.243..1668.909 rows=602085 loops=1)"
    "  Workers Planned: 2"
    "  Workers Launched: 2"
    "  ->  Parallel Seq Scan on title_basics  (cost=0.00..245591.92 rows=24275 width=84) (actual time=5.341..1619.159 rows=200695 loops=3)"
    "        Filter: (lower((primary_title)::text) ~~ 'the%'::text)"
    "        Rows Removed by Filter: 3683247"
    "Planning Time: 1.655 ms"
    "JIT:"
    "  Functions: 6"
    "  Options: Inlining false, Optimization false, Expressions true, Deforming true"
    "  Timing: Generation 2.106 ms (Deform 0.399 ms), Inlining 0.000 ms, Optimization 2.059 ms, Emission 13.063 ms, Total 17.229 ms"
    "Execution Time: 1686.338 ms"

    Mesure de l'amélioration de performances:

    - Aucun gain mesurable n’a été observé : La conversion pour utiliser LOWER(primary_title) n’a pas permis d’éviter le Parallel Seq Scan puisque le filtre retourne un très grand nombre de lignes.
    - Dans ce contexte, même avec l’index d'expression, PostgreSQL estime qu’un scan séquentiel en parallèle reste optimal par rapport à l’utilisation de l’index.
    - Le temps d’exécution global ne montre donc pas d’amélioration significative soit 1686.338 ms dans les deux cas.
    
    5.5 Autre exemple d'expression
```sql
CREATE INDEX idx_title_basics_title_length ON title_basics (LENGTH(primary_title));
```
```sql 
    EXPLAIN ANALYZE
    SELECT *
    FROM title_basics
    WHERE LENGTH(primary_title) > 10;
```

    "Seq Scan on title_basics  (cost=0.00..347545.41 rows=3883942 width=84) (actual time=8.680..1410.321 rows=10407496 loops=1)"
    "  Filter: (length((primary_title)::text) > 10)"
    "  Rows Removed by Filter: 1244331"
    "Planning Time: 1.487 ms"
    "JIT:"
    "  Functions: 2"
    "  Options: Inlining false, Optimization false, Expressions true, Deforming true"
    "  Timing: Generation 2.190 ms (Deform 0.435 ms), Inlining 0.000 ms, Optimization 1.542 ms, Emission 7.076 ms, Total 10.808 ms"
    "Execution Time: 1656.475 ms"

    5.6 Analyse et réflexion
      1. Correspondance exacte de l'expression :
        L'optimiseur de requêtes ne peut exploiter l'index que si l'expression utilisée dans la clause WHERE est identique (même fonction, même syntaxe) à celle qui a été indexée. Toute divergence empêche l'utilisation de l'index, car la valeur calculée au moment de l'indexation doit correspondre exactement à celle calculée lors de l'exécution de la requête.

      2. Impact sur les performances d'écriture :
        Les index d'expressions augmentent la charge lors des opérations d'insertion ou de mise à jour. Chaque écriture doit recalculer l'expression indexée et mettre à jour l'index, ce qui peut ralentir les performances d'écriture, notamment dans les tables très actives.

      3. Transformations couramment utilisées :
        - Les fonctions de manipulation de texte, comme LOWER() ou UPPER(), pour appliquer une casse standard.
        - Des fonctions de conversion ou de formatage, telles que CAST(), TRIM(), ou COALESCE().
        - Des fonctions de calcul, par exemple LENGTH() pour obtenir la longueur d'une chaîne.  

## Exercice 6: Index couvrants (INCLUDE)

    6.1 Requête fréquente avec projection
```sql
    SELECT primary_title, start_year
    FROM title_basics
    WHERE genres = 'Drama';
```
    6.2 Index standard
```sql
    CREATE INDEX idx_title_basics_genres ON title_basics(genres);
```

    Analyse du plan d'exécution :
```sql
    EXPLAIN ANALYZE
    SELECT primary_title, start_year
    FROM title_basics
    WHERE genres = 'Drama';
```
    - L'index sur genres permet de filtrer sur cette colonne, mais la requête sélectionne également les colonnes primary_title et start_year qui ne font pas partie de l'index.
    - Pour que PostgreSQL réalise un "Index Only Scan", toutes les colonnes requises par la requête doivent être disponibles dans l'index (ou être accessibles via le heap grâce à la visibilité complète).
    - Dans ce cas précis, l'index idx_title_basics_genres ne contient que la colonne genres. PostgreSQL doit donc contacter la table pour récupérer primary_title et start_year, ce qui empêche un "Index Only Scan".

    Pour obtenir un "Index Only Scan", il faudrait créer un index couvrant avec l'option INCLUDE (disponible à partir de PostgreSQL 11) :
```sql
    CREATE INDEX idx_title_basics_genres_covering 
    ON title_basics(genres) 
    INCLUDE (primary_title, start_year);
```
    6.3 Index couvrant
    Créez un index couvrant qui inclut les colonnes supplémentaires nécessaires.
```sql
    CREATE INDEX idx_title_basics_genres_covering 
    ON title_basics(genres) 
    INCLUDE (primary_title, start_year);
```
```sql
    EXPLAIN ANALYZE
    SELECT primary_title, start_year
    FROM title_basics
    WHERE genres = 'Drama';
```

    6.4 Comparaison des performances
    
    1. Aucun index
        PostgreSQL effectue un scan séquentiel complet sur la table, ce qui peut être lent si la table est volumineuse.
    2. Index standard
        Le filtre sur « genres » est optimisé grâce à l'index, mais l'extraction des colonnes « primary_title » et « start_year » nécessite un accès supplémentaire au heap. L'index n'est donc pas entièrement utilisé en mode « Index Only Scan ». Le gain de performance peut être modeste.
    3. Index couvrant
       Comme toutes les colonnes nécessaires sont incluses dans l'index, PostgreSQL peut réaliser un « Index Only Scan » si la visibilité de la table le permet (c'est-à-dire que le heap est synchronisé via la visibilité map). Cela peut réduire significativement le nombre d'accès disque et améliorer la performance de la requête.

    6.5 Analyse et réflexion
    1. Index Only Scan
        C'est une méthode d'accès où PostgreSQL peut satisfaire une requête en se limitant uniquement aux pages de l'index, sans consulter les données réelles dans la table (heap). C'est avantageux car cela réduit le nombre d'accès disque, accélère l'exécution et diminue la charge sur le système, à condition que l'index couvre toutes les colonnes demandées et que la visibilité des lignes soit à jour.
    2. Différence entre ajouter une colonne à l'index et l'inclure avec INCLUDE
        - Ajouter une colonne à l'index signifie qu'elle fait partie de la clé d'indexation, ce qui influence l'ordre de tri et la manière dont l'index est utilisé pour rechercher des valeurs.
        - Inclure une colonne avec INCLUDE place la colonne dans la partie "payload" de l'index. Elle n'affecte pas l'ordre de tri ni la recherche, mais est disponible pour les requêtes, permettant par exemple un « Index Only Scan » sans surcharger la clé d'index.
    3. Quand privilégier un index couvrant par rapport à un index composite
        - On privilégie un index couvrant lorsque l'objectif est de satisfaire complètement une requête sans accéder à la table. Cela est utile pour les requêtes en lecture fréquentes qui sélectionnent quelques colonnes supplémentaires (non utilisées pour filtrer ou trier) et ainsi améliorer les performances grâce à un « Index Only Scan ».
        - Un index composite est plus adapté lorsqu'il faut optimiser les recherches sur plusieurs colonnes en tant que clés de filtrage ou de tri, même si certaines colonnes ne sont pas retournées dans la requête.  

## Exercice 7: Recherche textuelle
    7.1 Requête de recherche simple
        Requête simple qui recherche tous les titres contenant le mot "love" 
```sql
    SELECT *
    FROM title_basics
    WHERE primary_title ILIKE '%love%';
```

    7.2 Test de différentes approches
        Mesurez les performances avec:
    1. LIKE sans index
```sql
    EXPLAIN ANALYZE
    SELECT *
    FROM title_basics
    WHERE primary_title LIKE '%love%';
```
    2. LIKE avec index B-tree
```sql
    -- Création de l'index B-tree sur primary_title
    CREATE INDEX idx_title_basics_primary_title ON title_basics(primary_title);

    -- Test avec le B-tree index
    EXPLAIN ANALYZE
    SELECT *
    FROM title_basics
    WHERE primary_title LIKE '%love%';
```
    3. Index trigram (GIN)
```sql
    -- Activation de l'extension pg_trgm 
    CREATE EXTENSION IF NOT EXISTS pg_trgm;

    -- Création de l'index GIN trigram sur primary_title
    CREATE INDEX idx_title_basics_trgm ON title_basics USING gin (primary_title gin_trgm_ops);

    -- Test avec l'index trigram
    EXPLAIN ANALYZE
    SELECT *
    FROM title_basics
    WHERE primary_title ILIKE '%love%';
```
7.3 Recherche full-text
    1. Ajoutez une colonne de type tsvector
```sql
    ALTER TABLE title_basics
    ADD COLUMN primary_title_tsv tsvector;
```
    2. Remplissez cette colonne avec le résultat de to_tsvector. Ici, nous utilisons la configuration 'english' (vous pouvez adapter selon vos besoins) :
```sql
    UPDATE title_basics
    SET primary_title_tsv = to_tsvector('english', primary_title);
```
    3. Créez un index GIN sur cette nouvelle colonne :
```sql
    CREATE INDEX idx_title_basics_primary_title_tsv
    ON title_basics USING gin(primary_title_tsv);
```
    4. Réécrivez la requête à l'aide de to_tsquery pour effectuer la recherche full-text (ici, on recherche le terme "love") :
```sql
    CREATE INDEX idx_title_basics_primary_title_tsv
    ON title_basics USING gin(primary_title_tsv);
```

    7.4 Analyse et réflexion
    1. Quelles sont les différences entre LIKE, trigram et full-text search?
        LIKE : Permet une recherche par correspondance de motifs simples avec des caractères génériques. Il est limité pour les recherches non préfixées (ex. %love%) et peut être inefficace sur de grands volumes de données.
        Trigram (GIN avec pg_trgm) : Utilise des n-grammes pour découper les chaînes en séquences de caractères. Cela permet de rechercher des sous-chaînes de manière plus efficace, même avec des jokers en début de motif, et offre une tolérance aux fautes ou variations mineures.
        Full-text search : Transforme le texte en « tokens » en appliquant une configuration linguistique (stop words, racinisation, etc.) afin de permettre une recherche sémantique et contextuelle, avec la possibilité de classer les résultats par pertinence.

    2. Quels compromis faites-vous en termes de précision, performance et espace?
        LIKE :
            - Précision : Recherche exacte de correspondance de motifs, mais limitée dans sa capacité à gérer des variations ou fautes.
            - Performance : Peut être très lent sur de grands volumes si aucun index adapté n'est utilisé.
            - Espace : N'ajoute pratiquement aucun coût en termes d'index (sauf s'il est indexé par un B-tree, qui dans le cas des jokers en début d'expression n'est pas efficace).
        Trigram :
            - Précision : Permet des recherches approximatives et tolérantes aux erreurs, mais peut parfois retourner des résultats moins précis si le seuil de similarité est bas.
            - Performance : Améliore considérablement la recherche par sous-chaînes sur de grands ensembles grâce à l'indexation GIN.
            - Espace : Les index trigram peuvent occuper plus d'espace disque en raison du stockage des n-grammes.
        Full-text search :
            - Précision : Offre une compréhension plus « linguistique » et sémantique du texte ce qui est adapté aux recherches de documents, même si cela peut parfois manquer de précision pour des correspondances exactes.
            - Performance : Très performant pour les grands volumes de texte, surtout lorsqu'on utilise des index GIN adaptés, et permet un classement par pertinence.
            - Espace : Les colonnes tsvector et leurs index peuvent être volumineux et nécessiter un temps de maintenance supplémentaire.

    3. Pour quels volumes de données et types de recherches chaque approche est-elle adaptée?
        - LIKE est adapté aux petits ensembles de données ou lorsque le motif recherché est très sélectif.
        - Trigram est particulièrement utile pour des recherches sur de grandes tables lorsque la recherche porte sur une sous-chaîne, avec tolérance aux erreurs et des motifs non préfixés, typiques des applications de recherche « fuzzy ».
        - Full-text search convient aux volumes massifs de texte et aux applications nécessitant une analyse linguistique (par exemple, moteurs de recherche sur des articles de blog, documents, etc.) où la pertinence et le classement des résultats sont importants.

## Exercice 8: Indexation de données JSON/JSONB

## Exercice 9: Analyse et maintenance des index

## Exercice 10: Synthèse et cas pratiques