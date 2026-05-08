import firebase_admin
from firebase_admin import credentials, storage

def initialize_firebase():
    if not firebase_admin._apps:
        cred = credentials.Certificate("swapscout-firebase-adminsdk-fbsvc-4ccd1fde01.json")
        firebase_admin.initialize_app(cred, {
            'storageBucket': 'swapscout.firebasestorage.app'
        })

def get_storage_bucket():
    initialize_firebase()
    return storage.bucket()
