import firebase_admin
from firebase_admin import credentials, firestore
import pandas as pd
import numpy as np
from datetime import datetime
import json
import os
import warnings

# Suppress warnings if needed (e.g., future warnings from pandas)
warnings.simplefilter("ignore", FutureWarning)

# --- Configuration ---
CRED_PATH = "/home/ubuntu/firebase_credentials.json"
COLLECTION_NAME = "transactions"
# Configuration for savings suggestions
TOP_N_CATEGORIES = 5 # Number of top spending categories to highlight
COMPARISON_MONTHS = 3 # Number of previous months to average for comparison
INCREASE_THRESHOLD = 0.15 # Percentage increase threshold to flag (15%)
# Define potentially discretionary categories (example list, can be customized)
DISCRETIONARY_CATEGORIES = [
    "Restaurants", "Fast Food", "Entertainment", "Shopping", "Coffee Shops",
    "Hobbies", "Travel", "Gifts & Donations", "Personal Care", "Clothing"
]

# --- Helper Functions (Copied/Adapted) ---

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
    try:
        return float(value)
    except (ValueError, TypeError):
        return np.nan

def safe_date_conversion(value):
    try:
        return pd.to_datetime(value, format="%m/%d/%Y", errors="coerce")
    except (ValueError, TypeError):
        return pd.NaT

# --- Data Fetching and Preprocessing (Copied/Adapted) ---

def fetch_and_preprocess_data(cred_path, collection_name):
    """Fetches data from Firestore, preprocesses it, and returns a DataFrame."""
    initialize_firebase(cred_path)
    db = firestore.client()
    docs = db.collection(collection_name).stream()
    data = [doc.to_dict() for doc in docs]

    if not data:
        print("No documents found.")
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
        print("No expense transactions found.")
        return pd.DataFrame()

    df_expenses["amount"] = df_expenses["amount"].apply(safe_float_conversion)
    df_expenses["date"] = df_expenses["date"].apply(safe_date_conversion)
    df_expenses.dropna(subset=["amount", "date", "category"], inplace=True)
    df_expenses["category"] = df_expenses["category"].astype(str)
    df_expenses.sort_values("date", inplace=True)
    df_expenses["year_month"] = df_expenses["date"].dt.to_period("M")

    print(f"Preprocessing complete. {len(df_expenses)} valid expense transactions remaining.")
    return df_expenses

# --- Savings Suggestion Functions ---

def suggest_savings(df):
    """Generates savings suggestions based on spending patterns."""
    if df.empty:
        return {"error": "No data available for savings suggestions."}

    suggestions = []
    now = pd.Timestamp.now()
    current_month_period = now.to_period("M")
    last_month_period = current_month_period - 1

    # Ensure we have data for the last completed month
    if last_month_period not in df["year_month"].unique():
        suggestions.append({
            "type": "info",
            "message": f"Insufficient data for the most recent full month {last_month_period.strftime('%Y-%m')} to generate detailed savings suggestions." # Corrected f-string
        })
        # Still provide overall top categories if possible
        if not df.empty:
            total_spending = df["amount"].sum()
            category_spending = df.groupby("category")["amount"].sum().sort_values(ascending=False)
            top_categories = category_spending.head(TOP_N_CATEGORIES)
            suggestions.append({
                "type": "top_categories_overall",
                "message": f"Your overall top {TOP_N_CATEGORIES} spending categories are: {', '.join(top_categories.index.tolist())}. Reviewing these might reveal savings opportunities.",
                "details": top_categories.reset_index().to_dict(orient="records")
            })
        return {"savings_suggestions": suggestions}

    # 1. Identify Top Spending Categories (Last Month)
    last_month_df = df[df["year_month"] == last_month_period]
    if not last_month_df.empty:
        last_month_total = last_month_df["amount"].sum()
        category_spending_last_month = last_month_df.groupby("category")["amount"].sum().sort_values(ascending=False)
        top_categories_last_month = category_spending_last_month.head(TOP_N_CATEGORIES)

        suggestions.append({
            "type": "top_categories_last_month",
            "message": f"In {last_month_period.strftime('%B %Y')}, your top {len(top_categories_last_month)} spending categories were: {', '.join(top_categories_last_month.index.tolist())}. Consider reviewing these areas.", # Corrected f-string
            "details": top_categories_last_month.reset_index().to_dict(orient="records")
        })

        # Highlight discretionary spending within top categories
        top_discretionary = top_categories_last_month[top_categories_last_month.index.isin(DISCRETIONARY_CATEGORIES)]
        if not top_discretionary.empty:
             suggestions.append({
                "type": "top_discretionary",
                "message": f"Among your top spending areas last month, these are often considered discretionary: {', '.join(top_discretionary.index.tolist())}. Reducing spending here could lead to savings.",
                "details": top_discretionary.reset_index().to_dict(orient="records")
            })

    # 2. Compare Last Month vs. Previous Average
    comparison_start_period = last_month_period - COMPARISON_MONTHS
    comparison_df = df[(df["year_month"] >= comparison_start_period) & (df["year_month"] < last_month_period)]

    if not comparison_df.empty and not last_month_df.empty:
        avg_monthly_spending_prev = comparison_df.groupby(["year_month", "category"])["amount"].sum().unstack(fill_value=0).mean()
        category_spending_last_month_series = last_month_df.groupby("category")["amount"].sum()

        comparison = pd.DataFrame({
            "last_month": category_spending_last_month_series,
            "previous_avg": avg_monthly_spending_prev
        }).fillna(0)
        comparison["change"] = comparison["last_month"] - comparison["previous_avg"]
        comparison["pct_change"] = (comparison["change"] / comparison["previous_avg"])
        # Handle division by zero or NaN if avg was 0
        comparison["pct_change"].replace([np.inf, -np.inf], np.nan, inplace=True)
        comparison["pct_change"].fillna(0, inplace=True)

        # Identify significant increases
        significant_increases = comparison[(comparison["pct_change"] > INCREASE_THRESHOLD) & (comparison["last_month"] > 0)] # Ensure increase is meaningful
        significant_increases = significant_increases.sort_values("pct_change", ascending=False)

        if not significant_increases.empty:
            for category, row in significant_increases.iterrows():
                suggestions.append({
                    "type": "spending_increase",
                    "category": category,
                    "message": f"Spending in \"{category}\" increased by {row['pct_change']:.0%} last month compared to the previous {COMPARISON_MONTHS}-month average (spent {row['last_month']:.2f} vs avg {row['previous_avg']:.2f}).",
                    "last_month_amount": row["last_month"],
                    "previous_avg_amount": row["previous_avg"],
                    "percentage_increase": row["pct_change"]
                })

    # 3. (Optional) Identify Frequent Small Purchases (Example for 'Fast Food')
    # This requires more granular analysis, potentially looking at transaction counts
    fast_food_last_month = last_month_df[last_month_df["category"] == "Fast Food"]
    if len(fast_food_last_month) > 5: # Example threshold
        avg_amount = fast_food_last_month["amount"].mean()
        total_amount = fast_food_last_month["amount"].sum()
        suggestions.append({
            "type": "frequent_small_purchases",
            "category": "Fast Food",
            "message": f"You made {len(fast_food_last_month)} purchases in \"Fast Food\" last month, totaling {total_amount:.2f}. Even small amounts add up.",
            "count": len(fast_food_last_month),
            "total_amount": total_amount,
            "average_amount": avg_amount
        })

    if not suggestions:
         suggestions.append({"type": "info", "message": "No specific savings suggestions identified based on recent spending patterns."}) 

    return {"savings_suggestions": suggestions}

# --- Main Execution ---
if __name__ == "__main__":
    results = {}
    try:
        print("Starting data fetching and preprocessing for savings suggestions...")
        df_processed = fetch_and_preprocess_data(CRED_PATH, COLLECTION_NAME)

        if not df_processed.empty:
            print("Generating savings suggestions...")
            savings_results = suggest_savings(df_processed)
            results = savings_results
        else:
            results["error"] = "No valid expense data found for savings suggestions."

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
    output_path = "/home/ubuntu/savings_suggestions_results.json"
    print(f"\nSaving savings suggestions results to {output_path}...")
    try:
        with open(output_path, "w") as f:
            json.dump(results, f, indent=2, default=str)
        print("Savings suggestions results saved successfully.")
    except Exception as e:
        print(f"Error saving results to JSON: {e}")

