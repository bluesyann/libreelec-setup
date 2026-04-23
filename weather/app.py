from flask import Flask, jsonify, render_template, request
import pymysql
import plotly.graph_objects as go
import pandas as pd
import scipy
import os
import subprocess
from datetime import datetime, timedelta

app = Flask(__name__)

def get_weather_data(days=3):
    end = datetime.now()
    start = end - timedelta(days=days)

    conn = pymysql.connect(
        host="@@WEATHER_DB_HOST@@",
        database="@@WEATHER_DB_NAME@@",
        user="@@WEATHER_DB_USER@@",
        password="@@WEATHER_DB_PASSWORD@@",
        port=int("@@WEATHER_DB_PORT@@"),
        connect_timeout=3,
        read_timeout=5,
        write_timeout=5,
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

    with conn.cursor() as cursor:
        cursor.execute(query, (start, end))
        rows = cursor.fetchall()
        columns = [column[0] for column in cursor.description]

    conn.close()
    df = pd.DataFrame(rows, columns=columns)
    return df

@app.route("/", methods=["GET", "POST"])
def dashboard():
    try:
        days = int(request.form.get("days", 3))  # Default: 3 days
    except ValueError:
        days = 3

    try:
        df = get_weather_data(days)
    except pymysql.MySQLError as exc:
        app.logger.warning("MariaDB unavailable: %s", exc)
        return render_template(
            "dashboard.html",
            plot="",
            temp="-",
            hum="-",
            press="-",
            time="-",
            days=days,
            db_error="Database not ready yet. Please retry in a few seconds.",
        ), 503

    if df.empty:
        return render_template(
            "dashboard.html",
            plot="",
            temp="-",
            hum="-",
            press="-",
            time="-",
            days=days,
            db_error="No weather data for the selected range.",
        )

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


@app.route("/reboot", methods=["POST"])
def reboot_board():
    trigger_path = "/data/reboot_trigger"

    # Always write a trigger file so host-side automation can reboot reliably.
    if trigger_path:
        try:
            trigger_dir = os.path.dirname(trigger_path)
            if trigger_dir:
                os.makedirs(trigger_dir, exist_ok=True)
            with open(trigger_path, "w", encoding="utf-8") as trigger_file:
                trigger_file.write("1\n")
                return jsonify({"status": "queued", "message": "Reboot trigger file written"}), 202
        except OSError as exc:
            app.logger.error("Failed to write reboot trigger '%s': %s", trigger_path, exc)
            return jsonify({"status": "error", "message": "Trigger file not written"}), 500
    else:
        return jsonify({"status": "error", "message": "Trigger file path undefined"}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

