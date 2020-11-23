import 'package:flutter/material.dart';
import 'package:flutter_app_new/screens/cropping_screen.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import 'config.dart';
import 'dialogs/getPremiumAccount.dart';
import 'dialogs/referalCode.dart';
import 'dialogs/review.dart';

class SettingsMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 200,
      color: Colors.transparent, //could change this to Color(0xFF737373),
      //so you don't have to change MaterialApp canvasColor
      child: new Container(
          height: 200,
          decoration: new BoxDecoration(
              color: Colors.white,
              borderRadius: new BorderRadius.only(
                  topLeft: const Radius.circular(40.0),
                  topRight: const Radius.circular(40.0))),
          child: Stack(
            children: [
              Positioned(
                top: 15,
                right: 10,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: CircleAvatar(
                    child: Icon(
                      Icons.close,
                      color: Colors.black,
                    ),
                    backgroundColor: secondaryColor,
                  ),
                ),
              ),
              Positioned.fill(
                child: Container(
                  padding: const EdgeInsets.only(top: 70),
                  width: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      InkWell(
                        onTap: () {
                          // showDialog(context: context, child: PremiumDialogue());
                        },
                        child: buildField(
                            leading: FittedBox(
                              child: Container(
                                  height: 20,
                                  width: 20,
                                  child: Container(
                                      decoration: BoxDecoration(
                                          color: Colors.orange,
                                          borderRadius:
                                              BorderRadius.circular(15)),
                                      child: Icon(
                                        Icons.star,
                                        color: Colors.yellow,
                                        size: 20,
                                      ))),
                            ),
                            title: "Get Premium Account",
                            trailing: Icon(Icons.arrow_forward_ios_rounded)),
                      ),
                      Divider(
                        indent: 20,
                        endIndent: 20,
                        thickness: 1.5,
                      ),
                      // InkWell(
                      //   onTap: () {
                      //     showDialog(context: context, child: ReferalCode());
                      //   },
                      //   child: buildField(
                      //       leading: FittedBox(
                      //         child: Container(
                      //             height: 20,
                      //             width: 20,
                      //             child: Image.asset(
                      //               "assets/images/group.png",
                      //             )),
                      //       ),
                      //       title: "Enter referral code",
                      //       trailing: Icon(Icons.arrow_forward_ios_rounded)),
                      // ),
                      // Divider(
                      //   indent: 20,
                      //   endIndent: 20,
                      //   thickness: 1.5,
                      // ),
                      // InkWell(
                      //   onTap: () {
                      //     showDialog(context: context, child: Review());
                      //   },
                      //   child: buildField(
                      //       leading: FittedBox(
                      //         child: Container(
                      //             height: 20,
                      //             width: 20,
                      //             child: Image.asset(
                      //               "assets/images/send.png",
                      //             )),
                      //       ),
                      //       title: "Share with your friend or free premium"),
                      // ),
                      // Divider(
                      //   indent: 20,
                      //   endIndent: 20,
                      //   thickness: 1.5,
                      // ),
                      // buildField(
                      //     leading: FittedBox(
                      //       child: Container(
                      //           height: 20,
                      //           width: 20,
                      //           child: Icon(
                      //             Icons.notifications_none,
                      //             color: Colors.black,
                      //             size: 20,
                      //           )),
                      //     ),
                      //     title: "Notifications",
                      //     trailing: buildSwitch()),
                      // Divider(
                      //   indent: 20,
                      //   endIndent: 20,
                      //   thickness: 1.5,
                      // ),
                      buildField(
                          leading: FittedBox(
                            child: Container(
                                height: 20,
                                width: 20,
                                child: Image.asset(
                                  "assets/images/moon.png",
                                )),
                          ),
                          title: "Dark Mode",
                          trailing: buildSwitch()),
                      // Card(
                      //   elevation: 5,
                      //   margin: const EdgeInsets.all(20),
                      //   shape: RoundedRectangleBorder(
                      //       borderRadius: BorderRadius.circular(10)),
                      //   child: Column(
                      //     children: [
                      //       SizedBox(
                      //         height: 10,
                      //       ),
                      //       Text(
                      //         "Rate Us",
                      //         style:
                      //             TextStyle(color: primaryColor, fontSize: 16),
                      //       ),
                      //       // buildRating(),
                      //       SizedBox(
                      //         height: 10,
                      //       )
                      //     ],
                      //   ),
                      // )
                    ],
                  ),
                ),
              )
            ],
          )),
    );
  }

  Switch buildSwitch() {
    return Switch.adaptive(
      activeTrackColor: primaryColor,
      focusColor: primaryColor,
      activeColor: primaryColor,
      value: true,
      onChanged: (value) {},
    );
  }

  RatingBar buildRating() {
    return RatingBar.builder(
      initialRating: 4,
      minRating: 1,
      direction: Axis.horizontal,
      allowHalfRating: true,
      itemCount: 5,
      itemPadding: EdgeInsets.symmetric(horizontal: 4.0),
      itemBuilder: (context, _) => Icon(
        Icons.star,
        color: primaryColor,
      ),
      onRatingUpdate: (rating) {
        print(rating);
      },
    );
  }

  Widget buildField({Widget leading, String title, Widget trailing}) {
    return Container(
      height: 50,
      padding: const EdgeInsets.only(left: 20, bottom: 5),
      child: Row(
        children: [
          leading,
          Container(
              padding: const EdgeInsets.only(left: 20), child: Text(title)),
          if (trailing != null) ...trailingWidgets(trailing)
        ],
      ),
    );
  }

  List<Widget> trailingWidgets(Widget trailing) {
    return [
      Spacer(),
      trailing,
      SizedBox(
        width: 10,
      )
    ];
  }
}
