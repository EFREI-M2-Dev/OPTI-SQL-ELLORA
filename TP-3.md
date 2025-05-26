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
### 4.2 Requête sur ce sous-ensemble
### 4.3 Création d'un index partiel
### 4.4 Comparaison avec index complet
### 4.5 Analyse et réflexion

## Exercice 5: Index d'expressions

## Exercice 6: Index couvrants (INCLUDE)

## Exercice 7: Recherche textuelle

## Exercice 8: Indexation de données JSON/JSONB

## Exercice 9: Analyse et maintenance des index

## Exercice 10: Synthèse et cas pratiques