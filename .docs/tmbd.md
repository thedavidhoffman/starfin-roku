# TMDB API

https://developer.themoviedb.org/reference

## Filmography

The app uses a custom TMDB account API key from settings to retrieve person filmography data. Jellyfin does not provide the combined filmography credits we need for the Filmography page, so we call TMDB directly with the configured `api_key`.

https://api.themoviedb.org/3/authentication?api_key={api_key}

https://api.themoviedb.org/3/movie/550
https://api.themoviedb.org/3/movie/78

https://image.tmdb.org/t/p/w342{poster_path}
https://image.tmdb.org/t/p/w500{poster_path}
https://image.tmdb.org/t/p/w780{poster_path}
https://image.tmdb.org/t/p/original{poster_path}

https://image.tmdb.org/t/p/w500/63N9uy8nd9j7Eog2axPQ8lbr3Wj.jpg

https://image.tmdb.org/t/p/w342/63N9uy8nd9j7Eog2axPQ8lbr3Wj.jpg
