import os
import json
import math
import re
import io

import numpy as np

from dotenv import load_dotenv
from supabase import create_client, Client


# --------------------------------------------------
# SUPABASE
# --------------------------------------------------

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    raise RuntimeError(
        "SUPABASE_URL and SUPABASE_SERVICE_KEY must be set."
    )

supabase: Client = create_client(
    SUPABASE_URL,
    SUPABASE_SERVICE_KEY
)

STORAGE_BUCKET = "pdfs"


# --------------------------------------------------
# FOLDERS
# --------------------------------------------------

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Local folder kept only for temporary/backward compatibility.
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
    """
    Save RAG data to Supabase Storage.

    Files:
        rag/<document_id>/metadata.json
        rag/<document_id>/embeddings.npy
    """

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

    # ----------------------------------------------
    # Metadata JSON -> bytes
    # ----------------------------------------------

    metadata_bytes = json.dumps(
        metadata,
        ensure_ascii=False,
        indent=2
    ).encode("utf-8")

    metadata_path = (
        f"rag/{document_id}/metadata.json"
    )

    # ----------------------------------------------
    # Embeddings NumPy -> bytes
    # ----------------------------------------------

    buffer = io.BytesIO()

    np.save(
        buffer,
        embeddings
    )

    embeddings_bytes = buffer.getvalue()

    embeddings_path = (
        f"rag/{document_id}/embeddings.npy"
    )

    # ----------------------------------------------
    # Upload metadata
    # ----------------------------------------------

    try:

        supabase.storage.from_(
            STORAGE_BUCKET
        ).upload(
            metadata_path,
            metadata_bytes,
            {
                "content-type": "application/json",
                "upsert": "true"
            }
        )

        print(
            "SUPABASE RAG METADATA UPLOAD SUCCESS:",
            metadata_path
        )

    except Exception as e:

        print(
            "SUPABASE RAG METADATA UPLOAD ERROR:",
            repr(e)
        )

        raise

    # ----------------------------------------------
    # Upload embeddings
    # ----------------------------------------------

    try:

        supabase.storage.from_(
            STORAGE_BUCKET
        ).upload(
            embeddings_path,
            embeddings_bytes,
            {
                "content-type": "application/octet-stream",
                "upsert": "true"
            }
        )

        print(
            "SUPABASE RAG EMBEDDINGS UPLOAD SUCCESS:",
            embeddings_path
        )

    except Exception as e:

        print(
            "SUPABASE RAG EMBEDDINGS UPLOAD ERROR:",
            repr(e)
        )

        raise


# --------------------------------------------------
# LOAD DOCUMENT
# --------------------------------------------------

def load_document(document_id):
    """
    Load RAG data from Supabase Storage.
    """

    metadata_path = (
        f"rag/{document_id}/metadata.json"
    )

    embeddings_path = (
        f"rag/{document_id}/embeddings.npy"
    )

    # ----------------------------------------------
    # Download metadata
    # ----------------------------------------------

    try:

        metadata_bytes = (
            supabase.storage
            .from_(STORAGE_BUCKET)
            .download(metadata_path)
        )

        metadata = json.loads(
            metadata_bytes.decode("utf-8")
        )

    except Exception as e:

        print(
            "SUPABASE RAG METADATA DOWNLOAD ERROR:",
            repr(e)
        )

        return None

    # ----------------------------------------------
    # Download embeddings
    # ----------------------------------------------

    try:

        embeddings_bytes = (
            supabase.storage
            .from_(STORAGE_BUCKET)
            .download(embeddings_path)
        )

        embeddings = np.load(
            io.BytesIO(embeddings_bytes),
            allow_pickle=False
        )

    except Exception as e:

        print(
            "SUPABASE RAG EMBEDDINGS DOWNLOAD ERROR:",
            repr(e)
        )

        return None

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
    """
    List documents from Supabase RAG storage.
    """

    documents = []

    try:

        folders = (
            supabase.storage
            .from_(STORAGE_BUCKET)
            .list("rag")
        )

    except Exception as e:

        print(
            "SUPABASE RAG LIST ERROR:",
            repr(e)
        )

        return documents

    for item in folders:

        document_id = item.get("name")

        if not document_id:
            continue

        metadata_path = (
            f"rag/{document_id}/metadata.json"
        )

        try:

            metadata_bytes = (
                supabase.storage
                .from_(STORAGE_BUCKET)
                .download(metadata_path)
            )

            metadata = json.loads(
                metadata_bytes.decode("utf-8")
            )

            documents.append({
                "document_id":
                    metadata["document_id"],

                "filename":
                    metadata["filename"],

                "chunks":
                    len(metadata["chunks"])
            })

        except Exception as e:

            print(
                "SUPABASE RAG DOCUMENT READ ERROR:",
                document_id,
                repr(e)
            )

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
    """
    Delete RAG data from Supabase Storage.
    """

    metadata_path = (
        f"rag/{document_id}/metadata.json"
    )

    embeddings_path = (
        f"rag/{document_id}/embeddings.npy"
    )

    try:

        result = (
            supabase.storage
            .from_(STORAGE_BUCKET)
            .remove([
                metadata_path,
                embeddings_path
            ])
        )

        print(
            "SUPABASE RAG DELETE SUCCESS:",
            document_id,
            result
        )

        return True

    except Exception as e:

        print(
            "SUPABASE RAG DELETE ERROR:",
            repr(e)
        )

        return False