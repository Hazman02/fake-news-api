from fastapi import FastAPI, Form, File, UploadFile
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.templating import Jinja2Templates
from fastapi.requests import Request

import joblib
import xgboost as xgb
import numpy as np
import malaya
import pytesseract
from PIL import Image
import io

# Initialize FastAPI app
app = FastAPI()

# Set up Jinja2 templates
templates = Jinja2Templates(directory="templates")

# Load the trained XGBoost model
model = xgb.Booster()
model.load_model("xgboost_fake_news_model.json")

# Load the Malaya Word2Vec vocab and vector
vocab, vector = malaya.wordvector.load('combine')

# If on Windows, ensure Tesseract path is correct
pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

# Function to preprocess text
def preprocess_text(text):
    text = text.lower()
    text = ''.join([char for char in text if char.isalnum() or char.isspace()])
    return text

# Function to get Word2Vec embeddings
def get_word2vec_embeddings(text, vocab, vector, vector_size=256):
    words = text.split()  # Tokenize by spaces
    embeddings = []
    for word in words:
        word_index = vocab.get(word)
        if word_index is not None:
            embedding = vector[word_index]
            embeddings.append(embedding)
    if len(embeddings) == 0:
        return np.zeros(vector_size)
    return np.mean(embeddings, axis=0)

# Home route to render the HTML form (for browser users)
@app.get("/", response_class=HTMLResponse)
async def home(request: Request):
    return templates.TemplateResponse("index.html", {"request": request})

# API route to handle predictions from text (returns JSON for Flutter)
@app.post("/predict")
async def predict_api(headline: str = Form(...)):
    try:
        # Preprocess the headline
        cleaned_headline = preprocess_text(headline)
        # Convert to embeddings
        headline_embedding = get_word2vec_embeddings(cleaned_headline, vocab, vector)
        # XGBoost DMatrix
        headline_dmatrix = xgb.DMatrix([headline_embedding])
        # Predict
        probabilities = model.predict(headline_dmatrix)
        fake_probability = 1 - probabilities[0]
        real_probability = probabilities[0]

        # Decide label
        if real_probability >= 0.7:
            label = "Likely Real News"
        elif fake_probability >= 0.7:
            label = "Likely Fake News"
        else:
            label = "Uncertain"

        return JSONResponse({
            "headline": headline,
            "prediction": label,
            "fake_probability": f"{fake_probability * 100:.2f}%",
            "real_probability": f"{real_probability * 100:.2f}%"
        })
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)

# ============== Web-based image endpoint (HTML) =============
@app.post("/predict_from_image", response_class=HTMLResponse)
async def predict_from_image(request: Request, file: UploadFile = File(...)):
    """
    This route is for your *web* form. Renders 'index.html' with results.
    """
    try:
        image_bytes = await file.read()
        image = Image.open(io.BytesIO(image_bytes))
        extracted_text = pytesseract.image_to_string(image)
        cleaned_text = preprocess_text(extracted_text)

        text_embedding = get_word2vec_embeddings(cleaned_text, vocab, vector)
        text_dmatrix = xgb.DMatrix([text_embedding])
        probabilities = model.predict(text_dmatrix)
        fake_probability = 1 - probabilities[0]
        real_probability = probabilities[0]

        if real_probability >= 0.7:
            label = "Likely Real News"
        elif fake_probability >= 0.7:
            label = "Likely Fake News"
        else:
            label = "Uncertain"

        return templates.TemplateResponse(
            "index.html",
            {
                "request": request,
                "headline": extracted_text,
                "prediction": label,
                "fake_probability": f"{fake_probability * 100:.2f}%",
                "real_probability": f"{real_probability * 100:.2f}%"
            },
        )
    except Exception as e:
        return templates.TemplateResponse(
            "index.html",
            {"request": request, "error": str(e)}
        )

# ============== New Flutter-based image endpoint (JSON) ==============
@app.post("/predict_from_image_api")
async def predict_from_image_api(file: UploadFile = File(...)):
    """
    This route returns *JSON* so your Flutter chat can parse it easily.
    """
    try:
        image_bytes = await file.read()
        image = Image.open(io.BytesIO(image_bytes))
        extracted_text = pytesseract.image_to_string(image)
        cleaned_text = preprocess_text(extracted_text)

        text_embedding = get_word2vec_embeddings(cleaned_text, vocab, vector)
        text_dmatrix = xgb.DMatrix([text_embedding])
        probabilities = model.predict(text_dmatrix)
        fake_probability = 1 - probabilities[0]
        real_probability = probabilities[0]

        if real_probability >= 0.7:
            label = "Likely Real News"
        elif fake_probability >= 0.7:
            label = "Likely Fake News"
        else:
            label = "Uncertain"

        return JSONResponse({
            "extracted_text": extracted_text,
            "prediction": label,
            "fake_probability": f"{fake_probability * 100:.2f}%",
            "real_probability": f"{real_probability * 100:.2f}%"
        })
    except Exception as e:
        return JSONResponse({"error": str(e)}, status_code=500)
