from flask import Flask, render_template, request
import pymysql
import plotly.graph_objects as go
import pandas as pd
import scipy
import os
from datetime import datetime, timedelta

app = Flask(__name__)

def get_weather_data(days=3):
    end = datetime.now()
    start = end - timedelta(days=days)

    db_host = os.getenv("WEATHER_DB_HOST", "mariadb")
    db_name = os.getenv("WEATHER_DB_NAME", "WeatherData")
    db_user = os.getenv("WEATHER_DB_USER", "root")
    db_password = os.getenv("WEATHER_DB_PASSWORD", "")
    db_port = int(os.getenv("WEATHER_DB_PORT", "3306"))

    conn = pymysql.connect(
        host=db_host,
        database=db_name,
        user=db_user,
        password=db_password,
        port=db_port
    )
    query = """
    SELECT
        ROUND(Temperature,1) as Temperature,
        0.01*Pressure as Pressure,
        Humidity,
        DateTime
    FROM weather
    WHERE DateTime BETWEEN %s AND %s
    ORDER BY DateTime
    """
    df = pd.read_sql(query, conn, params=(start, end))
    conn.close()
    return df

@app.route("/", methods=["GET", "POST"])
def dashboard():
    days = int(request.form.get("days", 3))  # Default: 3 days
    df = get_weather_data(days)
    if df.empty:
        return "No data for the selected range."

    # Apply a gaussian filter
    df["HumidityFiltered"]= df["Humidity"].rolling(window=20, win_type='gaussian').mean(std=8)
    df["PressureFiltered"]= df["Pressure"].rolling(window=20, win_type='gaussian').mean(std=8)
    df["TemperatureFiltered"]= df["Temperature"].rolling(window=20, win_type='gaussian').mean(std=8)
    latest = df.iloc[-1]

    # Create multi-line chart with stacked Y-axes
    fig = go.Figure()
    fig.add_trace(go.Scatter(x=df["DateTime"], y=df["TemperatureFiltered"], name="Temperature (°C)", line=dict(color="red")))
    fig.add_trace(go.Scatter(x=df["DateTime"], y=df["HumidityFiltered"], name="Humidity (%)", line=dict(color="green")))
    fig.add_trace(go.Scatter(x=df["DateTime"], y=df["PressureFiltered"], name="Pressure (hPa)", line=dict(color="blue")))

    fig.update_layout(
        xaxis=dict(
            domain=[0.05, 0.95],
            tickangle=45,
            tickfont=dict(size=12),
            title="Date & Time",
            anchor="y3",  # Anchor x-axis to the bottom Y-axis
            linewidth=1,
            mirror=True,
        ),
        yaxis=dict(
            title="Temperature (°C)",
            side="left",
            position=0.05,
            domain=[0.66, 1],  # Top 40% of the plot
            showline=True,
            linewidth=1,
            mirror=True,
        ),
        yaxis2=dict(
            title="Humidity (%)",
            side="left",
            position=0.05,
            domain=[0.33, 0.65],  # Middle 25% of the plot
            showline=True,
            linewidth=1,
            mirror=True,
        ),
        yaxis3=dict(
            title="Pressure (hPa)",
            side="left",
            position=0.05,
            domain=[0, 0.32],  # Bottom 25% of the plot
            showline=True,
            linewidth=2,
            mirror=True,
        ),
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
        template="plotly",
        height=800,
        margin=dict(l=5, r=1, t=10, b=1),
    )


    # Assign traces to Y-axes
    fig.update_traces(yaxis="y1", selector=dict(name="Temperature (°C)"))
    fig.update_traces(yaxis="y2", selector=dict(name="Humidity (%)"))
    fig.update_traces(yaxis="y3", selector=dict(name="Pressure (hPa)"))

    plot_html = fig.to_html(full_html=False)

    return render_template(
        "dashboard.html",
        plot=plot_html,
        temp=latest["Temperature"],
        hum=latest["Humidity"],
        press=latest["Pressure"],
        time=latest["DateTime"],
        days=days
    )

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

