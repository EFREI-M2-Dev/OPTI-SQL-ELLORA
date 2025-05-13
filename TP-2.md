# TP #02 : Optimisation des requêtes avec les index


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