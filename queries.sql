-- Comptage simple
SELECT COUNT(*) FROM title_basics;

-- Distribution par type
SELECT title_type, COUNT(*)
FROM title_basics
GROUP BY title_type
ORDER BY COUNT(*) DESC;


-- Films les mieux notés
SELECT b.primary_title, r.average_rating, r.num_votes
FROM title_basics b
         JOIN title_ratings r ON b.tconst = r.tconst
WHERE b.title_type = 'movie'
ORDER BY r.average_rating DESC
LIMIT 10;

-- Plan execution
EXPLAIN ANALYZE
SELECT b.primary_title, r.average_rating
FROM title_basics b
         JOIN title_ratings r ON b.tconst = r.tconst
WHERE r.num_votes > 1000
ORDER BY r.average_rating DESC
LIMIT 10;