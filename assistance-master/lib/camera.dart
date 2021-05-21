import "package:path/path.dart";
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:async/async.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;

class CameraScreen extends StatefulWidget {
  @override
  _CameraScreenState createState() => _CameraScreenState();
}

enum TtsState { playing, stopped }

class _CameraScreenState extends State<CameraScreen> {
  double volume = 1.0;
  double pitch = 1.0;
  double rate = 0.8;
  FlutterTts flutterTts;
  CameraController cameraController;
  List cameras;
  int selectedCameraIndex;
  String imgPath, display = "loading...";
  File image;
  int stop = 0;
  var response;
  int i = 0;
  TtsState ttsState = TtsState.stopped;
  get isPlaying => ttsState == TtsState.playing;
  get isStopped => ttsState == TtsState.stopped;

  void onCapture() async {
    try {
      i = i+1;
      final p = await getTemporaryDirectory();
      final path = "${p.path}/${DateTime.now().toString()}.jpg";
      await cameraController.takePicture(path);
      setState(() {
        image = File(path);
      });
      print(path);
      //TODO send request to backend
      await sendReq(image);
      //TODO call a function for audio output
      await _speak(display);
      Timer(Duration(seconds: 10), () {
        onCapture();
      });
    } catch (e) {
      showCameraException(e);
    }
  }

//TODO request for backend
  Future<void> sendReq(File image) async {
    var stream = new http.ByteStream(DelegatingStream.typed(image.openRead()));
    var length = await image.length();
    var uri = Uri.parse("http://10.0.2.2:5000/predict"); //url for call
    print(uri);
    var request = http.MultipartRequest("POST", uri);
    var multipartFile = http.MultipartFile('file', stream, length,
        filename: basename(image.path));
    request.files.add(multipartFile);
    var res = await request.send();
    response = await http.Response.fromStream(res);
    final decoded = json.decode(response.body) as Map<String, dynamic>;
    setState(() {
      display = decoded["class"];
    });
    print(display);
  }

  Future initCamera(CameraDescription cameraDescription) async {
    if (cameraController != null) {
      await cameraController.dispose();
    }
    cameraController =
        CameraController(cameraDescription, ResolutionPreset.high);
    cameraController.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    if (cameraController.value.hasError) {
      print('Camera Error ${cameraController.value.errorDescription}');
    }
    try {
      await cameraController.initialize();
    } catch (e) {
      showCameraException(e);
    }
    if (mounted) {
      setState(() {});
    }
  }

  _speak(String text) async {
    print('text is ' + text);
    await flutterTts.setVolume(1);
    print('Successfully passed 1st await');
    await flutterTts.setSpeechRate(0.8);
    await flutterTts.setPitch(1);
    await flutterTts.setLanguage('en-US');
    if (text != null) {
      if (text.isNotEmpty) {
        var result = await flutterTts.speak(text);
        print(result);
        if (result == 1) setState(() => ttsState = TtsState.playing);
      }
    }
  }

  /// Display camera preview
  Widget cameraPreview(context) {
    if (cameraController == null || !cameraController.value.isInitialized) {
      return Text(
        'Loading',
        style: TextStyle(
            color: Colors.white, fontSize: 20.0, fontWeight: FontWeight.bold),
      );
    }
    final size = MediaQuery.of(context).size;
    final deviceRatio = size.width / size.height;
    final xScale = cameraController.value.aspectRatio / deviceRatio;
    // Modify the yScale if you are in Landscape
    final yScale = 1.0;
    return Container(
      child: AspectRatio(
        aspectRatio: deviceRatio,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.diagonal3Values(xScale, yScale, 1),
          child: CameraPreview(cameraController),
        ),
      ),
    );
  }
  Future _stop() async {
    var result = await flutterTts.stop();
    if (result == 1) setState(() => ttsState = TtsState.stopped);
  }


  Future initTts() async {
    flutterTts = FlutterTts();
    print('inside initTTS');
    flutterTts.setStartHandler(() {
      setState(() {
        print("Playing");
        ttsState = TtsState.playing;
      });
    });
    flutterTts.setCompletionHandler(() {
      setState(() {
        print("Complete");
        ttsState = TtsState.stopped;
      });
    });
    flutterTts.setErrorHandler((msg) {
      setState(() {
        print("error: $msg");
        ttsState = TtsState.stopped;
      });
    });
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    flutterTts.stop();
  }

  @override
  void initState() {
    super.initState();
    initTts();
    availableCameras().then((value) {
      cameras = value;
      if (cameras.length > 0) {
        setState(() {
          selectedCameraIndex = 0;
        });
        initCamera(cameras[selectedCameraIndex]).then((value) {
          onCapture();
        });
      } else {
        print('No camera available');
      }
    }).catchError((e) {
      print('Error : ${e.code}');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
          child: Align(
            alignment: Alignment.center,
            child: cameraPreview(context),
          )),
    );
  }

  showCameraException(e) {
    String errorText = 'Error ${e.code} \nError message: ${e.description}';
  }
}
