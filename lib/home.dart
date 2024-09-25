import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  CameraImage? cameraImage;
  CameraController? cameraController;
  List<CameraDescription>? cameras;
  String output = '';
  File? selectedImage;
  bool isModelLoading = true;

  @override
  void initState() {
    super.initState();
    loadCameras();
    loadModel();
  }

  Future<void> loadCameras() async {
    await Permission.camera.request();
    if (await Permission.camera.isGranted) {
      cameras = await availableCameras();
      if (cameras!.isNotEmpty) {
        loadCamera(cameras![0]);
      } else {
        showError("No cameras available");
      }
    } else {
      showError("Camera permission denied. Please enable it in settings.");
    }
  }

  Future<void> loadCamera(CameraDescription camera) async {
    try {
      cameraController = CameraController(camera, ResolutionPreset.medium);
      await cameraController!.initialize();
      if (!mounted) return;

      setState(() {
        cameraController!.startImageStream((imageStream) {
          cameraImage = imageStream;
          runModel();
        });
      });
    } catch (e) {
      showError("Error initializing camera: $e");
    }
  }

  Future<void> runModel() async {
    if (cameraImage != null) {
      var predictions = await Tflite.runModelOnFrame(
        bytesList: cameraImage!.planes.map((plane) {
          return plane.bytes;
        }).toList(),
        imageHeight: cameraImage!.height,
        imageWidth: cameraImage!.width,
        imageMean: 127.5,
        imageStd: 127.5,
        rotation: 90,
        numResults: 2,
        threshold: 0.1,
      );

      if (predictions != null && predictions.isNotEmpty) {
        setState(() {
          output = predictions.map((p) => p['label']).join(', ');
        });
      }
    }
  }

  Future<void> loadModel() async {
    setState(() {
      isModelLoading = true;
    });

    await Tflite.loadModel(
      model: "assets/model.tflite",
      labels: "assets/labels.txt",
    );

    setState(() {
      isModelLoading = false;
    });
  }

  Future<void> takePhoto() async {
    try {
      final image = await cameraController!.takePicture();
      setState(() {
        selectedImage = File(image.path);
        runModelOnImage(selectedImage!);
      });
    } catch (e) {
      showError("Error taking photo: $e");
    }
  }

  Future<void> runModelOnImage(File imageFile) async {
    var predictions = await Tflite.runModelOnImage(
      path: imageFile.path,
      imageMean: 127.5,
      imageStd: 127.5,
      numResults: 2,
      threshold: 0.1,
    );

    if (predictions != null && predictions.isNotEmpty) {
      setState(() {
        output = predictions.map((p) => p['label']).join(', ');
      });
    } else {
      setState(() {
        output = "No predictions";
      });
    }
  }

  Future<void> selectImage() async {
    final ImagePicker _picker = ImagePicker();
    final XFile? image = await _picker.pickImage(source: ImageSource.camera);
    if (image != null) {
      setState(() {
        selectedImage = File(image.path);
        runModelOnImage(selectedImage!);
      });
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live Eye Stress Detection App')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.5,
              width: MediaQuery.of(context).size.width,
              child: cameraController == null || !cameraController!.value.isInitialized
                  ? const Center(child: CircularProgressIndicator())
                  : AspectRatio(
                      aspectRatio: cameraController!.value.aspectRatio,
                      child: CameraPreview(cameraController!),
                    ),
            ),
          ),
          if (selectedImage != null)
            Container(
              margin: const EdgeInsets.only(top: 20),
              child: Image.file(selectedImage!, height: 200, width: 200),
            ),
          Text(
            output.isNotEmpty ? output : 'No prediction yet',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          if (isModelLoading) const CircularProgressIndicator(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: selectImage,
                child: const Text('Select Image'),
              ),
              ElevatedButton(
                onPressed: takePhoto,
                child: const Text('Take Photo'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
