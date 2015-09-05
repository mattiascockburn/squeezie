#!/usr/bin/env python

from flask import Flask, jsonify, request, abort
app = Flask(__name__)

@app.route("/")
def hello():
  return "Hello World!"

if __name__ == "__main__":
  app.run(host='0.0.0.0', debug=True)
