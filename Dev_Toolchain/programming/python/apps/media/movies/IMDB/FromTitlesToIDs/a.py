# First: install IMDbPY if you haven't already:
#    pip install imdbpy

from imdb import IMDb

# Example with only 3 movies
titles = [
    "16 Blocks (2006)",
    "2 Guns (2013)",
    "21 (2008)",
]

ia = IMDb()
id_list = []
for title in titles:
    name, year = title.rsplit("(", 1)
    results = ia.search_movie(name.strip())
    imdb_id = None
    for r in results:
        if 'year' in r.keys() and str(r['year']) == year.rstrip(")"):
            imdb_id = r.movieID
            break
    if not imdb_id and results:
        imdb_id = results[0].movieID
    id_list.append(imdb_id or "NOT_FOUND")

for mid in id_list:
    print(f"tt{mid}")
