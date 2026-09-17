import os
import json
import math
import re
import shutil

import numpy as np


# --------------------------------------------------
# FOLDERS
# --------------------------------------------------

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

DATA_DIR = os.path.join(BASE_DIR, "documents")

os.makedirs(DATA_DIR, exist_ok=True)


# --------------------------------------------------
# TEXT PROCESSING
# --------------------------------------------------

def tokenize(text):
    """
    Convert text into simple lowercase word tokens.
    """

    return re.findall(
        r"\b[a-zA-Z0-9]+\b",
        text.lower()
    )


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
# TF-IDF
# --------------------------------------------------

def build_tfidf(chunks):

    if not chunks:
        return (
            np.array([]),
            {},
            []
        )

    tokenized_chunks = [
        tokenize(chunk)
        for chunk in chunks
    ]

    # Build vocabulary
    vocabulary = {}

    for tokens in tokenized_chunks:

        for token in set(tokens):

            if token not in vocabulary:

                vocabulary[token] = len(vocabulary)

    vocab_size = len(vocabulary)

    # Document frequency
    document_frequency = np.zeros(
        vocab_size,
        dtype=np.float32
    )

    for tokens in tokenized_chunks:

        for token in set(tokens):

            index = vocabulary[token]

            document_frequency[index] += 1

    number_of_documents = len(chunks)

    # IDF
    idf = (
        np.log(
            (number_of_documents + 1)
            /
            (document_frequency + 1)
        )
        + 1
    )

    # TF-IDF matrix
    matrix = np.zeros(
        (
            number_of_documents,
            vocab_size
        ),
        dtype=np.float32
    )

    for row, tokens in enumerate(tokenized_chunks):

        if not tokens:
            continue

        counts = {}

        for token in tokens:

            if token in vocabulary:

                counts[token] = (
                    counts.get(token, 0) + 1
                )

        total_words = len(tokens)

        for token, count in counts.items():

            column = vocabulary[token]

            tf = count / total_words

            matrix[row, column] = (
                tf * idf[column]
            )

    # Normalize vectors
    norms = np.linalg.norm(
        matrix,
        axis=1,
        keepdims=True
    )

    norms[norms == 0] = 1

    matrix = matrix / norms

    return (
        matrix,
        vocabulary,
        idf.tolist()
    )


# --------------------------------------------------
# CREATE EMBEDDINGS
# --------------------------------------------------

def create_embeddings(chunks):

    """
    Lightweight TF-IDF vectors.

    Kept under the same function name so the
    rest of the application can continue using it.
    """

    matrix, _, _ = build_tfidf(chunks)

    return matrix


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

    # Rebuild TF-IDF metadata so the same
    # vocabulary can be used for questions.
    _, vocabulary, idf = build_tfidf(chunks)

    metadata = {
        "document_id": document_id,
        "filename": filename,
        "chunks": chunks,
        "vocabulary": vocabulary,
        "idf": idf
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
        "document_id":
            metadata["document_id"],

        "filename":
            metadata["filename"],

        "chunks":
            metadata["chunks"],

        "embeddings":
            embeddings,

        "vocabulary":
            metadata.get("vocabulary", {}),

        "idf":
            metadata.get("idf", [])
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

    vocabulary = document["vocabulary"]

    idf = document["idf"]

    if len(chunks) == 0:
        return []

    # --------------------------------------------------
    # Backward compatibility
    # --------------------------------------------------

    # Old documents created with the previous
    # SentenceTransformer system won't have
    # TF-IDF metadata.

    if not vocabulary or not idf:

        embeddings, vocabulary, idf = build_tfidf(
            chunks
        )

    # --------------------------------------------------
    # Create question vector
    # --------------------------------------------------

    question_tokens = tokenize(
        question
    )

    question_vector = np.zeros(
        len(vocabulary),
        dtype=np.float32
    )

    counts = {}

    for token in question_tokens:

        if token in vocabulary:

            counts[token] = (
                counts.get(token, 0) + 1
            )

    total_words = len(question_tokens)

    if total_words > 0:

        for token, count in counts.items():

            column = vocabulary[token]

            question_vector[column] = (
                (count / total_words)
                * idf[column]
            )

    # Normalize question vector
    question_norm = np.linalg.norm(
        question_vector
    )

    if question_norm > 0:

        question_vector = (
            question_vector
            /
            question_norm
        )

    # --------------------------------------------------
    # Cosine similarity
    # --------------------------------------------------

    similarities = np.dot(
        embeddings,
        question_vector
    )

    # --------------------------------------------------
    # Get highest scores
    # --------------------------------------------------

    top_indices = np.argsort(
        similarities
    )[::-1][:top_k]

    results = []

    for index in top_indices:

        results.append({
            "chunk":
                chunks[index],

            "score":
                float(
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

    shutil.rmtree(
        document_folder
    )

    return True
