import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class AppColors {
  static const primaryColor = Color(0xFF19E6C1);
  static const blackColor = Colors.black;
}

void showCustomToast({
  required String message,
  Color backgroundColor = AppColors.primaryColor,
  Color textColor = AppColors.blackColor,
  ToastGravity gravity = ToastGravity.BOTTOM,
  Toast toastLength = Toast.LENGTH_SHORT,
  double fontSize = 16.0,
}) {
  if (message.trim().isEmpty) return;

  Fluttertoast.showToast(
    msg: message,
    toastLength: toastLength,
    gravity: gravity,
    timeInSecForIosWeb: 1,
    backgroundColor: backgroundColor,
    textColor: textColor,
    fontSize: fontSize,
  );
}
