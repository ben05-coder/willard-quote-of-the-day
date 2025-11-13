#!/bin/bash
set -e

echo "🚀 Deploying all new features..."

# 1. Update app.py
cat > app.py << 'ENDAPP'
from flask import Flask, render_template, request, jsonify, redirect, url_for
from flask_sqlalchemy import SQLAlchemy
import requests
from datetime import date
import random
import urllib3
import os

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///quotes.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
db = SQLAlchemy(app)

class CustomQuote(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    text = db.Column(db.String(500), nullable=False)
    author = db.Column(db.String(100), nullable=False)
    added_date = db.Column(db.String(20), default=date.today().strftime("%Y-%m-%d"))

    def to_dict(self):
        return {
            "text": self.text,
            "author": self.author,
            "date": date.today().strftime("%B %d, %Y"),
            "source": "custom"
        }

def init_db():
    with app.app_context():
        db.create_all()
        if CustomQuote.query.count() == 0:
            starter_quotes = [
                CustomQuote(text="Every day is a new opportunity to make a positive impact.", author="Willard"),
                CustomQuote(text="Believe in yourself and amazing things will happen.", author="Willard"),
            ]
            for quote in starter_quotes:
                db.session.add(quote)
            db.session.commit()

def get_api_quote():
    try:
        response = requests.get(
            "https://api.quotable.io/quotes/random",
            params={"limit": 50, "tags": "inspirational|motivational|wisdom"},
            timeout=5,
            verify=False
        )
        response.raise_for_status()
        quotes = response.json()
        if quotes:
            selected_quote = random.choice(quotes)
            return {
                "text": selected_quote["content"],
                "author": selected_quote["author"],
                "date": date.today().strftime("%B %d, %Y"),
                "source": "api"
            }
    except Exception as e:
        print(f"Error fetching API quote: {e}")
    return None

def get_random_quote():
    custom_quotes = CustomQuote.query.all()
    if custom_quotes and random.random() < 0.5:
        quote = random.choice(custom_quotes)
        return quote.to_dict()
    else:
        api_quote = get_api_quote()
        if api_quote:
            return api_quote
        elif custom_quotes:
            quote = random.choice(custom_quotes)
            return quote.to_dict()
        else:
            return {
                "text": "The only way to do great work is to love what you do.",
                "author": "Steve Jobs",
                "date": date.today().strftime("%B %d, %Y"),
                "source": "fallback"
            }

def get_daily_quote():
    today = date.today()
    seed_value = int(today.strftime("%Y%m%d"))
    random.seed(seed_value)
    quote = get_random_quote()
    random.seed()
    return quote

@app.route('/')
def index():
    quote = get_daily_quote()
    return render_template('index.html', quote=quote)

@app.route('/api/random-quote')
def api_random_quote():
    quote = get_random_quote()
    return jsonify(quote)

@app.route('/admin')
def admin():
    custom_quotes = CustomQuote.query.order_by(CustomQuote.id.desc()).all()
    return render_template('admin.html', quotes=custom_quotes)

@app.route('/admin/add-quote', methods=['POST'])
def add_quote():
    text = request.form.get('text', '').strip()
    author = request.form.get('author', '').strip()
    if not text or not author:
        return "Error: Both quote text and author are required!", 400
    if len(text) > 500:
        return "Error: Quote text too long (max 500 characters)", 400
    new_quote = CustomQuote(text=text, author=author)
    db.session.add(new_quote)
    db.session.commit()
    return redirect(url_for('admin'))

@app.route('/admin/delete-quote/<int:quote_id>', methods=['POST'])
def delete_quote(quote_id):
    quote = CustomQuote.query.get_or_404(quote_id)
    db.session.delete(quote)
    db.session.commit()
    return redirect(url_for('admin'))

if __name__ == '__main__':
    init_db()
    port = int(os.environ.get('PORT', 5000))
    debug = os.environ.get('DEBUG', 'False') == 'True'
    app.run(debug=debug, host='0.0.0.0', port=port)
ENDAPP

# 2. Update requirements.txt
echo "Flask==3.0.0
requests==2.31.0
gunicorn==21.2.0
Flask-SQLAlchemy==3.1.1" > requirements.txt

# 3. Create .gitignore
echo "*.db
*.sqlite
__pycache__/" > .gitignore

# 4. Create admin.html
cat > templates/admin.html << 'ENDADMIN'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin - Willard's Quotes</title>
    <style>
        body { font-family: Arial, sans-serif; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); min-height: 100vh; padding: 20px; }
        .container { max-width: 800px; margin: 0 auto; background: white; border-radius: 20px; padding: 40px; }
        h1 { color: #667eea; text-align: center; }
        .back-link { display: block; text-align: center; margin-bottom: 30px; color: #667eea; }
        .form-group { margin-bottom: 20px; }
        label { display: block; margin-bottom: 5px; font-weight: bold; }
        textarea, input { width: 100%; padding: 10px; border: 2px solid #ddd; border-radius: 8px; font-size: 16px; }
        textarea { min-height: 100px; resize: vertical; }
        button { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; border: none; padding: 15px 30px; border-radius: 50px; cursor: pointer; font-size: 16px; font-weight: bold; }
        button:hover { transform: translateY(-2px); box-shadow: 0 10px 20px rgba(0,0,0,0.2); }
        .quote-item { border-bottom: 1px solid #eee; padding: 20px 0; }
        .quote-text { font-size: 18px; font-style: italic; margin-bottom: 10px; }
        .quote-author { color: #667eea; font-weight: bold; }
        .delete-btn { background: #e53e3e; padding: 8px 16px; font-size: 14px; margin-top: 10px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📝 Manage Willard's Quotes</h1>
        <a href="/" class="back-link">← Back to Home</a>
        
        <h2>Add New Quote</h2>
        <form method="POST" action="/admin/add-quote">
            <div class="form-group">
                <label>Quote Text *</label>
                <textarea name="text" required maxlength="500"></textarea>
            </div>
            <div class="form-group">
                <label>Author *</label>
                <input type="text" name="author" required maxlength="100" />
            </div>
            <button type="submit">Add Quote</button>
        </form>
        
        <h2 style="margin-top: 40px;">Your Custom Quotes ({{ quotes|length }})</h2>
        {% if quotes %}
            {% for quote in quotes %}
            <div class="quote-item">
                <div class="quote-text">"{{ quote.text }}"</div>
                <div class="quote-author">— {{ quote.author }}</div>
                <div style="font-size: 12px; color: #999;">Added: {{ quote.added_date }}</div>
                <form method="POST" action="/admin/delete-quote/{{ quote.id }}" style="display: inline;">
                    <button type="submit" class="delete-btn" onclick="return confirm('Delete this quote?');">Delete</button>
                </form>
            </div>
            {% endfor %}
        {% else %}
            <p style="text-align: center; color: #999; font-style: italic;">No custom quotes yet. Add your first one above!</p>
        {% endif %}
    </div>
</body>
</html>
ENDADMIN

echo "✅ Files updated!"
echo ""
echo "📦 Committing and pushing..."
git add -A
git commit -m "Add database, admin panel, and New Quote button"
git push origin main

echo ""
echo "🎉 DONE! Render will deploy in 1-2 minutes."
echo "Visit: https://willard-quote-of-the-day.onrender.com/admin"
