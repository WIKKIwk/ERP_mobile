import '../gscale_mobile_app.dart';
import 'package:flutter/material.dart';

class GScaleModeScreen extends StatelessWidget {
  const GScaleModeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GScaleMobileApp(
      onExitMode: () async {
        Navigator.of(context).pop();
      },
    );
  }
}
