import os
import tensorflow as tf
from tensorflow.keras.models import load_model
from tensorflow.keras.preprocessing import image as img
from tensorflow.keras.preprocessing.image import img_to_array
from tensorflow.keras import backend as k
import numpy as np
from PIL import Image
from tensorflow.keras.applications.resnet50 import ResNet50, decode_predictions, preprocess_input
import io
from flask import Flask , request , jsonify
from trash_new import prediction
from werkzeug.utils import secure_filename
import time


app = Flask(__name__)

@app.route('/predict' , methods=['POST'])
def predict():
    if request.method == 'POST':
        image_file = request.files['file']
        path = os.path.join(os.getcwd() + image_file.filename)
        path = secure_filename(path)
        #path = os.getcwd() + '/' + image_file.filename
        #print(image_file.filename)
        #path = path.replace('\\','/')
        image_file.save(path)
        time.sleep(0.001)
        classes = prediction(path)

    return jsonify({
            "status" : "Success" ,
            "class" : classes
        })

if __name__ == '__main__':
    app.run(debug=True, host = '127.0.0.1' , port = 5000)
