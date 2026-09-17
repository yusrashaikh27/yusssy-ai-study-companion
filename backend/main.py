from fastapi import FastAPI, UploadFile, File
from pydantic import BaseModel
from dotenv import load_dotenv
from supabase import create_client, Client
import httpx
import os
import uuid

import fitz

from rag import (
    create_chunks,
    create_embeddings,
    save_document,
    list_documents,
    search_document,
    delete_document,
    load_document,
)


# --------------------------------------------------
# ENVIRONMENT
# --------------------------------------------------

load_dotenv()

GROQ_API_KEY = os.getenv(
    "GROQ_API_KEY"
)

GROQ_URL = (
    "https://api.groq.com/openai/v1/chat/completions"
)
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")

supabase: Client = create_client(
    SUPABASE_URL,
    SUPABASE_SERVICE_KEY
)

# --------------------------------------------------
# FASTAPI
# --------------------------------------------------

app = FastAPI(
    title="AI Companion Backend"
)


# --------------------------------------------------
# REQUEST MODELS
# --------------------------------------------------

class ChatRequest(BaseModel):

    messages: list


class PDFQuestion(BaseModel):

    question: str

    document_id: str


# --------------------------------------------------
# HOME
# --------------------------------------------------

@app.get("/")
def home():

    return {
        "message":
            "AI Companion backend is running"
    }


# --------------------------------------------------
# NORMAL AI CHAT
# --------------------------------------------------

@app.post("/chat")
async def chat(
    request: ChatRequest
):

    headers = {
        "Authorization":
            f"Bearer {GROQ_API_KEY}",

        "Content-Type":
            "application/json",
    }

    data = {

        "model":
            "openai/gpt-oss-120b",

        "messages":
            request.messages,
    }

    async with httpx.AsyncClient() as client:

        response = await client.post(

            GROQ_URL,

            headers=headers,

            json=data,

            timeout=60,
        )

    if response.status_code != 200:

        return {
            "error":
                response.text
        }

    result = response.json()

    answer = (
        result["choices"][0]
        ["message"]
        ["content"]
    )

    return {
        "response":
            answer
    }


# --------------------------------------------------
# UPLOAD PDF
# --------------------------------------------------
@app.post("/upload-pdf")
async def upload_pdf(
    file: UploadFile = File(...)
):

    # Validate PDF
    if (
        not file.filename
        or not file.filename.lower().endswith(".pdf")
    ):
        return {
            "error": "Only PDF files are allowed."
        }

    # Read uploaded file
    contents = await file.read()

    # Temporary file
    temp_path = f"/tmp/{uuid.uuid4()}.pdf"

    with open(temp_path, "wb") as pdf_file:
        pdf_file.write(contents)

    document = None

    try:

        # ------------------------------------------
        # EXTRACT TEXT
        # ------------------------------------------

        document = fitz.open(temp_path)

        text_parts = []

        for page in document:
            page_text = page.get_text("text")

            if page_text:
                text_parts.append(page_text)

        text = "\n\n".join(text_parts)

        page_count = len(document)

        document.close()
        document = None

        if not text.strip():
            return {
                "error": (
                    "This PDF does not contain extractable text."
                )
            }

        # ------------------------------------------
        # CREATE CHUNKS
        # ------------------------------------------

        chunks = create_chunks(text)

        if not chunks:
            return {
                "error": "Could not create text chunks from this PDF."
            }

        # ------------------------------------------
        # CREATE EMBEDDINGS
        # ------------------------------------------

        embeddings = create_embeddings(chunks)

        # ------------------------------------------
        # CREATE DOCUMENT ID
        # ------------------------------------------

        document_id = str(uuid.uuid4())

        # ------------------------------------------
        # UPLOAD ORIGINAL PDF TO SUPABASE
        # ------------------------------------------

        storage_path = f"{document_id}/{file.filename}"

        supabase.storage.from_("pdfs").upload(
            storage_path,
            contents,
            {
                "content-type": "application/pdf",
                "upsert": "false",
            }
        )

        # ------------------------------------------
        # SAVE RAG DATA
        # ------------------------------------------

        save_document(
            document_id,
            file.filename,
            chunks,
            embeddings
        )

        # ------------------------------------------
        # RESPONSE
        # ------------------------------------------

        return {
            "document_id": document_id,
            "filename": file.filename,
            "pages": page_count,
            "chunks": len(chunks),
            "storage_path": storage_path,
            "message": (
                "PDF uploaded, stored and indexed successfully."
            )
        }

    except Exception as e:

        print(f"PDF processing error: {e}")

        return {
            "error": f"PDF processing failed: {str(e)}"
        }

    finally:

        if document is not None:
            document.close()

        if os.path.exists(temp_path):
            os.remove(temp_path)

# --------------------------------------------------
# GET DOCUMENTS
# --------------------------------------------------

@app.get("/documents")
def get_documents():

    return {
        "documents":
            list_documents()
    }


# --------------------------------------------------
# ASK PDF
# --------------------------------------------------

@app.post("/ask-pdf")
async def ask_pdf(
    request: PDFQuestion
):

    # ------------------------------------------
    # CHECK DOCUMENT
    # ------------------------------------------

    document = load_document(
        request.document_id
    )

    if document is None:

        return {
            "error":
                "Document not found."
        }


    # ------------------------------------------
    # SEARCH RELEVANT CHUNKS
    # ------------------------------------------

    search_results = search_document(

        request.document_id,

        request.question,

        top_k=5
    )


    if not search_results:

        return {
            "error":
                "No relevant information found."
        }


    # ------------------------------------------
    # BUILD CONTEXT
    # ------------------------------------------

    context_parts = []

    for result in search_results:

        context_parts.append(
            result["chunk"]
        )


    context = "\n\n---\n\n".join(
        context_parts
    )


    # ------------------------------------------
    # AI SYSTEM PROMPT
    # ------------------------------------------

    system_prompt = f"""
You are an AI Study Companion.

The user uploaded this document:

{document["filename"]}

Answer the user's question using the
relevant sections retrieved from the document.

Rules:

1. Use the provided document context as
   the main source.

2. Explain the answer in simple,
   student-friendly language.

3. Do not invent information.

4. If the answer cannot be found in the
   provided context, clearly say that the
   information was not found in the document.

5. You may organize the answer using
   headings, bullet points and examples.

RELEVANT DOCUMENT CONTEXT:

{context}
"""


    messages = [

        {
            "role":
                "system",

            "content":
                system_prompt,
        },

        {
            "role":
                "user",

            "content":
                request.question,
        }

    ]


    # ------------------------------------------
    # CALL GROQ
    # ------------------------------------------

    headers = {

        "Authorization":
            f"Bearer {GROQ_API_KEY}",

        "Content-Type":
            "application/json",
    }


    data = {

        "model":
            "openai/gpt-oss-120b",

        "messages":
            messages,
    }


    async with httpx.AsyncClient() as client:

        response = await client.post(

            GROQ_URL,

            headers=headers,

            json=data,

            timeout=60,
        )


    if response.status_code != 200:

        return {

            "error":
                response.text
        }


    result = response.json()


    answer = (
        result["choices"][0]
        ["message"]
        ["content"]
    )


    # ------------------------------------------
    # RETURN ANSWER
    # ------------------------------------------

    return {

        "response":
            answer,

        "filename":
            document["filename"],

        "document_id":
            request.document_id,

        "sources":
            [
                {
                    "score":
                        result["score"]
                }

                for result
                in search_results
            ]
    }


# --------------------------------------------------
# DELETE DOCUMENT
# --------------------------------------------------

@app.delete(
    "/documents/{document_id}"
)
def remove_document(
    document_id: str
):

    deleted = delete_document(
        document_id
    )

    if not deleted:

        return {
            "error":
                "Document not found."
        }

    return {

        "message":
            "Document deleted successfully."
    }
