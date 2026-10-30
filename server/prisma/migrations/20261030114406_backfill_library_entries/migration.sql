-- Free books someone already started reading stay in their library.
INSERT INTO "LibraryEntry" ("id", "readerId", "bookId", "createdAt")
SELECT 'backfill_' || rp."id", rp."readerId", rp."bookId", rp."createdAt"
FROM "ReadingProgress" rp
JOIN "Book" b ON b."id" = rp."bookId"
WHERE b."accessType" = 'FREE'
ON CONFLICT ("readerId", "bookId") DO NOTHING;
