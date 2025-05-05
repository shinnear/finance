import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import numpy as np
from datetime import datetime
import json
import os

# --- Configuration ---
CRED_PATH = '/home/ubuntu/firebase_credentials.json'
COLLECTION_NAME = 'transactions'

# --- Helper Functions ---

def initialize_firebase(cred_path):
    """Initializes Firebase Admin SDK if not already initialized."""
    if not os.path.exists(cred_path):
        raise FileNotFoundError(f"Credentials file not found at {cred_path}")
    try:
        firebase_admin.get_app()
        # print("Firebase app already initialized.")
    except ValueError:
        # print("Initializing Firebase app...")
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)

def safe_float_conversion(value):
    """Safely converts a value to float, returning NaN on error."""
    try:
        return float(value)
    except (ValueError, TypeError):
        return np.nan

def safe_date_conversion(value):
    """Safely converts a string to datetime using expected format, returning NaT on error."""
    try:
        # Assuming MM/DD/YYYY format based on sample data
        return pd.to_datetime(value, format='%m/%d/%Y', errors='coerce')
    except (ValueError, TypeError):
        return pd.NaT

# --- Core Functions ---

def fetch_and_preprocess_data(cred_path, collection_name):
    """Fetches data from Firestore, preprocesses it, and returns a DataFrame."""
    initialize_firebase(cred_path)
    db = firestore.client()
    docs = db.collection(collection_name).stream()

    data = []
    for doc in docs:
        doc_data = doc.to_dict()
        doc_data['id'] = doc.id # Keep track of document ID
        data.append(doc_data)

    if not data:
        print("No documents found in the collection.")
        return pd.DataFrame() # Return empty DataFrame

    df = pd.DataFrame(data)
    print(f"Fetched {len(df)} documents.")

    # Basic checks for required columns
    required_cols = ['isExpense', 'amount', 'date', 'category']
    if not all(col in df.columns for col in required_cols):
        missing = [col for col in required_cols if col not in df.columns]
        raise ValueError(f"Missing required columns: {missing}")

    # 1. Filter for expenses
    # Handle potential variations in boolean representation
    df['isExpense'] = df['isExpense'].astype(str).str.lower().map({'true': True, 'false': False, '1': True, '0': False}).fillna(False)
    df_expenses = df[df['isExpense'] == True].copy()
    print(f"Filtered down to {len(df_expenses)} expense transactions.")

    if df_expenses.empty:
        print("No expense transactions found after filtering.")
        return pd.DataFrame()

    # 2. Type Conversion
    df_expenses['amount'] = df_expenses['amount'].apply(safe_float_conversion)
    df_expenses['date'] = df_expenses['date'].apply(safe_date_conversion)

    # 3. Handle Missing/Invalid Data
    original_len = len(df_expenses)
    df_expenses.dropna(subset=['amount', 'date', 'category'], inplace=True)
    if len(df_expenses) < original_len:
        print(f"Dropped {original_len - len(df_expenses)} rows due to missing/invalid amount, date, or category.")

    # Ensure category is string
    df_expenses['category'] = df_expenses['category'].astype(str)

    # Add time-based features
    df_expenses['year'] = df_expenses['date'].dt.year
    df_expenses['month'] = df_expenses['date'].dt.month
    df_expenses['year_month'] = df_expenses['date'].dt.to_period('M')

    print(f"Preprocessing complete. {len(df_expenses)} valid expense transactions remaining.")
    return df_expenses

def analyze_spending_patterns(df):
    """Analyzes spending patterns from the preprocessed DataFrame."""
    if df.empty:
        return {"error": "No data available for analysis."}

    # Total Spending
    total_spending = df['amount'].sum()

    # Spending by Category
    category_spending = df.groupby('category')['amount'].agg(['sum', 'mean', 'count']).sort_values('sum', ascending=False)

    # Spending Over Time (Monthly)
    monthly_spending = df.groupby('year_month')['amount'].sum()
    # Convert PeriodIndex to string for JSON serialization
    monthly_spending.index = monthly_spending.index.astype(str)

    patterns = {
        'total_spending': total_spending,
        'spending_by_category': category_spending.reset_index().to_dict(orient='records'),
        'monthly_spending': monthly_spending.reset_index().to_dict(orient='records') # format: [{'year_month': 'YYYY-MM', 'amount': value}]
    }
    return patterns

def detect_anomalies_iqr(df, group_by_col='category', value_col='amount', threshold=1.5):
    """Detects anomalies using the IQR method within specified groups."""
    if df.empty or group_by_col not in df.columns or value_col not in df.columns:
        return {"error": "Insufficient data or invalid columns for anomaly detection."}

    anomalies = []
    for name, group in df.groupby(group_by_col):
        if len(group) < 5: # Need a minimum number of points to calculate IQR reliably
            continue

        Q1 = group[value_col].quantile(0.25)
        Q3 = group[value_col].quantile(0.75)
        IQR = Q3 - Q1

        lower_bound = Q1 - threshold * IQR
        upper_bound = Q3 + threshold * IQR

        # Find outliers in the current group
        group_anomalies = group[(group[value_col] < lower_bound) | (group[value_col] > upper_bound)]

        if not group_anomalies.empty:
            for index, row in group_anomalies.iterrows():
                anomaly_info = row.to_dict()
                anomaly_info['anomaly_reason'] = f"Amount {row[value_col]:.2f} outside IQR bounds [{lower_bound:.2f}, {upper_bound:.2f}] for category '{name}'"
                # Convert Timestamp/Period to string for JSON
                if 'date' in anomaly_info and isinstance(anomaly_info['date'], pd.Timestamp):
                    anomaly_info['date'] = anomaly_info['date'].strftime('%Y-%m-%d')
                if 'year_month' in anomaly_info and isinstance(anomaly_info['year_month'], pd.Period):
                     anomaly_info['year_month'] = str(anomaly_info['year_month'])
                anomalies.append(anomaly_info)

    return {'detected_anomalies': anomalies}

# --- Main Execution --- (Example Usage)
if __name__ == "__main__":
    results = {}
    try:
        print("Starting data fetching and preprocessing...")
        df_processed = fetch_and_preprocess_data(CRED_PATH, COLLECTION_NAME)

        if not df_processed.empty:
            print("Analyzing spending patterns...")
            spending_patterns = analyze_spending_patterns(df_processed)
            results['spending_patterns'] = spending_patterns

            print("Detecting anomalies...")
            anomalies = detect_anomalies_iqr(df_processed)
            results['anomalies'] = anomalies
        else:
             results['error'] = "No valid expense data found for analysis."

    except FileNotFoundError as e:
        print(f"Error: {e}")
        results['error'] = str(e)
    except ValueError as e:
        print(f"Data Error: {e}")
        results['error'] = f"Data Error: {e}"
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        results['error'] = f"An unexpected error occurred: {e}"

    # Output results as JSON
    output_path = 'ML/spending_analysis_results.json'
    print(f"
Saving results to {output_path}...")
    try:
        with open(output_path, 'w') as f:
            json.dump(results, f, indent=2, default=str) # Use default=str for any remaining non-serializable types
        print("Results saved successfully.")
    except Exception as e:
        print(f"Error saving results to JSON: {e}")
        # Fallback: Print results if saving fails
        # print("
--- Results --- (JSON saving failed)")
        # print(json.dumps(results, indent=2, default=str))


