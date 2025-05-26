# TP #04 : Techniques de requêtage optimisées

## Partie 1: Stratégies de jointure optimisées

### Exercice 1.1: Analyse des films populaires et bien notés

Requête : 
```sql
SELECT b.primary_title, b.start_year, b.genres, r.average_rating, r.num_votes FROM title_basics b
JOIN title_ratings r ON b.tconst = r.tconst WHERE r.num_votes > 10000 AND b.start_year >= 2000
ORDER BY r.num_votes DESC
LIMIT 20;
```

Résultat EXPLAIN Analyze : 
```
"Limit  (cost=19607.83..19823.52 rows=20 width=46) (actual time=252.110..267.349 rows=20 loops=1)"
"  ->  Nested Loop  (cost=19607.83..133435.57 rows=10555 width=46) (actual time=252.108..267.345 rows=20 loops=1)"
"        ->  Gather Merge  (cost=19607.83..21416.91 rows=15533 width=20) (actual time=252.062..267.159 rows=32 loops=1)"
"              Workers Planned: 2"
"              Workers Launched: 2"
"              ->  Sort  (cost=18607.81..18623.99 rows=6472 width=20) (actual time=99.343..99.369 rows=319 loops=3)"
"                    Sort Key: r.num_votes DESC"
"                    Sort Method: quicksort  Memory: 984kB"
"                    Worker 0:  Sort Method: quicksort  Memory: 42kB"
"                    Worker 1:  Sort Method: quicksort  Memory: 43kB"
"                    ->  Parallel Seq Scan on title_ratings r  (cost=0.00..18198.13 rows=6472 width=20) (actual time=4.130..97.866 rows=5421 loops=3)"
"                          Filter: (num_votes > 10000)"
"                          Rows Removed by Filter: 517212"
"        ->  Index Scan using idx_title_basics_tconst_hash on title_basics b  (cost=0.00..7.21 rows=1 width=46) (actual time=0.005..0.005 rows=1 loops=32)"
"              Index Cond: ((tconst)::text = (r.tconst)::text)"
"              Filter: (start_year >= 2000)"
"              Rows Removed by Filter: 0"
"Planning Time: 0.339 ms"
"Execution Time: 267.390 ms"
```

Types de jointures utilisés :

- Nested Loop : PostgreSQL scanne les résultats de title_ratings et va chercher les titres correspondants dans title_basics via un index.
- Parallel Seq Scan : sur title_ratings, car aucun index spécifique sur num_votes. 
- Index Scan : utilisé sur title_basics, ce qui évite un scan complet.

Index à créer :
```sql
CREATE INDEX idx_title_ratings_num_votes ON title_ratings(num_votes);
CREATE INDEX idx_title_basics_start_year ON title_basics(start_year);
CREATE INDEX idx_title_basics_tconst ON title_basics(tconst);
CREATE INDEX idx_title_ratings_tconst ON title_ratings(tconst);
```

Après création des index, le résultat est :
```
"Planning Time: 17.769 ms"
"Execution Time: 11.028 ms"
```

- Le filtre num_votes > 10000 est désormais accéléré via un index.
- Le temps d’exécution est passé de 267 ms à 11 ms.
- La requête est plus de 20 fois plus rapide.

### Exercice 1.2: Acteurs et réalisateurs à succès

```sql
EXPLAIN ANALYZE
SELECT
  nb.primary_name,
  COUNT(*) AS high_rated_films_count,
  ARRAY_AGG(tb.primary_title) AS films
FROM title_principals tp
JOIN name_basics nb ON tp.nconst = nb.nconst
JOIN title_basics tb ON tp.tconst = tb.tconst
JOIN title_ratings tr ON tb.tconst = tr.tconst
WHERE tp.category = 'actor'
  AND tr.average_rating > 8.0
GROUP BY nb.primary_name
HAVING COUNT(*) >= 3
ORDER BY high_rated_films_count DESC;
```

Résultat EXPLAIN Analyze :
```
"Sort  (cost=3109933.75..3111995.61 rows=824745 width=54) (actual time=17977.042..18290.689 rows=65426 loops=1)"
"  Sort Key: (count(*)) DESC"
"  Sort Method: external merge  Disk: 26480kB"
"  ->  Finalize GroupAggregate  (cost=2427948.19..2972502.75 rows=824745 width=54) (actual time=17029.872..18194.738 rows=65426 loops=1)"
"        Group Key: nb.primary_name"
"        Filter: (count(*) >= 3)"
"        Rows Removed by Filter: 202228"
"        ->  Gather Merge  (cost=2427948.19..2898261.62 rows=3712762 width=54) (actual time=17029.734..17883.285 rows=275116 loops=1)"
"              Workers Planned: 2"
"              Workers Launched: 2"
"              ->  Partial GroupAggregate  (cost=2426948.17..2468716.74 rows=1856381 width=54) (actual time=16966.842..17322.048 rows=91705 loops=3)"
"                    Group Key: nb.primary_name"
"                    ->  Sort  (cost=2426948.17..2431589.12 rows=1856381 width=34) (actual time=16966.705..17173.454 rows=408328 loops=3)"
"                          Sort Key: nb.primary_name"
"                          Sort Method: external merge  Disk: 17800kB"
"                          Worker 0:  Sort Method: external merge  Disk: 17296kB"
"                          Worker 1:  Sort Method: external merge  Disk: 16664kB"
"                          ->  Parallel Hash Join  (cost=579743.00..2132140.21 rows=1856381 width=34) (actual time=15299.621..16402.382 rows=408328 loops=3)"
"                                Hash Cond: ((tp.nconst)::text = (nb.nconst)::text)"
"                                ->  Parallel Hash Join  (cost=256620.57..1743609.78 rows=1856381 width=30) (actual time=10697.112..11737.779 rows=408331 loops=3)"
"                                      Hash Cond: ((tp.tconst)::text = (tb.tconst)::text)"
"                                      ->  Parallel Seq Scan on title_principals tp  (cost=0.00..1343728.04 rows=9126758 width=20) (actual time=0.960..6452.026 rows=7310156 loops=3)"
"                                            Filter: ((category)::text = 'actor'::text)"
"                                            Rows Removed by Filter: 23524255"
"                                      ->  Parallel Hash  (cost=253920.58..253920.58 rows=132879 width=40) (actual time=2562.487..2562.509 rows=104607 loops=3)"
"                                            Buckets: 131072  Batches: 4  Memory Usage: 6944kB"
"                                            ->  Parallel Hash Join  (cost=19859.12..253920.58 rows=132879 width=40) (actual time=168.600..2514.435 rows=104607 loops=3)"
"                                                  Hash Cond: ((tb.tconst)::text = (tr.tconst)::text)"
"                                                  ->  Parallel Seq Scan on title_basics tb  (cost=0.00..221317.28 rows=4854928 width=30) (actual time=0.197..1354.150 rows=3883942 loops=3)"
"                                                  ->  Parallel Hash  (cost=18198.13..18198.13 rows=132879 width=10) (actual time=167.336..167.337 rows=104607 loops=3)"
"                                                        Buckets: 524288  Batches: 1  Memory Usage: 18848kB"
"                                                        ->  Parallel Seq Scan on title_ratings tr  (cost=0.00..18198.13 rows=132879 width=10) (actual time=0.639..133.752 rows=104607 loops=3)"
"                                                              Filter: (average_rating > 8.0)"
"                                                              Rows Removed by Filter: 418025"
"                                ->  Parallel Hash  (cost=212977.52..212977.52 rows=5999352 width=24) (actual time=3391.791..3391.791 rows=4800445 loops=3)"
"                                      Buckets: 131072  Batches: 128  Memory Usage: 7744kB"
"                                      ->  Parallel Seq Scan on name_basics nb  (cost=0.00..212977.52 rows=5999352 width=24) (actual time=337.874..1977.453 rows=4800445 loops=3)"
"Planning Time: 1.462 ms"
"JIT:"
"  Functions: 112"
"  Options: Inlining true, Optimization true, Expressions true, Deforming true"
"  Timing: Generation 5.929 ms (Deform 2.492 ms), Inlining 221.494 ms, Optimization 471.787 ms, Emission 319.300 ms, Total 1018.511 ms"
"Execution Time: 18307.727 ms"
```

2. Création d'index pour optimiser la requête :
```sql
CREATE INDEX idx_title_ratings_avg_rating ON title_ratings(average_rating);
CREATE INDEX idx_title_basics_tconst ON title_basics(tconst); -- déjà existante attention
CREATE INDEX idx_title_principals_tconst ON title_principals(tconst);
CREATE INDEX idx_title_principals_nconst ON title_principals(nconst);
CREATE INDEX idx_name_basics_nconst ON name_basics(nconst);
```

Temps d'exécution après création des index :
```
"Planning Time: 0.926 ms"
"JIT:"
"  Functions: 112"
"  Options: Inlining true, Optimization true, Expressions true, Deforming true"
"  Timing: Generation 4.348 ms (Deform 1.856 ms), Inlining 191.261 ms, Optimization 420.842 ms, Emission 355.763 ms, Total 972.214 ms"
"Execution Time: 17651.418 ms"
```

Comparatif : 

| Critère                         | Version initiale | Version avec index |
|--------------------------------|------------------|---------------------|
| Filtrage `average_rating > 8`  | Tardif (Hash Join) | Précoce (Bitmap Index Scan) |
| Ligne de départ (`title_principals`) | 73M lignes scannées | 73M lignes scannées |
| Tri final                      | External merge    | External merge      |
| Temps total                    | **18 307 ms**     | **17 651 ms**       |

---

## Partie 2: Sous-requêtes et CTE efficaces

### Exercice 2.1: Transformation de sous-requêtes

```sql
SELECT tb.primary_title, tb.start_year, tr.average_rating
FROM title_basics tb
JOIN title_ratings tr ON tb.tconst = tr.tconst
WHERE tr.average_rating > (
SELECT AVG(r.average_rating)
FROM title_basics b
JOIN title_ratings r ON b.tconst = r.tconst
WHERE b.genres LIKE '%' || tb.genres || '%'
)
ORDER BY tr.average_rating DESC
LIMIT 100;
```

Très mauvaise performance, car la sous-requête est exécutée pour chaque ligne de `title_basics`.

Requête optimisée : 
```sql
SELECT tb.primary_title, tb.start_year, tr.average_rating
FROM title_basics tb
JOIN title_ratings tr ON tb.tconst = tr.tconst
JOIN (
  SELECT b.genres, AVG(r.average_rating) AS avg_rating
  FROM title_basics b
  JOIN title_ratings r ON b.tconst = r.tconst
  WHERE b.genres IS NOT NULL
  GROUP BY b.genres
) g ON tb.genres = g.genres
WHERE tr.average_rating > g.avg_rating
ORDER BY tr.average_rating DESC
LIMIT 100;
```

Comparaison des deux versions :

| Critère                       | Sous-requête corrélée                          | Version optimisée avec jointure simple |
|------------------------------|------------------------------------------------|----------------------------------------|
| Type de filtre               | Sous-requête corrélée (par ligne)              | Jointure non corrélée (`tb.genres = g.genres`) |
| Calcul de la moyenne         | Recalculée pour chaque film                   | Calculée une seule fois par genre      |
| Exploitation des index       | Non (utilisation de `LIKE` non indexable)     | Oui (comparaison directe avec `=`)     |
| Plan d'exécution typique     | `Nested Loop` + `SubPlan`                     | `Hash Join` optimisé                   |
| Temps d'exécution estimé     | Plusieurs **minutes**                         | Quelques **secondes**                  |
| Lisibilité et maintenance    | Faible                                        | Meilleure                              |
| Scalabilité                  | Mauvaise (non viable sur gros volumes)        | Bonne (structure réutilisable)         |


### Exercice 2.2: Utilisation de CTE

Requête complète avec CTE : 
```sql
WITH genre_stats AS (
    SELECT b.genres,
           AVG(r.average_rating) AS avg_rating,
           COUNT(*) AS film_count
    FROM title_basics b
             JOIN title_ratings r ON b.tconst = r.tconst
    WHERE b.genres IS NOT NULL
    GROUP BY b.genres
),

     exceptional_films AS (
         SELECT b.tconst, b.primary_title, b.genres, r.average_rating, g.avg_rating
         FROM title_basics b
                  JOIN title_ratings r ON b.tconst = r.tconst
                  JOIN genre_stats g ON b.genres = g.genres
         WHERE r.average_rating > g.avg_rating + 2
     ),

     main_actors AS (
         SELECT tp.tconst, nb.primary_name AS actor_name
         FROM title_principals tp
                  JOIN name_basics nb ON tp.nconst = nb.nconst
         WHERE tp.category = 'actor'
           AND tp.ordering = 1  -- acteur principal
     )

SELECT ef.primary_title,
       ef.genres,
       ef.average_rating,
       ef.avg_rating,
       ma.actor_name
FROM exceptional_films ef
         LEFT JOIN main_actors ma ON ef.tconst = ma.tconst
ORDER BY ef.average_rating DESC;
```

---

## Partie 3: Window Functions et agrégations avancées

### Exercice 3.1: Analyse de carrière avec Window Functions

### Exercice 3.2: Agrégations avancées

---

## Partie 4: Pagination et matérialisation

### Exercice 4.1: Pagination optimisée

### Exercice 4.2: Vues matérialisées

---

## Partie 5: Requêtes parallèles et analyse de performances

### Exercice 5.1: Configuration du parallélisme

### Exercice 5.2: Analyse globale de performances
