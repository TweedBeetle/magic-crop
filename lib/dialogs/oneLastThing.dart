import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

typedef void ResultHandler(bool result);

class OneLastThingDialogue extends StatelessWidget {
  ResultHandler resultHandler;
  TextEditingController widthController = TextEditingController();
  TextEditingController heightController = TextEditingController();

  OneLastThingDialogue(this.resultHandler);

  @override
  Widget build(BuildContext context) {
    var no = Container(
      width: 100,
      padding: const EdgeInsets.only(left: 10),
      child: ElevatedButton(
        onPressed: () {
          resultHandler(false);
          Navigator.of(context).pop();
        },
        style: ElevatedButton.styleFrom(primary: Colors.blueAccent),
        child: Text("No thanks"),
      ),
    );
    var yes = Container(
      padding: const EdgeInsets.only(left: 10),
      width: 100,
      child: ElevatedButton(
        onPressed: () {
          resultHandler(true);
          Navigator.of(context).pop();
        },
        style: ElevatedButton.styleFrom(primary: Colors.blueAccent),
        child: Text("Yes please!"),
      ),
    );
    return AlertDialog(
      content: Text(
        "Don't you think your photo would look amazing after you use this amazing app on it??",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      actions: [no, yes],
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
