import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef void AspectRatioHandler(String width, String height);

class AspectDialog extends StatelessWidget {
  AspectRatioHandler aspectRatioHandler;
  TextEditingController widthController = TextEditingController();
  TextEditingController heightController = TextEditingController();

  AspectDialog({this.aspectRatioHandler});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 20,
          ),
          Text(
            "Enter a custom aspect ratio",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(
            height: 30,
          ),
          Container(
            height: 150,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      buildTiles(title: "width", controller: widthController),
                      Container(
                        width: 100,
                        padding: const EdgeInsets.only(left: 10),
                        child: ElevatedButton(
                          onPressed: () {
                            FirebaseAnalytics().logEvent(
                                name: 'custom_ratio_cancel', parameters: null);

                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                              primary: Colors.blueAccent),
                          child: Text("Cancel"),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                    padding: const EdgeInsets.only(bottom: 100),
                    alignment: Alignment.center,
                    child: Text(
                      ":",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    )),
                Expanded(
                  child: Column(
                    children: [
                      buildTiles(title: "height", controller: heightController),
                      Container(
                        padding: const EdgeInsets.only(left: 10),
                        width: 100,
                        child: ElevatedButton(
                          onPressed: () {
                            aspectRatioHandler(
                                widthController.text, heightController.text);
                            Navigator.of(context).pop();
                          },
                          style: ElevatedButton.styleFrom(
                              primary: Colors.blueAccent),
                          child: Text("Ok"),
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
          SizedBox(
            height: 10,
          )
        ],
      ),
    );
  }

  Widget buildTiles({String title, TextEditingController controller}) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            child: TextFormField(
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly
              ],
              textAlign: TextAlign.center,
              controller: controller,
              decoration: InputDecoration(
                  contentPadding: EdgeInsets.zero,
                  focusedBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.zero),
                  errorBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.zero),
                  enabledBorder:
                      OutlineInputBorder(borderRadius: BorderRadius.zero)),
            ),
          ),
          SizedBox(
            height: 3,
          ),
          Text(title)
        ],
      ),
    );
  }
}
