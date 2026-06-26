import os
import google.generativeai as genai

genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

try:
    for m in genai.list_models():
        print(f"name: {m.name}, supported_generation_methods: {m.supported_generation_methods}")
except Exception as e:
    print(f"Error: {e}")
