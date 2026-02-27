import 'dart:math';

class Detection {
  final String label;
  final double confidence;
  final double xmin;
  final double ymin;
  final double xmax;
  final double ymax;

  Detection({
    required this.label,
    required this.confidence,
    required this.xmin,
    required this.ymin,
    required this.xmax,
    required this.ymax,
  });

  double get area => (xmax - xmin) * (ymax - ymin);
  double get centerX => (xmin + xmax) / 2;
  double get centerY => (ymin + ymax) / 2;

  String get zone {
    if (centerX < 0.33) return 'LEFT';
    if (centerX > 0.66) return 'RIGHT';
    return 'CENTER';
  }

  String direction(String lang) {
    if (zone == 'LEFT') {
      if (lang == 'hi') return 'बाईं ओर';
      if (lang == 'mr') return 'डावीकडे';
      return 'on the left';
    }
    if (zone == 'RIGHT') {
      if (lang == 'hi') return 'दाईं ओर';
      if (lang == 'mr') return 'उजवीकडे';
      return 'on the right';
    }
    if (lang == 'hi') return 'ठीक सामने';
    if (lang == 'mr') return 'थेट समोर';
    return 'straight ahead';
  }

  String distanceTier(String lang) {
    if (area > 0.5) {
      if (lang == 'hi') return 'बहुत करीब';
      if (lang == 'mr') return 'खूप जवळ';
      return 'very close';
    }
    if (area > 0.25) {
      if (lang == 'hi') return 'करीब';
      if (lang == 'mr') return 'जवळ';
      return 'close';
    }
    if (area > 0.1) {
      if (lang == 'hi') return 'आसपास';
      if (lang == 'mr') return 'आसपास';
      return 'nearby';
    }
    if (lang == 'hi') return 'दूर';
    if (lang == 'mr') return 'दूर';
    return 'far';
  }

  int get urgency {
    int u = 1;
    if (area > 0.5) {
      u = 4;
    } else if (area > 0.25) {
      u = 3;
    } else if (area > 0.1) {
      u = 2;
    }
    // Boost urgency if it's dead center and close
    if (zone == 'CENTER' && u < 4 && u >= 2) {
      u += 1;
    }
    return u;
  }

  String actionPhrase(String lang) {
    String dir = direction(lang);
    String dist = distanceTier(lang);
    
    // Check if it's "very close" based on english map
    // Because checking translated strings is messy, grab english mapping:
    String distEn = distanceTier('en');

    if (distEn == 'very close') {
      if (zone == 'CENTER') {
        if (lang == 'hi') return 'तुरंत रुकें, $label $dir $dist है।';
        if (lang == 'mr') return 'ताबडतोब थांबा, $label $dir $dist आहे.';
        return 'Stop immediately, $label very close straight ahead.';
      }
      if (lang == 'hi') return 'सावधान, $label $dir $dist है।';
      if (lang == 'mr') return 'सावधान, $label $dir $dist आहे.';
      return 'Caution, $label very close $dir.';
    }
    
    if (lang == 'hi') return '$label $dir $dist है।';
    if (lang == 'mr') return '$label $dir $dist आहे.';
    return '$label is $dist $dir.';
  }

  String toAlertMessage(String lang) {
    return actionPhrase(lang);
  }
}

double computeIoU(Detection a, Detection b) {
  double intersectionXMin = max(a.xmin, b.xmin);
  double intersectionYMin = max(a.ymin, b.ymin);
  double intersectionXMax = min(a.xmax, b.xmax);
  double intersectionYMax = min(a.ymax, b.ymax);

  double intersectionWidth = max(0, intersectionXMax - intersectionXMin);
  double intersectionHeight = max(0, intersectionYMax - intersectionYMin);
  double intersectionArea = intersectionWidth * intersectionHeight;

  double unionArea = a.area + b.area - intersectionArea;

  if (unionArea <= 0) return 0.0;
  return intersectionArea / unionArea;
}

List<Detection> nms(List<Detection> detections, double iouThreshold) {
  detections.sort((a, b) => b.confidence.compareTo(a.confidence));
  List<Detection> selected = [];

  for (var detection in detections) {
    bool shouldSelect = true;
    for (var selectedDetection in selected) {
      if (computeIoU(detection, selectedDetection) > iouThreshold) {
        shouldSelect = false;
        break;
      }
    }
    if (shouldSelect) {
      selected.add(detection);
    }
  }

  return selected;
}
