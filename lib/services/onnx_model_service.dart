import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:onnxruntime_v2/onnxruntime_v2.dart';
import '../models/detection.dart';

class OnnxModelService {
  OrtSession? _session;
  bool _isInit = false;

  final double confidenceThreshold = 0.20; 
  final double iouThreshold = 0.45;
  final int inputSize = 640;

  static const List<String> _cocoLabels = [
    'person', 'bicycle', 'car', 'motorcycle', 'airplane',
    'bus', 'train', 'truck', 'boat', 'traffic light',
    'fire hydrant', 'stop sign', 'parking meter', 'bench', 'bird',
    'cat', 'dog', 'horse', 'sheep', 'cow',
    'elephant', 'bear', 'zebra', 'giraffe', 'backpack',
    'umbrella', 'handbag', 'tie', 'suitcase', 'frisbee',
    'skis', 'snowboard', 'sports ball', 'kite', 'baseball bat',
    'baseball glove', 'skateboard', 'surfboard', 'tennis racket', 'bottle',
    'wine glass', 'cup', 'fork', 'knife', 'spoon',
    'bowl', 'banana', 'apple', 'sandwich', 'orange',
    'broccoli', 'carrot', 'hot dog', 'pizza', 'donut',
    'cake', 'chair', 'couch', 'potted plant', 'bed',
    'dining table', 'toilet', 'tv', 'laptop', 'mouse',
    'remote', 'keyboard', 'cell phone', 'microwave', 'oven',
    'toaster', 'sink', 'refrigerator', 'book', 'clock',
    'vase', 'scissors', 'teddy bear', 'hair drier', 'toothbrush',
  ];

  static const Set<String> _relevantLabels = {
    'person', 'bicycle', 'car', 'motorcycle', 'bus', 'truck',
    'traffic light', 'fire hydrant', 'stop sign', 'bench',
    'cat', 'dog', 'horse', 'chair', 'couch', 'bed',
    'dining table', 'toilet', 'tv', 'laptop', 'cell phone',
    'potted plant', 'suitcase', 'backpack', 'umbrella', 'bottle', 'book',
    'refrigerator', 'microwave', 'oven', 'sink', 'clock',
    'vase', 'bowl', 'cup', 'knife', 'fork', 'spoon',
    'mouse', 'keyboard', 'remote',
  };

  static const Map<String, double> _classThresholds = {
    'person':        0.30,
    'laptop':        0.15,
    'cell phone':    0.20,
    'tv':            0.25,
    'keyboard':      0.15,
    'book':          0.20,
    'refrigerator':  0.30,
    'chair':         0.20,
    'couch':         0.20,
    'bed':           0.20,
    'dining table':  0.20,
    'bottle':        0.20,
    'cup':           0.20,
    'bowl':          0.20,
    'car':           0.30,
    'bus':           0.30,
    'truck':         0.30,
    'dog':           0.25,
    'cat':           0.25,
    'backpack':      0.20,
    'umbrella':      0.20,
    'suitcase':      0.20,
    'bench':         0.20,
    'potted plant':  0.20,
    'sink':          0.20,
    'toilet':        0.20,
    'microwave':     0.25,
    'oven':          0.25,
    'clock':         0.20,
    'vase':          0.20,
    'remote':        0.20,
    'mouse':         0.15,
  };
  static const double _defaultThreshold = 0.15;

  bool get isReady => _isInit && _session != null;

  Future<void> initModel() async {
    try {
      debugPrint("OnnxModelService: initModel() started");
      OrtEnv.instance.init();
      
      // Fallback to yolov8n if yolov8s is not found to ensure app runs for diagnosis
      String modelPath = 'assets/models/yolov8s.onnx';
      ByteData? modelData;
      try {
        modelData = await rootBundle.load(modelPath);
      } catch (e) {
        debugPrint("yolov8s.onnx not found, falling back to yolov8n.onnx");
        modelPath = 'assets/models/yolov8n.onnx';
        modelData = await rootBundle.load(modelPath);
      }

      final bytes = modelData.buffer.asUint8List(modelData.offsetInBytes, modelData.lengthInBytes);
      debugPrint('Model path: $modelPath');
      debugPrint('MODEL SIZE: ${bytes.length} bytes');
      if (bytes.length < 15000000) {
        debugPrint('WARNING: This appears to be yolov8n not yolov8s!');
      }
      
      final sessionOptions = OrtSessionOptions();
      _session = OrtSession.fromBuffer(bytes, sessionOptions);
      
      debugPrint('Model input names: ${_session!.inputNames}');
      debugPrint('Model output names: ${_session!.outputNames}');
      
      _isInit = true;
      debugPrint("OnnxModelService: Model loaded successfully");
    } catch (e) {
      debugPrint("OnnxModelService: Model init error -> $e");
    }
  }

  Future<List<Detection>> detect(CameraImage image) async {
    if (!isReady) return [];

    try {
      // FIX: Rotate sensor dimensions 90-deg clockwise for portrait inference
      final int rotatedWidth = image.height;
      final int rotatedHeight = image.width;
      
      double scale = min(inputSize / rotatedWidth, inputSize / rotatedHeight);
      int scaledW = (rotatedWidth * scale).round();
      int scaledH = (rotatedHeight * scale).round();
      int padLeft = (inputSize - scaledW) ~/ 2;
      int padTop = (inputSize - scaledH) ~/ 2;

      Float32List inputData = preprocessFrame(image, scale, padLeft, padTop);

      final runOptions = OrtRunOptions();
      final inputTensor = OrtValueTensor.createTensorWithDataList(
        inputData,
        [1, 3, inputSize, inputSize],
      );

      final inputs = {'images': inputTensor};
      final outputs = await _session!.runAsync(runOptions, inputs);
      
      inputTensor.release();
      runOptions.release();

      final outputValue = outputs?[0];
      if (outputValue == null || outputValue.value is! List) {
        if (outputs != null) for (var item in outputs) item?.release();
        return [];
      }

      final List<dynamic> outputList = outputValue.value as List<dynamic>;
      if (outputs != null) for (var item in outputs) item?.release();
      
      final List<dynamic> rawDataDims = outputList[0] as List<dynamic>; 
      int numBoxes = (rawDataDims[0] as List).length;
      int numClasses = 80;

      List<Detection> rawDetections = [];
      for (int i = 0; i < numBoxes; i++) {
        double maxConf = 0;
        int maxClassId = -1;

        for (int c = 0; c < numClasses; c++) {
          double conf = (rawDataDims[c + 4][i] as num).toDouble();
          if (conf > maxConf) {
            maxConf = conf;
            maxClassId = c;
          }
        }

        double classThreshold = _classThresholds[_cocoLabels[maxClassId]] ?? _defaultThreshold;
        if (maxConf >= classThreshold && maxClassId != -1) {
          String label = _cocoLabels[maxClassId];
          double cxIdx = (rawDataDims[0][i] as num).toDouble();
          double cyIdx = (rawDataDims[1][i] as num).toDouble();
          double wIdx = (rawDataDims[2][i] as num).toDouble();
          double hIdx = (rawDataDims[3][i] as num).toDouble();

          rawDetections.add(Detection(
            label: label,
            confidence: maxConf,
            xmin: ((cxIdx - wIdx / 2) / inputSize).clamp(0.0, 1.0),
            ymin: ((cyIdx - hIdx / 2) / inputSize).clamp(0.0, 1.0),
            xmax: ((cxIdx + wIdx / 2) / inputSize).clamp(0.0, 1.0),
            ymax: ((cyIdx + hIdx / 2) / inputSize).clamp(0.0, 1.0),
          ));
        }
      }

      final nmsRes = nms(rawDetections, iouThreshold);
      final filtered = nmsRes.where((d) => _relevantLabels.contains(d.label)).toList();

      return filtered;
    } catch (e) {
      debugPrint("OnnxModelService: Inference error -> $e");
      return [];
    }
  }

  Float32List preprocessFrame(CameraImage image, double scale, int padLeft, int padTop) {
    final Float32List inputData = Float32List(3 * inputSize * inputSize);
    inputData.fillRange(0, inputData.length, 0.5);

    // FIX: Preprocess with 90-degree clockwise rotation
    final int rotatedWidth = image.height;
    final int rotatedHeight = image.width;
    final int sensorWidth = image.width;
    final int sensorHeight = image.height;
    final Uint8List bytes = image.planes[0].bytes;
    final int rowStride = image.planes[0].bytesPerRow;

    final int ySize = rowStride * sensorHeight;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        int sX = x - padLeft;
        int sY = y - padTop;

        if (sX < 0 || sX >= (rotatedWidth * scale).round() ||
            sY < 0 || sY >= (rotatedHeight * scale).round()) continue;

        // Coordinates in the rotated target space
        int rotX = (sX / scale).round().clamp(0, rotatedWidth - 1);
        int rotY = (sY / scale).round().clamp(0, rotatedHeight - 1);

        // Map rotated coords back to original sensor coords (90 deg clockwise)
        int oX = rotY;
        int oY = sensorHeight - 1 - rotX;

        // Y index (sensor coords)
        int yIdx = oY * rowStride + oX;

        // VU index in NV21
        int vuRow = oY ~/ 2;
        int vuCol = (oX ~/ 2) * 2;
        int vuIdx = ySize + vuRow * rowStride + vuCol;

        if (yIdx >= bytes.length || vuIdx + 1 >= bytes.length) continue;

        final int yVal = bytes[yIdx] & 0xFF;
        final int vVal = (bytes[vuIdx] & 0xFF) - 128;     // V first in NV21
        final int uVal = (bytes[vuIdx + 1] & 0xFF) - 128; // U second in NV21

        final int r = (yVal + 1.370705 * vVal).round().clamp(0, 255);
        final int g = (yVal - 0.337633 * uVal - 0.698001 * vVal).round().clamp(0, 255);
        final int b = (yVal + 1.732446 * uVal).round().clamp(0, 255);

        int pixIdx = y * inputSize + x;
        inputData[pixIdx] = r / 255.0;
        inputData[inputSize * inputSize + pixIdx] = g / 255.0;
        inputData[2 * inputSize * inputSize + pixIdx] = b / 255.0;
      }
    }

    // Verify center pixel
    int cIdx = (inputSize ~/ 2) * inputSize + (inputSize ~/ 2);
    debugPrint('CENTER PIXEL RGB: '
      'R=${inputData[cIdx].toStringAsFixed(3)} '
      'G=${inputData[inputSize*inputSize+cIdx].toStringAsFixed(3)} '
      'B=${inputData[2*inputSize*inputSize+cIdx].toStringAsFixed(3)}');
    // If still 0.500 → bytes.length check:
    debugPrint('PLANE bytes.length=${bytes.length} expected=${rowStride * sensorHeight + rowStride * sensorHeight ~/ 2}');

    return inputData;
  }

  List<Detection> nms(List<Detection> detections, double iouThreshold) {
    if (detections.isEmpty) return [];
    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    final List<Detection> selected = [];
    final List<bool> isActive = List.filled(detections.length, true);
    for (int i = 0; i < detections.length; i++) {
      if (isActive[i]) {
        selected.add(detections[i]);
        for (int j = i + 1; j < detections.length; j++) {
          if (isActive[j]) {
            if (_calculateIoU(detections[i], detections[j]) > iouThreshold) {
              isActive[j] = false;
            }
          }
        }
      }
    }
    return selected;
  }

  double _calculateIoU(Detection a, Detection b) {
    double x1 = max(a.xmin, b.xmin);
    double y1 = max(a.ymin, b.ymin);
    double x2 = min(a.xmax, b.xmax);
    double y2 = min(a.ymax, b.ymax);
    double intersectionArea = max(0, x2 - x1) * max(0, y2 - y1);
    double areaA = (a.xmax - a.xmin) * (a.ymax - a.ymin);
    double areaB = (b.xmax - b.xmin) * (b.ymax - b.ymin);
    return intersectionArea / (areaA + areaB - intersectionArea);
  }

  void dispose() {
    _session?.release();
    OrtEnv.instance.release();
    _isInit = false;
  }
}
