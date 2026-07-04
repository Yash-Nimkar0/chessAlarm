import requests
import zstandard
import io
import csv

def fetch_sample():
    url = "https://database.lichess.org/lichess_db_puzzle.csv.zst"
    response = requests.get(url, stream=True)
    dctx = zstandard.ZstdDecompressor()
    stream_reader = dctx.stream_reader(response.raw)
    text_stream = io.TextIOWrapper(stream_reader, encoding='utf-8')
    
    csv_reader = csv.reader(text_stream)
    puzzles = []
    
    headers = next(csv_reader)
    
    for i, row in enumerate(csv_reader):
        puzzles.append(row)
        if i >= 20000:
            break
            
    with open("assets/puzzles.csv", "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(headers)
        writer.writerows(puzzles)

fetch_sample()
