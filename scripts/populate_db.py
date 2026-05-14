import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime
import argparse
import sys
import os

def populate_db(service_account_path):
    print("Initialize Firebase Admin SDK...")
    
    # Check if path exists
    if not os.path.exists(service_account_path):
        print(f"Error: Service account file not found at '{service_account_path}'")
        print("Please download your serviceAccountKey.json from Firebase Console -> Project Settings -> Service Accounts")
        sys.exit(1)
        
    try:
        cred = credentials.Certificate(service_account_path)
        firebase_admin.initialize_app(cred)
        db = firestore.client()
        print("Firebase initialized successfully!")
    except Exception as e:
        print(f"Error initializing Firebase: {e}")
        sys.exit(1)

    # Note: Using local paths like "assets/3d_models/..." might not work out of the box in the app unless 
    # it's mapped to an actual URL in a remote storage, OR the app reads it locally.
    # In Flutter, assets configured in pubspec.yaml can be referenced using their exact path.
    products = [
        {
            "name": "Oversized Fit Cotton T-Shirt",
            "description": "A comfortable, everyday oversized cotton t-shirt with a relaxed fit. Perfect for casual wear.",
            "price": 24.99,
            "category": "Clothing",
            "brand": "Urban Wear",
            "material": "100% Cotton",
            "tags": ["t-shirt", "oversized", "casual", "cotton"],
            "image_2d": [
                "https://images.unsplash.com/photo-1576566588028-4147f3842f27?q=80&w=800&auto=format&fit=crop"
            ],
            "image_3d": "assets/3d_models/Oversized-T-Shirt.glb",
            "arModelUrl": "assets/3d_models/Oversized-T-Shirt.glb",
            "stock": 50,
            "soldAmount": 12,
            "rating": 4.8,
            "reviewCount": 42,
            "colors": ["Black", "White", "Grey"],
            "sizes": ["S", "M", "L", "XL"],
            "isFeatured": True,
            "createdAt": firestore.SERVER_TIMESTAMP,
        },
        {
            "name": "Classic Fit T-Shirt",
            "description": "Essential classic fit crewneck t-shirt. Soft, breathable, and durable for everyday use.",
            "price": 19.99,
            "category": "Clothing",
            "brand": "Essentials",
            "material": "95% Cotton, 5% Spandex",
            "tags": ["t-shirt", "classic", "basic", "cotton"],
            "image_2d": [
                "https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?q=80&w=800&auto=format&fit=crop"
            ],
            "image_3d": "assets/3d_models/T-Shirt.glb",
            "arModelUrl": "assets/3d_models/T-Shirt.glb",
            "stock": 100,
            "soldAmount": 85,
            "rating": 4.5,
            "reviewCount": 128,
            "colors": ["White", "Navy", "Olive"],
            "sizes": ["S", "M", "L", "XL", "XXL"],
            "isFeatured": True,
            "createdAt": firestore.SERVER_TIMESTAMP,
        }
    ]

    print(f"Populating Firestore with {len(products)} products...")
    
    collection_ref = db.collection(u'products')
    
    for product in products:
        try:
            # We don't force a specific doc ID, Firestore will generate one
            doc_ref = collection_ref.document()
            
            # The app model expects an 'id' field, so we can save the document ID back into the product
            product['id'] = doc_ref.id
            
            doc_ref.set(product)
            print(f"Successfully added product: {product['name']} (ID: {product['id']})")
        except Exception as e:
            print(f"Failed to add product {product['name']}: {e}")
            
    print("Database population complete!")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Populate Firestore with AR Products')
    parser.add_argument('--service-account', type=str, default='serviceAccountKey.json',
                        help='Path to the Firebase Service Account JSON credentials file')
    
    args = parser.parse_args()
    
    print("======================================================")
    print("Firestore Product Population Script")
    print("======================================================\n")
    populate_db(args.service_account)
