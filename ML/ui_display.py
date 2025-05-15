import streamlit as st
import json
import os
from datetime import datetime
import plotly.graph_objects as go
import plotly.express as px
import pandas as pd

# Constants
SAVINGS_SUGGESTIONS_FILE = "ML/savings_suggestions_results.json"
PERSONALIZED_TIPS_FILE = "ML/personalized_tips_results.json"
EXPENSE_FORECAST_FILE = "ML/expense_forecast_results.json"
SPENDING_ANALYSIS_FILE = "ML/spending_analysis_results.json"

def load_json_data(filepath):
    """Loads data from a JSON file."""
    if not os.path.exists(filepath):
        st.error(f"File not found: {filepath}")
        return None
    try:
        with open(filepath, "r") as f:
            return json.load(f)
    except Exception as e:
        st.error(f"Error loading file {filepath}: {e}")
        return None

def display_expense_forecast():
    """Displays expense forecasting results with interactive charts."""
    st.header("📈 Expense Forecast")
    
    data = load_json_data(EXPENSE_FORECAST_FILE)
    if not data or "forecast" not in data:
        st.warning("No expense forecast data available.")
        return

    forecast_data = data["forecast"]
    
    # Create a DataFrame for easier plotting
    df = pd.DataFrame(forecast_data)
    
    # Create the main forecast line chart
    fig = go.Figure()
    
    # Add the forecast line
    fig.add_trace(go.Scatter(
        x=df['month'],
        y=df['predicted_amount'],
        mode='lines+markers',
        name='Forecast',
        line=dict(color='#1f77b4', width=2)
    ))
    
    # Add confidence interval
    fig.add_trace(go.Scatter(
        x=df['month'],
        y=df['conf_int_upper'],
        mode='lines',
        name='Upper Bound',
        line=dict(width=0),
        showlegend=False
    ))
    
    fig.add_trace(go.Scatter(
        x=df['month'],
        y=df['conf_int_lower'],
        mode='lines',
        name='Lower Bound',
        line=dict(width=0),
        fill='tonexty',
        fillcolor='rgba(31, 119, 180, 0.2)',
        showlegend=False
    ))
    
    fig.update_layout(
        title='Expense Forecast with Confidence Intervals',
        xaxis_title='Month',
        yaxis_title='Predicted Amount',
        hovermode='x unified',
        height=400
    )
    
    st.plotly_chart(fig, use_container_width=True)
    
    # Display detailed forecast data in a table
    st.subheader("Detailed Forecast Data")
    st.dataframe(df.style.format({
        'predicted_amount': '${:.2f}',
        'conf_int_lower': '${:.2f}',
        'conf_int_upper': '${:.2f}'
    }))

def display_spending_analysis():
    """Displays spending analysis results with interactive visualizations."""
    st.header("📊 Spending Analysis")
    
    data = load_json_data(SPENDING_ANALYSIS_FILE)
    if not data:
        st.warning("No spending analysis data available.")
        return

    # Display spending patterns
    if "spending_patterns" in data:
        st.subheader("Spending Patterns")
        patterns = data["spending_patterns"]
        
        # Create tabs for different views
        tab1, tab2 = st.tabs(["Category Analysis", "Anomalies"])
        
        with tab1:
            if "spending_by_category" in patterns:
                # Create a bar chart for category spending
                df_categories = pd.DataFrame(patterns["spending_by_category"])
                fig = px.bar(
                    df_categories,
                    x='category',
                    y='sum',
                    title='Spending by Category',
                    labels={'sum': 'Total Amount', 'category': 'Category'},
                    color='sum',
                    color_continuous_scale='Viridis'
                )
                fig.update_layout(height=400)
                st.plotly_chart(fig, use_container_width=True)
        
        with tab2:
            if "anomalies" in data and "detected_anomalies" in data["anomalies"]:
                anomalies = data["anomalies"]["detected_anomalies"]
                if anomalies:
                    st.subheader("Detected Anomalies")
                    for anomaly in anomalies:
                        with st.expander(f"Anomaly on {anomaly.get('date', 'Unknown date')}"):
                            st.write(f"**Amount:** ${anomaly.get('amount', 'N/A')}")
                            st.write(f"**Category:** {anomaly.get('category', 'N/A')}")
                            st.write(f"**Reason:** {anomaly.get('anomaly_reason', 'N/A')}")

def display_savings_suggestions():
    """Displays savings suggestions in a modern card-based layout."""
    st.header("💰 Savings Suggestions")
    
    data = load_json_data(SAVINGS_SUGGESTIONS_FILE)
    if not data or "savings_suggestions" not in data:
        st.warning("No savings suggestions available.")
        return

    suggestions = data["savings_suggestions"]
    
    # Create columns for the layout
    col1, col2 = st.columns(2)
    
    for i, suggestion in enumerate(suggestions):
        # Determine which column to use
        col = col1 if i % 2 == 0 else col2
        
        with col:
            # Create a card-like container
            with st.container():
                # Style the container
                st.markdown("""
                    <style>
                    .suggestion-card {
                        background-color: #ffffff;
                        border-radius: 10px;
                        padding: 20px;
                        margin: 10px 0;
                        box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
                    }
                    </style>
                """, unsafe_allow_html=True)
                
                # Add card content
                st.markdown(f'<div class="suggestion-card">', unsafe_allow_html=True)
                
                # Add icon based on suggestion type
                icon = "📊" if suggestion["type"] == "top_categories_last_month" else \
                       "⚠️" if suggestion["type"] == "spending_increase" else \
                       "💡" if suggestion["type"] == "top_discretionary" else \
                       "📝" if suggestion["type"] == "frequent_small_purchases" else "ℹ️"
                
                st.markdown(f"### {icon} {suggestion['type'].replace('_', ' ').title()}")
                
                # Display the message
                st.write(suggestion["message"])
                
                # Add visualizations for specific suggestion types
                if suggestion["type"] == "spending_increase" and "last_month_amount" in suggestion:
                    # Create a bar chart comparing last month vs previous average
                    fig = go.Figure(data=[
                        go.Bar(name='Last Month', x=['Amount'], y=[suggestion['last_month_amount']], marker_color='#FF9999'),
                        go.Bar(name='Previous Average', x=['Amount'], y=[suggestion['previous_avg_amount']], marker_color='#66B2FF')
                    ])
                    fig.update_layout(
                        title=f"Spending Comparison for {suggestion['category']}",
                        barmode='group',
                        height=200,
                        margin=dict(l=20, r=20, t=40, b=20)
                    )
                    st.plotly_chart(fig, use_container_width=True)
                
                elif suggestion["type"] == "frequent_small_purchases":
                    # Create a pie chart for the frequent purchases
                    labels = ['Total Amount', 'Average per Purchase']
                    values = [suggestion['total_amount'], suggestion['average_amount']]
                    fig = go.Figure(data=[go.Pie(labels=labels, values=values, hole=.3)])
                    fig.update_layout(
                        title=f"Purchase Analysis for {suggestion['category']}",
                        height=200,
                        margin=dict(l=20, r=20, t=40, b=20)
                    )
                    st.plotly_chart(fig, use_container_width=True)
                
                st.markdown('</div>', unsafe_allow_html=True)

def display_personalized_tips():
    """Displays personalized tips in a modern, interactive format."""
    st.header("🎯 Personalized Tips")
    
    data = load_json_data(PERSONALIZED_TIPS_FILE)
    if not data or "personalized_tips" not in data:
        st.warning("No personalized tips available.")
        return

    tips = data["personalized_tips"]
    
    # Create a container for tips
    with st.container():
        for tip in tips:
            # Determine the color based on severity
            color = "#FF9999" if tip["severity"] == "warning" else "#66B2FF" if tip["severity"] == "info" else "#99FF99"
            
            # Create an expandable section for each tip
            with st.expander(f"💡 {tip['type'].replace('_', ' ').title()}", expanded=True):
                # Style the tip content
                st.markdown(f"""
                    <style>
                    .tip-content {{
                        background-color: {color}20;
                        border-left: 4px solid {color};
                        padding: 10px;
                        border-radius: 4px;
                        margin: 10px 0;
                    }}
                    </style>
                    <div class="tip-content">
                        {tip['message']}
                    </div>
                """, unsafe_allow_html=True)

def main():
    """Main function to run the Streamlit app."""
    st.set_page_config(
        page_title="Financial Insights Dashboard",
        page_icon="💰",
        layout="wide"
    )
    
    st.title("Financial Insights Dashboard")
    
    # Add a sidebar for navigation
    st.sidebar.title("Navigation")
    page = st.sidebar.radio("Go to", [
        "Spending Analysis",
        "Expense Forecast",
        "Savings Suggestions",
        "Personalized Tips"
    ])
    
    if page == "Spending Analysis":
        display_spending_analysis()
    elif page == "Expense Forecast":
        display_expense_forecast()
    elif page == "Savings Suggestions":
        display_savings_suggestions()
    else:
        display_personalized_tips()

if __name__ == "__main__":
    main() 