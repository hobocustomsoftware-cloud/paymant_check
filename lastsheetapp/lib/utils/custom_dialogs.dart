import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:another_flushbar/flushbar.dart';

// MessageType enum ကို CustomDialogs class အပြင်ဘက်မှာ define လုပ်ပါ။
enum MessageType { success, error, info }

class CustomDialogs {
  static Color _color(MessageType t) {
    switch (t) {
      case MessageType.success:
        return Colors.green;
      case MessageType.error:
        return Colors.redAccent;
      case MessageType.info:
        return Colors.blueGrey;
    }
  }

  static void showAlertDialog(
    BuildContext context,
    String title,
    String message, {
    VoidCallback? onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
  static Future<bool?> showConfirmationDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('လုပ်ဆောင်မည်'),
            ),
          ],
        );
      },
    );
  }

  // showFlushbar method တွင် MessageType parameter ထပ်ပေါင်းထားပါသည်။
  static void showFlushbar(
    BuildContext context,
    String title,
    String message,
    MessageType type, {
    Duration? duration,
    VoidCallback? onDismissed,
  }) {
    final d =
        duration ??
        (type == MessageType.error
            ? const Duration(seconds: 4)
            : const Duration(seconds: 2));

    if (kIsWeb) {
      // ✅ Web: SnackBar သာ သုံး — URL hash မပြောင်းတော့
      final bg = _color(type);
      final scaffold = ScaffoldMessenger.of(context);
      scaffold
          .showSnackBar(
            SnackBar(
              content: Text(
                '$title: $message',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              backgroundColor: bg,
              duration: d,
              behavior: SnackBarBehavior.floating,
              showCloseIcon: true,
            ),
          )
          .closed
          .then((_) {
            if (onDismissed != null) onDismissed();
          });

      return;
    }

    // ✅ App platforms: Flushbar ဆက်သုံး
    Flushbar? fb; // capture instance to dismiss safely
    fb =
        Flushbar(
              title: title,
              message: message,
              backgroundColor: _color(type),
              duration: d,
              flushbarPosition: FlushbarPosition.TOP,
              margin: const EdgeInsets.all(12),
              borderRadius: BorderRadius.circular(8),
              onStatusChanged: (status) {
                if (status == FlushbarStatus.DISMISSED && onDismissed != null) {
                  onDismissed();
                }
              },
              mainButton: TextButton(
                onPressed: () => fb?.dismiss(), // ✅ just dismiss flushbar
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ).show(context)
            as Flushbar?;
  }

  static void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true, // ✅ nested navigators safe
      builder: (ctx) {
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

  // ✅ new: easy close
  static void hideLoadingDialog(BuildContext context) {
    if (Navigator.canPop(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
