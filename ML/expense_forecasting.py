import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import numpy as np
from datetime import datetime
import json
import os
import warnings
from statsmodels.tsa.arima.model import ARIMA
from statsmodels.tools.sm_exceptions import ConvergenceWarning

# Suppress specific warnings from statsmodels
warnings.simplefilter("ignore", ConvergenceWarning)
warnings.simplefilter("ignore", UserWarning) # Often related to frequency inference

# --- Configuration ---
CRED_PATH = "/home/ubuntu/firebase_credentials.json" # Corrected line
COLLECTION_NAME = "transactions"
FORECAST_STEPS = 6 # Number of months to forecast
MIN_MONTHS_FOR_FORECAST = 24 # Minimum months of data required

# --- Helper Functions (Copied from spending_analysis.py for consistency) ---

def initialize_firebase(cred_path):
    """Initializes Firebase Admin SDK if not already initialized."""
    if not os.path.exists(cred_path):
        raise FileNotFoundError(f"Credentials file not found at {cred_path}")
    try:
        firebase_admin.get_app()
    except ValueError:
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
        return pd.to_datetime(value, format="%m/%d/%Y", errors="coerce")
    except (ValueError, TypeError):
        return pd.NaT

# --- Data Fetching and Preprocessing (Copied from spending_analysis.py) ---

def fetch_and_preprocess_data(cred_path, collection_name):
    """Fetches data from Firestore, preprocesses it, and returns a DataFrame."""
    initialize_firebase(cred_path)
    db = firestore.client()
    docs = db.collection(collection_name).stream()

    data = []
    for doc in docs:
        doc_data = doc.to_dict()
        doc_data["id"] = doc.id
        data.append(doc_data)

    if not data:
        print("No documents found in the collection.")
        return pd.DataFrame()

    df = pd.DataFrame(data)
    print(f"Fetched {len(df)} documents.")

    required_cols = ["isExpense", "amount", "date", "category"]
    if not all(col in df.columns for col in required_cols):
        missing = [col for col in required_cols if col not in df.columns]
        raise ValueError(f"Missing required columns: {missing}")

    df["isExpense"] = df["isExpense"].astype(str).str.lower().map({"true": True, "false": False, "1": True, "0": False}).fillna(False)
    df_expenses = df[df["isExpense"] == True].copy()
    print(f"Filtered down to {len(df_expenses)} expense transactions.")

    if df_expenses.empty:
        print("No expense transactions found after filtering.")
        return pd.DataFrame()

    df_expenses["amount"] = df_expenses["amount"].apply(safe_float_conversion)
    df_expenses["date"] = df_expenses["date"].apply(safe_date_conversion)

    original_len = len(df_expenses)
    df_expenses.dropna(subset=["amount", "date", "category"], inplace=True)
    if len(df_expenses) < original_len:
        print(f"Dropped {original_len - len(df_expenses)} rows due to missing/invalid amount, date, or category.")

    df_expenses["category"] = df_expenses["category"].astype(str)
    df_expenses.sort_values("date", inplace=True)

    print(f"Preprocessing complete. {len(df_expenses)} valid expense transactions remaining.")
    return df_expenses

# --- Forecasting Function ---

def forecast_expenses(df, steps=FORECAST_STEPS):
    """Forecasts future expenses using ARIMA model."""
    if df.empty:
        return {"error": "No data available for forecasting."}

    # Aggregate expenses by month
    # Ensure the index is DatetimeIndex and set frequency
    monthly_expenses = df.set_index("date")["amount"].resample("M").sum()

    if len(monthly_expenses) < MIN_MONTHS_FOR_FORECAST:
        return {"error": f"Insufficient data for forecasting. Need at least {MIN_MONTHS_FOR_FORECAST} months, but found {len(monthly_expenses)}."}

    print(f"Aggregated data into {len(monthly_expenses)} monthly periods for forecasting.")

    try:
        # Fit ARIMA model - Using a simple order (p=5, d=1, q=0) as a starting point.
        # A more robust approach would involve order selection (e.g., auto_arima).
        model = ARIMA(monthly_expenses, order=(5, 1, 0), freq="M")
        model_fit = model.fit()
        print("ARIMA model fitted successfully.")

        # Generate forecast
        forecast_result = model_fit.get_forecast(steps=steps)
        forecast_values = forecast_result.predicted_mean
        conf_int = forecast_result.conf_int(alpha=0.05) # 95% confidence interval

        # Format forecast output
        forecast_output = []
        for i in range(steps):
            forecast_date = forecast_values.index[i].strftime("%Y-%m")
            forecast_output.append({
                "month": forecast_date,
                "predicted_amount": forecast_values.iloc[i],
                "conf_int_lower": conf_int.iloc[i, 0],
                "conf_int_upper": conf_int.iloc[i, 1]
            })

        return {"forecast": forecast_output}

    except Exception as e:
        print(f"Error during forecasting: {e}")
        return {"error": f"Forecasting failed: {e}"}

# --- Main Execution ---
if __name__ == "__main__":
    results = {}
    try:
        print("Starting data fetching and preprocessing for forecasting...")
        df_processed = fetch_and_preprocess_data(CRED_PATH, COLLECTION_NAME)

        if not df_processed.empty:
            print("Forecasting future expenses...")
            forecast_results = forecast_expenses(df_processed)
            results = forecast_results # Store forecast results directly
        else:
            results["error"] = "No valid expense data found for forecasting."

    except FileNotFoundError as e:
        print(f"Error: {e}")
        results["error"] = str(e)
    except ValueError as e:
        print(f"Data Error: {e}")
        results["error"] = f"Data Error: {e}"
    except Exception as e:
        print(f"An unexpected error occurred: {e}")
        results["error"] = f"An unexpected error occurred: {e}"

    # Output results as JSON
    output_path = "ML/expense_forecast_results.json"
    print(f"
Saving forecast results to {output_path}...")
    try:
        with open(output_path, "w") as f:
            json.dump(results, f, indent=2, default=str)
        print("Forecast results saved successfully.")
    except Exception as e:
        print(f"Error saving results to JSON: {e}")

