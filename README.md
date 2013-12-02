## Scripts for Importing Songs

This Repository contains all scripts and rake tasks used to clean and process lyrics files. Song metadata is stored in a CSV file.

Lyrics are stored in the lyrics folder.
Processed lyrics files have a .jsi extension

#### There are two components for song/lyrics data:

  1. A CSV file with rows containting the attributes (column names) for all songs. The first column should be the ```ID``` of the song
  2. A lyrics file for each song containing named as ```ID.jsi```

## CSV formats should *exactly* match the format of tier1.csv and tier2.csv
