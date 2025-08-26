import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';
import 'package:another_flushbar/flushbar_helper.dart'; // For FlushbarStatus

// MessageType enum ကို CustomDialogs class အပြင်ဘက်မှာ define လုပ်ပါ။
enum MessageType {
  success,
  error,
  info,
}

class CustomDialogs {
  static void showAlertDialog(BuildContext context, String title, String message, {VoidCallback? onConfirm}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (onConfirm != null) {
                  onConfirm();
                }
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // showConfirmDialog ကို showConfirmationDialog အဖြစ် ပြောင်းထားပါသည်။
  static Future<bool?> showConfirmationDialog(BuildContext context, String title, String message) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('မလုပ်တော့ပါ'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('လုပ်ဆောင်မည်'),
            ),
          ],
        );
      },
    );
  }

  // showFlushbar method တွင် MessageType parameter ထပ်ပေါင်းထားပါသည်။
  static void showFlushbar(BuildContext context, String title, String message, MessageType type, {VoidCallback? onDismissed}) {
    Color backgroundColor;
    IconData iconData;
    Color iconColor;

    switch (type) {
      case MessageType.success:
        backgroundColor = Colors.green;
        iconData = Icons.check_circle_outline;
        iconColor = Colors.white;
        break;
      case MessageType.error:
        backgroundColor = Colors.red;
        iconData = Icons.error_outline;
        iconColor = Colors.white;
        break;
      case MessageType.info:
        backgroundColor = Colors.blue;
        iconData = Icons.info_outline;
        iconColor = Colors.white;
        break;
    }

    Flushbar(
      title: title,
      message: message,
      icon: Icon(iconData, size: 28.0, color: iconColor),
      duration: const Duration(seconds: 3),
      leftBarIndicatorColor: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      margin: const EdgeInsets.all(8),
      flushbarPosition: FlushbarPosition.TOP,
      onStatusChanged: (status) {
        if (status == FlushbarStatus.DISMISSED && onDismissed != null) {
          onDismissed();
        }
      },
    ).show(context);
  }

  static void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text("လုပ်ဆောင်နေပါသည်..."),
            ],
          ),
        );
      },
    );
  }
}
