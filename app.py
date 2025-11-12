"""

Willard's Quote of the Day - A Flask web application that displays

a random motivational quote each day using the Quotable.io API.

"""

from flask import Flask, render_template

import requests

from datetime import date

import random

 

app = Flask(__name__)

 

def get_daily_quote():

    """

    Fetch a random motivational quote from Quotable.io.

    Uses the current date as a seed to ensure the same quote appears all day.

    """

    try:

        # Use today's date as a seed for consistent daily quotes

        today = date.today()

        seed_value = int(today.strftime("%Y%m%d"))

        random.seed(seed_value)

 

        # Fetch multiple quotes and select one based on today's seed

        response = requests.get(

            "https://api.quotable.io/quotes/random",

            params={"limit": 50, "tags": "inspirational|motivational|wisdom"},

            timeout=5

        )

        response.raise_for_status()

        quotes = response.json()

 

        if quotes:

            # Select a quote based on today's seed

            selected_quote = random.choice(quotes)

            return {

                "text": selected_quote["content"],

                "author": selected_quote["author"],

                "date": today.strftime("%B %d, %Y")

            }

        else:

            return get_fallback_quote()

 

    except Exception as e:

        print(f"Error fetching quote: {e}")

        return get_fallback_quote()

 

def get_fallback_quote():

    """Return a fallback quote if the API is unavailable."""

    return {

        "text": "The only way to do great work is to love what you do.",

        "author": "Steve Jobs",

        "date": date.today().strftime("%B %d, %Y")

    }

 

@app.route('/')

def index():

    """Render the homepage with today's quote."""

    quote = get_daily_quote()

    return render_template('index.html', quote=quote)

 

if __name__ == '__main__':

    app.run(debug=True, host='0.0.0.0', port=5050)

