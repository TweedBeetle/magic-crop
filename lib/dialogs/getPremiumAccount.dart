import 'package:firebase_admob/firebase_admob.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

import '../config.dart';
import '../screens/cropping_screen.dart';

class PremiumDialogue extends StatefulWidget {
  // BuildContext context;
  bool _rewardedAdReady;

  PremiumDialogue(this._rewardedAdReady);

  @override
  _PremiumDialogueState createState() =>
      _PremiumDialogueState(this._rewardedAdReady);
}

class _PremiumDialogueState extends State<PremiumDialogue> {
  bool _rewardedAdReady;

  _PremiumDialogueState(this._rewardedAdReady) {
    print('_rewardedAdReady $_rewardedAdReady');
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Container(
        height: 366,
        // padding: EdgeInsets.symmetric(vertical: 20),
        width: MediaQuery.of(context).size.width * 0.9,
        child: Stack(
          children: [
            Positioned(
              top: 15,
              right: 10,
              child: InkWell(
                onTap: () {
                  FirebaseAnalytics()
                      .logEvent(name: 'premium_popup_close', parameters: null);
                  Navigator.of(context).pop();
                },
                child: Container(
                  height: 30,
                  width: 30,
                  child: CircleAvatar(
                    child: Icon(
                      Icons.close,
                      color: Colors.black,
                    ),
                    backgroundColor: secondaryColor,
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 10,
                ),
                Container(
                  alignment: Alignment.center,
                  child: Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(25)),
                    child: Container(
                        decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(25)),
                        child: Container(
                            margin: const EdgeInsets.all(5.0),
                            child: Icon(
                              MdiIcons.crown,
                              color: Colors.yellow,
                              size: 50,
                            ))),
                  ),
                ),

                SizedBox(
                  height: 10,
                ),

                Text(
                  "Premium features ",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(
                  height: 5,
                ),

                // Text("\$2", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor), textAlign: TextAlign.center,),

                SizedBox(
                  height: 10,
                ),

                buildField(title: "Rescaling to scales other than 1:1"),
                buildField(title: "50 % better image resolution"),
                buildField(title: "No ads"),

                SizedBox(
                  height: 10,
                ),
                buildVideoAdOffer(context, _rewardedAdReady),
                SizedBox(
                  height: 10,
                ),

                Container(
                  height: 50,
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  child: RaisedButton(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    color: primaryColor,
                    onPressed: () {
                      FirebaseAnalytics()
                          .logEvent(name: 'IAP_init', parameters: null);
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      child: Center(
                          child: Text(
                        "GET PREMIUM FOREVER",
                        style: TextStyle(color: Colors.white),
                      )),
                      // padding: const EdgeInsets.only(right: 30),
                    ),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}

buildVideoAdOffer(BuildContext context, bool _rewardedAdReady) {
  return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        if (_rewardedAdReady) {
          RewardedVideoAd.instance
              .show(); // TODO: why doesn't this whole thing update once _rewardedAdReady changes?
        }
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20),
        padding: EdgeInsets.only(left: 10, right: 10),
        decoration: BoxDecoration(
            color: secondaryColor, borderRadius: BorderRadius.circular(10)),
        height: 60,
        child: Container(
            child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Image.asset("assets/images/youtube.png", height: 30, color: primaryColor,),
            Icon(Icons.ondemand_video, color: primaryColor, size: 30),
            // SizedBox(
            //   width: 15,
            // ),
            Container(
                child: Text(
              "Get premium for this session",
              // maxLines: 2,
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: primaryColor),
            )),
            _rewardedAdReady
                ? Icon(Icons.ondemand_video, color: primaryColor, size: 30)
                : CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(primaryColor))
          ],
        )),
      ));
}

Widget buildField({String title}) {
  return Container(
    height: 30,
    child: Row(
      children: [
        SizedBox(
          width: 20,
        ),
        Icon(
          Icons.check_circle,
          color: primaryColor,
        ),
        SizedBox(
          width: 10,
        ),
        Text(title)
      ],
    ),
  );
}
