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
        return {"text": self.text, "author": self.author, "date": date.today().strftime("%B %d, %Y"), "source": "custom"}

_db_initialized = False

def init_db():
    global _db_initialized
    if not _db_initialized:
        with app.app_context():
            db.create_all()
            if CustomQuote.query.count() == 0:
                db.session.add(CustomQuote(text="Every day is a new opportunity to make a positive impact.", author="Willard"))
                db.session.add(CustomQuote(text="Believe in yourself and amazing things will happen.", author="Willard"))
                db.session.commit()
        _db_initialized = True

def get_api_quote():
    try:
        r = requests.get("https://api.quotable.io/quotes/random", params={"limit": 50, "tags": "inspirational|motivational|wisdom"}, timeout=5, verify=False)
        r.raise_for_status()
        quotes = r.json()
        if quotes:
            q = random.choice(quotes)
            return {"text": q["content"], "author": q["author"], "date": date.today().strftime("%B %d, %Y"), "source": "api"}
    except:
        pass
    return None

def get_random_quote():
    init_db()
    custom_quotes = CustomQuote.query.all()
    if custom_quotes and random.random() < 0.5:
        return random.choice(custom_quotes).to_dict()
    api_quote = get_api_quote()
    if api_quote:
        return api_quote
    elif custom_quotes:
        return random.choice(custom_quotes).to_dict()
    return {"text": "The only way to do great work is to love what you do.", "author": "Steve Jobs", "date": date.today().strftime("%B %d, %Y"), "source": "fallback"}

def get_daily_quote():
    random.seed(int(date.today().strftime("%Y%m%d")))
    quote = get_random_quote()
    random.seed()
    return quote

@app.route('/')
def index():
    return render_template('index.html', quote=get_daily_quote())

@app.route('/api/random-quote')
def api_random_quote():
    return jsonify(get_random_quote())

@app.route('/admin')
def admin():
    init_db()
    return render_template('admin.html', quotes=CustomQuote.query.order_by(CustomQuote.id.desc()).all())

@app.route('/admin/add-quote', methods=['POST'])
def add_quote():
    init_db()
    text = request.form.get('text', '').strip()
    author = request.form.get('author', '').strip()
    if not text or not author:
        return "Error!", 400
    if len(text) > 500:
        return "Too long!", 400
    db.session.add(CustomQuote(text=text, author=author))
    db.session.commit()
    return redirect(url_for('admin'))

@app.route('/admin/delete-quote/<int:quote_id>', methods=['POST'])
def delete_quote(quote_id):
    q = CustomQuote.query.get_or_404(quote_id)
    db.session.delete(q)
    db.session.commit()
    return redirect(url_for('admin'))

if __name__ == '__main__':
    init_db()
    app.run(debug=os.environ.get('DEBUG')=='True', host='0.0.0.0', port=int(os.environ.get('PORT', 5000)))
