# TP #02 : Optimisation des requêtes avec les index

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


## Exercice 4 : Agrégation et tri

### 4.1 Requête complexe
```sql
SELECT tb.start_year AS year, COUNT(*) AS film_count, ROUND(AVG(tr.average_rating), 2) AS avg_rating FROM title_basics tb 
JOIN title_ratings tr ON tb.tconst = tr.tconst
WHERE tb.title_type = 'movie' AND tb.start_year BETWEEN 1990 AND 2000
GROUP BY tb.start_year
ORDER BY avg_rating DESC;
```

### 4.2 Analyse du plan complexe
1.
   - **Parallel Seq Scan** on _title_basics_ : PostgreSQL lit en parallèle les lignes de title_basics et applique un filtre sur start_year et title_type.**Index Scan** on _title_ratings_ : pour chaque ligne de title_basics, un accès est fait via l’index title_ratings_pkey pour trouver la note correspondante (tconst).
   - **Nested Loop** : boucle imbriquée pour associer chaque film à sa note.
   - **Sort by** _start_year_ : trie les lignes pour l’agrégation groupée.
   - **Partial GroupAggregate** : chaque worker agrège les données de son lot (nombre de films, moyenne).
   - **Gather Merge** : fusionne les résultats des workers.
   - **Finalize GroupAggregate** : combine les résultats partiels pour obtenir les moyennes finales par année.
   - **Sort final** : trie les années par note moyenne décroissante


2. L’agrégation est divisée en deux phases car PostgreSQL utilise le parallélisme (2 workers). Cela permet de répartir la charge de calcul :
      - **Partial GroupAggregate** : chaque worker calcule localement le nombre de films et la moyenne des notes pour les années qu’il traite.
      - **Finalize GroupAggregate** : le processus principal agrège les résultats partiels pour obtenir les résultats globaux.

3. L'index permet une recherche rapide de la note associée à chaque film (tconst), au lieu de scanner toute la table title_ratings.

4. Le tri final n'est pas "couteux". Le résultat porte sur 11 lignes.

### 4.3 Indexation des colonnes de jointure
```sql
CREATE INDEX idx_title_basics_tconst ON title_basics(tconst);
CREATE INDEX idx_title_ratings_tconst ON title_ratings(tconst);
```

### 4.4 Analyse après indexation
On observe que l'indexation des colonnes de jointure a amélioré les performances de la requête. Le plan d'exécution montre que PostgreSQL utilise des **Index Scan** au lieu de **Seq Scan**, ce qui réduit le temps d'accès aux données. La jointure est plus rapide car elle évite de lire toutes les lignes des tables concernées ; on gagne 50% de rapidité.


### 4.5 Analyse des résultats
1. Oui : Cela signifie que PostgreSQL utilise cet index pour accéder rapidement à la note (average_rating) associée à chaque film (tconst) de title_basics. Cela remplace efficacement un Seq Scan sur title_ratings. En revanche, l’index sur title_basics(tconst) n’est pas utilisé, car title_basics est la table principale du FROM, et elle est toujours scannée en parallèle (via Parallel Seq Scan), pour filtrer sur start_year et title_type.
2. La logique de la requête n’a pas changé ; PostgreSQL avait déjà choisi un plan performant, mais l’ajout de l’index a simplement permis d’améliorer localement la jointure ; Le volume de données reste le même, donc la structure du plan est conservée.
3. Si la table jointe est très grande OU Si le nombre de lignes filtrées OU Si le plan utilise une Nested Loop Join

## Exercice 6 : Synthèse et réflexion

1. 
   - Il est plus efficace pour les recherches ponctuelles, sur un petit nombre de lignes.
   - Il est plus utile sur des colonnes à forte cardinalité (beaucoup de valeurs distinctes).
   - Il est très performant pour les recherches par égalité, et reste utile pour les intervalles si les données sont bien triées.


2. 
   - Nested Loop : préféré quand l’une des tables est petite et qu’un index est disponible sur l’autre.
   - Hash Join : utilisé quand il n’y a pas d’ordre particulier, et efficace sur de grandes tables.
   - Merge Join : efficace si les deux tables sont triées sur la colonne de jointure.


3. 
   - Il est activé quand le volume de données dépasse un certain seuil, estimé par PostgreSQL.
   - Les opérations qui en bénéficient le plus sont les scans, agrégations et jointures.
   - Il n’est pas toujours utilisé car le coût de coordination entre threads peut dépasser le gain sur des petites requêtes.


4. 
   - Recherche exacte sur une colonne : index B-tree standard.
   - Filtrage sur plusieurs colonnes combinées : index multicolonne (col1, col2).
   - Tri fréquent sur une colonne : index B-tree (PostgreSQL trie naturellement dans l’ordre d’un index).
   - Jointures fréquentes entre tables : index sur les clés de jointure (souvent des clés étrangères ou primaires).