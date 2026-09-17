import os
import json
import numpy as np

from sentence_transformers import SentenceTransformer


# --------------------------------------------------
# FOLDERS
# --------------------------------------------------

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

DATA_DIR = os.path.join(BASE_DIR, "documents")

os.makedirs(DATA_DIR, exist_ok=True)


# --------------------------------------------------
# EMBEDDING MODEL
# --------------------------------------------------

print("Loading embedding model...")

model = SentenceTransformer(
    "all-MiniLM-L6-v2"
)

print("Embedding model loaded!")


# --------------------------------------------------
# CHUNK TEXT
# --------------------------------------------------

def create_chunks(
    text: str,
    chunk_size: int = 500,
    overlap: int = 100
):
    """
    Split document text into overlapping chunks.
    """

    words = text.split()

    chunks = []

    start = 0

    while start < len(words):

        end = start + chunk_size

        chunk = " ".join(
            words[start:end]
        )

        if chunk.strip():
            chunks.append(chunk)

        start += chunk_size - overlap

    return chunks


# --------------------------------------------------
# CREATE EMBEDDINGS
# --------------------------------------------------

def create_embeddings(chunks):

    if not chunks:
        return np.array([])

    embeddings = model.encode(
        chunks,
        normalize_embeddings=True
    )

    return np.array(embeddings)


# --------------------------------------------------
# SAVE DOCUMENT
# --------------------------------------------------

def save_document(
    document_id,
    filename,
    chunks,
    embeddings
):

    document_folder = os.path.join(
        DATA_DIR,
        document_id
    )

    os.makedirs(
        document_folder,
        exist_ok=True
    )

    metadata = {
        "document_id": document_id,
        "filename": filename,
        "chunks": chunks
    }

    metadata_path = os.path.join(
        document_folder,
        "metadata.json"
    )

    with open(
        metadata_path,
        "w",
        encoding="utf-8"
    ) as file:

        json.dump(
            metadata,
            file,
            ensure_ascii=False,
            indent=2
        )

    embeddings_path = os.path.join(
        document_folder,
        "embeddings.npy"
    )

    np.save(
        embeddings_path,
        embeddings
    )


# --------------------------------------------------
# LOAD DOCUMENT
# --------------------------------------------------

def load_document(document_id):

    document_folder = os.path.join(
        DATA_DIR,
        document_id
    )

    metadata_path = os.path.join(
        document_folder,
        "metadata.json"
    )

    embeddings_path = os.path.join(
        document_folder,
        "embeddings.npy"
    )

    if not os.path.exists(metadata_path):
        return None

    if not os.path.exists(embeddings_path):
        return None

    with open(
        metadata_path,
        "r",
        encoding="utf-8"
    ) as file:

        metadata = json.load(file)

    embeddings = np.load(
        embeddings_path
    )

    return {
        "document_id": metadata["document_id"],
        "filename": metadata["filename"],
        "chunks": metadata["chunks"],
        "embeddings": embeddings
    }


# --------------------------------------------------
# LIST DOCUMENTS
# --------------------------------------------------

def list_documents():

    documents = []

    if not os.path.exists(DATA_DIR):
        return documents

    for document_id in os.listdir(DATA_DIR):

        document_folder = os.path.join(
            DATA_DIR,
            document_id
        )

        if not os.path.isdir(document_folder):
            continue

        metadata_path = os.path.join(
            document_folder,
            "metadata.json"
        )

        if not os.path.exists(metadata_path):
            continue

        try:

            with open(
                metadata_path,
                "r",
                encoding="utf-8"
            ) as file:

                metadata = json.load(file)

            documents.append({
                "document_id":
                    metadata["document_id"],

                "filename":
                    metadata["filename"],

                "chunks":
                    len(metadata["chunks"])
            })

        except Exception:
            continue

    return documents


# --------------------------------------------------
# SEARCH RELEVANT CHUNKS
# --------------------------------------------------

def search_document(
    document_id,
    question,
    top_k=5
):

    document = load_document(
        document_id
    )

    if document is None:
        return []

    chunks = document["chunks"]

    embeddings = document["embeddings"]

    if len(chunks) == 0:
        return []

    # Create embedding for user question
    question_embedding = model.encode(
        [question],
        normalize_embeddings=True
    )[0]

    # Cosine similarity
    similarities = np.dot(
        embeddings,
        question_embedding
    )

    # Get highest scores
    top_indices = np.argsort(
        similarities
    )[::-1][:top_k]

    results = []

    for index in top_indices:

        results.append({
            "chunk": chunks[index],
            "score": float(
                similarities[index]
            )
        })

    return results


# --------------------------------------------------
# DELETE DOCUMENT
# --------------------------------------------------

def delete_document(document_id):

    document_folder = os.path.join(
        DATA_DIR,
        document_id
    )

    if not os.path.exists(
        document_folder
    ):
        return False

    import shutil

    shutil.rmtree(
        document_folder
    )

    return True