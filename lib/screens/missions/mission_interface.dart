import 'package:flutter/material.dart';

abstract class MissionWidget extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onSkip;

  const MissionWidget({
    Key? key,
    required this.onSuccess,
    required this.onSkip,
  }) : super(key: key);
}
