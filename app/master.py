#!/usr/bin/env python

from flask import Flask, jsonify, request, abort, render_template
app = Flask(__name__)

@app.route("/",methods=['GET'])
def index():
  if request.method == 'GET':
    return render_template('index.html')
  else:
    abort(400)

@app.route("/devices",methods=['GET'])
def devices():
  if request.method == 'GET':
    return render_template('devices.html')
  else:
    abort(400)


if __name__ == "__main__":
  app.debug = True
  app.run(host='0.0.0.0')
