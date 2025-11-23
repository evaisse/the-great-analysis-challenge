import json
import os
import glob

REQUIRED_FEATURES = {"perft", "fen", "ai", "castling", "en_passant", "promotion"}

def check_features():
    implementations_dir = "/Users/evaisse/Sites/projects/the-great-analysis-challenge/implementations"
    meta_files = glob.glob(os.path.join(implementations_dir, "*/chess.meta"))
    
    for meta_file in meta_files:
        lang = os.path.basename(os.path.dirname(meta_file))
        try:
            with open(meta_file, 'r') as f:
                data = json.load(f)
                features = set(data.get("features", []))
                missing = REQUIRED_FEATURES - features
                if missing:
                    print(f"{lang}: Missing features: {missing}")
                else:
                    print(f"{lang}: All features implemented")
        except Exception as e:
            print(f"{lang}: Error reading meta file: {e}")

if __name__ == "__main__":
    check_features()
