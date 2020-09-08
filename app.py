import os

from flask import Flask
from flask_httpauth import HTTPTokenAuth

if os.getenv('APP_SECRET_TOKEN') is None:
    raise EnvironmentError("Failed because APP_SECRET_TOKEN is not set.")

app = Flask(__name__)
auth = HTTPTokenAuth("Token")

@app.route("/health", methods=["GET"])
def health_check():
    return ""

@auth.verify_token
def verify_token(token):
    return token == os.getenv("APP_SECRET_TOKEN")

@app.route("/", methods=["GET"])
@auth.login_required
def home():
    return {
        "message": "DevOps test server is flying!!"
    }

app.run("0.0.0.0", port=8000)
