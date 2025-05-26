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


### 3.3 Index sur colonnes individuelles
### 3.4 Index composite
### 3.5 Test de l'ordre des colonnes
### 3.6 Analyse et réflexion

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