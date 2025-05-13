# Exercice 1
```
EXPLAIN ANALYZE SELECT * FROM title_basics WHERE start_year = 2020;
```
### 1.1 Résultat
"Gather  (cost=1000.00..178435.80 rows=4313 width=1363) (actual time=211.182..11748.462 rows=438620 loops=1)" \
"  Workers Planned: 2" \
"  Workers Launched: 2" \
"  ->  Parallel Seq Scan on title_basics  (cost=0.00..177004.50 rows=1797 width=1363) (actual time=83.367..5133.813 rows=146207 loops=3)" \
"        Filter: (start_year = 2020)" \
"        Rows Removed by Filter: 3737132" \
"Planning Time: 0.563 ms" \
"JIT:" \
"  Functions: 6" \
"  Options: Inlining false, Optimization false, Expressions true, Deforming true" \
"  Timing: Generation 22.373 ms (Deform 4.510 ms), Inlining 0.000 ms, Optimization 103.771 ms, Emission 82.430 ms, Total 208.574 ms" \
"Execution Time: 11835.618 ms"

### 1.2 Résultat
- Postgresql utilise un Seq scan
- 438620 lignes retourné
- 3737132 ont été rejeté
- Le temps d'éxecution est de 11835.618 ms (11 secondes)
1. Postgresql a utilisé un Parallel Sequential Scan car la table était surement beaucoup trop grande
2. 
3. Rows removed by filter correspond aux lignes enlevés par le filtre de l'année
### 1.3
Crée
### 1.4
"Gather  (cost=5899.29..271957.35 rows=439594 width=84) (actual time=53.819..779.643 rows=438620 loops=1)" \
"  Workers Planned: 2" \
"  Workers Launched: 2" \
"  ->  Parallel Bitmap Heap Scan on title_basics  (cost=4899.29..226997.95 rows=183164 width=84) (actual time=33.526..638.825 rows=146207 loops=3)" \
"        Recheck Cond: (start_year = 2020)" \
"        Rows Removed by Index Recheck: 672361" \
"        Heap Blocks: exact=11008 lossy=10413" \
"        ->  Bitmap Index Scan on idx_title_basics_start_year  (cost=0.00..4789.39 rows=439594 width=0) (actual time=45.257..45.257 rows=438620 loops=1)" \
"              Index Cond: (start_year = 2020)" \
"Planning Time: 3.434 ms" \
"JIT:" \
"  Functions: 6" \
"  Options: Inlining false, Optimization false, Expressions true, Deforming true" \
"  Timing: Generation 2.778 ms (Deform 1.233 ms), Inlining 0.000 ms, Optimization 2.683 ms, Emission 15.746 ms, Total 21.207 ms" \
"Execution Time: 805.551 ms" \

- Le temps d'execution a été coupé par 10, un Parallel Bitmap Heap Scan a été utilisé au lieu de Parallel Seq Scan entre autres

### 1.5
"Gather  (cost=5899.29..271957.35 rows=439594 width=34) (actual time=67.361..5889.557 rows=438620 loops=1)" \
"  Workers Planned: 2" \
"  Workers Launched: 2" \
"  ->  Parallel Bitmap Heap Scan on title_basics  (cost=4899.29..226997.95 rows=183164 width=34) (actual time=26.447..5751.299 rows=146207 loops=3)" \
"        Recheck Cond: (start_year = 2020)" \
"        Rows Removed by Index Recheck: 672361" \
"        Heap Blocks: exact=12092 lossy=11277" \
"        ->  Bitmap Index Scan on idx_title_basics_start_year  (cost=0.00..4789.39 rows=439594 width=0) (actual time=46.118..46.119 rows=438620 loops=1)" \
"              Index Cond: (start_year = 2020)" \
"Planning Time: 0.116 ms" \
"JIT:" \
"  Functions: 12" \
"  Options: Inlining false, Optimization false, Expressions true, Deforming true" \
"  Timing: Generation 4.010 ms (Deform 0.862 ms), Inlining 0.000 ms, Optimization 1.159 ms, Emission 15.272 ms, Total 20.441 ms" \
"Execution Time: 5913.488 ms"
- 1 & 2: Les méthodes utilisés reste les même après l'indexation, mais le temps d'éxecution ici est plus long, surement car il doit actuellement vérifier les valeurs tandis que tout selectionner il y'a pas d'étape supplémentaire

### 1.6
1. La stratégie utilisé maintenant est le Parallel Bitmap Heap Scan
2. Le temps d'éxecution s'est amélioré de 5/6 secondes
3. Le Bitmap Index Scan parcours notre index à la recherche des entrées qui correspondent à notre recherche. À la différence d'un index scan, au lieu d'aller chercher tout de suite les entrées correspondantes dans la table, il les garde en mémoire.
Le Bitmap Heap Scan, une fois qu'il a trouvé toutes les entrées recherchées dans l'index, va les trier par rapport à leur localisation physique sur le disque dur
4. Le temps d'éxecution ne s'est pas amélioré d'avantage car il reste tout de même un grand nombre de lignes

# Exercice 2
### 2.1
"Bitmap Heap Scan on title_basics  (cost=76.97..23493.08 rows=428 width=34) (actual time=4.936..1053.346 rows=2011 loops=1)" \
"  Recheck Cond: (start_year = 1950)" \
"  Filter: ((title_type)::text = 'movie'::text)" \
"  Rows Removed by Filter: 6265" \
"  Heap Blocks: exact=3280" \
"  ->  Bitmap Index Scan on idx_title_basics_start_year  (cost=0.00..76.86 rows=6990 width=0) (actual time=3.750..3.751 rows=8276 loops=1)" \
"        Index Cond: (start_year = 1950)" \
"Planning Time: 0.214 ms" \
"Execution Time: 1053.748 ms"

### 2.2
1. Postgresql utilise un Bitmap Index Scan sur title_type et start_year
2. 8 276 lignes passent le premier filtre, 2 011 passent ensuite le second filtre
3. L'index n'est que sur une colonne, il ne prend donc pas en compte des filtres supplémentaires

### 2.3
CREATE INDEX idx_title_basics_start_year_title_type
ON title_basics (start_year, title_type);

### 2.4
"Bitmap Heap Scan on title_basics  (cost=8.82..1663.29 rows=428 width=34) (actual time=0.373..2.234 rows=2011 loops=1)" \
"  Recheck Cond: ((start_year = 1950) AND ((title_type)::text = 'movie'::text))" \
"  Heap Blocks: exact=935" \
"  ->  Bitmap Index Scan on idx_title_basics_start_year_title_type  (cost=0.00..8.72 rows=428 width=0) (actual time=0.161..0.161 rows=2011 loops=1)" \
"        Index Cond: ((start_year = 1950) AND ((title_type)::text = 'movie'::text))" \
"Planning Time: 0.088 ms" \
"Execution Time: 2.374 ms"

- La requête est devenu pratiquement instantané
### 2.5
"Bitmap Heap Scan on title_basics  (cost=78.61..23477.25 rows=6990 width=43) (actual time=1.132..6.552 rows=8276 loops=1)" \
"  Recheck Cond: (start_year = 1950)" \
"  Heap Blocks: exact=3280" \
"  ->  Bitmap Index Scan on idx_title_basics_start_year  (cost=0.00..76.86 rows=6990 width=0) (actual time=0.514..0.515 rows=8276 loops=1)" \
"        Index Cond: (start_year = 1950)" \
"Planning Time: 0.106 ms" \
"Execution Time: 6.862 ms" \
1. Il est techniquement devenu 3 fois plus long, même si c'est sur des nombres très petit
2. Cette optimisation est plus efficace grâce à l'ajout d'un index qui gère deux colonnes.
3. Un covering index serait idéal si les requêtes SELECT à toute les colonnes qui sont présente dans l'index

### 2.6

1. Par rapport au temps d'éxecution du 2.1, le temps est passé de 1 seconde à 0,006862 seconde.
2. Sans l'index composite, la stratégie semble rester la même.
3. L'index a diminué le nombre de blocs qu'il doit lire dans la table actuelle.
4. Un covering index est donc particulièrement efficace si les requêtes font un SELECT sur ces colonnes précisement.
