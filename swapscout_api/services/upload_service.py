from fastapi import UploadFile
from utils.firebase_setup import get_storage_bucket
import uuid

def upload_image_to_firebase(file: UploadFile) -> str:
    bucket = get_storage_bucket()
    
    # Generate a unique filename
    file_extension = file.filename.split(".")[-1] if "." in file.filename else "jpg"
    unique_filename = f"homes/{uuid.uuid4()}.{file_extension}"
    
    # Create a blob
    blob = bucket.blob(unique_filename)
    
    # Upload from file object
    blob.upload_from_file(file.file, content_type=file.content_type)
    blob.make_public()
    
    # Return the public URL
    return blob.public_url
