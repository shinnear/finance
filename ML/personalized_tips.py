import json
import os
import random

# --- Configuration ---
SPENDING_ANALYSIS_FILE = "ML/spending_analysis_results.json"
FORECAST_FILE = "ML/expense_forecast_results.json"
SAVINGS_SUGGESTIONS_FILE = "ML/savings_suggestions_results.json"
OUTPUT_FILE = "ML/personalized_tips_results.json"

# --- Helper Function ---
def load_json_data(filepath):
    """Loads data from a JSON file, returning None if file not found or invalid."""
    if not os.path.exists(filepath):
        print(f"Warning: Input file not found: {filepath}")
        return None
    try:
        with open(filepath, "r") as f:
            data = json.load(f)
        # Check for top-level error keys
        if isinstance(data, dict) and "error" in data:
             print(f"Warning: Input file {filepath} contains an error: {data['error']}")
             return None
        return data
    except json.JSONDecodeError:
        print(f"Warning: Could not decode JSON from file: {filepath}")
        return None
    except Exception as e:
        print(f"Warning: Error loading file {filepath}: {e}")
        return None

# --- Tip Generation Logic ---
def generate_tips(spending_data, forecast_data, savings_data):
    """Generates personalized tips based on analysis results."""
    tips = []

    # --- Tips based on Spending Patterns & Anomalies ---
    if spending_data and "spending_patterns" in spending_data:
        patterns = spending_data["spending_patterns"]
        if "spending_by_category" in patterns and patterns["spending_by_category"]:
            top_category = patterns["spending_by_category"][0]["category"]
            top_amount = patterns["spending_by_category"][0]["sum"]
            tips.append({
                "type": "top_spending_category",
                "severity": "info",
                "message": f'Your highest spending category overall is "{top_category}" (${top_amount:.2f} total). Regularly reviewing expenses here might reveal savings opportunities.'
            })

            # Add more pattern-based tips here (e.g., trend analysis if implemented)

    if spending_data and "anomalies" in spending_data and "detected_anomalies" in spending_data["anomalies"]:
        anomalies = spending_data["anomalies"]["detected_anomalies"]
        if anomalies:
            # Select one anomaly to highlight to avoid overwhelming the user
            anomaly = random.choice(anomalies)
            tips.append({
                "type": "anomaly_detected",
                "severity": "warning",
                "message": f'We noticed an unusual transaction: ${anomaly.get("amount", "N/A"):.2f} in "{anomaly.get("category", "N/A")}" around {anomaly.get("date", "N/A")}. Was this expected? {anomaly.get("anomaly_reason", "")}'
            })

    # --- Tips based on Forecasts ---
    if forecast_data and "forecast" in forecast_data and forecast_data["forecast"]:
        first_forecast_month = forecast_data["forecast"][0]
        # Basic check: Compare first forecast month to last historical month if available
        # (Requires loading historical monthly data - simplified for now)
        # Simple forecast tip:
        tips.append({
            "type": "forecast_info",
            "severity": "info",
            "message": f'Looking ahead, we forecast expenses around ${first_forecast_month["predicted_amount"]:.2f} for {first_forecast_month["month"]}. Keep this in mind for your budget.'
        })
        # Add more sophisticated forecast tips (e.g., comparing trend)

    # --- Tips based on Savings Suggestions ---
    if savings_data and "savings_suggestions" in savings_data:
        suggestions = savings_data["savings_suggestions"]
        # Prioritize certain suggestion types
        increase_suggestions = [s for s in suggestions if s.get("type") == "spending_increase"]
        discretionary_suggestions = [s for s in suggestions if s.get("type") == "top_discretionary"]
        frequent_suggestions = [s for s in suggestions if s.get("type") == "frequent_small_purchases"]

        if increase_suggestions:
            # Highlight the largest percentage increase
            increase_suggestions.sort(key=lambda x: x.get("percentage_increase", 0), reverse=True)
            top_increase = increase_suggestions[0]
            tips.append({
                "type": "spending_increase_tip",
                "severity": "warning",
                "message": f'Focus on "{top_increase["category"]}": spending here jumped {top_increase["percentage_increase"]:.0%} last month compared to your average. Review recent purchases in this category.'
            })
        elif discretionary_suggestions:
            # Suggest reviewing top discretionary category
            top_disc = discretionary_suggestions[0]["details"][0]["category"]
            tips.append({
                "type": "discretionary_spending_tip",
                "severity": "info",
                "message": f'Your spending on discretionary items like "{top_disc}" was significant last month. This is often a good area to find potential savings.'
            })
        elif frequent_suggestions:
            freq_sugg = frequent_suggestions[0]
            tips.append({
                "type": "frequent_purchases_tip",
                "severity": "info",
                "message": f'Those frequent small purchases in "{freq_sugg["category"]}" ({freq_sugg["count"]} times last month) add up! Consider if you can cut back slightly.'
            })
        elif suggestions: # Generic fallback if specific types aren't present but others are
             generic_sugg = suggestions[0]
             if generic_sugg.get("type") == "top_categories_last_month":
                 tips.append({
                     "type": "general_review_tip",
                     "severity": "info",
                     "message": f'Reviewing your top spending categories from last month, like "{generic_sugg["details"][0]["category"]}", is a good starting point for managing your budget.'
                 })

    # --- General Encouragement/Default Tip ---
    if not tips:
        tips.append({
            "type": "general_encouragement",
            "severity": "info",
            "message": "Keep tracking your expenses to stay on top of your finances!"
        })
    # Limit number of tips shown at once?
    # max_tips = 3
    # if len(tips) > max_tips:
    #     tips = random.sample(tips, max_tips)

    return {"personalized_tips": tips}

# --- Main Execution ---
if __name__ == "__main__":
    print("Loading analysis results...")
    spending_results = load_json_data(SPENDING_ANALYSIS_FILE)
    forecast_results = load_json_data(FORECAST_FILE)
    savings_results = load_json_data(SAVINGS_SUGGESTIONS_FILE)

    print("Generating personalized tips...")
    final_tips = generate_tips(spending_results, forecast_results, savings_results)

    # Output results as JSON
    print(f"Saving personalized tips to {OUTPUT_FILE}...")
    try:
        with open(OUTPUT_FILE, "w") as f:
            json.dump(final_tips, f, indent=2, default=str)
        print("Personalized tips saved successfully.")
    except Exception as e:
        print(f"Error saving results to JSON: {e}")

